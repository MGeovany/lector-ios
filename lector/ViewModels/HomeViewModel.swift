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
  private let indexStore = DocumentsIndexStore()
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

  /// Polls backend optimized status until it becomes `ready`, fails, or times out.
  /// Returns true if it looks safe to open the reader now.
  /// Throws (e.g. `CancellationError`) when the task is cancelled so the caller can avoid setting `selectedBook`.
  func waitForOptimizedReady(documentID: String, maxWaitSeconds: Int = 45) async throws -> Bool {
    guard !documentID.isEmpty else { return true }
    let intervalSeconds: Int = 2
    var waited: Int = 0

    while waited <= maxWaitSeconds {
      if Task.isCancelled {
        throw CancellationError()
      }
      do {
        let meta = try await documentsService.getOptimizedDocumentMeta(id: documentID)
        switch meta.processingStatus.lowercased() {
        case "ready":
          return true
        case "failed":
          return true // open anyway; reader will show an error message
        default:
          break
        }
      } catch let cancel as CancellationError {
        throw cancel
      } catch APIError.server(let status, _) where status == 404 {
        // Backend doesn't support optimized endpoint; open reader and fall back.
        return true
      } catch {
        // Keep polling on transient errors.
      }

      try await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
      waited += intervalSeconds
    }

    // Timeout: open anyway; reader has its own loader.
    return true
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

    // Offline-first: show local index immediately.
    let cached = indexStore.load()
    if !cached.isEmpty {
      let baseBooks = cached.map { summary in
        let pending = PendingReadingPositionStore.get(documentID: summary.id)
        let currentPage = pending.map { $0.pageNumber } ?? summary.currentPage
        let readingProgress = pending?.progress ?? summary.readingProgress
        let pagesTotal = max(1, summary.pagesTotal, currentPage)
        let lastReadAt = pending?.updatedAt ?? summary.readingPositionUpdatedAt ?? summary.updatedAt
        let effectiveProgress =
          readingProgress
          ?? (pagesTotal > 1
            ? min(1.0, max(0.0, Double(min(max(1, currentPage), pagesTotal)) / Double(pagesTotal)))
            : 0.0)
        return Book(
          id: UUID(uuidString: summary.id) ?? UUID(),
          remoteID: summary.id,
          title: summary.title,
          author: summary.author,
          createdAt: summary.createdAt,
          pagesTotal: pagesTotal,
          currentPage: min(currentPage, pagesTotal),
          readingProgress: readingProgress,
          sizeBytes: summary.sizeBytes,
          lastOpenedAt: lastReadAt,
          lastOpenedDaysAgo: max(
            0,
            Calendar.current.dateComponents(
              [.day], from: lastReadAt, to: Date()
            ).day ?? 0
          ),
          isRead: effectiveProgress >= 0.999,
          isFavorite: summary.isFavorite,
          tags: summary.tag.map { [$0] } ?? []
        )
      }

      switch filter {
      case .recents:
        books = baseBooks.sorted { $0.lastOpenedSortDate > $1.lastOpenedSortDate }
      case .all, .read:
        books = baseBooks.sorted {
          $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
      }
    }

    // Add any queued uploads as local-only placeholders.
    let queued = PendingUploadsStore.list()
    if !queued.isEmpty {
      let queuedBooks: [Book] = queued.map { item in
        let baseTitle = URL(fileURLWithPath: item.fileName).deletingPathExtension().lastPathComponent
        return Book(
          id: UUID(uuidString: item.id) ?? UUID(),
          remoteID: nil,
          title: baseTitle.isEmpty ? item.fileName : baseTitle,
          author: "Queued",
          createdAt: item.createdAt,
          pagesTotal: 1,
          currentPage: 1,
          readingProgress: nil,
          sizeBytes: 0,
          lastOpenedAt: item.createdAt,
          lastOpenedDaysAgo: 0,
          isRead: false,
          isFavorite: false,
          tags: ["Book"]
        )
      }
      books = queuedBooks + books
    }

    guard NetworkMonitor.shared.isOnline else {
      return
    }

    do {
      let docs: [RemoteDocument]
      switch filter {
      case .recents:
        docs = try await loadRecents()
      case .all, .read:
        docs = try await documentsService.getDocumentsByUserID(userID)
      }
      var next =
        docs
        .map(Book.init(remoteDocument:))
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
      for i in next.indices {
        guard let rid = next[i].remoteID, !rid.isEmpty else { continue }
        if let pending = PendingReadingPositionStore.get(documentID: rid) {
          next[i].pagesTotal = max(1, next[i].pagesTotal, pending.pageNumber)
          next[i].currentPage = min(pending.pageNumber, next[i].pagesTotal)
          next[i].readingProgress = pending.progress
          next[i].isRead = min(1.0, max(0.0, pending.progress)) >= 0.999
        }
      }
      books = next

      // Persist metadata for offline-first browsing.
      indexStore.save(from: docs)
      // Never keep non-pinned optimized payloads on disk.
      OptimizedPagesStore.pruneUnpinned()
      // Sync pending reading positions saved while offline; remove from local store once on server.
      for pending in PendingReadingPositionStore.list() {
        do {
          try await readingPositionService.updateReadingPosition(
            documentID: pending.documentID,
            pageNumber: pending.pageNumber,
            progress: pending.progress
          )
          PendingReadingPositionStore.remove(documentID: pending.documentID)
        } catch {
          // Keep in store for next sync.
        }
      }
    } catch {
      // If we already have content, avoid blocking the UX with an alert on transient network failures
      // (e.g. pull-to-refresh while offline). Keep existing books visible.
      if !books.isEmpty, (error as? APIError) == .network {
        return
      }
      let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to load documents."
      alertMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "reload_documents"])
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
      PostHogAnalytics.captureError(message: "Missing document id.", context: ["action": "set_tag"])
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
      PostHogAnalytics.capture("tag_updated", properties: ["document_id": remoteID])
    } catch {
      let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to update tag."
      alertMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "set_tag"])
    }
  }

  func createTag(name: String) async {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do {
      try await documentsService.createDocumentTag(name: trimmed)
      await refreshTags()
      PostHogAnalytics.capture("tag_created", properties: ["tag": trimmed])
    } catch {
      let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to create tag."
      alertMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "create_tag"])
    }
  }

  func deleteTag(name: String) async {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do {
      try await documentsService.deleteDocumentTag(name: trimmed)
      await refreshTags()
      // If any books were using this tag, remove it from them
      for idx in books.indices {
        if books[idx].tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
          books[idx].tags.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
      }
    } catch {
      // Ignore "Tag not found" errors - tag may have already been deleted
      let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      if !errorMessage.lowercased().contains("tag not found")
        && !errorMessage.lowercased().contains("not found")
      {
        alertMessage = errorMessage
        PostHogAnalytics.captureError(message: errorMessage, context: ["action": "delete_tag"])
      } else {
        // Tag doesn't exist, just remove it locally and refresh
        await refreshTags()
        for idx in books.indices {
          if books[idx].tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
          {
            books[idx].tags.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
          }
        }
      }
    }
  }

  func updateBookDetails(bookID: UUID, title: String, author: String, tag: String) async {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      PostHogAnalytics.captureError(message: "Missing document id.", context: ["action": "update_book_details"])
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
      PostHogAnalytics.capture("book_details_updated", properties: ["document_id": remoteID])
    } catch {
      let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to update details."
      alertMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "update_book_details"])
    }
  }

  func toggleRead(bookID: UUID) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    setCompletion(bookID: bookID, completed: !books[idx].isRead)
  }

  func markAsRead(bookID: UUID) {
    setCompletion(bookID: bookID, completed: true)
  }

  /// Persists completion by updating the backend reading position.
  /// - completed=true: sets page=pagesTotal and progress=1.0
  /// - completed=false: sets page=1 and progress=0.0
  func setCompletion(bookID: UUID, completed: Bool) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    let total = max(1, books[idx].pagesTotal)
    if completed {
      updateBookProgress(bookID: bookID, page: total, totalPages: total, progressOverride: 1.0)
    } else {
      // Special-case single-page docs: page=1 implies 100% in page-based math.
      // Persist page_number=0 so backend + reload don't mark it as read again.
      let persistedPageOverride: Int? = (total == 1) ? 0 : nil
      updateBookProgress(
        bookID: bookID,
        page: 1,
        totalPages: total,
        progressOverride: 0.0,
        persistedPageNumberOverride: persistedPageOverride
      )
    }
  }

  func toggleFavorite(bookID: UUID) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      PostHogAnalytics.captureError(message: "Missing document id.", context: ["action": "toggle_favorite"])
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
        PostHogAnalytics.capture("favorite_toggled", properties: ["document_id": remoteID, "is_favorite": books[idx].isFavorite])
      } catch {
        // Revert on failure.
        if let retryIdx = books.firstIndex(where: { $0.id == bookID }) {
          books[retryIdx].isFavorite = previous
        }
        let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to update favorite."
        alertMessage = msg
        PostHogAnalytics.captureError(message: msg, context: ["action": "toggle_favorite"])
      }
    }
  }

  func updateBookProgress(
    bookID: UUID,
    page: Int,
    totalPages: Int,
    progressOverride: Double? = nil,
    persistedPageNumberOverride: Int? = nil
  ) {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    books[idx].pagesTotal = max(1, totalPages)
    books[idx].currentPage = min(max(1, page), books[idx].pagesTotal)
    if let progressOverride {
      books[idx].readingProgress = min(1.0, max(0.0, progressOverride))
    }

    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else { return }

    // Debounce network updates so we don't spam the backend while the user flips pages quickly.
    pendingReadingPositionTasks[remoteID]?.cancel()
    let persistedPageNumber = persistedPageNumberOverride ?? books[idx].currentPage
    let progress =
      progressOverride
      ?? min(1.0, max(0.0, Double(persistedPageNumber) / Double(max(1, books[idx].pagesTotal))))

    // Derive read state from progress so single-page books can be "unread" again when progress=0.
    books[idx].isRead = progress >= 0.999
    pendingReadingPositionTasks[remoteID] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 650_000_000)  // ~0.65s
      guard let self else { return }
      do {
        try await self.readingPositionService.updateReadingPosition(
          documentID: remoteID,
          pageNumber: persistedPageNumber,
          progress: progress
        )
        PendingReadingPositionStore.remove(documentID: remoteID)
      } catch {
        PendingReadingPositionStore.save(
          documentID: remoteID, pageNumber: persistedPageNumber, progress: progress)
      }
    }
  }

  func deleteBook(bookID: UUID) async {
    guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
    guard let remoteID = books[idx].remoteID, !remoteID.isEmpty else {
      alertMessage = "Missing document id."
      PostHogAnalytics.captureError(message: "Missing document id.", context: ["action": "delete_book"])
      return
    }

    do {
      try await documentsService.deleteDocument(documentID: remoteID)
      books.remove(at: idx)
      if selectedBook?.id == bookID { selectedBook = nil }
      NotificationCenter.default.post(name: .documentsDidChange, object: nil)
      PostHogAnalytics.capture("document_deleted", properties: ["document_id": remoteID])
    } catch {
      let msg = (error as? LocalizedError)?.errorDescription ?? "Failed to delete document."
      alertMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "delete_book"])
    }
  }

  var filteredBooks: [Book] {
    let base: [Book] = {
      switch filter {
      case .recents:
        // Unread first, then most recently opened.
        return books.sorted { lhs, rhs in
          if lhs.isRead != rhs.isRead { return !lhs.isRead }
          if lhs.lastOpenedSortDate != rhs.lastOpenedSortDate {
            return lhs.lastOpenedSortDate > rhs.lastOpenedSortDate
          }
          // Deterministic tie-breaker (stable-ish ordering).
          return lhs.id.uuidString < rhs.id.uuidString
        }
      case .all:
        // Unread first, then title (A→Z).
        return books.sorted { lhs, rhs in
          if lhs.isRead != rhs.isRead { return !lhs.isRead }
          let c = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
          if c != .orderedSame { return c == .orderedAscending }
          return lhs.id.uuidString < rhs.id.uuidString
        }
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

  // MARK: - Library Sections (All / Current / To read / Finished)

  /// Returns books for the requested Library section, applying the same search behavior
  /// as `filteredBooks`.
  func libraryBooks(for section: LibrarySection) -> [Book] {
    let base: [Book] = {
      switch section {
      case .allBooks:
        // Unread first, then title (A→Z).
        return books.sorted { lhs, rhs in
          if lhs.isRead != rhs.isRead { return !lhs.isRead }
          let c = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
          if c != .orderedSame { return c == .orderedAscending }
          return lhs.id.uuidString < rhs.id.uuidString
        }

      case .current:
        // In progress (started but not finished), most recently opened first.
        return
          books
          .filter { book in
            !book.isRead && !isToRead(book)
          }
          .sorted { lhs, rhs in
            if lhs.lastOpenedSortDate != rhs.lastOpenedSortDate {
              return lhs.lastOpenedSortDate > rhs.lastOpenedSortDate
            }
            return lhs.id.uuidString < rhs.id.uuidString
          }

      case .toRead:
        // Not started yet; sort by title.
        return
          books
          .filter { book in
            !book.isRead && isToRead(book)
          }
          .sorted { lhs, rhs in
            let c = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if c != .orderedSame { return c == .orderedAscending }
            return lhs.id.uuidString < rhs.id.uuidString
          }

      case .finished:
        // Finished; most recently opened first.
        return
          books
          .filter { $0.isRead }
          .sorted { lhs, rhs in
            if lhs.lastOpenedSortDate != rhs.lastOpenedSortDate {
              return lhs.lastOpenedSortDate > rhs.lastOpenedSortDate
            }
            return lhs.id.uuidString < rhs.id.uuidString
          }
      }
    }()

    return applySearch(to: base)
  }

  private func isToRead(_ book: Book) -> Bool {
    // Heuristic: "to read" means not finished and effectively not started.
    // Many items start at page 1 by default, so we treat page 1 + near-zero progress as "not started".
    guard !book.isRead else { return false }
    let rp = min(1.0, max(0.0, book.readingProgress ?? 0))
    return book.currentPage <= 1 && rp <= 0.02
  }

  private func applySearch(to base: [Book]) -> [Book] {
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

extension HomeViewModel {
  static func previewLibrary(books: [Book]) -> HomeViewModel {
    let vm = HomeViewModel()
    vm.filter = .all
    vm.searchQuery = ""
    vm.books = books
    vm.availableTags = ["Book", "Essay", "Notes", "Poetry"]
    vm.isLoading = false
    // Prevent `onAppear()` from calling `reload()` in previews.
    vm.didLoadOnce = true
    return vm
  }
}
