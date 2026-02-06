import Foundation

enum OfflinePinStore {
  private static let pinnedKey = "offline.pinnedDocumentIDs"

  static func isPinned(remoteID: String) -> Bool {
    pinnedIDs().contains(remoteID)
  }

  static func setPinned(remoteID: String, pinned: Bool) {
    var set = pinnedIDs()
    if pinned {
      set.insert(remoteID)
    } else {
      set.remove(remoteID)
    }
    UserDefaults.standard.set(Array(set), forKey: pinnedKey)
  }

  static func pinnedIDs() -> Set<String> {
    let ids = UserDefaults.standard.array(forKey: pinnedKey) as? [String] ?? []
    return Set(ids)
  }
}

enum OptimizedPagesStore {
  struct Manifest: Codable {
    let remoteID: String
    let optimizedVersion: Int
    let optimizedChecksumSHA256: String?
    let savedAt: Date
  }

  private static let fm = FileManager.default

  private static func baseDir() throws -> URL {
    let root = try fm.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let dir = root.appendingPathComponent("OfflineDocuments", isDirectory: true)
    if !fm.fileExists(atPath: dir.path) {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private static func docDir(remoteID: String) throws -> URL {
    try baseDir().appendingPathComponent(remoteID, isDirectory: true)
  }

  static func loadPages(remoteID: String, expectedChecksum: String?) -> [String]? {
    do {
      let dir = try docDir(remoteID: remoteID)
      let manifestURL = dir.appendingPathComponent("manifest.json")
      let pagesURL = dir.appendingPathComponent("pages.json")
      guard fm.fileExists(atPath: manifestURL.path), fm.fileExists(atPath: pagesURL.path) else {
        return nil
      }

      let manifestData = try Data(contentsOf: manifestURL)
      let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
      if let expectedChecksum, !expectedChecksum.isEmpty {
        if let saved = manifest.optimizedChecksumSHA256, saved == expectedChecksum {
          // ok
        } else {
          return nil
        }
      }

      let pagesData = try Data(contentsOf: pagesURL)
      return try JSONDecoder().decode([String].self, from: pagesData)
    } catch {
      return nil
    }
  }

  static func loadManifest(remoteID: String) -> Manifest? {
    do {
      let dir = try docDir(remoteID: remoteID)
      let manifestURL = dir.appendingPathComponent("manifest.json")
      guard fm.fileExists(atPath: manifestURL.path) else { return nil }
      let manifestData = try Data(contentsOf: manifestURL)
      return try JSONDecoder().decode(Manifest.self, from: manifestData)
    } catch {
      return nil
    }
  }

  static func hasLocalCopy(remoteID: String) -> Bool {
    loadManifest(remoteID: remoteID) != nil
  }

  static func savePages(
    remoteID: String,
    pages: [String],
    optimizedVersion: Int,
    optimizedChecksumSHA256: String?
  ) throws {
    let dir = try docDir(remoteID: remoteID)
    if !fm.fileExists(atPath: dir.path) {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    let manifest = Manifest(
      remoteID: remoteID,
      optimizedVersion: max(1, optimizedVersion),
      optimizedChecksumSHA256: optimizedChecksumSHA256,
      savedAt: Date()
    )

    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys]

    let manifestURL = dir.appendingPathComponent("manifest.json")
    let pagesURL = dir.appendingPathComponent("pages.json")
    try enc.encode(manifest).write(to: manifestURL, options: [.atomic])
    try enc.encode(pages).write(to: pagesURL, options: [.atomic])
  }

  static func delete(remoteID: String) {
    do {
      let dir = try docDir(remoteID: remoteID)
      if fm.fileExists(atPath: dir.path) {
        try fm.removeItem(at: dir)
      }
    } catch {
      // ignore
    }
  }

  static func pruneUnpinned() {
    let pinned = OfflinePinStore.pinnedIDs()
    do {
      let dir = try baseDir()
      let children = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
      for child in children {
        let id = child.lastPathComponent
        if !pinned.contains(id) {
          try? fm.removeItem(at: child)
        }
      }
    } catch {
      // ignore
    }
  }
}

// Stores a lightweight local index of documents for offline-first library rendering.
final class DocumentsIndexStore {
  struct Summary: Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let pagesTotal: Int
    let currentPage: Int
    let readingProgress: Double?
    /// Last time the reading position was updated (if available).
    let readingPositionUpdatedAt: Date?
    let sizeBytes: Int64
    let updatedAt: Date
    let createdAt: Date
    let isFavorite: Bool
    let tag: String?

    let processingStatus: String?
    let optimizedVersion: Int?
    let optimizedChecksumSHA256: String?
    let languageCode: String?
    let processedAt: Date?
  }

  private let fm = FileManager.default
  private let url: URL

  init(fileName: String = "documents_index.json") {
    let root = (try? fm.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )) ?? fm.temporaryDirectory
    self.url = root.appendingPathComponent(fileName)
  }

  func load() -> [Summary] {
    do {
      guard fm.fileExists(atPath: url.path) else { return [] }
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([Summary].self, from: data)
    } catch {
      return []
    }
  }

  func save(from remote: [RemoteDocument]) {
    let summaries: [Summary] = remote.map { doc in
      let authorText = doc.author ?? doc.metadata.originalAuthor ?? "Unknown"
      let savedPage = max(1, doc.readingPosition?.pageNumber ?? 1)
      let totalPages = max(1, doc.metadata.pageCount ?? 1, savedPage)
      let startPage = min(savedPage, totalPages)
      let size = doc.originalSizeBytes ?? doc.metadata.fileSize ?? 0

      return Summary(
        id: doc.id,
        title: doc.title,
        author: authorText,
        pagesTotal: totalPages,
        currentPage: startPage,
        readingProgress: doc.readingPosition?.progress,
        readingPositionUpdatedAt: doc.readingPosition?.updatedAt,
        sizeBytes: size,
        updatedAt: doc.updatedAt,
        createdAt: doc.createdAt,
        isFavorite: doc.isFavorite,
        tag: doc.tag,
        processingStatus: doc.processingStatus,
        optimizedVersion: doc.optimizedVersion,
        optimizedChecksumSHA256: doc.optimizedChecksumSHA256,
        languageCode: doc.languageCode,
        processedAt: doc.processedAt
      )
    }

    do {
      let enc = JSONEncoder()
      enc.outputFormatting = [.sortedKeys]
      try enc.encode(summaries).write(to: url, options: [.atomic])
    } catch {
      // ignore
    }
  }
}
