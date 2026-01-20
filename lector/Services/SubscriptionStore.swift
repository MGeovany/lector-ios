import Combine
import Foundation
import StoreKit
import UIKit

enum SubscriptionPlan: String, CaseIterable, Equatable, Hashable, Identifiable {
  case free
  case proMonthly
  case proYearly
  case founderLifetime

  var id: String { rawValue }

  var isPremium: Bool {
    switch self {
    case .free: return false
    case .proMonthly, .proYearly, .founderLifetime: return true
    }
  }

  var isPro: Bool {
    switch self {
    case .proMonthly, .proYearly: return true
    default: return false
    }
  }

  var isFounder: Bool {
    self == .founderLifetime
  }
}

enum BillingCycle: String, CaseIterable, Equatable {
  case monthly
  case yearly
}

final class SubscriptionStore: ObservableObject {
  private let persistToDefaults: Bool

  @Published var plan: SubscriptionPlan {
    didSet {
      guard persistToDefaults else { return }
      UserDefaults.standard.set(plan.rawValue, forKey: Self.planKey)
      // Back-compat: older builds used a boolean.
      UserDefaults.standard.set(plan.isPremium, forKey: Self.legacyIsPremiumKey)
    }
  }

  @Published private(set) var isPurchasing: Bool = false
  @Published private(set) var lastErrorMessage: String?
  @Published private(set) var expirationDate: Date?
  @Published private(set) var isAutoRenewable: Bool = false
  @Published private(set) var nextPlan: SubscriptionPlan?
  @Published private(set) var nextPlanStartDate: Date?

  @MainActor private let storeKit = StoreKitService()

  init(initialPlan: SubscriptionPlan? = nil, persistToDefaults: Bool = true) {
    self.persistToDefaults = persistToDefaults

    // Prefer explicit initial plan (useful for Previews/tests), otherwise load persisted plan.
    if let initialPlan {
      self.plan = initialPlan
    } else if let raw = UserDefaults.standard.string(forKey: Self.planKey),
      let plan = SubscriptionPlan(rawValue: raw)
    {
      self.plan = plan
    } else {
      let legacyPremium = UserDefaults.standard.bool(forKey: Self.legacyIsPremiumKey)
      self.plan = legacyPremium ? .proYearly : .free
      UserDefaults.standard.set(self.plan.rawValue, forKey: Self.planKey)
    }

    // Best-effort: sync entitlements at startup (skip in Xcode Previews).
    let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    if !isPreview {
      Task { await refreshFromStoreKit() }
    }
  }

  // MARK: - Derived state

  var isPremium: Bool { plan.isPremium }
  var isPro: Bool { plan.isPro }
  var isFounder: Bool { plan.isFounder }

  /// Free is capped. Pro/Founder have a higher cap. Backend must also enforce the same limits.
  var maxStorageBytes: Int64 {
    switch plan {
    case .free:
      return Int64(MAX_STORAGE_MB) * 1024 * 1024
    case .proMonthly, .proYearly, .founderLifetime:
      // Use decimal GB for UX consistency (50GB = 50,000,000,000 bytes).
      return Int64(MAX_STORAGE_PRO_GB) * 1_000_000_000
    }
  }

  var maxStorageText: String {
    switch plan {
    case .free:
      return ByteCountFormatter.string(fromByteCount: maxStorageBytes, countStyle: .file)
    case .proMonthly, .proYearly, .founderLifetime:
      return "\(MAX_STORAGE_PRO_GB) GB"
    }
  }

  /// If Pro is active and auto-renewable, returns remaining whole days until expiration/renewal.
  var remainingDaysInPeriod: Int? {
    guard isAutoRenewable, let expirationDate else { return nil }
    let days =
      Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
      ?? 0
    return max(0, days)
  }

  // MARK: - Actions (StoreKit 2)

