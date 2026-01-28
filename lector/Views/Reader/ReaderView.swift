import SwiftUI
import UIKit

struct ReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var preferences: PreferencesViewModel

  let book: Book
  var onProgressChange: ((Int, Int, Double?) -> Void)? = nil
  let initialText: String?

  @StateObject private var viewModel = ReaderViewModel()

  @State private var search = ReaderSearchState()
  @State private var highlight = ReaderHighlightState()
  @State private var settings = ReaderSettingsState()
  @State private var chrome = ReaderChromeState()
  @State private var scroll = ReaderScrollState()

  @State private var isDismissing: Bool = false
  @State private var didStartLoading: Bool = false
  @State private var resolvedStartPage: Int? = nil
  @State private var resolvedStartProgress: Double? = nil

  private let documentsService: DocumentsServicing = GoDocumentsService()
  private let readingPositionService: ReadingPositionServicing = GoReadingPositionService()

  private let shortDocContinuousScrollMaxPages: Int = 10
  private let horizontalPadding: CGFloat = 20
  #if DEBUG
    private let debugScrollLogs: Bool = true
  #else
    private let debugScrollLogs: Bool = false
  #endif

  init(
    book: Book,
    onProgressChange: ((Int, Int, Double?) -> Void)? = nil,
    initialText: String? = nil
  ) {
    self.book = book
    self.onProgressChange = onProgressChange
    self.initialText = initialText
  }

  var body: some View {
    ZStack {
      Group {
        if settings.isPresented {
          // TODO: Match reference backdrop for each theme's surfaceBackground
          if preferences.theme == .day {
            Color(red: 248.0 / 255.0, green: 248.0 / 255.0, blue: 248.0 / 255.0)
          } else {
            Color(.systemGray5)
          }
        } else {
          preferences.theme.surfaceBackground
        }
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        ReaderCollapsibleTopBar(isVisible: chrome.isVisible, measuredHeight: $chrome.measuredHeight)
        {
          ReaderTopBarView(
            horizontalPadding: horizontalPadding,
            showReaderSettings: $settings.isPresented,
            onBack: handleBack
          )
        }

        GeometryReader { geo in
          // Match ReaderSettingsPanelView's height (65% of available height).
          // Avoid UIScreen.main (deprecated in iOS 26).
          let settingsGap: CGFloat = 16

          ReaderContentScrollView(
            book: book,
            viewModel: viewModel,
            headerModel: ReaderHeaderModel(book: book, pages: viewModel.pages),
            horizontalPadding: horizontalPadding,
            shouldUseContinuousScroll: shouldUseContinuousScroll,
            showTopChrome: chrome.isVisible,
            showSearch: $search.isVisible,
            searchQuery: $search.query,
            clearSelectionToken: $highlight.clearSelectionToken,
            scrollOffsetY: $scroll.offsetY,
            scrollContentHeight: $scroll.contentHeight,
            scrollViewportHeight: $scroll.viewportHeight,
            scrollInsetTop: $scroll.insetTop,
            scrollInsetBottom: $scroll.insetBottom,
            scrollProgress: $scroll.progress,
            didRestoreContinuousScroll: $scroll.didRestoreContinuousScroll,
            didAttachKVOScrollMetrics: $scroll.didAttachKVOScrollMetrics,
            restoreProgress: continuousRestoreProgress,
            debugScrollLogs: debugScrollLogs,
            onScrollStateChange: handleScrollStateChange,
            onShareSelection: { text, page, progress in
              highlight.present(text: text, pageNumber: page, progress: progress)
            },
            onPagedProgressChange: { page, total in
              onProgressChange?(page, total, nil)
            }
          )
          .onChange(of: geo.size, initial: true) { _, newSize in
            startLoadingIfNeeded(container: newSize)
          }
          // Keep text size/width (no scaling), but add the floating card style.
          .padding(.top, settings.isPresented ? 14 : 0)
          // .padding(.horizontal, settings.isPresented ? 14 : 0)
          .padding(.bottom, settings.isPresented ? settingsGap : 0)
          .background {
            RoundedRectangle(
              cornerRadius: settings.isPresented ? 28 : 0,
              style: .continuous
            )
            .fill(settings.isPresented ? Color.white : Color.clear)
          }
          .clipShape(
            RoundedRectangle(
              cornerRadius: settings.isPresented ? 28 : 0,
              style: .continuous
            )
          )
          .shadow(
            color: settings.isPresented && preferences.theme == .day
              ? Color.black.opacity(0.08)
              : Color.clear,
            radius: settings.isPresented ? 12 : 0,
            x: 0,
            y: 0
          )
          .animation(.spring(response: 0.35, dampingFraction: 0.85), value: settings.isPresented)
          .allowsHitTesting(!settings.isLocked)
          .onAppear {
            chrome.lastScrollOffsetY = scroll.offsetY
            if shouldUseContinuousScroll, scroll.offsetY > 40 {
              chrome.isVisible = false
            }
          }
          .onChange(of: scroll.didRestoreContinuousScroll) { _, restored in
            guard restored else { return }
            if shouldUseContinuousScroll, scroll.offsetY > 40, !search.isVisible {
              withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                chrome.isVisible = false
              }
            }
            chrome.lastScrollOffsetY = scroll.offsetY
          }
          // Put the settings panel in an inset so it does NOT cover the document.
          .safeAreaInset(edge: .bottom, spacing: 40) {
            ReaderSettingsPanelView(
              containerHeight: geo.size.height,
              isPresented: $settings.isPresented,
              dragOffset: $settings.dragOffset,
              isLocked: $settings.isLocked,
              searchVisible: $search.isVisible,
              searchQuery: $search.query
            )
          }
        }

        if !shouldUseContinuousScroll && !settings.isPresented {
          ReaderBottomPagerView(
            currentIndex: viewModel.currentIndex,
            totalPages: viewModel.pages.count,
            onPrevious: viewModel.goToPreviousPage,
            onNext: viewModel.goToNextPage
          )
        }
      }
      .frame(maxWidth: 720)
      .frame(maxWidth: .infinity)
      // .border(Color.blue, width: 1)
      .padding(.horizontal, 12)
    }
    .toolbar(.hidden, for: .tabBar)
    .toolbar(.hidden, for: .navigationBar)
    .preferredColorScheme(readerStatusBarScheme)
    .navigationBarBackButtonHidden(true)
    .preference(key: TabBarHiddenPreferenceKey.self, value: !isDismissing)
    .overlay {
      if highlight.isPresented {
        HighlightShareEditorView(
          quote: highlight.selectedText,
          bookTitle: book.title,
          author: book.author,
          documentID: book.remoteID,
          pageNumber: highlight.pageNumber,
          progress: highlight.progress,
          onDismiss: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              highlight.dismiss()
            }
          }
        )
        .environmentObject(preferences)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: highlight.isPresented)
    .overlay(alignment: .center) {
      if settings.isLocked {
        Button {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            settings.isLocked = false
            chrome.isVisible = true
          }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "lock.open.fill")
              .font(.system(size: 14, weight: .bold))
            Text("Unlock")
              .font(.system(size: 14, weight: .bold))
          }
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(
            Capsule(style: .continuous)
              .fill(
                preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.10 : 0.06))
          )
          .overlay(
            Capsule(style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.12), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .onChange(of: settings.isLocked) { _, locked in
      if locked {
        // Close chrome + settings and clear search when locking.
        settings.isPresented = false
        search.close()
        chrome.isVisible = false
      }
    }
  }

  private var readerStatusBarScheme: ColorScheme {
    preferences.theme == .day ? .light : .dark
  }

  private var shouldUseContinuousScroll: Bool {
    preferences.continuousScrollForShortDocs
      && !viewModel.isLoading
      && viewModel.pages.count > 0
      && viewModel.pages.count < shortDocContinuousScrollMaxPages
  }

  private func handleBack() {
    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
      isDismissing = true
    }
    DispatchQueue.main.async {
      dismiss()
    }
  }

  private func startLoadingIfNeeded(container size: CGSize) {
    guard !didStartLoading else { return }
    guard size.width > 240, size.height > 320 else { return }
    didStartLoading = true

    let containerSize = CGSize(
      width: max(10, size.width - (horizontalPadding * 2)),
      height: max(10, size.height - 18)
    )

    let uiFont = preferences.font.uiFont(size: CGFloat(preferences.fontSize))
    let style = TextPaginator.Style(
      font: uiFont,
      lineSpacing: CGFloat(preferences.fontSize) * CGFloat(max(0, preferences.lineSpacing - 1))
    )

    if let initialText,
      !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      let paged = TextPaginator.paginate(
        text: initialText, containerSize: containerSize, style: style)
      viewModel.setPages(paged, initialPage: book.currentPage)
      return
    }

    Task {
      if resolvedStartPage == nil, let docID = book.remoteID, !docID.isEmpty {
        if let pos = try? await readingPositionService.getReadingPosition(documentID: docID) {
          let page = max(1, pos.pageNumber ?? book.currentPage)
          resolvedStartPage = page
          resolvedStartProgress = pos.progress
        }
      }

      var startBook = book
      if let resolvedStartPage { startBook.currentPage = resolvedStartPage }
      if let resolvedStartProgress { startBook.readingProgress = resolvedStartProgress }

      await viewModel.loadRemoteDocumentIfNeeded(
        book: startBook,
        documentsService: documentsService,
        containerSize: containerSize,
        style: style
      )
    }
  }

  private func handleScrollStateChange() {
    updateScrollProgress()
    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
      chrome.updateVisibility(scrollOffsetY: scroll.offsetY, isSearchVisible: search.isVisible)
    }
  }

  private func updateScrollProgress() {
    guard shouldUseContinuousScroll else { return }
    let maxOffset = max(
      1,
      scroll.contentHeight - scroll.viewportHeight + scroll.insetTop + scroll.insetBottom
    )
    let next = min(1.0, max(0.0, Double(scroll.offsetY / maxOffset)))
    if abs(next - scroll.progress) > 0.0005 {
      scroll.progress = next
      emitContinuousScrollProgressIfNeeded()
    }
  }

  private func emitContinuousScrollProgressIfNeeded() {
    guard shouldUseContinuousScroll else { return }
    let total = max(1, viewModel.pages.count)

    let pageIndex = min(
      max(0, Int(round(scroll.progress * Double(max(0, total - 1))))),
      max(0, total - 1)
    )
    let pageNumber = pageIndex + 1

    if scroll.lastEmittedProgress < 0
      || abs(scroll.progress - scroll.lastEmittedProgress) >= 0.01
      || scroll.progress <= 0.001
      || scroll.progress >= 0.999
    {
      scroll.lastEmittedProgress = scroll.progress
      onProgressChange?(pageNumber, total, scroll.progress)
    }
  }

  private var continuousRestoreProgress: Double? {
    if let p = (resolvedStartProgress ?? book.readingProgress) {
      return min(1.0, max(0.0, p))
    }
    let total = max(1, viewModel.pages.count)
    let startPage = resolvedStartPage ?? book.currentPage
    guard total > 1 else { return nil }
    let idx = min(max(0, startPage - 1), total - 1)
    return Double(idx) / Double(total - 1)
  }
}
