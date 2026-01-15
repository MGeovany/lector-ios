import Foundation

// Mirrors `reader-go/internal/domain/document.go`
struct RemoteDocument: Codable, Hashable {
  let id: String
  let userID: String

  let title: String
  let author: String?
  let description: String?

  /// On list endpoints this is typically `[]` (backend omits content for performance).
  /// On upload or fetch-by-id this can be large.
  let content: JSONValue?

  let metadata: RemoteDocumentMetadata
  let tag: String?

  /// Backend-managed favorite flag.
  let isFavorite: Bool

  /// Optional reading progress returned by some endpoints.
  let readingPosition: RemoteReadingPosition?

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
    case isFavorite = "is_favorite"
    case readingPosition = "reading_position"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    userID = try container.decode(String.self, forKey: .userID)
    title = try container.decode(String.self, forKey: .title)
    author = try container.decodeIfPresent(String.self, forKey: .author)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    content = try container.decodeIfPresent(JSONValue.self, forKey: .content)
    metadata = try container.decode(RemoteDocumentMetadata.self, forKey: .metadata)
    tag = try container.decodeIfPresent(String.self, forKey: .tag)
    isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    readingPosition = try container.decodeIfPresent(RemoteReadingPosition.self, forKey: .readingPosition)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }
}

struct RemoteReadingPosition: Codable, Hashable {
  let progress: Double?
  let pageNumber: Int?

  enum CodingKeys: String, CodingKey {
    case progress
    case pageNumber = "page_number"
  }
}

struct RemoteDocumentMetadata: Codable, Hashable {
  let originalTitle: String?
  let originalAuthor: String?
  let language: String?
  let pageCount: Int?
  let wordCount: Int?
  let fileSize: Int64?
  let format: String?
  let source: String?
  let hasPassword: Bool?

  enum CodingKeys: String, CodingKey {
    case originalTitle = "original_title"
    case originalAuthor = "original_author"
    case language
    case pageCount = "page_count"
    case wordCount = "word_count"
    case fileSize = "file_size"
    case format
    case source
    case hasPassword = "has_password"
  }
}

/// Minimal dynamic JSON type to decode `content` (array/object/etc) without breaking decoding.
enum JSONValue: Codable, Hashable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
      return
    }
    if let b = try? container.decode(Bool.self) {
      self = .bool(b)
      return
    }
    if let n = try? container.decode(Double.self) {
      self = .number(n)
      return
    }
    if let s = try? container.decode(String.self) {
      self = .string(s)
      return
    }
    if let a = try? container.decode([JSONValue].self) {
      self = .array(a)
      return
    }
    if let o = try? container.decode([String: JSONValue].self) {
      self = .object(o)
      return
    }

    throw DecodingError.typeMismatch(
      JSONValue.self,
      .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let s):
      try container.encode(s)
    case .number(let n):
      try container.encode(n)
    case .bool(let b):
      try container.encode(b)
    case .object(let o):
      try container.encode(o)
    case .array(let a):
      try container.encode(a)
    case .null:
      try container.encodeNil()
    }
  }
}