  @MainActor
  func purchase(_ newPlan: SubscriptionPlan) async {
    guard !isPurchasing else { return }
    isPurchasing = true
    lastErrorMessage = nil
    defer { isPurchasing = false }

    if newPlan == .free {
      setFree()
      return
    }

    do {
      #if DEBUG
        // If the user is "ignoring" Founder in debug, un-ignore before attempting to buy it.
        if newPlan == .founderLifetime {
          StoreKitService.debugIgnoreFounderEntitlement = false
        }
      #endif
      try await storeKit.loadProducts()
      let ent = try await storeKit.purchase(plan: newPlan)
      apply(entitlement: ent)
    } catch {
      lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Purchase failed."
    }
  }

  func setFree() {
    plan = .free
    expirationDate = nil
    isAutoRenewable = false
    nextPlan = nil
    nextPlanStartDate = nil
  }

  func upgradeToPremium() {
    // Backward-compatible call site: default to yearly Pro.
    plan = .proYearly
  }

  func downgradeToFree() {
    plan = .free
  }

  @MainActor
  func restorePurchases() async {
    guard !isPurchasing else { return }
    isPurchasing = true
    lastErrorMessage = nil
    defer { isPurchasing = false }

    do {
      try await storeKit.restorePurchases()
      apply(entitlement: storeKit.entitlement)
    } catch {
      lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Restore failed."
    }
  }

  @MainActor
  func refreshFromStoreKit() async {
    do {
      try await storeKit.loadProducts()
    } catch {
      // Non-fatal (e.g., product IDs not set yet). Still try entitlements.
    }
    await storeKit.refreshEntitlements()
    apply(entitlement: storeKit.entitlement)
  }

  @MainActor
  func showManageSubscriptions() async {
    do {
      try await storeKit.showManageSubscriptions()
    } catch {
      lastErrorMessage =
        (error as? LocalizedError)?.errorDescription ?? "Couldn’t open subscriptions."
    }
  }

  #if DEBUG
    var debugIsIgnoringFounderPurchase: Bool {
      StoreKitService.debugIgnoreFounderEntitlement
    }

    /// Debug-only: "forget" Founder entitlement in-app (sandbox/local) so you can test Free/Pro flows.
    /// Note: StoreKit non-consumables can't be truly "cancelled" via API; this is an app-side override.
    @MainActor
    func debugSetIgnoreFounderPurchase(_ ignore: Bool) async {
      StoreKitService.debugIgnoreFounderEntitlement = ignore
      await refreshFromStoreKit()
    }
  #endif

  @MainActor
  func priceText(for plan: SubscriptionPlan) -> String? {
    guard let product = storeKit.productsByPlan[plan] else { return nil }
    return product.displayPrice
  }

  private func apply(entitlement: StoreKitService.Entitlement) {
    plan = entitlement.plan
    expirationDate = entitlement.expirationDate
    isAutoRenewable = entitlement.isAutoRenewable
    nextPlan = storeKit.nextEntitlementPlanChange?.nextPlan
    nextPlanStartDate = storeKit.nextEntitlementPlanChange?.effectiveDate
    Task { await syncPlanToBackendIfPossible() }
  }

  static let planKey = "lector_subscription_plan"
  static let legacyIsPremiumKey = "lector_isPremium"

  @MainActor
  private func syncPlanToBackendIfPossible() async {
    let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    guard !isPreview else { return }

    struct Body: Encodable {
      let subscription_plan: String
    }

    let api = APIClient()
    do {
      try await api.putJSON("preferences", body: Body(subscription_plan: backendPlanString))
    } catch {
      // Non-blocking: backend sync best-effort.
    }
  }

  private var backendPlanString: String {
    switch plan {
    case .free: return "free"
    case .proMonthly: return "pro_monthly"
    case .proYearly: return "pro_yearly"
    case .founderLifetime: return "founder_lifetime"
    }
  }
}

// MARK: - StoreKit 2

enum StoreKitServiceError: LocalizedError {
  case productIDsNotConfigured
  case productNotFound(String)
  case purchaseCancelled
  case purchasePending
  case purchaseUnverified

  var errorDescription: String? {
    switch self {
    case .productIDsNotConfigured:
      return "In‑app purchase product IDs are not configured. Add them to Info.plist."
    case .productNotFound(let id):
      return "Product not found: \(id)"
    case .purchaseCancelled:
      return "Purchase cancelled."
    case .purchasePending:
      return "Purchase pending approval."
    case .purchaseUnverified:
      return "Purchase could not be verified."
    }
  }
}

