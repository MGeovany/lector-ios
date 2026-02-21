import Combine
import SwiftUI

// MARK: - Scene coordination (navigation, highlights)
// Single responsibility: navigate to highlight/search and manage highlight list.
// Depends on ReaderViewModel (document) and HighlightsServicing (abstraction).

@MainActor
final class ReaderSceneViewModel: ObservableObject {
  // Navigation: scroll to page (continuous) or scroll to text (paged)
  @Published var scrollToPageIndex: Int?
  @Published var scrollToPageToken: Int = 0
  @Published var scrollToPageAnchor: UnitPoint = .top
  @Published var scrollToText: String?
  @Published var scrollToTextToken: Int = 0

  @Published var documentHighlights: [RemoteHighlight] = []

  private let documentViewModel: ReaderViewModel
  private let book: Book
  private let highlightsService: HighlightsServicing
  private let debugNavLogs: Bool

  init(
    documentViewModel: ReaderViewModel,
    book: Book,
    highlightsService: HighlightsServicing = GoHighlightsService(),
    debugNavLogs: Bool = false
  ) {
    self.documentViewModel = documentViewModel
    self.book = book
    self.highlightsService = highlightsService
    self.debugNavLogs = debugNavLogs
  }

  func shouldUseContinuousScroll(
    continuousScrollForShortDocs: Bool,
    isLoading: Bool,
    pagesCount: Int
  ) -> Bool {
    continuousScrollForShortDocs
      && !isLoading
      && pagesCount > 0
      && pagesCount < ReaderLimits.continuousScrollMaxPages
  }

  func goToHighlight(
    _ h: RemoteHighlight,
    continuousScroll: Bool,
    onClearSelection: @escaping () -> Void
  ) {
    let total = documentViewModel.pages.count
    guard total > 0 else { return }

    let idx: Int = {
      if let page = h.pageNumber {
        return min(max(0, page - 1), total - 1)
      }
      if let pr = h.progress {
        return min(max(0, Int(round(min(1, max(0, pr)) * Double(total - 1)))), total - 1)
      }
      return min(max(0, documentViewModel.currentIndex), total - 1)
    }()

    // Defer state updates to next runloop to avoid "Modifying state during view update".
    Task { @MainActor in
      documentViewModel.currentIndex = idx

      if continuousScroll {
        let isNearEnd: Bool = {
          if let pr = h.progress, pr >= 0.7 { return true }
          if total > 0, Double(idx) >= Double(total - 1) * 0.75 { return true }
          return false
        }()
        let anchor: UnitPoint = isNearEnd ? .bottom : .top
        if debugNavLogs {
          print(
            "[ReaderNav] goToHighlight id=\(h.id) totalPages=\(total) idx=\(idx) anchor=\(anchor == .bottom ? "bottom" : "top")"
          )
        }
        requestScrollToPage(idx, anchor: anchor)
      } else {
        scrollToText = h.quote
        scrollToTextToken &+= 1
        if debugNavLogs {
          print("[ReaderNav] goToHighlight (paged) id=\(h.id) idx=\(idx) scrollToText token=\(scrollToTextToken)")
        }
      }
      onClearSelection()
    }
  }

  func handleSearchQuery(
    _ query: String,
    continuousScroll: Bool
  ) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty, !documentViewModel.pages.isEmpty else { return false }
    guard let idx = documentViewModel.pages.firstIndex(where: { $0.localizedCaseInsensitiveContains(q) }) else {
      return false
    }
    Task { @MainActor in
      documentViewModel.currentIndex = idx
      if continuousScroll {
        requestScrollToPage(idx, anchor: .top)
      } else {
        scrollToText = q
        scrollToTextToken &+= 1
        if debugNavLogs { print("[ReaderNav] search (paged) scrollToText token=\(scrollToTextToken)") }
      }
    }
    return true
  }

  func requestScrollToPage(_ idx: Int, anchor: UnitPoint = .top) {
    scrollToPageAnchor = anchor
    scrollToPageIndex = idx
    scrollToPageToken &+= 1
    if debugNavLogs {
      print(
        "[ReaderNav] requestScrollToPage idx=\(idx) anchor=\(anchor == .bottom ? "bottom" : "top") token=\(scrollToPageToken)"
      )
    }
  }

  func refreshHighlights() async {
    guard let id = book.remoteID, !id.isEmpty else {
      documentHighlights = []
      return
    }
    documentHighlights = (try? await highlightsService.listHighlights(documentID: id)) ?? []
  }

  func deleteHighlight(_ h: RemoteHighlight) async {
    do {
      try await highlightsService.deleteHighlight(highlightID: h.id)
      documentHighlights.removeAll { $0.id == h.id }
    } catch {
      // Non-blocking
    }
  }
}
