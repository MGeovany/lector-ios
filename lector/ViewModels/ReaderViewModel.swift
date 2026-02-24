import Combine
import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
  @Published private(set) var pages: [String] = []
  @Published var currentIndex: Int = 0
  @Published private(set) var isLoading: Bool = false
  @Published var loadErrorMessage: String?
  /// Tracks optimized processing status so UI can show per-page placeholders.
  /// Values: "ready" | "processing" | "failed" | nil (unknown / non-optimized path).
  @Published private(set) var optimizedProcessingStatus: String?

  /// Key used in loadErrorMessage when the app is offline and the book has no local copy.
  static let offlineNotAvailableErrorKey = "OFFLINE_NOT_AVAILABLE"

  private let emptyRemoteMessage = "No content to display."

  private let debugLoggingEnabled: Bool = false
  private var processingRefreshTask: Task<Void, Never>? = nil

  private func debugLog(_ message: @autoclosure () -> String) {
    guard debugLoggingEnabled else { return }
    print("[ReaderLoad] \(message())")
  }

  private static func normalizedStatus(_ raw: String?) -> String? {
    raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private static func padPagesToTotal(_ pages: [String], totalPages: Int) -> [String] {
    let total = max(1, totalPages)
    guard pages.count < total else { return pages }
    return pages + Array(repeating: "", count: total - pages.count)
  }

  private func startRefreshingOptimizedWhileProcessing(
    remoteID: String,
    documentsService: DocumentsServicing
  ) {
    processingRefreshTask?.cancel()
    processingRefreshTask = Task { @MainActor in
      let intervalNanos: UInt64 = 2_000_000_000
      let maxSeconds: Int = 120
      var elapsed: Int = 0
      var lastChecksum: String? = nil

      while elapsed < maxSeconds, !Task.isCancelled {
        try? await Task.sleep(nanoseconds: intervalNanos)
        elapsed += 2
        guard !Task.isCancelled else { return }

        guard let opt = try? await documentsService.getOptimizedDocument(id: remoteID) else { continue }
        let nextChecksum = opt.optimizedChecksumSHA256
        self.optimizedProcessingStatus = Self.normalizedStatus(opt.processingStatus)

        if let rawPages = opt.pages, !rawPages.isEmpty {
          let nextPages = Self.padPagesToTotal(rawPages, totalPages: max(rawPages.count, self.pages.count))

          let didChange =
            nextPages.count != self.pages.count
            || nextChecksum != lastChecksum

          if didChange {
            self.debugLog(
              "optimized_refresh docID=\(remoteID) status=\(opt.processingStatus) pages=\(rawPages.count) visible=\(nextPages.count)"
            )
            self.setPages(nextPages, initialPage: nil)
          }
        }

        lastChecksum = nextChecksum

        if opt.processingStatus.lowercased() == "ready" {
          if OfflinePinStore.isPinned(remoteID: remoteID),
            let pages = opt.pages,
            !pages.isEmpty
          {
            try? OptimizedPagesStore.savePages(
              remoteID: remoteID,
              pages: pages,
              optimizedVersion: opt.optimizedVersion,
              optimizedChecksumSHA256: opt.optimizedChecksumSHA256
            )
          }
          return
        }
      }
    }
  }

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
    
    debugLog("start docID=\(id) title=\(book.title)")

    // Offline-first: prefer cached optimized pages.
    if let cached = OptimizedPagesStore.loadPages(remoteID: id, expectedChecksum: nil),
      !cached.isEmpty
    {
      debugLog("cache_hit docID=\(id) pages=\(cached.count)")
      optimizedProcessingStatus = "ready"
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

    debugLog("cache_miss docID=\(id) fetching_optimized=1")

    // Open instantly: seed placeholders for total page count.
    // As the backend processes pages, we’ll swap in real content per page.
    optimizedProcessingStatus = "processing"
    setPages(Array(repeating: "", count: max(1, book.pagesTotal)), initialPage: book.currentPage)
    isLoading = false
    loadErrorMessage = nil

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

      if let opt = opt {
        optimizedProcessingStatus = Self.normalizedStatus(opt.processingStatus)
        debugLog(
          "optimized docID=\(id) status=\(opt.processingStatus) pages=\(opt.pages?.count ?? 0) optVer=\(opt.optimizedVersion) checksum=\(opt.optimizedChecksumSHA256 ?? "nil")"
        )

        if opt.processingStatus.lowercased() == "failed" {
          debugLog("optimized_failed docID=\(id)")
          optimizedProcessingStatus = "failed"
          loadErrorMessage = "Failed to process."
          isLoading = false
          setPages([""], initialPage: 1)
          return
        }

        if let pages = opt.pages, !pages.isEmpty {
          // Keep full length (including empty placeholders) so paging stays stable.
          let padded = Self.padPagesToTotal(pages, totalPages: book.pagesTotal)
          setPages(padded, initialPage: book.currentPage)
        } else {
          // No pages ready yet: keep placeholders seeded above.
        }

        // While processing, refresh in background so pages fill in as they become available.
        if opt.processingStatus.lowercased() != "ready" {
          debugLog("optimized_processing docID=\(id) status=\(opt.processingStatus)")
          startRefreshingOptimizedWhileProcessing(remoteID: id, documentsService: documentsService)
          return
        }

        // Ready: if pinned, persist for offline.
        if OfflinePinStore.isPinned(remoteID: id),
          let pages = opt.pages,
          !pages.isEmpty
        {
          try? OptimizedPagesStore.savePages(
            remoteID: id,
            pages: pages,
            optimizedVersion: opt.optimizedVersion,
            optimizedChecksumSHA256: opt.optimizedChecksumSHA256
          )
        }

        // If ready but empty, fall back to full document below.
        if (opt.pages ?? []).isEmpty {
          debugLog("optimized_ready_but_empty_pages docID=\(id) fallback_to_document_detail=1")
        }
      }

      // Fallback (older docs/backends): fetch full content and paginate.
      let doc = try await documentsService.getDocument(id: id)
      if debugLoggingEnabled {
        let blocks = doc.content
        let types = Dictionary(grouping: blocks, by: { $0.type.lowercased() }).mapValues(\.count)
        let nonEmpty =
          blocks.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        debugLog(
          "document_detail docID=\(id) format=\(doc.metadata.format ?? "nil") pageCount=\(doc.metadata.pageCount ?? -1) wordCount=\(doc.metadata.wordCount ?? -1) hasPassword=\(doc.metadata.hasPassword ?? false) blocks=\(blocks.count) nonEmptyBlocks=\(nonEmpty) types=\(types)"
        )
        for (i, b) in blocks.prefix(3).enumerated() {
          let snippet = b.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
          debugLog("block[\(i)] type=\(b.type) page=\(b.pageNumber) pos=\(b.position) len=\(b.content.count) snippet=\(snippet)")
        }
      }
      // Prefer backend page boundaries to match the web reader exactly.
      // If blocks don't have meaningful page numbers, fall back to local pagination.
      let pagesByBackend = Self.pagesPreservingBackendPages(doc.content)
      debugLog("pagesByBackend docID=\(id) pages=\(pagesByBackend.count) firstLen=\(pagesByBackend.first?.count ?? 0)")
      if pagesByBackend.count > 1
        || (pagesByBackend.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
      {
        setPages(pagesByBackend, initialPage: book.currentPage)
        isLoading = false
        optimizedProcessingStatus = "ready"
        debugLog("done_using_backend_pages docID=\(id)")
        return
      }

      let text = Self.flattenContent(doc.content)
      debugLog("flattened docID=\(id) textLen=\(text.count)")

      // If the backend returns an empty/omitted content array (or it flattens to empty),
      // don't paginate an empty string; show an explicit placeholder instead.
      if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        debugLog("empty_after_flatten docID=\(id) -> showing_placeholder (likely scanned/image-only pdf or processing returned no text)")
        loadErrorMessage = nil
        setPages([emptyRemoteMessage], initialPage: 1)
        isLoading = false
        optimizedProcessingStatus = "ready"
        return
      }

      let paged = TextPaginator.paginate(text: text, containerSize: containerSize, style: style)
      debugLog("paginated docID=\(id) pages=\(paged.count)")
      setPages(paged, initialPage: book.currentPage)
      isLoading = false
      optimizedProcessingStatus = "ready"
    } catch {
      debugLog("error docID=\(id) error=\(error)")
      if let cached = OptimizedPagesStore.loadPages(remoteID: id, expectedChecksum: nil),
        !cached.isEmpty
      {
        setPages(cached, initialPage: book.currentPage)
        optimizedProcessingStatus = "ready"
        loadErrorMessage = nil
        isLoading = false
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
      } else if case APIError.network = error, !isDownloaded {
        // Device is offline (or unreachable) and this book has no local copy.
        loadErrorMessage = Self.offlineNotAvailableErrorKey
        setPages(
          [
            "This book isn't available for offline reading. You can download your books from the library: open a book and turn on Offline in settings when you're connected."
          ],
          initialPage: 1
        )
      } else {
        // Any other error (timeout, server error, decoding, etc.) or has local copy but can't reach server.
        loadErrorMessage = "Can't connect"
        setPages(
          [
            "Couldn't reach the server to load this book. Check your connection and try again."
          ],
          initialPage: 1
        )
      }
      isLoading = false
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
