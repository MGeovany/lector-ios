import Foundation

struct PendingReadingPosition: Codable, Equatable {
  let documentID: String
  let pageNumber: Int
  let progress: Double
  let updatedAt: Date
}

enum PendingReadingPositionStore {
  private static let fm = FileManager.default
  private static let fileName = "pending_reading_positions.json"

  private static func fileURL(create: Bool) throws -> URL {
    let root = try fm.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: create
    )
    return root.appendingPathComponent(fileName)
  }

  private static func loadAll() -> [PendingReadingPosition] {
    do {
      let url = try fileURL(create: false)
      guard fm.fileExists(atPath: url.path) else { return [] }
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([PendingReadingPosition].self, from: data)
    } catch {
      return []
    }
  }

  private static func saveAll(_ items: [PendingReadingPosition]) {
    do {
      _ = try fileURL(create: true)
      let url = try fileURL(create: true)
      let data = try JSONEncoder().encode(items)
      try data.write(to: url, options: [.atomic])
    } catch {
      // ignore
    }
  }

  static func get(documentID: String) -> PendingReadingPosition? {
    loadAll().first { $0.documentID == documentID }
  }

  static func save(documentID: String, pageNumber: Int, progress: Double) {
    var items = loadAll().filter { $0.documentID != documentID }
    items.append(PendingReadingPosition(
      documentID: documentID,
      pageNumber: pageNumber,
      progress: progress,
      updatedAt: Date()
    ))
    saveAll(items)
  }

  static func remove(documentID: String) {
    saveAll(loadAll().filter { $0.documentID != documentID })
  }

  static func list() -> [PendingReadingPosition] {
    loadAll()
  }
}
