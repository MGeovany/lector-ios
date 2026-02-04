import Foundation

// Mirrors `reader-go/internal/domain/document.go` OptimizedDocument.
struct RemoteOptimizedDocument: Codable, Hashable {
  let documentID: String
  let processingStatus: String
  let optimizedVersion: Int
  let optimizedChecksumSHA256: String?
  let optimizedSizeBytes: Int64?
  let languageCode: String?
  let processedAt: Date?
  let pages: [String]?

  enum CodingKeys: String, CodingKey {
    case documentID = "document_id"
    case processingStatus = "processing_status"
    case optimizedVersion = "optimized_version"
    case optimizedChecksumSHA256 = "optimized_checksum_sha256"
    case optimizedSizeBytes = "optimized_size_bytes"
    case languageCode = "language_code"
    case processedAt = "processed_at"
    case pages
  }
}
