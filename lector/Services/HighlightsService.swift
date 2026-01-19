import Foundation

protocol HighlightsServicing {
  func listHighlights(documentID: String?) async throws -> [RemoteHighlight]
  func createHighlight(documentID: String, quote: String, pageNumber: Int?, progress: Double?) async throws -> RemoteHighlight
  func deleteHighlight(highlightID: String) async throws
}

final class GoHighlightsService: HighlightsServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func listHighlights(documentID: String?) async throws -> [RemoteHighlight] {
    if let documentID, !documentID.isEmpty {
      return try await api.get(
        "highlights",
        queryItems: [URLQueryItem(name: "document_id", value: documentID)]
      )
    }
    return try await api.get("highlights")
  }

  func createHighlight(documentID: String, quote: String, pageNumber: Int?, progress: Double?) async throws -> RemoteHighlight {
    struct Body: Encodable {
      let documentID: String
      let quote: String
      let pageNumber: Int?
      let progress: Double?

      enum CodingKeys: String, CodingKey {
        case documentID = "document_id"
        case quote
        case pageNumber = "page_number"
        case progress
      }
    }

    return try await api.postJSON(
      "highlights",
      body: Body(documentID: documentID, quote: quote, pageNumber: pageNumber, progress: progress)
    )
  }

  func deleteHighlight(highlightID: String) async throws {
    try await api.delete("highlights/\(highlightID)")
  }
}

