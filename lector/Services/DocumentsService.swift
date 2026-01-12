import Foundation

protocol DocumentsServicing {
  func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument]
  func getDocument(id: String) async throws -> RemoteDocumentDetail
  func uploadDocument(pdfData: Data, fileName: String) async throws -> RemoteDocument
  func setFavorite(documentID: String, isFavorite: Bool) async throws
}

final class GoDocumentsService: DocumentsServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument] {
    try await api.get("documents/user/\(userID)")
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
