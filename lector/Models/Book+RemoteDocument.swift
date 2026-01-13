import Foundation

extension Book {
  init(remoteDocument doc: RemoteDocument) {
    let stableID = UUID(uuidString: doc.id) ?? UUID()

    let authorText =
      doc.author ?? doc.metadata.originalAuthor ?? "Unknown"

    let totalPages = max(1, doc.metadata.pageCount ?? 1)
    let daysAgo = max(
      0,
      Calendar.current.dateComponents([.day], from: doc.updatedAt, to: Date()).day ?? 0
    )

    self.init(
      id: stableID,
      remoteID: doc.id,
      title: doc.title,
      author: authorText,
      pagesTotal: totalPages,
      currentPage: 0,
      sizeBytes: doc.metadata.fileSize ?? 0,
      lastOpenedDaysAgo: daysAgo,
      isRead: false,
      isFavorite: doc.isFavorite,
      tags: doc.tag.map { [$0] } ?? []
    )
  }
}