/// StoreKit 2 service that backs subscription UI and state.
@MainActor
final class StoreKitService: ObservableObject {
  #if DEBUG
    static let debugIgnoreFounderKey = "lector_debug_ignore_founder_entitlement"

    static var debugIgnoreFounderEntitlement: Bool {
      get { UserDefaults.standard.bool(forKey: debugIgnoreFounderKey) }
      set { UserDefaults.standard.set(newValue, forKey: debugIgnoreFounderKey) }
    }
  #endif

  struct ProductIDs: Equatable {
    let proMonthly: String
    let proYearly: String
    let founderLifetime: String
  }

  struct Entitlement: Equatable {
    let plan: SubscriptionPlan
    let expirationDate: Date?
    let isAutoRenewable: Bool
  }

  struct NextPlanChange: Equatable {
    let nextPlan: SubscriptionPlan
    let effectiveDate: Date?
  }

  @Published private(set) var productsByPlan: [SubscriptionPlan: Product] = [:]
  @Published private(set) var entitlement: Entitlement = .init(
    plan: .free, expirationDate: nil, isAutoRenewable: false)
  @Published private(set) var nextEntitlementPlanChange: NextPlanChange?

  private let productIDs: ProductIDs?

  init(productIDs: ProductIDs? = nil) {
    self.productIDs = productIDs ?? Self.loadProductIDsFromInfoPlist()
  }

  func loadProducts() async throws {
    guard let productIDs else { throw StoreKitServiceError.productIDsNotConfigured }
    let ids: [String] = [productIDs.proMonthly, productIDs.proYearly, productIDs.founderLifetime]

    let products = try await Product.products(for: ids)
    var map: [SubscriptionPlan: Product] = [:]
    for product in products {
      switch product.id {
      case productIDs.proMonthly:
        map[.proMonthly] = product
      case productIDs.proYearly:
        map[.proYearly] = product
      case productIDs.founderLifetime:
        map[.founderLifetime] = product
      default:
        break
      }
    }
    productsByPlan = map
  }

  func refreshEntitlements() async {
    let best = await Self.bestEntitlementFromCurrentEntitlements()
    entitlement = best ?? .init(plan: .free, expirationDate: nil, isAutoRenewable: false)
    nextEntitlementPlanChange = await computeNextPlanChange(current: entitlement)
  }

  func restorePurchases() async throws {
    try await AppStore.sync()
    await refreshEntitlements()
  }

  func purchase(plan: SubscriptionPlan) async throws -> Entitlement {
    guard plan != .free else {
      let free = Entitlement(plan: .free, expirationDate: nil, isAutoRenewable: false)
      entitlement = free
      return free
    }

    guard let product = productsByPlan[plan] else {
      // Try one lazy load before failing.
      try await loadProducts()
      guard let product = productsByPlan[plan] else {
        let expectedID = expectedProductID(for: plan) ?? plan.rawValue
        throw StoreKitServiceError.productNotFound(expectedID)
      }
      return try await purchaseProduct(product, expectedPlan: plan)
    }

    return try await purchaseProduct(product, expectedPlan: plan)
  }

