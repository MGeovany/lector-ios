import Foundation

extension Book {
  init(remoteDocument doc: RemoteDocument) {
    let stableID = UUID(uuidString: doc.id) ?? UUID()

    let authorText =
      doc.author ?? doc.metadata.originalAuthor ?? "Unknown"

    // `page_count` can be missing/incorrect on list endpoints.
    // Never clamp the saved reading position down to 1 just because metadata is incomplete.
    let savedPageRaw = doc.readingPosition?.pageNumber ?? 1
    let savedPage = max(0, savedPageRaw)  // allow 0 = "not started"
    let totalPages = max(1, doc.metadata.pageCount ?? 1, max(1, savedPage))
    let startPage = min(savedPage, totalPages)
    let startProgress = doc.readingPosition?.progress
    let lastReadAt = doc.readingPosition?.updatedAt ?? doc.updatedAt
    let effectiveProgress =
      startProgress
      ?? (totalPages > 1 ? min(1.0, max(0.0, Double(min(max(1, startPage), totalPages)) / Double(totalPages)))
        : 0.0)
    let daysAgo = max(
      0,
      Calendar.current.dateComponents([.day], from: lastReadAt, to: Date()).day ?? 0
    )

    self.init(
      id: stableID,
      remoteID: doc.id,
      title: doc.title,
      author: authorText,
      createdAt: doc.createdAt,
      pagesTotal: totalPages,
      currentPage: startPage,
      readingProgress: startProgress,
      sizeBytes: doc.metadata.fileSize ?? 0,
      lastOpenedAt: lastReadAt,
      lastOpenedDaysAgo: daysAgo,
      isRead: effectiveProgress >= 0.999,
      isFavorite: doc.isFavorite,
      tags: doc.tag.map { [$0] } ?? []
    )
  }
}
