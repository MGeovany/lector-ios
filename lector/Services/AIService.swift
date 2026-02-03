import Foundation

protocol AIServicing {
  func ingestDocument(documentID: String) async throws
  func ask(
    documentID: String, sessionID: String?, prompt: String, currentPage: Int?, totalPages: Int?
  ) async throws -> ChatResponse
  func getChatHistory(sessionID: String) async throws -> ChatSessionData
}

final class AIService: AIServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func ingestDocument(documentID: String) async throws {
    struct Response: Decodable {}
    // postJSON expects a body, but ingest takes no body currently in backend?
    // Backend: func (h *AIHandler) Ingest(w http.ResponseWriter, r *http.Request)
    // It's a POST, but no body needed.
    // APIClient postJSON requires body.
    // Let's use makeRequest manually or add a post without body to APIClient?
    // Or just send empty body.
    struct EmptyBody: Encodable {}
    try await api.postJSON("documents/\(documentID)/ingest", body: EmptyBody())
  }

  func ask(
    documentID: String, sessionID: String?, prompt: String, currentPage: Int?, totalPages: Int?
  ) async throws -> ChatResponse {
    let req = ChatRequest(
      sessionID: sessionID, documentID: documentID, prompt: prompt, currentPage: currentPage,
      totalPages: totalPages)
    return try await api.postJSON("ask-ai", body: req)
  }

  func getChatHistory(sessionID: String) async throws -> ChatSessionData {
    return try await api.get("chat/\(sessionID)")
  }
}
