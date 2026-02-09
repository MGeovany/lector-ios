import Foundation

struct PendingUpload: Codable, Hashable, Identifiable {
  let id: String
  let fileName: String
  let createdAt: Date
}

enum PendingUploadsStore {
  private static let fm = FileManager.default
  private static let manifestName = "pending_uploads.json"
  private static let dataExtension = "upload"
  /// Legacy extension used before migrating to .upload; kept for one-time migration of existing files.
  private static let legacyDataExtension = "pdf"

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

  private static func uploadURL(baseDir: URL, id: String) -> URL {
    baseDir.appendingPathComponent("\(id).\(dataExtension)")
  }

  private static func legacyUploadURL(baseDir: URL, id: String) -> URL {
    baseDir.appendingPathComponent("\(id).\(legacyDataExtension)")
  }

  /// Returns the URL of the data file for the given id. If a legacy .pdf file exists, it is renamed to .upload and the new URL is returned.
  private static func resolveDataURL(baseDir: URL, id: String) -> URL {
    let current = uploadURL(baseDir: baseDir, id: id)
    let legacy = legacyUploadURL(baseDir: baseDir, id: id)
    if fm.fileExists(atPath: current.path) {
      return current
    }
    if fm.fileExists(atPath: legacy.path) {
      try? fm.moveItem(at: legacy, to: current)
      return current
    }
    return current
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

  static func enqueue(fileData: Data, fileName: String) throws -> PendingUpload {
    let base = try baseDir(create: true)
    var items = list()

    let item = PendingUpload(
      id: UUID().uuidString,
      fileName: fileName.isEmpty ? "document" : fileName,
      createdAt: Date()
    )

    let upload = uploadURL(baseDir: base, id: item.id)
    try fileData.write(to: upload, options: [.atomic])
    items.insert(item, at: 0)

    let manifest = try manifestURL(create: true)
    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys]
    try enc.encode(items).write(to: manifest, options: [.atomic])
    return item
  }

  /// Enqueues a file picked from Files / "Open in…", handling security-scoped URLs.
  static func enqueue(fileURL: URL) throws -> PendingUpload {
    let needsSecurity = fileURL.startAccessingSecurityScopedResource()
    defer {
      if needsSecurity {
        fileURL.stopAccessingSecurityScopedResource()
      }
    }
    let data = try Data(contentsOf: fileURL)
    let fileName = fileURL.lastPathComponent.isEmpty ? "document" : fileURL.lastPathComponent
    return try enqueue(fileData: data, fileName: fileName)
  }

  static func loadData(id: String) throws -> Data {
    let base = try baseDir(create: false)
    let url = resolveDataURL(baseDir: base, id: id)
    return try Data(contentsOf: url)
  }

  static func remove(id: String) {
    do {
      let base = try baseDir(create: false)
      var items = list()
      items.removeAll { $0.id == id }

      let upload = uploadURL(baseDir: base, id: id)
      let legacy = legacyUploadURL(baseDir: base, id: id)
      if fm.fileExists(atPath: upload.path) { try? fm.removeItem(at: upload) }
      if fm.fileExists(atPath: legacy.path) { try? fm.removeItem(at: legacy) }

      let manifest = try manifestURL(create: true)
      let enc = JSONEncoder()
      enc.outputFormatting = [.sortedKeys]
      try enc.encode(items).write(to: manifest, options: [.atomic])
    } catch {
      // ignore
    }
  }
}
