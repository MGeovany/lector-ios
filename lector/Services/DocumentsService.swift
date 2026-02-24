import Foundation

protocol DocumentsServicing {
  func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument]
  /// Attempts to fetch a recent subset from the backend.
  /// Default implementation falls back to fetching all documents.
  func getRecentDocumentsByUserID(_ userID: String, since: Date, limit: Int) async throws -> [RemoteDocument]
  func getDocument(id: String) async throws -> RemoteDocumentDetail
  func getOptimizedDocument(id: String) async throws -> RemoteOptimizedDocument
  /// Fetches optimized document with a specific request timeout.
  /// Useful for polling flows where we want to bound UI wait time.
  func getOptimizedDocument(id: String, timeoutInterval: TimeInterval) async throws -> RemoteOptimizedDocument
  func getOptimizedDocumentMeta(id: String) async throws -> RemoteOptimizedDocument
  func updateDocument(documentID: String, title: String?, author: String?, tag: String?) async throws -> RemoteDocumentDetail
  func uploadDocument(fileData: Data, fileName: String, mimeType: String) async throws -> RemoteDocument
  func deleteDocument(documentID: String) async throws
  func setFavorite(documentID: String, isFavorite: Bool) async throws
  func getDocumentTags() async throws -> [String]
  func createDocumentTag(name: String) async throws
  func deleteDocumentTag(name: String) async throws
}

extension DocumentsServicing {
  func getRecentDocumentsByUserID(_ userID: String, since: Date, limit: Int) async throws -> [RemoteDocument] {
    // Fallback for services/backends that don't support recent filters.
    try await getDocumentsByUserID(userID)
  }

  func getOptimizedDocument(id: String, timeoutInterval: TimeInterval) async throws -> RemoteOptimizedDocument {
    try await getOptimizedDocument(id: id)
  }
}

final class GoDocumentsService: DocumentsServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument] {
    try await api.get("documents/user/\(userID)")
  }

  func getRecentDocumentsByUserID(_ userID: String, since: Date, limit: Int) async throws -> [RemoteDocument] {
    let sinceString = ISO8601DateFormatter.lectorInternetDateTime.string(from: since)
    return try await api.get(
      "documents/user/\(userID)",
      queryItems: [
        URLQueryItem(name: "since", value: sinceString),
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "order", value: "updated_at_desc"),
      ]
    )
  }

  func getDocument(id: String) async throws -> RemoteDocumentDetail {
    try await api.get("documents/\(id)")
  }

  func getOptimizedDocument(id: String) async throws -> RemoteOptimizedDocument {
    try await api.get("documents/\(id)/optimized")
  }

  func getOptimizedDocument(id: String, timeoutInterval: TimeInterval) async throws -> RemoteOptimizedDocument {
    try await api.get("documents/\(id)/optimized", timeoutInterval: timeoutInterval)
  }

  func getOptimizedDocumentMeta(id: String) async throws -> RemoteOptimizedDocument {
    try await api.get(
      "documents/\(id)/optimized",
      queryItems: [URLQueryItem(name: "include_pages", value: "0")],
      timeoutInterval: 8
    )
  }

  func updateDocument(documentID: String, title: String?, author: String?, tag: String?) async throws
    -> RemoteDocumentDetail
  {
    struct Body: Encodable {
      let title: String?
      let author: String?
      let tag: String?
    }
    return try await api.putJSON("documents/\(documentID)", body: Body(title: title, author: author, tag: tag))
  }

  func uploadDocument(fileData: Data, fileName: String, mimeType: String) async throws -> RemoteDocument {
    try await api.postMultipart("documents", fileData: fileData, fileName: fileName, mimeType: mimeType)
  }

  func deleteDocument(documentID: String) async throws {
    try await api.delete("documents/\(documentID)")
  }

  func setFavorite(documentID: String, isFavorite: Bool) async throws {
    struct Body: Encodable {
      let isFavorite: Bool
      enum CodingKeys: String, CodingKey { case isFavorite = "is_favorite" }
    }
    try await api.putJSON("documents/\(documentID)/favorite", body: Body(isFavorite: isFavorite))
  }

  func getDocumentTags() async throws -> [String] {
    try await api.get("document-tags")
  }

  func createDocumentTag(name: String) async throws {
    struct Body: Encodable { let name: String }
    try await api.postJSON("document-tags", body: Body(name: name))
  }

  func deleteDocumentTag(name: String) async throws {
    // NOTE: Do NOT pre-encode here.
    // APIClient builds URLs via `baseURL.appendingPathComponent(...)` which performs encoding.
    // Pre-encoding would double-encode (e.g. "New%20tag" -> "New%2520tag") and backend can't find it.
    try await api.delete("document-tags/\(name)")
  }
}
