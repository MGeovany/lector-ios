import Foundation

// Mirrors `reader-go/internal/domain/highlight.go`
struct RemoteHighlight: Codable, Hashable, Identifiable {
  let id: String
  let userID: String
  let documentID: String
  let quote: String
  let pageNumber: Int?
  let progress: Double?
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case userID = "user_id"
    case documentID = "document_id"
    case quote
    case pageNumber = "page_number"
    case progress
    case createdAt = "created_at"
  }
}

