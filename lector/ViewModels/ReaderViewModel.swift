import Combine
import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
  @Published private(set) var pages: [String] = []
  @Published var currentIndex: Int = 0
  @Published private(set) var isLoading: Bool = false
  @Published var loadErrorMessage: String?
  private let emptyRemoteMessage = "No content to display."
  
  #if DEBUG
    private func debugLog(_ message: String) {
      print("[ReaderLoad] \(message)")
    }
  #endif

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
    
    #if DEBUG
      debugLog("start docID=\(id) title=\(book.title)")
    #endif

    // Offline-first: prefer cached optimized pages.
    if let cached = OptimizedPagesStore.loadPages(remoteID: id, expectedChecksum: nil),
      !cached.isEmpty
    {
      #if DEBUG
        debugLog("cache_hit docID=\(id) pages=\(cached.count)")
      #endif
      setPages(cached, initialPage: book.currentPage)

      // If the user pinned this doc for offline, refresh in background when possible.
      if OfflinePinStore.isPinned(remoteID: id) {
        let savedChecksum = OptimizedPagesStore.loadManifest(remoteID: id)?.optimizedChecksumSHA256
        Task {
          if let opt = try? await documentsService.getOptimizedDocument(id: id),
            opt.processingStatus == "ready",
            let nextChecksum = opt.optimizedChecksumSHA256,
            let pages = opt.pages,
            !pages.isEmpty,
            savedChecksum != nextChecksum
          {
            try? OptimizedPagesStore.savePages(
              remoteID: id,
              pages: pages,
              optimizedVersion: opt.optimizedVersion,
              optimizedChecksumSHA256: opt.optimizedChecksumSHA256
            )
          }
        }
      }
      return
    }

    #if DEBUG
      debugLog("cache_miss docID=\(id) fetching_optimized=1")
    #endif

    isLoading = true
    loadErrorMessage = nil

    // Safety: update subtitle if the spinner takes too long.
    let watchdog = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 6_000_000_000)
      if self.isLoading, (self.loadErrorMessage ?? "").isEmpty {
        self.loadErrorMessage = "Still working…"
      }
    }

    do {
      // Prefer optimized offline-first payload.
      // Backend may return partial pages while still `processing`.
      // Retry once on network error (e.g. Cloud Run cold start timeout).
      var opt: RemoteOptimizedDocument?
      do {
        opt = try await documentsService.getOptimizedDocument(id: id)
      } catch APIError.network {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        opt = try await documentsService.getOptimizedDocument(id: id)
      } catch APIError.server(let statusCode, _) where statusCode == 404 {
        // Backend revision doesn't support `/documents/{id}/optimized` yet.
        opt = nil
      }

      if var opt = opt {
        #if DEBUG
          let pagesCount = opt.pages?.count ?? 0
          debugLog(
            "optimized docID=\(id) status=\(opt.processingStatus) pages=\(pagesCount) optVer=\(opt.optimizedVersion) checksum=\(opt.optimizedChecksumSHA256 ?? "nil")"
          )
        #endif
        if let pages = opt.pages, !pages.isEmpty {
          setPages(pages, initialPage: book.currentPage)
          isLoading = false
          loadErrorMessage = nil
          watchdog.cancel()
          if OfflinePinStore.isPinned(remoteID: id) {
            try? OptimizedPagesStore.savePages(
              remoteID: id,
              pages: pages,
              optimizedVersion: opt.optimizedVersion,
              optimizedChecksumSHA256: opt.optimizedChecksumSHA256
            )
          }
          return
        }

        if opt.processingStatus == "failed" {
          #if DEBUG
            debugLog("optimized_failed docID=\(id)")
          #endif
          loadErrorMessage = "Failed to process."
          isLoading = false
          watchdog.cancel()
          setPages([""], initialPage: 1)
          return
        }

        if opt.processingStatus != "ready" {
          #if DEBUG
            debugLog("optimized_processing docID=\(id) status=\(opt.processingStatus)")
          #endif
          loadErrorMessage = "Preparing your document…"
          let maxWaitSeconds: Int = 12
          let intervalSeconds: Int = 2
          var waited: Int = 0

          while opt.processingStatus != "ready", opt.processingStatus != "failed",
            waited < maxWaitSeconds
          {
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
            waited += intervalSeconds
            loadErrorMessage = "Preparing your document…"
            if let next = try? await documentsService.getOptimizedDocument(id: id) {
              opt = next
            }
            #if DEBUG
              let pagesCount = opt.pages?.count ?? 0
              debugLog("optimized_poll docID=\(id) waited=\(waited)s status=\(opt.processingStatus) pages=\(pagesCount)")
            #endif
            if let pages = opt.pages, !pages.isEmpty {
              setPages(pages, initialPage: book.currentPage)
              isLoading = false
              loadErrorMessage = nil
              watchdog.cancel()
              return
            }
          }

          if opt.processingStatus == "failed" {
            #if DEBUG
              debugLog("optimized_failed_after_poll docID=\(id) waited=\(waited)s")
            #endif
            loadErrorMessage = "Failed to process."
            isLoading = false
            watchdog.cancel()
            setPages([""], initialPage: 1)
            return
          }

          // Keep the loader up; backend continues processing.
          #if DEBUG
            debugLog("optimized_timeout_keep_loader docID=\(id) waited=\(waited)s lastStatus=\(opt.processingStatus)")
          #endif
          loadErrorMessage = "Still preparing…"
          watchdog.cancel()
          return
        }
        
        #if DEBUG
          // `ready` but no pages payload: we'll fall back to full doc blocks.
          debugLog("optimized_ready_but_empty_pages docID=\(id) fallback_to_document_detail=1")
        #endif
      }

      // Fallback (older docs/backends): fetch full content and paginate.
      let doc = try await documentsService.getDocument(id: id)
      #if DEBUG
        let blocks = doc.content
        let types = Dictionary(grouping: blocks, by: { $0.type.lowercased() }).mapValues(\.count)
        let nonEmpty = blocks.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        debugLog(
          "document_detail docID=\(id) format=\(doc.metadata.format ?? "nil") pageCount=\(doc.metadata.pageCount ?? -1) wordCount=\(doc.metadata.wordCount ?? -1) hasPassword=\(doc.metadata.hasPassword ?? false) blocks=\(blocks.count) nonEmptyBlocks=\(nonEmpty) types=\(types)"
        )
        for (i, b) in blocks.prefix(3).enumerated() {
          let snippet = b.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
          debugLog("block[\(i)] type=\(b.type) page=\(b.pageNumber) pos=\(b.position) len=\(b.content.count) snippet=\(snippet)")
        }
      #endif
      // Prefer backend page boundaries to match the web reader exactly.
      // If blocks don't have meaningful page numbers, fall back to local pagination.
      let pagesByBackend = Self.pagesPreservingBackendPages(doc.content)
      #if DEBUG
        debugLog("pagesByBackend docID=\(id) pages=\(pagesByBackend.count) firstLen=\(pagesByBackend.first?.count ?? 0)")
      #endif
      if pagesByBackend.count > 1
        || (pagesByBackend.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
      {
        setPages(pagesByBackend, initialPage: book.currentPage)
        isLoading = false
        watchdog.cancel()
        #if DEBUG
          debugLog("done_using_backend_pages docID=\(id)")
        #endif
        return
      }

      let text = Self.flattenContent(doc.content)
      #if DEBUG
        debugLog("flattened docID=\(id) textLen=\(text.count)")
      #endif

      // If the backend returns an empty/omitted content array (or it flattens to empty),
      // don't paginate an empty string; show an explicit placeholder instead.
      if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        #if DEBUG
          debugLog("empty_after_flatten docID=\(id) -> showing_placeholder (likely scanned/image-only pdf or processing returned no text)")
        #endif
        loadErrorMessage = nil
        setPages([emptyRemoteMessage], initialPage: 1)
        isLoading = false
        watchdog.cancel()
        return
      }

      let paged = TextPaginator.paginate(text: text, containerSize: containerSize, style: style)
      #if DEBUG
        debugLog("paginated docID=\(id) pages=\(paged.count)")
      #endif
      setPages(paged, initialPage: book.currentPage)
      isLoading = false
      watchdog.cancel()
    } catch {
      #if DEBUG
        debugLog("error docID=\(id) error=\(error)")
      #endif
      if let cached = OptimizedPagesStore.loadPages(remoteID: id, expectedChecksum: nil),
        !cached.isEmpty
      {
        setPages(cached, initialPage: book.currentPage)
        loadErrorMessage = nil
        isLoading = false
        watchdog.cancel()
        return
      }
      let isDownloaded = OptimizedPagesStore.hasLocalCopy(remoteID: id)
      if OfflinePinStore.isPinned(remoteID: id), !isDownloaded {
        loadErrorMessage = "Not downloaded"
        setPages(
          [
            "This book isn't available offline yet. Turn on Offline while the server is reachable, then try again."
          ],
          initialPage: 1
        )
      } else if case APIError.server(let status, _) = error, status == 404 {
        loadErrorMessage = "Not found"
        setPages(
          [
            "This document couldn't be found on the server. It may have been deleted or you may need to refresh your library."
          ],
          initialPage: 1
        )
      } else {
        loadErrorMessage = "Can't connect"
        setPages(
          [
            "Couldn't reach the server to load this book. Check your connection and try again."
          ],
          initialPage: 1
        )
      }
      isLoading = false
      watchdog.cancel()
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
