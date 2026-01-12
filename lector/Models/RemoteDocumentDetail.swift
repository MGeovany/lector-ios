import Foundation

/// Same as `RemoteDocument`, but with fully decoded `content` blocks.
struct RemoteDocumentDetail: Codable, Hashable {
  let id: String
  let userID: String

  let title: String
  let author: String?
  let description: String?

  let content: [RemoteContentBlock]

  let metadata: RemoteDocumentMetadata
  let tag: String?

  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case userID = "user_id"
    case title
    case author
    case description
    case content
    case metadata
    case tag
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
