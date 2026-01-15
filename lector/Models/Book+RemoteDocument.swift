import Foundation

extension Book {
  init(remoteDocument doc: RemoteDocument) {
    let stableID = UUID(uuidString: doc.id) ?? UUID()

    let authorText =
      doc.author ?? doc.metadata.originalAuthor ?? "Unknown"

    let totalPages = max(1, doc.metadata.pageCount ?? 1)
    let startPage = max(0, doc.readingPosition?.pageNumber ?? 0)
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
      currentPage: min(startPage, totalPages),
      sizeBytes: doc.metadata.fileSize ?? 0,
      lastOpenedDaysAgo: daysAgo,
      isRead: (startPage >= totalPages && totalPages > 0),
      isFavorite: doc.isFavorite,
      tags: doc.tag.map { [$0] } ?? []
    )
  }
}
