import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
  var filter: ReadingFilter = .unread
  var selectedBook: Book?

  private(set) var books: [Book] = []
  private(set) var isLoading: Bool = false
  var alertMessage: String?

  private let documentsService: DocumentsServicing
  private let userID: String
  private var didLoadOnce: Bool = false
  nonisolated(unsafe) private var documentsChangedObserver: NSObjectProtocol?

  init(
    documentsService: DocumentsServicing? = nil,
    userID: String? = nil
  ) {
    // Default arguments are evaluated outside actor isolation.
    // Doing the fallback inside the initializer avoids Swift 6 actor-isolation warnings.
    self.documentsService = documentsService ?? GoDocumentsService()
    self.userID = userID ?? KeychainStore.getString(account: KeychainKeys.userID) ?? APIConfig.defaultUserID
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
      let docs = try await documentsService.getDocumentsByUserID(userID)
      books =
        docs
        .map(Book.init(remoteDocument:))
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    } catch {
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load documents."
    }
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
    case .unread:
      return books.filter { !$0.isRead }
    case .read:
      return books.filter { $0.isRead }
    }
  }
}
