import SwiftUI
import UIKit

/// Reader has two independent theme concepts:
/// - **App theme** (Settings / Profile): `AppTheme` — light/dark for the whole app. Drives status bar when *not* in reader.
/// - **Reader theme** (reader only): `ReadingTheme` — day/night/amber for the reading surface. Drives status bar *while* in reader.
struct ReaderView: View {
  @Environment(\.dismiss) private var dismiss
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

  @State private var isDismissing: Bool = false
  @State private var didStartLoading: Bool = false
  @State private var resolvedStartPage: Int? = nil
  @State private var resolvedStartProgress: Double? = nil

  @State private var focusAutoHideTask: Task<Void, Never>? = nil
  @State private var focusSwipeInFlight: Bool = false

  private let documentsService: DocumentsServicing = GoDocumentsService()
  private let readingPositionService: ReadingPositionServicing = GoReadingPositionService()
  private let highlightsService: HighlightsServicing = GoHighlightsService()

  @State private var documentHighlights: [RemoteHighlight] = []

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
    _askAI = StateObject(wrappedValue: ReaderAskAIViewModel(documentID: book.remoteID ?? ""))
  }

  var body: some View {
    let focusEnabled = settings.isLocked
    let showEdges = !focusEnabled || chrome.isVisible

    ZStack {
      Group {
        if settings.isPresented {
          if preferences.theme == .day {
            Color(red: 248.0 / 255.0, green: 248.0 / 255.0, blue: 248.0 / 255.0)
          } else if preferences.theme == .night {
            Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0)
          } else {
            preferences.theme.surfaceBackground
          }
        } else {
          preferences.theme.surfaceBackground
        }
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        if showEdges {
          ReaderCollapsibleTopBar(isVisible: true, measuredHeight: $chrome.measuredHeight) {
            ReaderTopBarView(
              horizontalPadding: horizontalPadding,
              showReaderSettings: $settings.isPresented,
              onBack: handleBack
            )
          }
        }

        GeometryReader { geo in
          let settingsGap: CGFloat = 16

          ReaderContentScrollView(
            book: book,
            viewModel: viewModel,
            headerModel: ReaderHeaderModel(book: book, pages: viewModel.pages),
            horizontalPadding: horizontalPadding,
            shouldUseContinuousScroll: shouldUseContinuousScroll,
            showTopChrome: showEdges,
            highlightQuotes: documentHighlights.map(\.quote),
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
                guard focusEnabled else { return }
                guard !settings.isPresented else { return }
                guard !search.isVisible else { return }
                guard !highlight.isPresented else { return }
                guard !viewModel.isLoading else { return }
                guard !focusSwipeInFlight else { return }

                let dx = value.translation.width
                let dy = value.translation.height

                guard abs(dx) > max(24, abs(dy) * 1.35) else { return }

                focusSwipeInFlight = true
                defer {
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    focusSwipeInFlight = false
                  }
                }

                if dx > 60 {
                  focusSwipeAdvancePage()
                } else if dx < -60 {
                  focusSwipeGoBackPage()
                }
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
          .padding(.top, settings.isPresented ? 14 : 0)
          .padding(.bottom, settings.isPresented ? settingsGap : 0)
          .background {
            RoundedRectangle(
              cornerRadius: settings.isPresented ? 28 : 0,
              style: .continuous
            )
            .fill(settings.isPresented ? preferences.theme.surfaceBackground : Color.clear)
          }
          .clipShape(
            RoundedRectangle(
              cornerRadius: settings.isPresented ? 28 : 0,
              style: .continuous,
            )
          )
          .overlay {
            if settings.isPresented {
              RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
              )
              .stroke(
                preferences.theme.surfaceText.opacity(preferences.theme == .day ? 0.08 : 0.12),
                lineWidth: 1
              )
            }
          }
          .shadow(
            color: {
              guard settings.isPresented else { return Color.clear }
              switch preferences.theme {
              case .day:
                return Color.black.opacity(0.08)
              case .night:
                return Color.black.opacity(0.25)
              case .amber:
                return Color.black.opacity(0.12)
              }
            }(),
            radius: settings.isPresented ? 12 : 0,
            x: 0,
            y: 0
          )
          .padding(.horizontal, settings.isPresented ? 16 : 0)
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
              let total = max(1, viewModel.pages.count)
              let idx = min(max(0, audiobook.currentPageIndex), max(0, total - 1))
              let overall = min(
                1.0, max(0.0, (Double(idx) + audiobook.pageProgress) / Double(total)))

              ReaderAudiobookControlsView(
                isPlaying: audiobook.isPlaying,
                progress: overall,
                pageLabel: "\(idx + 1) of \(total)",
                onPreviousPage: {
                  audiobook.previousPage()
                },
                onBack5: {
                  audiobook.skipBackward5Seconds()
                },
                onPlayPause: {
                  audiobook.togglePlayPause()
                },
                onForward5: {
                  audiobook.skipForward5Seconds()
                },
                onNextPage: {
                  audiobook.nextPage()
                }
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

        }

        if showEdges, !shouldUseContinuousScroll && !settings.isPresented && !audiobookEnabled {
          ReaderBottomPagerView(
            currentIndex: viewModel.currentIndex,
            totalPages: viewModel.pages.count,
            onPrevious: viewModel.goToPreviousPage,
            onNext: viewModel.goToNextPage
          )
        }
      }
      .overlay {
        let b = min(1.0, max(0.0, preferences.brightness))
        let dim = min(0.78, max(0.0, (1.0 - b) * 0.90))
        if dim > 0.001 {
          Color.black.opacity(dim)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
      }
      .frame(maxWidth: 720)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, settings.isPresented ? 0 : (showEdges ? 12 : 6))
    }
    .toolbar(.hidden, for: .tabBar)
    .toolbar(.hidden, for: .navigationBar)
    .preferredColorScheme(readerStatusBarScheme)
    .environment(\.colorScheme, readerStatusBarScheme)
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
        refreshOfflineSubtitle(remoteID: id)

        startOfflineMonitor(remoteID: id)

        Task {
          if let meta = try? await documentsService.getOptimizedDocumentMeta(id: id) {
            offlineMeta = meta
            refreshOfflineSubtitle(remoteID: id)
          }
        }
        Task {
          documentHighlights = (try? await highlightsService.listHighlights(documentID: id)) ?? []
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

    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
      settings.isPresented = false
    }

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
    refreshOfflineSubtitle(remoteID: id)
    stopOfflineMonitor()
  }

  @MainActor private func downloadAndSaveOffline(remoteID: String) async {
    guard !isOfflineSaving else { return }
    isOfflineSaving = true
    offlineSaveMessage = "Downloading…"
    refreshOfflineSubtitle(remoteID: remoteID)
    print("[OfflineDownload] start id=\(remoteID)")
    defer {
      isOfflineSaving = false
      offlineSaveMessage = nil
      refreshOfflineSubtitle(remoteID: remoteID)
      print("[OfflineDownload] end id=\(remoteID)")
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
          try? OptimizedPagesStore.savePages(
            remoteID: remoteID,
            pages: pages,
            optimizedVersion: opt.optimizedVersion,
            optimizedChecksumSHA256: opt.optimizedChecksumSHA256
          )
          if opt.processingStatus == "ready" {
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
    guard let id = book.remoteID, !id.isEmpty else { return false }
    return OptimizedPagesStore.hasLocalCopy(remoteID: id)
  }

  @MainActor private func attemptAutoDownloadIfNeeded(remoteID: String) {
    guard OfflinePinStore.isPinned(remoteID: remoteID) else { return }
    guard OptimizedPagesStore.loadManifest(remoteID: remoteID) == nil else { return }
    guard offlineIsAvailable else { return }
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

        if OptimizedPagesStore.loadManifest(remoteID: remoteID) != nil {
          isOfflineSaving = false
          offlineSaveMessage = nil
          refreshOfflineSubtitle(remoteID: remoteID)
          return
        }

        if let meta = try? await documentsService.getOptimizedDocument(id: remoteID) {
          offlineMeta = meta
          if meta.processingStatus == "ready" {
            isOfflineSaving = false
            offlineSaveMessage = nil
          }
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
