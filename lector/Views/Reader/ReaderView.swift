import SwiftUI
import UIKit

/// Reader has two independent theme concepts:
/// - **App theme** (Settings / Profile): `AppTheme` — light/dark for the whole app. Drives status bar when *not* in reader.
/// - **Reader theme** (reader only): `ReadingTheme` — day/night/amber for the reading surface. Drives status bar *while* in reader.
struct ReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var preferences: PreferencesViewModel
  @AppStorage(AppPreferenceKeys.theme) private var appThemeRawValue: String = AppTheme.dark.rawValue

  let book: Book
  var onProgressChange: ((Int, Int, Double?) -> Void)? = nil
  let initialText: String?

  @StateObject private var viewModel = ReaderViewModel()
  @StateObject private var audiobook = ReaderAudiobookViewModel()
  @StateObject private var networkMonitor = NetworkMonitor.shared

  @State private var search = ReaderSearchState()
  @State private var highlight = ReaderHighlightState()
  @State private var settings = ReaderSettingsState()
  @StateObject private var askAI: ReaderAskAIViewModel
  @State private var chrome = ReaderChromeState()
  @State private var scroll = ReaderScrollState()

  @State private var audiobookEnabled: Bool = false
  @State private var audiobookScrollToIndex: Int? = nil
  @State private var audiobookScrollToToken: Int = 0

  @State private var offlineEnabled: Bool = false
  @State private var isOfflineSaving: Bool = false
  @State private var offlineSaveMessage: String? = nil
  @State private var offlineSubtitle: String? = nil
  @State private var offlineMeta: RemoteOptimizedDocument? = nil
  @State private var offlineLastAutoDownloadAt: Date? = nil
  @State private var offlineMonitorTask: Task<Void, Never>? = nil
  // Used to force UI refresh when local offline files change.
  @State private var offlineAvailabilityToken: Int = 0
  @State private var offlineIsAvailableState: Bool = false

  @State private var isDismissing: Bool = false
  @State private var didStartLoading: Bool = false
  @State private var resolvedStartPage: Int? = nil
  @State private var resolvedStartProgress: Double? = nil

  @State private var focusAutoHideTask: Task<Void, Never>? = nil
  @State private var focusSwipeInFlight: Bool = false

  @State private var activeScreen: UIScreen? = nil
  @State private var originalSystemBrightness: CGFloat? = nil

  // Pinch-to-zoom font sizing (reader surface).
  @State private var pinchBaseFontSize: Double? = nil
  @State private var pinchLastAppliedFontSize: Double? = nil

  private let documentsService: DocumentsServicing = GoDocumentsService()
  private let readingPositionService: ReadingPositionServicing = GoReadingPositionService()
  private let highlightsService: HighlightsServicing = GoHighlightsService()

  @State private var documentHighlights: [RemoteHighlight] = []
  @State private var isHighlightsSheetPresented: Bool = false

  private let horizontalPadding: CGFloat = 20
  private let readerFontSizeMin: Double = 14
  private let readerFontSizeMax: Double = 26
  private let readerFontSizeStep: Double = 0.25
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
    _askAI = StateObject(wrappedValue: ReaderAskAIViewModel(documentID: book.remoteID ?? ""))
  }

  var body: some View {
    let focusEnabled: Bool = settings.isLocked
    let showEdges: Bool = !focusEnabled || chrome.isVisible
    let isFullBrightness: Bool = preferences.brightness >= 0.999

    let contentMaxWidth: CGFloat? = (isFullBrightness && !settings.isPresented) ? .infinity : 720
    let outerHorizontalPadding: CGFloat = readerOuterHorizontalPadding(
      showEdges: showEdges,
      isFullBrightness: isFullBrightness
    )

    return ZStack {
      readerBackgroundView

      VStack(spacing: 0) {
        if showEdges {
          ReaderCollapsibleTopBar(isVisible: true, measuredHeight: $chrome.measuredHeight) {
            ReaderTopBarView(
              horizontalPadding: horizontalPadding,
              showReaderSettings: $settings.isPresented,
              onShowHighlights: { isHighlightsSheetPresented = true },
              onBack: handleBack
            )
          }
        }

        GeometryReader { geo in
          readerScrollSurface(
            geo: geo,
            showEdges: showEdges,
            focusEnabled: focusEnabled
          )
        }
        // Allow paged mode to use the bottom safe-area space (user wants text + pager down there).
        .ignoresSafeArea(.container, edges: .bottom)
      }
      .overlay { readerBrightnessDimOverlay }
      // When brightness is at 100%, avoid the "boxed" look by letting the reading surface go full-bleed.
      .frame(maxWidth: contentMaxWidth)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, outerHorizontalPadding)
    }
    .toolbar(.hidden, for: .tabBar)
    .toolbar(.hidden, for: .navigationBar)
    .preferredColorScheme(readerStatusBarScheme)
    .environment(\.colorScheme, readerStatusBarScheme)
    .navigationBarBackButtonHidden(true)
    .preference(key: TabBarHiddenPreferenceKey.self, value: !isDismissing)
    .onAppear {
      applyReaderBrightnessIfPossible()
    }
    .onDisappear {
      restoreSystemBrightnessIfNeeded()
    }
    .onChange(of: preferences.brightness) { _, _ in
      applyReaderBrightnessIfPossible()
    }
    .onChange(of: activeScreen) { _, _ in
      applyReaderBrightnessIfPossible()
    }
    .onChange(of: scenePhase) { _, newPhase in
      // Restore when leaving active, re-apply when returning.
      switch newPhase {
      case .active:
        applyReaderBrightnessIfPossible()
      case .inactive, .background:
        restoreSystemBrightnessIfNeeded()
      @unknown default:
        break
      }
    }
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
            if let id = book.remoteID, !id.isEmpty {
              Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                documentHighlights =
                  (try? await highlightsService.listHighlights(documentID: id)) ?? []
              }
            }
          }
        )
        .environmentObject(preferences)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
      }
    }
    .sheet(isPresented: $isHighlightsSheetPresented) {
      ReaderHighlightsSheetView(
        book: book,
        highlights: $documentHighlights,
        onGoToHighlight: { h in
          goToHighlight(h)
        },
        onDeleteHighlight: { h in
          await deleteHighlight(h)
        },
        onRefresh: {
          await refreshHighlights()
        }
      )
      .environmentObject(preferences)
      .presentationDetents([.medium, .large])
    }
    .overlay {
      if audiobook.isConverting {
        ReaderAudiobookConvertingOverlayView()
          .environmentObject(preferences)
      }
    }
    .overlay(alignment: .bottom) {
      if isOfflineSaving {
        HStack(spacing: 10) {
          ProgressView()
          VStack(alignment: .leading, spacing: 2) {
            Text("Downloading in the background")
              .font(.parkinsansSemibold(size: 12))
              .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
            Text(offlineSaveMessage ?? "Downloading…")
              .font(.parkinsans(size: 11, weight: .regular))
              .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.85))
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .allowsHitTesting(false)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: highlight.isPresented)
    .onChange(of: settings.isLocked) { _, locked in
      if locked {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          settings.isPresented = false
          search.close()
          chrome.isVisible = false
        }
        cancelFocusAutoHide()
      } else {
        cancelFocusAutoHide()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          chrome.isVisible = true
        }
      }
    }
    .onChange(of: settings.isPresented) { _, isPresented in
      if focusEnabled, !isPresented, chrome.isVisible {
        scheduleFocusAutoHide()
      }
      if focusEnabled, isPresented {
        cancelFocusAutoHide()
      }
      if isPresented {
        updateAskAIPageContext()
      }
    }
    .onChange(of: viewModel.currentIndex) { _, _ in updateAskAIPageContext() }
    .onChange(of: viewModel.pages.count) { _, _ in updateAskAIPageContext() }
    .onChange(of: scroll.progress) { _, _ in updateAskAIPageContext() }
    .onAppear {
      networkMonitor.startIfNeeded()
      #if DEBUG
        print(
          "[ReaderView] onAppear docID=\(book.remoteID ?? "nil") readerStatusBarScheme=\(readerStatusBarScheme) appThemeColorScheme=\(appThemeColorScheme)"
        )
      #endif
      applyReaderStatusBarStyle(readerStatusBarScheme)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        applyReaderStatusBarStyle(readerStatusBarScheme)
        #if DEBUG
          print(
            "[ReaderView] onAppear delayed re-apply docID=\(book.remoteID ?? "nil") readerStatusBarScheme=\(readerStatusBarScheme)"
          )
        #endif
      }
      if let id = book.remoteID, !id.isEmpty {
        offlineEnabled = OfflinePinStore.isPinned(remoteID: id)
        offlineIsAvailableState = OptimizedPagesStore.hasLocalCopy(remoteID: id)
        refreshOfflineSubtitle(remoteID: id)

        startOfflineMonitor(remoteID: id)

        Task {
          if let meta = try? await documentsService.getOptimizedDocumentMeta(id: id) {
            offlineMeta = meta
            refreshOfflineSubtitle(remoteID: id)
          }
        }
        Task {
          await refreshHighlights()
        }
      }
      audiobook.setOnRequestPageIndexChange { idx in
        DispatchQueue.main.async {
          viewModel.currentIndex = min(max(0, idx), max(0, viewModel.pages.count - 1))
          if shouldUseContinuousScroll {
            requestScrollToPage(viewModel.currentIndex)
          }
        }
      }
      audiobook.updatePages(viewModel.pages)
      updateAskAIPageContext()
    }
    .onChange(of: readerStatusBarScheme, initial: true) { _, newScheme in
      #if DEBUG
        print(
          "[ReaderView] onChange(readerStatusBarScheme) docID=\(book.remoteID ?? "nil") initial/change -> newScheme=\(newScheme)"
        )
      #endif
      applyReaderStatusBarStyle(newScheme)
    }
    .onDisappear {
      #if DEBUG
        print(
          "[ReaderView] onDisappear docID=\(book.remoteID ?? "nil") restoring appThemeColorScheme=\(appThemeColorScheme)"
        )
      #endif
      applyReaderStatusBarStyle(appThemeColorScheme)
      disableAudiobook()
      cancelFocusAutoHide()
      stopOfflineMonitor()
    }
  }

  private var readerBackgroundView: some View {
    readerBackgroundColor
      .ignoresSafeArea()
      // Capture the actual screen for "native" brightness control.
      .background(
        ReaderScreenAccessor { screen in
          activeScreen = screen
        }
        .frame(width: 0, height: 0)
      )
  }

  private var readerBackgroundColor: Color {
    // Keep the reader surface background stable while the settings panel is up.
    if settings.isPresented {
      switch preferences.theme {
      case .day:
        return Color(red: 248.0 / 255.0, green: 248.0 / 255.0, blue: 248.0 / 255.0)
      case .night:
        return Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0)
      case .amber:
        return preferences.theme.surfaceBackground
      }
    }
    return preferences.theme.surfaceBackground
  }

  private func readerOuterHorizontalPadding(showEdges: Bool, isFullBrightness: Bool) -> CGFloat {
    if settings.isPresented { return 0 }
    if isFullBrightness { return 0 }
    return showEdges ? 12 : 6
  }

  private var readerDimOpacity: Double {
    // If the user wants the reader dimmer than the device's current brightness,
    // apply a black overlay. If they want it brighter, we raise system brightness instead.
    let desired: Double = min(1.0, max(0.0, preferences.brightness))
    let original: Double = Double(originalSystemBrightness ?? 1.0)
    let sys: Double = max(original, desired)
    let dim: Double = sys > 0.001 ? min(0.92, max(0.0, 1.0 - (desired / sys))) : 0.0
    return dim
  }

  @ViewBuilder
  private var readerBrightnessDimOverlay: some View {
    let dim: Double = readerDimOpacity
    if dim > 0.001 {
      Color.black.opacity(dim)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
  }

  private var readerSurfaceShadowColor: Color {
    guard settings.isPresented else { return Color.clear }
    switch preferences.theme {
    case .day:
      return Color.black.opacity(0.05)
    case .night:
      return Color.black.opacity(0.18)
    case .amber:
      return Color.black.opacity(0.08)
    }
  }

  @ViewBuilder
  private func readerScrollSurface(
    geo: GeometryProxy,
    showEdges: Bool,
    focusEnabled: Bool
  ) -> some View {
    let settingsGap: CGFloat = 16
    let surfaceCornerRadius: CGFloat = settings.isPresented ? 28 : 0
    let surfaceTopPadding: CGFloat = settings.isPresented ? 14 : 0
    let surfaceBottomPadding: CGFloat = settings.isPresented ? settingsGap : 0
    let surfaceHorizontalPadding: CGFloat = settings.isPresented ? 16 : 0

    ReaderContentScrollView(
      book: book,
      viewModel: viewModel,
      headerModel: ReaderHeaderModel(book: book, pages: viewModel.pages),
      horizontalPadding: horizontalPadding,
      shouldUseContinuousScroll: shouldUseContinuousScroll,
      showTopChrome: showEdges,
      // Bottom pager is an overlay that covers text at the bottom edge.
      showBottomPagerOverlay: showEdges && !shouldUseContinuousScroll && !settings.isPresented
        && !audiobookEnabled,
      highlights: documentHighlights,
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
      },
      scrollToPageIndex: $audiobookScrollToIndex,
      scrollToPageToken: $audiobookScrollToToken
    )
    .contentShape(Rectangle())
    .simultaneousGesture(
      TapGesture().onEnded {
        guard focusEnabled else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          chrome.isVisible.toggle()
        }
        if chrome.isVisible {
          scheduleFocusAutoHide()
        } else {
          cancelFocusAutoHide()
        }
      }
    )
    .simultaneousGesture(
      DragGesture(minimumDistance: 16, coordinateSpace: .local)
        .onEnded { value in
          guard !settings.isPresented else { return }
          guard !search.isVisible else { return }
          guard !highlight.isPresented else { return }
          guard !viewModel.isLoading else { return }
          guard !focusSwipeInFlight else { return }

          let dx: CGFloat = value.translation.width
          let dy: CGFloat = value.translation.height

          guard abs(dx) > max(24, abs(dy) * 1.35) else { return }

          focusSwipeInFlight = true
          defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
              focusSwipeInFlight = false
            }
          }

          // UX: swipe right→left (left swipe) = next, left→right (right swipe) = back.
          if dx < -60 {
            focusSwipeAdvancePage()
          } else if dx > 60 {
            focusSwipeGoBackPage()
          }
        }
    )
    .simultaneousGesture(
      MagnificationGesture()
        .onChanged { scale in
          guard !settings.isPresented else { return }
          guard !search.isVisible else { return }
          guard !highlight.isPresented else { return }
          guard !viewModel.isLoading else { return }

          if pinchBaseFontSize == nil {
            pinchBaseFontSize = preferences.fontSize
            pinchLastAppliedFontSize = preferences.fontSize
          }

          let base = pinchBaseFontSize ?? preferences.fontSize
          var next = base * Double(scale)
          next = clamp(next, min: readerFontSizeMin, max: readerFontSizeMax)
          next = quantize(next, step: readerFontSizeStep)

          // Avoid excessive re-renders while pinching.
          if let last = pinchLastAppliedFontSize, abs(next - last) < (readerFontSizeStep * 0.5) {
            return
          }
          pinchLastAppliedFontSize = next

          if next != preferences.fontSize {
            preferences.fontSize = next
          }
        }
        .onEnded { _ in
          pinchBaseFontSize = nil
          pinchLastAppliedFontSize = nil
          // Clamp once more and persist.
          preferences.fontSize = clamp(
            preferences.fontSize, min: readerFontSizeMin, max: readerFontSizeMax)
          preferences.save()
          // Clear any active text selection to avoid weird selection/handles after resizing.
          highlight.clearSelectionToken &+= 1
        }
    )
    .onChange(of: geo.size, initial: true) { _, newSize in
      startLoadingIfNeeded(container: newSize)
    }
    .onChange(of: viewModel.pages) { _, newPages in
      audiobook.updatePages(newPages)
    }
    .onChange(of: viewModel.currentIndex) { _, idx in
      if audiobookEnabled {
        audiobook.userDidNavigate(to: idx)
        if shouldUseContinuousScroll {
          requestScrollToPage(idx)
        }
      }
    }
    .padding(.top, surfaceTopPadding)
    .padding(.bottom, surfaceBottomPadding)
    .background {
      RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous)
        .fill(settings.isPresented ? preferences.theme.surfaceBackground : Color.clear)
    }
    .clipShape(RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous))
    .overlay {
      if settings.isPresented {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .stroke(
            preferences.theme.surfaceText.opacity(preferences.theme == .day ? 0.08 : 0.12),
            lineWidth: 1
          )
      }
    }
    .shadow(
      color: readerSurfaceShadowColor,
      radius: settings.isPresented ? 8 : 0,
      x: 0,
      y: 0
    )
    .padding(.horizontal, surfaceHorizontalPadding)
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: settings.isPresented)
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
    .safeAreaInset(edge: .bottom, spacing: 12) {
      if showEdges, audiobookEnabled, !audiobook.isConverting, !settings.isPresented {
        let total: Int = max(1, viewModel.pages.count)
        let idx: Int = min(max(0, audiobook.currentPageIndex), max(0, total - 1))
        let overall: Double = min(
          1.0,
          max(0.0, (Double(idx) + audiobook.pageProgress) / Double(total))
        )

        ReaderAudiobookControlsView(
          isPlaying: audiobook.isPlaying,
          progress: overall,
          pageLabel: "\(idx + 1) of \(total)",
          onPreviousPage: { audiobook.previousPage() },
          onBack5: { audiobook.skipBackward5Seconds() },
          onPlayPause: { audiobook.togglePlayPause() },
          onForward5: { audiobook.skipForward5Seconds() },
          onNextPage: { audiobook.nextPage() }
        )
        .environmentObject(preferences)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if showEdges {
        ReaderSettingsPanelView(
          containerHeight: geo.size.height,
          isPresented: $settings.isPresented,
          dragOffset: $settings.dragOffset,
          isLocked: $settings.isLocked,
          searchVisible: $search.isVisible,
          searchQuery: $search.query,
          audiobookEnabled: $audiobookEnabled,
          onEnableAudiobook: enableAudiobook,
          onDisableAudiobook: disableAudiobook,
          offlineEnabled: $offlineEnabled,
          onEnableOffline: enableOffline,
          onDisableOffline: disableOffline,
          offlineSubtitle: offlineSubtitle,
          offlineIsAvailable: offlineIsAvailable,
          askAI: askAI
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .overlay(alignment: .bottom) {
      if showEdges, !shouldUseContinuousScroll && !settings.isPresented && !audiobookEnabled {
        ReaderBottomPagerView(
          currentIndex: viewModel.currentIndex,
          totalPages: viewModel.pages.count,
          onPrevious: viewModel.goToPreviousPage,
          onNext: viewModel.goToNextPage
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
  }

  @MainActor
  private func applyReaderBrightnessIfPossible() {
    let desired = CGFloat(min(1.0, max(0.0, preferences.brightness)))
    let screen = activeScreen ?? UIScreen.main

    if originalSystemBrightness == nil {
      originalSystemBrightness = screen.brightness
    }

    let original = originalSystemBrightness ?? screen.brightness
    // Only raise system brightness when needed (never lower the user's system setting).
    let targetSystem = max(original, desired)
    if abs(screen.brightness - targetSystem) > 0.005 {
      screen.brightness = targetSystem
    }
  }

  @MainActor
  private func restoreSystemBrightnessIfNeeded() {
    guard let originalSystemBrightness else { return }
    let screen = activeScreen ?? UIScreen.main
    if abs(screen.brightness - originalSystemBrightness) > 0.005 {
      screen.brightness = originalSystemBrightness
    }
    self.originalSystemBrightness = nil
  }

  @MainActor
  private func refreshHighlights() async {
    guard let id = book.remoteID, !id.isEmpty else {
      documentHighlights = []
      return
    }
    documentHighlights = (try? await highlightsService.listHighlights(documentID: id)) ?? []
  }

  @MainActor
  private func deleteHighlight(_ h: RemoteHighlight) async {
    do {
      try await highlightsService.deleteHighlight(highlightID: h.id)
      documentHighlights.removeAll { $0.id == h.id }
    } catch {
      // Non-blocking; keep existing list if delete fails.
      #if DEBUG
        print("[ReaderView] Failed to delete highlight: \(error)")
      #endif
    }
  }

  @MainActor
  private func goToHighlight(_ h: RemoteHighlight) {
    let total = viewModel.pages.count
    guard total > 0 else { return }

    let idx: Int = {
      if let page = h.pageNumber {
        return min(max(0, page - 1), total - 1)
      }
      if let pr = h.progress {
        return min(max(0, Int(round(min(1, max(0, pr)) * Double(total - 1)))), total - 1)
      }
      return min(max(0, viewModel.currentIndex), total - 1)
    }()

    viewModel.currentIndex = idx
    if shouldUseContinuousScroll {
      requestScrollToPage(idx)
    }
    // Clear any text selection overlay state.
    highlight.clearSelectionToken &+= 1
  }

  private func updateAskAIPageContext() {
    let total = viewModel.pages.count
    guard total > 0 else {
      askAI.totalPages = nil
      askAI.currentPage = nil
      return
    }
    askAI.totalPages = total
    if shouldUseContinuousScroll {
      let idx = min(max(0, Int(round(scroll.progress * Double(total - 1)))), total - 1)
      askAI.currentPage = idx + 1
    } else {
      askAI.currentPage = min(viewModel.currentIndex + 1, total)
    }
  }

  private var appThemeColorScheme: ColorScheme {
    AppTheme(rawValue: appThemeRawValue)?.colorScheme ?? .dark
  }

  private func applyReaderStatusBarStyle(_ scheme: ColorScheme?) {
    let uiStyle: UIUserInterfaceStyle =
      scheme.map { s in
        switch s {
        case .light: return .light
        case .dark: return .dark
        @unknown default: return .unspecified
        }
      } ?? .unspecified

    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap(\.windows)
    let keyWindow = windows.first(where: \.isKeyWindow)

    #if DEBUG
      let readerTheme = preferences.theme
      let appTheme = AppTheme(rawValue: appThemeRawValue) ?? .dark
      print(
        "[ReaderView] applyReaderStatusBarStyle docID=\(book.remoteID ?? "nil") scheme=\(String(describing: scheme)) uiStyle=\(uiStyle.rawValue) readerTheme=\(readerTheme) appTheme=\(appTheme) windowsCount=\(windows.count) keyWindow=\(keyWindow != nil)"
      )
    #endif

    guard let window = keyWindow ?? windows.first else {
      #if DEBUG
        print(
          "[ReaderView] applyReaderStatusBarStyle docID=\(book.remoteID ?? "nil") FAILED: no window"
        )
      #endif
      return
    }
    window.overrideUserInterfaceStyle = uiStyle
    window.rootViewController?.overrideUserInterfaceStyle = uiStyle
    #if DEBUG
      print(
        "[ReaderView] applyReaderStatusBarStyle docID=\(book.remoteID ?? "nil") SET window+rootVC.overrideUserInterfaceStyle=\(uiStyle.rawValue)"
      )
    #endif
  }

  /// Status bar style while in reader: follows *reader* theme (day → light bar, night/amber → dark bar).
  private var readerStatusBarScheme: ColorScheme {
    preferences.theme == .day ? .light : .dark
  }

  private var shouldUseContinuousScroll: Bool {
    preferences.continuousScrollForShortDocs
      && !viewModel.isLoading
      && viewModel.pages.count > 0
      && viewModel.pages.count < ReaderLimits.continuousScrollMaxPages
  }

  private func clamp(_ value: Double, min: Double, max: Double) -> Double {
    Swift.min(max, Swift.max(min, value))
  }

  private func quantize(_ value: Double, step: Double) -> Double {
    guard step > 0 else { return value }
    return (value / step).rounded() * step
  }

  private func handleBack() {
    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
      isDismissing = true
    }
    DispatchQueue.main.async {
      dismiss()
    }
  }

  private func enableAudiobook() {
    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
      settings.isPresented = false
    }

    audiobookEnabled = true
    audiobook.updatePages(viewModel.pages)

    let startIndex: Int = {
      if shouldUseContinuousScroll {
        let total = max(1, viewModel.pages.count)
        let idx = Int(round(scroll.progress * Double(max(0, total - 1))))
        return min(max(0, idx), max(0, total - 1))
      }
      return viewModel.currentIndex
    }()

    if shouldUseContinuousScroll {
      requestScrollToPage(startIndex)
    }
    audiobook.enable(startingAt: startIndex)
  }

  private func disableAudiobook() {
    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
      settings.isPresented = false
    }
    audiobookEnabled = false
    audiobook.disable()
  }

  @MainActor private func enableOffline() {
    guard let id = book.remoteID, !id.isEmpty else { return }
    OfflinePinStore.setPinned(remoteID: id, pinned: true)
    offlineEnabled = true
    offlineLastAutoDownloadAt = nil
    offlineIsAvailableState = OptimizedPagesStore.hasLocalCopy(remoteID: id)

    if networkMonitor.isOnline, networkMonitor.isOnWiFi {
      Task { @MainActor in
        await downloadAndSaveOffline(remoteID: id)
      }
    }

    startOfflineMonitor(remoteID: id)
  }

  @MainActor private func disableOffline() {
    guard let id = book.remoteID, !id.isEmpty else { return }
    OfflinePinStore.setPinned(remoteID: id, pinned: false)
    offlineEnabled = false
    OptimizedPagesStore.delete(remoteID: id)
    offlineAvailabilityToken &+= 1
    offlineIsAvailableState = false
    refreshOfflineSubtitle(remoteID: id)
    stopOfflineMonitor()
  }

  @MainActor private func downloadAndSaveOffline(remoteID: String) async {
    guard !isOfflineSaving else { return }
    isOfflineSaving = true
    offlineSaveMessage = "Downloading…"
    refreshOfflineSubtitle(remoteID: remoteID)
    print("[OfflineDownload] start id=\(remoteID)")
    var didSaveLocalCopy: Bool = false
    defer {
      isOfflineSaving = false
      offlineSaveMessage = nil
      refreshOfflineSubtitle(remoteID: remoteID)
      print("[OfflineDownload] end id=\(remoteID) saved=\(didSaveLocalCopy)")
    }

    do {
      let maxWaitSeconds: Int = 45
      let intervalSeconds: Int = 2
      var waited: Int = 0

      while waited <= maxWaitSeconds {
        print("[OfflineDownload] poll t=\(waited)s id=\(remoteID)")
        let opt = try await documentsService.getOptimizedDocument(id: remoteID)
        offlineMeta = opt

        let total = opt.pages?.count ?? 0
        let ready =
          opt.pages?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
          ?? 0
        if total > 0, let totalBytes = opt.optimizedSizeBytes {
          let ratio = min(1, max(0, Double(ready) / Double(total)))
          let estimatedBytes = Int64((Double(totalBytes) * ratio).rounded(.down))
          offlineSaveMessage = formatProgressMB(estimatedBytes)
        } else {
          offlineSaveMessage = "Downloading…"
        }
        refreshOfflineSubtitle(remoteID: remoteID)

        let bytesStr = opt.optimizedSizeBytes.map { "\($0)" } ?? "nil"
        print(
          "[OfflineDownload] response status=\(opt.processingStatus) pages=\(ready)/\(total) optimizedSizeBytes=\(bytesStr) display=\(offlineSaveMessage ?? "")"
        )

        if let pages = opt.pages, !pages.isEmpty {
          do {
            try OptimizedPagesStore.savePages(
              remoteID: remoteID,
              pages: pages,
              optimizedVersion: opt.optimizedVersion,
              optimizedChecksumSHA256: opt.optimizedChecksumSHA256
            )
            offlineAvailabilityToken &+= 1
            offlineIsAvailableState = true
            didSaveLocalCopy = true
          } catch {
            // Keep polling; saving locally is best-effort.
            #if DEBUG
              print("[OfflineDownload] savePages failed id=\(remoteID) error=\(error)")
            #endif
          }
          // Only finish the flow when we actually saved a local copy.
          if opt.processingStatus == "ready", didSaveLocalCopy || OptimizedPagesStore.hasLocalCopy(remoteID: remoteID) {
            print("[OfflineDownload] done status=ready id=\(remoteID)")
            return
          }
        }

        if opt.processingStatus == "failed" {
          offlineSaveMessage = "Failed."
          print("[OfflineDownload] done status=failed id=\(remoteID)")
          return
        }

        try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
        waited += intervalSeconds
      }

      offlineSaveMessage = "Try again"
      print("[OfflineDownload] done timeout after \(maxWaitSeconds)s id=\(remoteID)")
    } catch {
      offlineSaveMessage = "Failed"
      print("[OfflineDownload] error id=\(remoteID) error=\(error)")
    }
  }

  private var offlineIsAvailable: Bool {
    _ = offlineAvailabilityToken
    return offlineIsAvailableState
  }

  @MainActor private func attemptAutoDownloadIfNeeded(remoteID: String) {
    guard OfflinePinStore.isPinned(remoteID: remoteID) else { return }
    guard networkMonitor.isOnline, networkMonitor.isOnWiFi else { return }
    guard !OptimizedPagesStore.hasLocalCopy(remoteID: remoteID) else { return }
    guard !isOfflineSaving else { return }

    let now = Date()
    if let last = offlineLastAutoDownloadAt, now.timeIntervalSince(last) < 12 {
      return
    }
    offlineLastAutoDownloadAt = now

    Task { @MainActor in
      await downloadAndSaveOffline(remoteID: remoteID)
    }
  }

  @MainActor private func refreshOfflineSubtitle(remoteID: String) {
    guard isOfflineSaving else {
      offlineSubtitle = nil
      return
    }
    offlineSubtitle = offlineDownloadProgressLabelText()
  }

  private func offlineDownloadProgressLabelText() -> String {
    if let meta = offlineMeta,
      let totalBytes = meta.optimizedSizeBytes,
      let pages = meta.pages,
      !pages.isEmpty
    {
      let total = pages.count
      let ready = pages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
      if total > 0 {
        let ratio = min(1, max(0, Double(ready) / Double(total)))
        let estimatedBytes = Int64((Double(totalBytes) * ratio).rounded(.down))
        return formatProgressMB(estimatedBytes)
      }
    }

    if let msg = offlineSaveMessage, !msg.isEmpty {
      let cleaned = msg.lowercased().replacingOccurrences(of: " ", with: "")
      if cleaned.contains(where: { $0.isNumber }) {
        return cleaned
      }
      return "…"
    }
    return "…"
  }

  private func formatProgressMB(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = false
    formatter.allowsNonnumericFormatting = false

    return formatter.string(fromByteCount: max(0, bytes))
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
  }

  @MainActor private func startOfflineMonitor(remoteID: String) {
    stopOfflineMonitor()
    offlineMonitorTask = Task { @MainActor in
      while !Task.isCancelled {
        guard offlineEnabled else { return }
        guard OfflinePinStore.isPinned(remoteID: remoteID) else { return }

        if OptimizedPagesStore.hasLocalCopy(remoteID: remoteID) {
          isOfflineSaving = false
          offlineSaveMessage = nil
          refreshOfflineSubtitle(remoteID: remoteID)
          offlineAvailabilityToken &+= 1
          offlineIsAvailableState = true
          return
        }

        if let meta = try? await documentsService.getOptimizedDocument(id: remoteID) {
          offlineMeta = meta
          refreshOfflineSubtitle(remoteID: remoteID)
        }

        attemptAutoDownloadIfNeeded(remoteID: remoteID)
        refreshOfflineSubtitle(remoteID: remoteID)

        try? await Task.sleep(nanoseconds: 3_000_000_000)
      }
    }
  }

  @MainActor private func stopOfflineMonitor() {
    offlineMonitorTask?.cancel()
    offlineMonitorTask = nil
  }

  private func requestScrollToPage(_ idx: Int) {
    audiobookScrollToIndex = idx
    audiobookScrollToToken &+= 1
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
    if settings.isLocked { return }
    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
      chrome.updateVisibility(scrollOffsetY: scroll.offsetY, isSearchVisible: search.isVisible)
    }
  }

  private func scheduleFocusAutoHide() {
    cancelFocusAutoHide()
    focusAutoHideTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard settings.isLocked else { return }
      guard !settings.isPresented else { return }
      guard !search.isVisible else { return }
      guard !highlight.isPresented else { return }
      withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
        chrome.isVisible = false
      }
    }
  }

  private func focusSwipeAdvancePage() {
    if shouldUseContinuousScroll {
      let total = max(1, viewModel.pages.count)
      let idx = min(
        max(0, Int(round(scroll.progress * Double(max(0, total - 1))))),
        max(0, total - 1)
      )
      let next = min(max(0, total - 1), idx + 1)
      viewModel.currentIndex = next
      requestScrollToPage(next)
      return
    }
    viewModel.goToNextPage()
  }

  private func focusSwipeGoBackPage() {
    if shouldUseContinuousScroll {
      let total = max(1, viewModel.pages.count)
      let idx = min(
        max(0, Int(round(scroll.progress * Double(max(0, total - 1))))),
        max(0, total - 1)
      )
      let prev = max(0, idx - 1)
      viewModel.currentIndex = prev
      requestScrollToPage(prev)
      return
    }
    viewModel.goToPreviousPage()
  }

  private func cancelFocusAutoHide() {
    focusAutoHideTask?.cancel()
    focusAutoHideTask = nil
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

/// Tiny view used to resolve the `UIScreen` the reader is actually displayed on.
/// Avoids `UIScreen.main` where possible (multi-window / external display).
private struct ReaderScreenAccessor: UIViewRepresentable {
  let onResolve: (UIScreen) -> Void

  func makeUIView(context: Context) -> ReaderScreenAccessorView {
    let v = ReaderScreenAccessorView()
    v.onResolve = onResolve
    return v
  }

  func updateUIView(_ uiView: ReaderScreenAccessorView, context: Context) {
    uiView.onResolve = onResolve
    uiView.resolveIfPossible()
  }
}

private final class ReaderScreenAccessorView: UIView {
  var onResolve: ((UIScreen) -> Void)?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    resolveIfPossible()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    resolveIfPossible()
  }

  func resolveIfPossible() {
    guard let screen = window?.windowScene?.screen ?? window?.screen else { return }
    onResolve?(screen)
  }
}
