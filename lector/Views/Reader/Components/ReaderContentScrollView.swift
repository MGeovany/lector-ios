import SwiftUI

struct ReaderContentScrollView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  private let debugNavLogs: Bool = true

  let book: Book
  @ObservedObject var viewModel: ReaderViewModel
  let headerModel: ReaderHeaderModel

  let horizontalPadding: CGFloat
  let shouldUseContinuousScroll: Bool
  let showTopChrome: Bool
  let showBottomPagerOverlay: Bool
  let highlights: [RemoteHighlight]

  @Binding var showSearch: Bool
  @Binding var searchQuery: String
  @Binding var clearSelectionToken: Int

  @Binding var scrollOffsetY: CGFloat
  @Binding var scrollContentHeight: CGFloat
  @Binding var scrollViewportHeight: CGFloat
  @Binding var scrollInsetTop: CGFloat
  @Binding var scrollInsetBottom: CGFloat
  @Binding var scrollProgress: Double
  @Binding var didRestoreContinuousScroll: Bool
  @Binding var didAttachKVOScrollMetrics: Bool
  let restoreProgress: Double?

  let debugScrollLogs: Bool
  let onScrollStateChange: () -> Void
  let onShareSelection: (String, Int?, Double?) -> Void
  let onPagedProgressChange: (Int, Int) -> Void

  @Binding var scrollToPageIndex: Int?
  @Binding var scrollToPageToken: Int
  /// Anchor for scroll-to-page (e.g. .bottom so highlight at end of page is visible).
  var scrollToPageAnchor: UnitPoint = .top

  @Binding var scrollToText: String?
  @Binding var scrollToTextToken: Int

  private let topAnchorID: String = "readerTop"
  private let scrollSpaceName: String = "readerScrollSpace"

  private var bottomContentPadding: CGFloat {
    // When the bottom pager overlays the content, add padding so the text
    // is not covered by the next/previous controls.
    if showBottomPagerOverlay && !shouldUseContinuousScroll { return 96 }
    return showTopChrome ? 8 : 4
  }

  private var endOfBookExtraBottomPadding: CGFloat {
    // Extra space on the last page when pager is visible (bottomContentPadding
    // already covers the overlay for all pages; this is only if we need more).
    0
  }

  var body: some View {
    ScrollViewReader { proxy in
      ZStack {
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            Color.clear
              .frame(height: 0)
              .id(topAnchorID)

            Color.clear
              .frame(height: 0)
              .background(
                ReaderScrollOffsetRestorer(
                  enabled: shouldUseContinuousScroll && !viewModel.isLoading,
                  targetProgress: restoreProgress,
                  didRestore: $didRestoreContinuousScroll
                )
              )

            Color.clear
              .frame(height: 0)
              .background(
                ReaderScrollMetricsBridge(
                  enabled: shouldUseContinuousScroll && !viewModel.isLoading,
                  debugLogs: debugScrollLogs,
                  didAttach: $didAttachKVOScrollMetrics,
                  offsetY: $scrollOffsetY,
                  contentHeight: $scrollContentHeight,
                  viewportHeight: $scrollViewportHeight,
                  insetTop: $scrollInsetTop,
                  insetBottom: $scrollInsetBottom
                )
              )

            if showTopChrome {
              ReaderDocumentHeaderView(model: headerModel)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 18)

              Divider()
                .opacity(0.12)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 14)
            }

            if showSearch {
              ReaderSearchBarView(query: $searchQuery) {
                showSearch = false
              }
              .padding(.horizontal, horizontalPadding)
              .padding(.top, 12)
              .transition(.move(edge: .top).combined(with: .opacity))
              .animation(.spring(response: 0.3, dampingFraction: 0.7), value: searchQuery.isEmpty)
            }

            if viewModel.isLoading {
              ReaderLoadingView(
                subtitle: viewModel.loadErrorMessage ?? "This usually takes a few seconds."
              )
              .padding(.horizontal, horizontalPadding)
              .padding(.top, 44)
              .padding(.bottom, bottomContentPadding)
            } else if viewModel.loadErrorMessage != nil {
              ReaderConnectionErrorView(detailMessage: viewModel.loadErrorMessage)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 44)
                .padding(.bottom, bottomContentPadding)
            } else {
              if shouldUseContinuousScroll {
                continuousText
              } else {
                pagedText
              }
            }
          }
          .background(
            GeometryReader { geo in
              Color.clear
                .preference(
                  key: ReaderScrollOffsetKey.self,
                  value: geo.frame(in: .named(scrollSpaceName)).minY
                )
                .preference(key: ReaderScrollContentHeightKey.self, value: geo.size.height)
            }
          )
        }
        .coordinateSpace(name: scrollSpaceName)
        .background(
          GeometryReader { geo in
            Color.clear
              .preference(key: ReaderScrollViewportHeightKey.self, value: geo.size.height)
          }
        )
        .onPreferenceChange(ReaderScrollOffsetKey.self) { minY in
          if shouldUseContinuousScroll && didAttachKVOScrollMetrics { return }
          scrollOffsetY = max(0, -minY)
          onScrollStateChange()
        }
        .onPreferenceChange(ReaderScrollContentHeightKey.self) { newValue in
          if shouldUseContinuousScroll && didAttachKVOScrollMetrics { return }
          scrollContentHeight = max(1, newValue)
          onScrollStateChange()
        }
        .onPreferenceChange(ReaderScrollViewportHeightKey.self) { newValue in
          if shouldUseContinuousScroll && didAttachKVOScrollMetrics { return }
          scrollViewportHeight = max(1, newValue)
          onScrollStateChange()
        }
        .onChange(of: scrollOffsetY) { _, _ in
          onScrollStateChange()
        }
        .overlay(alignment: .trailing) {
          if shouldUseContinuousScroll && !viewModel.isLoading {
            let baseTopPadding: CGFloat = showSearch ? 106 : 72
            let topPadding = max(12, baseTopPadding - (showTopChrome ? 0 : 48))
            ReaderScrollIndicatorView(progress: scrollProgress, tint: preferences.theme.accent)
              .padding(.trailing, 8)
              .padding(.top, topPadding)
              .padding(.bottom, 16)
              .transition(.opacity)
          }
        }
      }
      .onChange(of: viewModel.currentIndex, initial: true) { _, newValue in
        guard !shouldUseContinuousScroll else { return }
        onPagedProgressChange(newValue + 1, max(1, viewModel.pages.count))
        // Defer to avoid fighting any pending in-page scroll requests.
        DispatchQueue.main.async {
          proxy.scrollTo(topAnchorID, anchor: .top)
        }
      }
      .onChange(of: showSearch) { _, isVisible in
        guard isVisible else { return }
        // When opening search, jump to the top so the search bar is visible.
        DispatchQueue.main.async {
          proxy.scrollTo(topAnchorID, anchor: .top)
        }
      }

      .onChange(of: scrollToPageToken) { _, _ in
        if debugNavLogs {
          print(
            "[ReaderNav] scrollToPageToken=\(scrollToPageToken) shouldUseContinuousScroll=\(shouldUseContinuousScroll) idx=\(scrollToPageIndex.map(String.init) ?? "nil") pages=\(viewModel.pages.count) anchor=\(scrollToPageAnchor == .bottom ? "bottom" : "top")"
          )
        }
        guard shouldUseContinuousScroll else { return }
        guard let idx = scrollToPageIndex else {
          if debugNavLogs { print("[ReaderNav] scrollToPage: missing idx") }
          return
        }
        guard viewModel.pages.indices.contains(idx) else {
          if debugNavLogs { print("[ReaderNav] scrollToPage: idx out of range idx=\(idx) pages=\(viewModel.pages.count)") }
          return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
          proxy.scrollTo("page-\(idx)", anchor: scrollToPageAnchor)
        }
        if debugNavLogs {
          let before = scrollOffsetY
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            print("[ReaderNav] scrollToPage done? idx=\(idx) offsetY \(Int(before)) -> \(Int(scrollOffsetY))")
          }
        }
      }
    }
  }

  private var continuousText: some View {
    VStack(alignment: .leading, spacing: 16) {
      ForEach(viewModel.pages.indices, id: \.self) { idx in
        SelectableTextView(
          text: viewModel.pages[idx],
          font: preferences.font.uiFont(size: CGFloat(preferences.fontSize)),
          textColor: UIColor(preferences.theme.surfaceText),
          lineSpacing: CGFloat(preferences.fontSize) * CGFloat(max(0, preferences.lineSpacing - 1)),
          textAlignment: preferences.textAlignment == .justify ? .justified : .natural,
          highlightQuery: searchQuery.isEmpty ? nil : searchQuery,
          highlightQuotes: highlightQuotesForPage(pageNumber: idx + 1),
          showHighlightsInText: preferences.showHighlightsInText,
          highlightColor: preferences.highlightColor.highlightUIColor(for: preferences.theme),
          highlightOpacity: preferences.highlightColor.highlightOpacity(for: preferences.theme),
          clearSelectionToken: clearSelectionToken,
          scrollToText: nil,
          scrollToTextToken: 0,
          onShareSelection: { selected in
            onShareSelection(selected, idx + 1, scrollProgress)
          }
        )
        .id("page-\(idx)")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 18)
    .padding(.bottom, bottomContentPadding)
  }

  private var pagedText: some View {
    let isLastPage = viewModel.currentIndex >= max(0, viewModel.pages.count - 1)
    return SelectableTextView(
      text: currentPageText,
      font: preferences.font.uiFont(size: CGFloat(preferences.fontSize)),
      textColor: UIColor(preferences.theme.surfaceText),
      lineSpacing: CGFloat(preferences.fontSize) * CGFloat(max(0, preferences.lineSpacing - 1)),
      textAlignment: preferences.textAlignment == .justify ? .justified : .natural,
      highlightQuery: searchQuery.isEmpty ? nil : searchQuery,
      highlightQuotes: highlightQuotesForPage(pageNumber: viewModel.currentIndex + 1),
      showHighlightsInText: preferences.showHighlightsInText,
      highlightColor: preferences.highlightColor.highlightUIColor(for: preferences.theme),
      highlightOpacity: preferences.highlightColor.highlightOpacity(for: preferences.theme),
      clearSelectionToken: clearSelectionToken,
      scrollToText: scrollToText,
      scrollToTextToken: scrollToTextToken,
      onShareSelection: { selected in
        onShareSelection(selected, viewModel.currentIndex + 1, nil)
      }
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 18)
    .padding(.bottom, bottomContentPadding + (isLastPage ? endOfBookExtraBottomPadding : 0))
  }

  private var currentPageText: String {
    guard viewModel.pages.indices.contains(viewModel.currentIndex) else { return "" }
    return viewModel.pages[viewModel.currentIndex]
  }

  private func highlightQuotesForPage(pageNumber: Int) -> [String] {
    // Critical: only highlight quotes that belong to this page.
    // This prevents common-word fallbacks (e.g. "the") from lighting up across many pages.
    highlights
      .filter { $0.pageNumber == pageNumber }
      .map(\.quote)
  }
}
