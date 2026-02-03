import Foundation

struct ChatSession: Identifiable, Codable, Equatable {
  let id: String
  let userID: String
  let documentID: String?
  let title: String
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case userID = "user_id"
    case documentID = "document_id"
    case title
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

struct ChatMessage: Identifiable, Codable, Equatable {
  let id: String
  let chatSessionID: String
  let role: Role
  let content: String
  let citations: [Int]?
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case chatSessionID = "chat_session_id"
    case role
    case content
    case citations
    case createdAt = "created_at"
  }

  enum Role: String, Codable {
    case user
    case model
    case system
  }
}

struct ChatRequest: Codable {
  let sessionID: String?
  let documentID: String
  let prompt: String
  let currentPage: Int?
  let totalPages: Int?

  enum CodingKeys: String, CodingKey {
    case sessionID = "session_id"
    case documentID = "document_id"
    case prompt
    case currentPage = "current_page"
    case totalPages = "total_pages"
  }
}

struct ChatResponse: Codable {
  let sessionID: String
  let message: String
  let citations: [Int]?

  enum CodingKeys: String, CodingKey {
    case sessionID = "session_id"
    case message
    case citations
  }
}

struct ChatSessionData: Codable {
  let session: ChatSession
  let messages: [ChatMessage]
}
