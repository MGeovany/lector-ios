import Foundation

protocol ReadingPositionServicing {
  func getAllReadingPositions() async throws -> [String: RemoteReadingPosition]
  func updateReadingPosition(documentID: String, pageNumber: Int, progress: Double) async throws
}

final class GoReadingPositionService: ReadingPositionServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func updateReadingPosition(documentID: String, pageNumber: Int, progress: Double) async throws {
    struct Body: Encodable {
      let progress: Double
      let pageNumber: Int

      enum CodingKeys: String, CodingKey {
        case progress
        case pageNumber = "page_number"
      }
    }

    try await api.putJSON(
      "preferences/reading-position/\(documentID)",
      body: Body(progress: progress, pageNumber: pageNumber)
    )
  }

  func getAllReadingPositions() async throws -> [String: RemoteReadingPosition] {
    try await api.get("preferences/reading-positions")
  }
}

