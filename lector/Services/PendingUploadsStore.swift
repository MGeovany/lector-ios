import Foundation

struct PendingUpload: Codable, Hashable, Identifiable {
  let id: String
  let fileName: String
  let createdAt: Date
}

enum PendingUploadsStore {
  private static let fm = FileManager.default
  private static let manifestName = "pending_uploads.json"

  private static func baseDir(create: Bool) throws -> URL {
    let root = try fm.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: create
    )
    let dir = root.appendingPathComponent("PendingUploads", isDirectory: true)
    if create, !fm.fileExists(atPath: dir.path) {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private static func manifestURL(create: Bool) throws -> URL {
    try baseDir(create: create).appendingPathComponent(manifestName)
  }

  private static func pdfURL(baseDir: URL, id: String) -> URL {
    baseDir.appendingPathComponent("\(id).pdf")
  }

  static func list() -> [PendingUpload] {
    do {
      let url = try manifestURL(create: false)
      guard fm.fileExists(atPath: url.path) else { return [] }
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([PendingUpload].self, from: data)
    } catch {
      return []
    }
  }

  static func enqueue(pdfData: Data, fileName: String) throws -> PendingUpload {
    let base = try baseDir(create: true)
    var items = list()

    let item = PendingUpload(
      id: UUID().uuidString,
      fileName: fileName.isEmpty ? "document.pdf" : fileName,
      createdAt: Date()
    )

    let pdf = pdfURL(baseDir: base, id: item.id)
    try pdfData.write(to: pdf, options: [.atomic])
    items.insert(item, at: 0)

    let manifest = try manifestURL(create: true)
    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys]
    try enc.encode(items).write(to: manifest, options: [.atomic])
    return item
  }

  static func loadPDFData(id: String) throws -> Data {
    let base = try baseDir(create: false)
    return try Data(contentsOf: pdfURL(baseDir: base, id: id))
  }

  static func remove(id: String) {
    do {
      let base = try baseDir(create: false)
      var items = list()
      items.removeAll { $0.id == id }

      let pdf = pdfURL(baseDir: base, id: id)
      if fm.fileExists(atPath: pdf.path) {
        try? fm.removeItem(at: pdf)
      }

      let manifest = try manifestURL(create: true)
      let enc = JSONEncoder()
      enc.outputFormatting = [.sortedKeys]
      try enc.encode(items).write(to: manifest, options: [.atomic])
    } catch {
      // ignore
    }
  }
}
