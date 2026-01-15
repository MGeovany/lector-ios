import Combine
import Foundation
import UIKit

@MainActor
final class ReaderViewModel: ObservableObject {
  @Published private(set) var pages: [String] = []
  @Published var currentIndex: Int = 0
  @Published private(set) var isLoading: Bool = false
  @Published var loadErrorMessage: String?
  private let emptyRemoteMessage = "No content to display."

  func setPages(_ newPages: [String], initialPage: Int?) {
    pages = newPages.isEmpty ? [""] : newPages

    let desiredIndex: Int = {
      if let initialPage {
        return max(0, initialPage - 1)
      }
      return currentIndex
    }()
    currentIndex = min(max(0, desiredIndex), max(0, pages.count - 1))
  }

  func goToPreviousPage() {
    currentIndex = max(0, currentIndex - 1)
  }

  func goToNextPage() {
    currentIndex = min(max(0, pages.count - 1), currentIndex + 1)
  }

  func loadRemoteDocumentIfNeeded(
    book: Book,
    documentsService: DocumentsServicing,
    containerSize: CGSize,
    style: TextPaginator.Style
  ) async {
    guard pages.isEmpty else { return }
    guard let id = book.remoteID, !id.isEmpty else {
      // No remote id => fallback to local sample pages.
      setPages(BookTextProvider.pages(for: book), initialPage: book.currentPage)
      return
    }

    isLoading = true
    loadErrorMessage = nil
    // Show a deterministic loading state while fetching remote content.
    // (If fetch returns no content, we replace this with `emptyRemoteMessage`.)
    setPages(["Loading…"], initialPage: 1)
    defer { isLoading = false }

    do {
      let doc = try await documentsService.getDocument(id: id)
      // Prefer backend page boundaries to match the web reader exactly.
      // If blocks don't have meaningful page numbers, fall back to local pagination.
      let pagesByBackend = Self.pagesPreservingBackendPages(doc.content)
      if pagesByBackend.count > 1
        || (pagesByBackend.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
      {
        setPages(pagesByBackend, initialPage: book.currentPage)
        return
      }

      let text = Self.flattenContent(doc.content)

      // If the backend returns an empty/omitted content array (or it flattens to empty),
      // don't paginate an empty string; show an explicit placeholder instead.
      if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        loadErrorMessage = nil
        setPages([emptyRemoteMessage], initialPage: 1)
        return
      }

      let paged = TextPaginator.paginate(text: text, containerSize: containerSize, style: style)
      setPages(paged, initialPage: book.currentPage)
    } catch {
      loadErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load document."
      setPages([""], initialPage: 1)
    }
  }

  private static func pagesPreservingBackendPages(_ blocks: [RemoteContentBlock]) -> [String] {
    guard !blocks.isEmpty else { return [] }

    // Group by page_number (ignoring 0/negative which are usually "unknown").
    let valid = blocks.filter { $0.pageNumber > 0 }
    guard !valid.isEmpty else { return [] }

    let grouped = Dictionary(grouping: valid) { $0.pageNumber }
    let pageNumbers = grouped.keys.sorted()

    var pages: [String] = []
    pages.reserveCapacity(pageNumbers.count)

    for n in pageNumbers {
      let pageBlocks = (grouped[n] ?? []).sorted { $0.position < $1.position }
      var out: [String] = []
      out.reserveCapacity(pageBlocks.count)

      for b in pageBlocks {
        let trimmed = b.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        switch b.type.lowercased() {
        case "heading":
          out.append(trimmed.uppercased())
        default:
          out.append(trimmed)
        }
      }

      let pageText = out.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
      pages.append(pageText.isEmpty ? " " : pageText)
    }

    return pages.isEmpty ? [""] : pages
  }

  private static func flattenContent(_ blocks: [RemoteContentBlock]) -> String {
    guard !blocks.isEmpty else { return "" }

    let sorted = blocks.sorted {
      if $0.pageNumber != $1.pageNumber { return $0.pageNumber < $1.pageNumber }
      return $0.position < $1.position
    }

    var out: [String] = []
    out.reserveCapacity(sorted.count)

    for b in sorted {
      let trimmed = b.content.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      switch b.type.lowercased() {
      case "heading":
        out.append(trimmed.uppercased())
      default:
        out.append(trimmed)
      }
    }

    return out.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
