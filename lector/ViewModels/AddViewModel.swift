import Foundation
import Observation

@MainActor
@Observable
final class AddViewModel {
  private(set) var isUploading: Bool = false
  var alertMessage: String?
  var didUploadSuccessfully: Bool = false

  private let documentsService: DocumentsServicing
  private let userID: String

  init(
    documentsService: DocumentsServicing? = nil,
    userID: String? = nil
  ) {
    self.documentsService = documentsService ?? GoDocumentsService()
    self.userID = userID ?? KeychainStore.getString(account: KeychainKeys.userID) ?? APIConfig.defaultUserID
  }

  func uploadPickedPDF(_ url: URL) async {
    isUploading = true
    didUploadSuccessfully = false
    defer { isUploading = false }

    do {
      let pdfData = try Self.readSecurityScopedFile(url)
      try await validateQuotaAndSize(nextFileBytes: Int64(pdfData.count))

      _ = try await documentsService.uploadDocument(
        pdfData: pdfData,
        fileName: url.lastPathComponent.isEmpty ? "document.pdf" : url.lastPathComponent
      )

      didUploadSuccessfully = true
      NotificationCenter.default.post(name: .documentsDidChange, object: nil)
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to upload document."
    }
  }

  private func validateQuotaAndSize(nextFileBytes: Int64) async throws {
    let plan = currentPlanFromDefaults()
    // Keep the single-file cap conservative to match backend validation.
    let maxSingleFileBytes: Int64 = Int64(MAX_STORAGE_PREMIUM_MB) * 1024 * 1024

    let maxTotalBytes: Int64 = {
      switch plan {
      case .free:
        return Int64(MAX_STORAGE_MB) * 1024 * 1024
      case .proMonthly, .proYearly, .founderLifetime:
        // Use decimal GB for UX consistency (50GB = 50,000,000,000 bytes).
        return Int64(MAX_STORAGE_PRO_GB) * 1_000_000_000
      }
    }()

    if nextFileBytes > maxSingleFileBytes {
      throw APIError.server(
        statusCode: 400,
        message:
          "File too large. Maximum single file size is \(Int(maxSingleFileBytes / 1024 / 1024))MB."
      )
    }

    // Best-effort precheck to match web UX. Backend also enforces this.
    let docs = try await documentsService.getDocumentsByUserID(userID)
    let currentUsage = docs.reduce(Int64(0)) { $0 + ($1.metadata.fileSize ?? 0) }
    if currentUsage + nextFileBytes > maxTotalBytes {
      throw APIError.server(
        statusCode: 400,
        message:
          "Storage limit reached. Max is \(plan == .free ? "\(MAX_STORAGE_MB)MB" : "\(MAX_STORAGE_PRO_GB)GB"). Delete a document or contact support for more space."
      )
    }
  }

  private func currentPlanFromDefaults() -> SubscriptionPlan {
    if let raw = UserDefaults.standard.string(forKey: SubscriptionStore.planKey),
      let plan = SubscriptionPlan(rawValue: raw)
    {
      return plan
    }
    // Back-compat
    let legacyPremium = UserDefaults.standard.bool(forKey: SubscriptionStore.legacyIsPremiumKey)
    return legacyPremium ? .proYearly : .free
  }

  private static func readSecurityScopedFile(_ url: URL) throws -> Data {
    let needsSecurity = url.startAccessingSecurityScopedResource()
    defer {
      if needsSecurity {
        url.stopAccessingSecurityScopedResource()
      }
    }
    return try Data(contentsOf: url)
  }
}

extension Notification.Name {
  static let documentsDidChange = Notification.Name("documentsDidChange")
}

