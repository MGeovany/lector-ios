import Foundation

protocol DocumentsServicing {
  func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument]
  /// Attempts to fetch a recent subset from the backend.
  /// Default implementation falls back to fetching all documents.
  func getRecentDocumentsByUserID(_ userID: String, since: Date, limit: Int) async throws -> [RemoteDocument]
  func getDocument(id: String) async throws -> RemoteDocumentDetail
  func uploadDocument(pdfData: Data, fileName: String) async throws -> RemoteDocument
  func setFavorite(documentID: String, isFavorite: Bool) async throws
}

extension DocumentsServicing {
  func getRecentDocumentsByUserID(_ userID: String, since: Date, limit: Int) async throws -> [RemoteDocument] {
    // Fallback for services/backends that don't support recent filters.
    try await getDocumentsByUserID(userID)
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

  func uploadDocument(pdfData: Data, fileName: String) async throws -> RemoteDocument {
    try await api.postMultipart("documents", fileData: pdfData, fileName: fileName)
  }

  func setFavorite(documentID: String, isFavorite: Bool) async throws {
    struct Body: Encodable {
      let isFavorite: Bool
      enum CodingKeys: String, CodingKey { case isFavorite = "is_favorite" }
    }
    try await api.putJSON("documents/\(documentID)/favorite", body: Body(isFavorite: isFavorite))
  }
}
