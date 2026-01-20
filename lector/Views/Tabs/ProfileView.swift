//
//  ProfileView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct ProfileView: View {
  @EnvironmentObject private var subscription: SubscriptionStore
  @Environment(AppSession.self) private var session
  @Environment(\.openURL) private var openURL
  @Environment(\.colorScheme) private var colorScheme
  @State private var showPremiumSheet: Bool = false
  @State private var showEditProfilePicture: Bool = false
  @State private var showDeleteAccountConfirm: Bool = false
  @State private var showLogoutConfirm: Bool = false
  @State private var showAccountDeletedAlert: Bool = false
  @State private var showLoggedOutAlert: Bool = false
  @State private var usedBytes: Int64 = 0
  @State private var maxBytesOverride: Int64? = nil
  @State private var isLoadingStorageUsage: Bool = false
  private let documentsService: DocumentsServicing = GoDocumentsService()
  private let api: APIClient = APIClient()

  @AppStorage(AppPreferenceKeys.language) private var languageRawValue: String = AppLanguage.english
    .rawValue
  @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue
  @AppStorage(AppPreferenceKeys.accountDisabled) private var accountDisabled: Bool = false

  var body: some View {

    NavigationStack {
      List {
        Section {
          if session.isAuthenticated {
            if let profile = session.profile {
              ProfileHeaderRowView(
                name: profile.displayName,
                email: profile.email,
                avatarURL: profile.avatarURL,
                badge: profileBadge
              )
            } else {
              ProfileHeaderRowView(
                name: "Loading…",
                email: "Retrieving your profile",
                badge: profileBadge
              )
            }
          } else {
            ProfileHeaderRowView(
              name: "Marlon Castro",
              email: "marlon.castro@thefndrs.com",
              badge: profileBadge
            )
          }

          Button {
            showEditProfilePicture = true
          } label: {
            // flex space between.
            HStack(alignment: .center, spacing: 10) {
              Text("Edit profile picture")
                .font(.parkinsans(size: 15, weight: .medium))
                // matte si es tema white letras negras, si es tema negro letras blancas
                .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

              Spacer(minLength: 0)

              Image(systemName: "shuffle")
                .font(.parkinsans(size: 15, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)
            }
            .frame(maxWidth: .infinity)
          }
        }

        Section("Subscription") {
          HStack {
            Text("Plan")
            Spacer()
            Text(planTitle)
              .foregroundStyle(.secondary)
          }

          if let statusText = planStatusText {
            HStack {
              Text("Status")
              Spacer()
              Text(statusText)
                .foregroundStyle(.secondary)
            }
          }

          if let next = nextPlanText {
            HStack {
              Text("Next")
              Spacer()
              Text(next)
                .foregroundStyle(.secondary)
            }
          }

          Button {
            showPremiumSheet = true
          } label: {
            HStack {
              Text(subscription.isPremium ? "Change subscription" : "Upgrade")
                .font(.parkinsans(size: 15, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            }
          }
        }

        if subscription.isFounder {
          Section("Founder") {
            FounderHighlightCard(displayName: founderDisplayName)
              .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
              .listRowBackground(Color.clear)
          }
        }

        Section("Storage") {
          StorageUsageCardView(
            usedBytes: usedBytes,
            maxBytes: maxBytesOverride ?? subscription.maxStorageBytes,
            isPremium: subscription.isPremium,
            onUpgradeTapped: subscription.isPremium ? nil : { showPremiumSheet = true },
            onMoreSpaceTapped: subscription.isPremium ? { requestMoreStorageByEmail() } : nil
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
          .listRowBackground(Color.clear)
        }

        Section("Preferences") {
          NavigationLink {
            LanguageSelectionView()
          } label: {
            SettingsRowView(
              icon: "globe",
              title: "Language",
              trailingText: (AppLanguage(rawValue: languageRawValue) ?? .english).title,
              showsChevron: false
            )
          }

          NavigationLink {
            ThemeSelectionView()
          } label: {
            SettingsRowView(
              icon: "moon.stars",
              title: "Theme",
              trailingText: (AppTheme(rawValue: themeRawValue) ?? .dark).title,
              showsChevron: false
            )
          }

          NavigationLink {
            AboutUsView()
          } label: {
            SettingsRowView(icon: "info.circle", title: "About Us", showsChevron: false)
          }
        }

        Section("Support") {
          NavigationLink {
            HelpCenterView()
          } label: {
            SettingsRowView(icon: "questionmark.circle", title: "Help Center", showsChevron: false)
          }

          Link(destination: contactSupportURL) {
            SettingsRowView(
              icon: "envelope",
              title: "Contact Support",
              trailingText: "Email",
              showsChevron: false
            )
          }
        }

        Section("Legal") {
          NavigationLink {
            TermsAndConditionsView()
          } label: {
            SettingsRowView(icon: "doc.text", title: "Terms & Conditions", showsChevron: false)
          }
        }

        Section {
          Button(role: .destructive) {
            showDeleteAccountConfirm = true
          } label: {
            SettingsRowView(
              icon: "trash",
              title: "Delete Account",
              trailingText: nil,
              showsChevron: false
            )
          }

          Button {
            showLogoutConfirm = true
          } label: {
            SettingsRowView(
              icon: "rectangle.portrait.and.arrow.right",
              title: "Log out",
              trailingText: nil,
              showsChevron: false
            )
          }
        }
      }
      .listStyle(.insetGrouped)
      .listSectionSpacing(8)
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Color.clear.frame(height: 62)
      }
      .sheet(isPresented: $showPremiumSheet) {
        PremiumUpsellSheetView()
          .environmentObject(subscription)
      }
      .sheet(isPresented: $showEditProfilePicture) {
        EditProfilePictureSheetView()
          .presentationDetents([.height(320)])
          .presentationDragIndicator(.visible)
      }
      .task {
        // In Xcode Previews we inject a fake SubscriptionStore (e.g. proYearly).
        // Avoid overriding it by syncing real StoreKit entitlements.
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        guard !isPreview else { return }
        await subscription.refreshFromStoreKit()
      }
      .task(id: session.isAuthenticated) {
        await loadStorageUsage()
      }
      .onReceive(NotificationCenter.default.publisher(for: .documentsDidChange)) { _ in
        Task { await loadStorageUsage() }
      }
      .overlay {
        if showDeleteAccountConfirm {
          CenteredConfirmationModal(
            title: "Delete account?",
            message:
              "Your account will be temporarily disabled while we process your request. All data will be permanently deleted, and you’ll receive an email confirmation once completed.",
            confirmTitle: "Request deletion",
            isDestructive: true,
            onConfirm: {
              showDeleteAccountConfirm = false
              requestAccountDeletion()
            },
            onCancel: { showDeleteAccountConfirm = false }
          )
          .transition(.scale(scale: 0.98).combined(with: .opacity))
        }

        if showLogoutConfirm {
          CenteredConfirmationModal(
            title: "Log out?",
            message: "This will sign you out on this device.",
            confirmTitle: "Log out",
            isDestructive: true,
            onConfirm: {
              showLogoutConfirm = false
              session.signOut()
              showLoggedOutAlert = true
            },
            onCancel: { showLogoutConfirm = false }
          )
          .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showDeleteAccountConfirm)
      .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showLogoutConfirm)
      .alert("Account deleted", isPresented: $showAccountDeletedAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Local data cleared on this device.")
      }
    }
    .task(id: session.isAuthenticated) {
      await session.refreshProfileIfNeeded()
    }
  }

  private var contactSupportURL: URL {
    let email = "marlon.castro@thefndrs.com"
    let subject = "Lector Support"
    let body = "Hi Marlon,\n\nI need help with:\n\n"
    let encodedSubject =
      subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
    return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
      ?? URL(string: "mailto:\(email)")
      ?? URL(string: "mailto:")
      ?? URL(fileURLWithPath: "/")
  }

  private func loadStorageUsage() async {
    guard session.isAuthenticated else {
      usedBytes = 0
      return
    }
    let userID = KeychainStore.getString(account: KeychainKeys.userID) ?? ""
    guard !userID.isEmpty else {
      usedBytes = 0
      return
    }

    isLoadingStorageUsage = true
    defer { isLoadingStorageUsage = false }

    // Prefer backend-provided usage+limit (keeps app in sync with server enforcement).
    struct StorageUsageResponse: Decodable {
      let used_bytes: Int64
      let limit_bytes: Int64
      let percent: Double
    }

    if let resp: StorageUsageResponse = try? await api.get("storage/usage") {
      usedBytes = max(0, resp.used_bytes)
      maxBytesOverride = resp.limit_bytes > 0 ? resp.limit_bytes : nil
      return
    }

    // Fallback: compute usage client-side.
    do {
      let docs = try await documentsService.getDocumentsByUserID(userID)
      usedBytes = docs.reduce(Int64(0)) { $0 + ($1.metadata.fileSize ?? 0) }
    } catch {
      // Non-blocking; keep last known value.
    }
  }

  private func requestAccountDeletion() {
    Task {
      do {
        // First, call backend to mark account_disabled = true in DB (server-side blocking).
        let profileService = GoUserProfileService()
        try await profileService.requestAccountDeletion()

        // Then disable access on this device (local blocking).
        accountDisabled = true
        subscription.downgradeToFree()

        // Prepare an email request to support (user will send via Mail).
        if let url = accountDeletionRequestEmailURL() {
          openURL(url)
        }

        // Sign out to ensure no further access with cached tokens.
        session.signOut()
      } catch {
        // If backend call fails, still block locally but show error.
        accountDisabled = true
        subscription.downgradeToFree()
        session.signOut()
        // TODO: Show error alert to user (backend call failed, but local blocking applied)
      }
    }
  }

  private func accountDeletionRequestEmailURL() -> URL? {
    let email = "marlon.castro@thefndrs.com"
    let userID = KeychainStore.getString(account: KeychainKeys.userID) ?? ""
    let userEmail = session.profile?.email ?? ""
    let subject = "Account Deletion Request"
    let body =
      """
      Hi,

      Please delete my Lector account and all associated data.

      User ID: \(userID)
      Email: \(userEmail)

      Thanks,
      """
    let encodedSubject =
      subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
    return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
      ?? URL(string: "mailto:\(email)")
  }

  private func requestMoreStorageByEmail() {
    if let url = moreStorageRequestEmailURL() {
      openURL(url)
    }
  }

  private func moreStorageRequestEmailURL() -> URL? {
    let email = "marlon.castro@thefndrs.com"
    let userID = KeychainStore.getString(account: KeychainKeys.userID) ?? ""
    let userEmail = session.profile?.email ?? ""
    let subject = "More storage request"
    let body =
      """
      Hi Marlon,

      I’d like to request more storage.

      Plan: \(planTitle)
      Current usage: \(ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file))
      Current limit: \(subscription.maxStorageText)

      User ID: \(userID)
      Email: \(userEmail)

      Thanks,
      """

    let encodedSubject =
      subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
    return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
      ?? URL(string: "mailto:\(email)")
  }

  private func deleteAccountLocally() {
    // Ensure the UI immediately reflects free-tier state (SubscriptionStore caches isPremium in memory).
    subscription.downgradeToFree()

    UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.language)
    UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.theme)
    UserDefaults.standard.removeObject(forKey: SubscriptionStore.legacyIsPremiumKey)
    UserDefaults.standard.removeObject(forKey: SubscriptionStore.planKey)
  }

  private var profileBadge: ProfilePlanBadge? {
    if subscription.isFounder { return .founder }
    if subscription.isPro { return .pro }
    return nil
  }

  private var planTitle: String {
    switch subscription.plan {
    case .free: return "Free"
    case .proMonthly: return "Pro (Monthly)"
    case .proYearly: return "Pro (Yearly)"
    case .founderLifetime: return "Founder (Lifetime)"
    }
  }

  private var planStatusText: String? {
    if subscription.isFounder { return "Active" }
    guard subscription.isPremium else { return nil }
    guard subscription.isAutoRenewable else { return "Active" }

    if let days = subscription.remainingDaysInPeriod, let date = subscription.expirationDate {
      return "\(days)d left • Renews \(Self.shortDate(date))"
    }
    if let date = subscription.expirationDate {
      return "Renews \(Self.shortDate(date))"
    }
    return "Active"
  }

  private var nextPlanText: String? {
    guard
      let nextPlan = subscription.nextPlan,
      nextPlan != subscription.plan
    else { return nil }

    let title: String = {
      switch nextPlan {
      case .free: return "Free"
      case .proMonthly: return "Pro (Monthly)"
      case .proYearly: return "Pro (Yearly)"
      case .founderLifetime: return "Founder (Lifetime)"
      }
    }()

    if let date = subscription.nextPlanStartDate {
      return "\(title) • Starts \(Self.shortDate(date))"
    }
    return title
  }

  private static func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: date)
  }

  private var founderDisplayName: String? {
    let raw = session.profile?.displayName ?? ""
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

// MARK: - Founder highlight card (animated + benefits)

private struct FounderHighlightCard: View {
  let displayName: String?
  @State private var shimmerPhase: CGFloat = -0.8

  private let gold = Color(red: 1.00, green: 0.74, blue: 0.22)
  private let amber = Color(red: 1.00, green: 0.42, blue: 0.14)

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header
      benefits
      footer
    }
    .padding(16)
    .background(background)
    .overlay(shimmer)
    .frame(maxWidth: .infinity, minHeight: 220)
    .onAppear {
      withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
        shimmerPhase = 1.2
      }
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      seal

      VStack(alignment: .leading, spacing: 3) {
        Text("Founder")
          .font(.parkinsansBold(size: 18))
          .foregroundStyle(.white.opacity(0.96))
        Text("One-time perks for early supporters.")
          .font(.parkinsans(size: 12, weight: .regular))
          .foregroundStyle(.white.opacity(0.72))
      }
      .padding(.bottom, 12)

    }
  }

  private var benefits: some View {
    VStack(spacing: 20) {
      BenefitRow(
        icon: "externaldrive.fill",
        title: "\(MAX_STORAGE_PRO_GB)GB storage",
        subtitle: "Keep your full library synced.",
        tint: gold
      )
      BenefitRow(
        icon: "bolt.fill",
        title: "Early access",
        subtitle: "Try new features before everyone else.",
        tint: gold
      )
      BenefitRow(
        icon: "person.crop.circle.badge.checkmark",
        title: "Founder identity",
        subtitle: "A special badge that stands out.",
        tint: gold
      )
    }
    .padding(.bottom, 12)

  }

  private var footer: some View {
    let name = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let line =
      name.isEmpty ? "Thanks for supporting Lector early." : "Thanks, \(name) — you’re a Founder."

    return HStack(spacing: 8) {
      Image(systemName: "sparkles")
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(gold.opacity(0.95))
      Text(line)
        .font(.parkinsansSemibold(size: 12))
        .foregroundStyle(.white.opacity(0.82))
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  private var background: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
      .fill(
        LinearGradient(
          colors: [
            Color(red: 0.06, green: 0.06, blue: 0.07),
            Color(red: 0.14, green: 0.10, blue: 0.08),
            Color(red: 0.20, green: 0.12, blue: 0.08),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [gold.opacity(0.35), Color.white.opacity(0.10), amber.opacity(0.25)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
      .shadow(color: gold.opacity(0.22), radius: 22, y: 12)
  }

  private var shimmer: some View {
    GeometryReader { geo in
      let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
      shape
        .fill(Color.clear)
        .overlay(
          LinearGradient(
            colors: [
              Color.white.opacity(0.00),
              Color.white.opacity(0.35),
              Color.white.opacity(0.00),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .rotationEffect(.degrees(18))
          // Give the gradient plenty of height so it never “cuts off”.
          .frame(width: geo.size.width * 0.75, height: geo.size.height * 2)
          .offset(x: geo.size.width * shimmerPhase)
          .blendMode(.screen)
          .opacity(0.14)
        )
        .clipShape(shape)
        .allowsHitTesting(false)
    }
  }

  private var seal: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(
          LinearGradient(colors: [gold, amber], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .frame(width: 44, height: 44)
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: gold.opacity(0.35), radius: 14, y: 10)

      Text("F")
        .font(.system(size: 20, weight: .heavy, design: .rounded))
        .foregroundStyle(.white.opacity(0.95))
        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
    }
  }
}

private struct BenefitRow: View {
  let icon: String
  let title: String
  let subtitle: String
  let tint: Color

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(tint.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.parkinsansSemibold(size: 13))
          .foregroundStyle(.white.opacity(0.92))
        Text(subtitle)
          .font(.parkinsans(size: 12, weight: .regular))
          .foregroundStyle(.white.opacity(0.68))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
  }
}

#Preview("Free User") {
  // Preview showing Free tier user
  // Differences: Plan shows "Free", Storage shows "Go Premium" button, no badge
  let freeSubscription = SubscriptionStore(initialPlan: .free, persistToDefaults: false)
  NavigationStack {
    ProfileView()
      .environment(AppSession())
      .environmentObject(freeSubscription)
  }
}

#Preview("Pro User") {
  // Preview showing Pro tier user
  // Differences: Plan shows "Pro (Yearly)", Storage shows "PREMIUM" badge,
  // storage shows "Unlimited", profile shows blue "PRO" badge
  let proSubscription = SubscriptionStore(initialPlan: .proYearly, persistToDefaults: false)
  NavigationStack {
    ProfileView()
      .environment(AppSession())
      .environmentObject(proSubscription)
  }
}

#Preview("Founder User") {
  let founderSubscription = SubscriptionStore(
    initialPlan: .founderLifetime, persistToDefaults: false)
  NavigationStack {
    ProfileView()
      .environment(AppSession())
      .environmentObject(founderSubscription)
  }
}
