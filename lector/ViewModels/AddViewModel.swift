import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class AddViewModel {
  private(set) var isUploading: Bool = false
  var alertMessage: String?
  var infoMessage: String?
  var didUploadSuccessfully: Bool = false
  var lastUploadedRemoteID: String?

  private let documentsService: DocumentsServicing
  private let userID: String

  init(
    documentsService: DocumentsServicing? = nil,
    userID: String? = nil
  ) {
    self.documentsService = documentsService ?? GoDocumentsService()
    self.userID = userID ?? KeychainStore.getString(account: KeychainKeys.userID) ?? APIConfig.defaultUserID
  }

  func uploadPickedDocument(_ url: URL) async {
    isUploading = true
    didUploadSuccessfully = false
    lastUploadedRemoteID = nil
    defer { isUploading = false }

    do {
      let fileData = try Self.readSecurityScopedFile(url)
      let fileName = url.lastPathComponent.isEmpty ? "document" : url.lastPathComponent

      // If offline, queue the upload locally.
      if !NetworkMonitor.shared.isOnline {
        _ = try PendingUploadsStore.enqueue(
          fileData: fileData,
          fileName: fileName
        )
        infoMessage = "You're offline. Your book will be uploaded and processed once you're back online."
        NotificationCenter.default.post(name: .documentsDidChange, object: nil)
        return
      }

      try await validateQuotaAndSize(nextFileBytes: Int64(fileData.count))

      let uploaded = try await documentsService.uploadDocument(
        fileData: fileData,
        fileName: fileName,
        mimeType: Self.mimeType(for: url) ?? "application/octet-stream"
      )

      didUploadSuccessfully = true
      lastUploadedRemoteID = uploaded.id
      NotificationCenter.default.post(name: .documentsDidChange, object: nil)
      NotificationCenter.default.post(
        name: .openReaderForUploadedDocument,
        object: nil,
        userInfo: [
          "remoteID": uploaded.id,
          "title": uploaded.title,
          "author": uploaded.author ?? "",
          "pagesTotal": uploaded.metadata.pageCount ?? 1,
          "createdAt": uploaded.createdAt,
          "sizeBytes": uploaded.originalSizeBytes ?? uploaded.metadata.fileSize ?? 0,
        ]
      )
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to upload document."
    }
  }

  func flushPendingUploadsIfPossible() async {
    guard NetworkMonitor.shared.isOnline else { return }
    let pending = PendingUploadsStore.list()
    guard !pending.isEmpty else { return }

    for item in pending {
      do {
        let data = try PendingUploadsStore.loadData(id: item.id)
        // Best-effort: quota check.
        try await validateQuotaAndSize(nextFileBytes: Int64(data.count))
        _ = try await documentsService.uploadDocument(
          fileData: data,
          fileName: item.fileName,
          mimeType: Self.mimeType(forFileName: item.fileName) ?? "application/octet-stream"
        )
        PendingUploadsStore.remove(id: item.id)
        NotificationCenter.default.post(name: .documentsDidChange, object: nil)
      } catch {
        // Stop on first failure; try again later.
        return
      }
    }
  }
  
  private static func mimeType(for url: URL) -> String? {
    mimeType(forFileName: url.lastPathComponent)
  }
  
  private static func mimeType(forFileName fileName: String) -> String? {
    let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
    if let type = UTType(filenameExtension: ext), let mime = type.preferredMIMEType {
      return mime
    }
    switch ext {
    case "pdf": return "application/pdf"
    case "epub": return "application/epub+zip"
    case "txt": return "text/plain"
    case "md", "markdown": return "text/markdown"
    default: return nil
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
  static let openReaderForUploadedDocument = Notification.Name("openReaderForUploadedDocument")
}
