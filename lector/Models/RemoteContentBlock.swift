import Foundation

/// Mirrors `reader-go/internal/service/pdf_processor.go` block output.
struct RemoteContentBlock: Codable, Hashable {
  let type: String
  let content: String
  let level: Int
  let pageNumber: Int
  let position: Int

  enum CodingKeys: String, CodingKey {
    case type
    case content
    case level
    case pageNumber = "page_number"
    case position
  }
}
