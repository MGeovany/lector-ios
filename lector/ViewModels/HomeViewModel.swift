import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
  var filter: ReadingFilter = .recents
  var selectedBook: Book?
  var searchQuery: String = ""

  private(set) var books: [Book] = []
  private(set) var availableTags: [String] = []
  private(set) var isLoading: Bool = false
  var alertMessage: String?

  private let documentsService: DocumentsServicing
  private let readingPositionService: ReadingPositionServicing
  private let userID: String
  private var didLoadOnce: Bool = false
  @ObservationIgnored private var documentsChangedObserver: NSObjectProtocol?
  @ObservationIgnored private var pendingReadingPositionTasks: [String: Task<Void, Never>] = [:]

  init(
    documentsService: DocumentsServicing? = nil,
    readingPositionService: ReadingPositionServicing? = nil,
    userID: String? = nil
  ) {
    // Default arguments are evaluated outside actor isolation.
    // Doing the fallback inside the initializer avoids Swift 6 actor-isolation warnings.
    self.documentsService = documentsService ?? GoDocumentsService()
    self.readingPositionService = readingPositionService ?? GoReadingPositionService()
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
    Task { await refreshTags() }
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
      let next =
        docs
        .map(Book.init(remoteDocument:))
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
      books = next
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

  func refreshTags() async {
    do {
      let tags = try await documentsService.getDocumentTags()
      availableTags = tags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    } catch {
      // Non-blocking; tags are optional UI.
    }
  }

  func setTag(bookID: UUID, tag: String?) async {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      return
    }

    // Backend uses single tag. To clear, send empty string to remove relationship.
    let trimmed = tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let payloadTag: String? = trimmed.isEmpty ? "" : trimmed

    do {
      _ = try await documentsService.updateDocument(
        documentID: remoteID,
        title: nil,
        author: nil,
        tag: payloadTag
      )
      books[idx].tags = trimmed.isEmpty ? [] : [trimmed]
      // Keep tag list fresh (if user created tags elsewhere).
      if !trimmed.isEmpty
        && !availableTags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
      {
        await refreshTags()
      }
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update tag."
    }
  }

  func createTag(name: String) async {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do {
      try await documentsService.createDocumentTag(name: trimmed)
      await refreshTags()
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to create tag."
    }
  }

  func updateBookDetails(bookID: UUID, title: String, author: String, tag: String) async {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      return
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)

    do {
      _ = try await documentsService.updateDocument(
        documentID: remoteID,
        title: trimmedTitle,
        author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
        tag: trimmedTag.isEmpty ? "" : trimmedTag
      )

      books[idx].title = trimmedTitle.isEmpty ? books[idx].title : trimmedTitle
      books[idx].author = trimmedAuthor.isEmpty ? books[idx].author : trimmedAuthor
      books[idx].tags = trimmedTag.isEmpty ? [] : [trimmedTag]

      // Keep tag list fresh if user typed a new tag name.
      if !trimmedTag.isEmpty {
        await refreshTags()
      }
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update details."
    }
  }

  func toggleRead(bookID: UUID) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    books[idx].isRead.toggle()
  }

  func markAsRead(bookID: UUID) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    books[idx].isRead = true
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
        // Keep other tabs / lists in sync.
        NotificationCenter.default.post(name: .documentsDidChange, object: nil)
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

  func updateBookProgress(bookID: UUID, page: Int, totalPages: Int, progressOverride: Double? = nil)
  {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    books[idx].pagesTotal = max(1, totalPages)
    books[idx].currentPage = min(max(1, page), books[idx].pagesTotal)
    if let progressOverride {
      books[idx].readingProgress = min(1.0, max(0.0, progressOverride))
    }
    books[idx].isRead = (books[idx].currentPage >= books[idx].pagesTotal)

    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else { return }

    // Debounce network updates so we don't spam the backend while the user flips pages quickly.
    pendingReadingPositionTasks[remoteID]?.cancel()
    let pageNumber = books[idx].currentPage
    let progress =
      progressOverride
      ?? min(1.0, max(0.0, Double(pageNumber) / Double(max(1, books[idx].pagesTotal))))
    pendingReadingPositionTasks[remoteID] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 650_000_000)  // ~0.65s
      guard let self else { return }
      do {
        try await self.readingPositionService.updateReadingPosition(
          documentID: remoteID,
          pageNumber: pageNumber,
          progress: progress
        )
      } catch {
        // Non-blocking: keep UX smooth even if the backend fails.
      }
    }
  }

  func deleteBook(bookID: UUID) async {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      return
    }

    do {
      try await documentsService.deleteDocument(documentID: remoteID)
      // Remove locally.
      books.remove(at: idx)
      if selectedBook?.id == bookID { selectedBook = nil }
      // Notify other tabs/lists to refresh.
      NotificationCenter.default.post(name: .documentsDidChange, object: nil)
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to delete document."
    }
  }

  var filteredBooks: [Book] {
    let base: [Book] = {
      switch filter {
      case .recents:
        // Return books sorted by last opened (most recent first)
        return books.sorted { $0.lastOpenedSortDate > $1.lastOpenedSortDate }
      case .all:
        return books
      case .read:
        return books.filter { $0.isRead }
      }
    }()

    let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return base }
    let lowered = q.lowercased()
    return base.filter { book in
      if book.title.lowercased().contains(lowered) { return true }
      if book.author.lowercased().contains(lowered) { return true }
      if book.tags.contains(where: { $0.lowercased().contains(lowered) }) { return true }
      return false
    }
  }
}
