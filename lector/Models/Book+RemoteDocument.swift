import Foundation

extension Book {
  init(remoteDocument doc: RemoteDocument) {
    let stableID = UUID(uuidString: doc.id) ?? UUID()

    let authorText =
      doc.author ?? doc.metadata.originalAuthor ?? "Unknown"

    // `page_count` can be missing/incorrect on list endpoints.
    // Never clamp the saved reading position down to 1 just because metadata is incomplete.
    let savedPage = max(1, doc.readingPosition?.pageNumber ?? 1)  // 1-based
    let totalPages = max(1, doc.metadata.pageCount ?? 1, savedPage)
    let startPage = min(savedPage, totalPages)
    let startProgress = doc.readingPosition?.progress
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
      currentPage: startPage,
      readingProgress: startProgress,
      sizeBytes: doc.metadata.fileSize ?? 0,
      lastOpenedAt: doc.updatedAt,
      lastOpenedDaysAgo: daysAgo,
      isRead: (startPage >= totalPages && totalPages > 0),
      isFavorite: doc.isFavorite,
      tags: doc.tag.map { [$0] } ?? []
    )
  }
}
