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
    let maxBytes = Int64(MAX_STORAGE_MB) * 1024 * 1024

    if nextFileBytes > maxBytes {
      throw APIError.server(
        statusCode: 400,
        message: "File too large. Maximum single file size is \(MAX_STORAGE_MB)MB."
      )
    }

    // Best-effort precheck to match web UX. Backend also enforces this.
    let docs = try await documentsService.getDocumentsByUserID(userID)
    let currentUsage = docs.reduce(Int64(0)) { $0 + ($1.metadata.fileSize ?? 0) }
    if currentUsage + nextFileBytes > maxBytes {
      throw APIError.server(
        statusCode: 400,
        message: "Storage limit reached (\(MAX_STORAGE_MB)MB). Delete a document or upgrade."
      )
    }
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

