import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
  var filter: ReadingFilter = .recents
  var selectedBook: Book?

  private(set) var books: [Book] = []
  private(set) var isLoading: Bool = false
  var alertMessage: String?

  private let documentsService: DocumentsServicing
  private let userID: String
  private var didLoadOnce: Bool = false
  @ObservationIgnored private var documentsChangedObserver: NSObjectProtocol?

  init(
    documentsService: DocumentsServicing? = nil,
    userID: String? = nil
  ) {
    // Default arguments are evaluated outside actor isolation.
    // Doing the fallback inside the initializer avoids Swift 6 actor-isolation warnings.
    self.documentsService = documentsService ?? GoDocumentsService()
    self.userID =
      userID ?? KeychainStore.getString(account: KeychainKeys.userID) ?? APIConfig.defaultUserID
  }

  func onAppear() {
    guard !didLoadOnce else { return }
    didLoadOnce = true
    documentsChangedObserver = NotificationCenter.default.addObserver(
      forName: .documentsDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { await self.reload() }
    }
    Task { await reload() }
  }

  deinit {
    if let documentsChangedObserver {
      NotificationCenter.default.removeObserver(documentsChangedObserver)
    }
  }

  func reload() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let docs: [RemoteDocument]
      switch filter {
      case .recents:
        docs = try await loadRecents()
      case .all, .read:
        docs = try await documentsService.getDocumentsByUserID(userID)
      }
      books =
        docs
        .map(Book.init(remoteDocument:))
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load documents."
    }
  }

  /// Recents loading strategy (per request):
  /// - If total docs < 10 → return all.
  /// - Else try last 5 weeks window (created/updated) and take up to 10, minimum 3.
  /// - If nothing in 5 weeks → return top 3 most recently updated/created.
  private func loadRecents() async throws -> [RemoteDocument] {
    let fiveWeeksAgo =
      Calendar.current.date(byAdding: .day, value: -35, to: Date())
      ?? Date().addingTimeInterval(-35 * 24 * 60 * 60)

    // Try to get a recent subset from backend (best-effort).
    let backendRecent = try await documentsService.getRecentDocumentsByUserID(
      userID,
      since: fiveWeeksAgo,
      limit: 10
    )

    // If backend returns a full page, assume enough recents and avoid fetching everything.
    if backendRecent.count >= 10 {
      return backendRecent
    }

    // Otherwise, fetch all once to decide "< 10" vs ">= 10" and to apply the fallback rules.
    let allDocs = try await documentsService.getDocumentsByUserID(userID)
    if allDocs.count < 10 {
      return
        allDocs
        .sorted { recencyDate(for: $0) > recencyDate(for: $1) }
    }

    let windowDocs =
      allDocs
      .filter { recencyDate(for: $0) >= fiveWeeksAgo }
      .sorted { recencyDate(for: $0) > recencyDate(for: $1) }

    if windowDocs.count >= 3 {
      return Array(windowDocs.prefix(10))
    }

    // If < 3 in window (or none), fall back to top 3 most recent overall.
    let topOverall =
      allDocs
      .sorted { recencyDate(for: $0) > recencyDate(for: $1) }
    return Array(topOverall.prefix(3))
  }

  private func recencyDate(for doc: RemoteDocument) -> Date {
    max(doc.createdAt, doc.updatedAt)
  }

  func toggleRead(bookID: UUID) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    books[idx].isRead.toggle()
  }

  func toggleFavorite(bookID: UUID) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      return
    }

    let previous = books[idx].isFavorite
    books[idx].isFavorite.toggle()
    Task {
      do {
        try await documentsService.setFavorite(
          documentID: remoteID,
          isFavorite: books[idx].isFavorite
        )
      } catch {
        // Revert on failure.
        if let retryIdx = books.firstIndex(where: { $0.id == bookID }) {
          books[retryIdx].isFavorite = previous
        }
        alertMessage =
          (error as? LocalizedError)?.errorDescription ?? "Failed to update favorite."
      }
    }
  }

  func updateBookProgress(bookID: UUID, page: Int, totalPages: Int) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    books[idx].pagesTotal = max(1, totalPages)
    books[idx].currentPage = min(max(1, page), books[idx].pagesTotal)
    books[idx].isRead = (books[idx].currentPage >= books[idx].pagesTotal)
  }

  var filteredBooks: [Book] {
    switch filter {
    case .recents:
      // Return books sorted by last opened (most recent first)
      return books.sorted { $0.lastOpenedDaysAgo < $1.lastOpenedDaysAgo }
    case .all:
      return books
    case .read:
      return books.filter { $0.isRead }
    }
  }
}