  func showManageSubscriptions() async throws {
    guard
      let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene })
        as? UIWindowScene
    else {
      return
    }
    try await AppStore.showManageSubscriptions(in: scene)
  }

  // MARK: - Internals

  private func computeNextPlanChange(current: Entitlement) async -> NextPlanChange? {
    guard current.plan.isPro else { return nil }
    guard let currentProduct = productsByPlan[current.plan] else { return nil }
    guard let ids = Self.loadProductIDsFromInfoPlist() else { return nil }

    do {
      let statuses = try await currentProduct.subscription?.status ?? []
      // Find the status entry corresponding to the currently active product.
      let status = try statuses.first(where: { st in
        let t = try Self.requireVerified(st.transaction)
        return t.productID == currentProduct.id
      })
      guard let status else { return nil }

      let renewal = try Self.requireVerified(status.renewalInfo)
      guard let preferredID = renewal.autoRenewPreference else { return nil }
      guard preferredID != currentProduct.id else { return nil }

      let nextPlan: SubscriptionPlan? = {
        if preferredID == ids.proMonthly { return .proMonthly }
        if preferredID == ids.proYearly { return .proYearly }
        return nil
      }()
      guard let nextPlan else { return nil }

      // Scheduled plan changes start at the end of the current paid period.
      let t = try Self.requireVerified(status.transaction)
      return NextPlanChange(nextPlan: nextPlan, effectiveDate: t.expirationDate)
    } catch {
      return nil
    }
  }

  private func expectedProductID(for plan: SubscriptionPlan) -> String? {
    guard let productIDs else { return nil }
    switch plan {
    case .free:
      return nil
    case .proMonthly:
      return productIDs.proMonthly
    case .proYearly:
      return productIDs.proYearly
    case .founderLifetime:
      return productIDs.founderLifetime
    }
  }

  private func purchaseProduct(_ product: Product, expectedPlan: SubscriptionPlan) async throws
    -> Entitlement
  {
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      let transaction = try Self.requireVerified(verification)
      await transaction.finish()
      await refreshEntitlements()
      return entitlement.plan == .free
        ? Entitlement(
          plan: expectedPlan, expirationDate: nil, isAutoRenewable: product.type == .autoRenewable)
        : entitlement
    case .userCancelled:
      throw StoreKitServiceError.purchaseCancelled
    case .pending:
      throw StoreKitServiceError.purchasePending
    @unknown default:
      throw StoreKitServiceError.purchaseUnverified
    }
  }

  private static func bestEntitlementFromCurrentEntitlements() async -> Entitlement? {
    var best: Entitlement?

    #if DEBUG
      let ignoreFounder = debugIgnoreFounderEntitlement
    #endif

    for await result in Transaction.currentEntitlements {
      guard let transaction = try? requireVerified(result) else { continue }

      let plan: SubscriptionPlan = {
        if let ids = loadProductIDsFromInfoPlist() {
          if transaction.productID == ids.founderLifetime {
            #if DEBUG
              if ignoreFounder { return .free }
            #endif
            return .founderLifetime
          }
          if transaction.productID == ids.proYearly { return .proYearly }
          if transaction.productID == ids.proMonthly { return .proMonthly }
        }
        return .free
      }()

      guard plan != .free else { continue }

      let ent = Entitlement(
        plan: plan,
        expirationDate: transaction.expirationDate,
        isAutoRenewable: transaction.productType == .autoRenewable
      )

      best = pickBest(best, ent)
    }

    return best
  }

  private static func pickBest(_ a: Entitlement?, _ b: Entitlement) -> Entitlement {
    guard let a else { return b }

    func rank(_ p: SubscriptionPlan) -> Int {
      switch p {
      case .free: return 0
      case .proMonthly: return 1
      case .proYearly: return 2
      case .founderLifetime: return 3
      }
    }

    if rank(b.plan) != rank(a.plan) {
      return rank(b.plan) > rank(a.plan) ? b : a
    }

    switch (a.expirationDate, b.expirationDate) {
    case (nil, _): return a
    case (_, nil): return b
    case (let ad?, let bd?):
      return bd > ad ? b : a
    }
  }

  private static func requireVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .verified(let safe): return safe
    case .unverified:
      throw StoreKitServiceError.purchaseUnverified
    }
  }

  private static func loadProductIDsFromInfoPlist() -> ProductIDs? {
    func str(_ key: String) -> String? {
      (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard
      let proMonthly = str("PRO_MONTHLY_PRODUCT_ID"), !proMonthly.isEmpty,
      let proYearly = str("PRO_YEARLY_PRODUCT_ID"), !proYearly.isEmpty,
      let founderLifetime = str("FOUNDER_LIFETIME_PRODUCT_ID"), !founderLifetime.isEmpty
    else {
      return nil
    }
    return ProductIDs(
      proMonthly: proMonthly, proYearly: proYearly, founderLifetime: founderLifetime)
  }
}
