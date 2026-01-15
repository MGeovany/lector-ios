import SwiftUI
import UIKit

struct ReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var preferences: PreferencesViewModel

  let book: Book
  /// - page: 1-based page number (for legacy/page-based UI + lists)
  /// - total: total pages
  /// - progressOverride: if provided, a 0..1 progress value to persist (used by continuous scroll)
  var onProgressChange: ((Int, Int, Double?) -> Void)? = nil
  /// Optional override used mainly for Xcode Previews to avoid network/DB dependencies.
  let initialText: String?

  @StateObject private var viewModel = ReaderViewModel()
  @State private var showControls: Bool = false
  @State private var showHighlightEditor: Bool = false
  @State private var selectedHighlightText: String = ""
  @State private var searchQuery: String = ""
  @State private var showSearch: Bool = false
  private let topAnchorID: String = "readerTop"
  private let documentsService: DocumentsServicing = GoDocumentsService()
  private let readingPositionService: ReadingPositionServicing = GoReadingPositionService()
  @State private var didStartLoading: Bool = false
  private let shortDocContinuousScrollMaxPages: Int = 10
  private let scrollSpaceName: String = "readerScrollSpace"
  @State private var scrollOffsetY: CGFloat = 0
  @State private var scrollContentHeight: CGFloat = 1
  @State private var scrollViewportHeight: CGFloat = 1
  @State private var scrollProgress: Double = 0
  @State private var lastEmittedScrollProgress: Double = -1
  @State private var didRestoreContinuousScroll: Bool = false
  @State private var resolvedStartPage: Int? = nil
  @State private var resolvedStartProgress: Double? = nil

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
      preferences.theme.surfaceBackground
        .ignoresSafeArea()

      VStack(spacing: 0) {
        topBar

        GeometryReader { geo in
          content(containerWidth: geo.size.width)
            .onChange(of: geo.size, initial: true) { _, newSize in
              // Wait until we have a real layout size; otherwise pagination can produce "tiny pages".
              guard !didStartLoading else { return }
              guard newSize.width > 240, newSize.height > 320 else { return }
              didStartLoading = true

              // Approximate the text container size based on our padding.
              let containerSize = CGSize(
                width: max(10, geo.size.width - 36),
                // GeometryReader already accounts for top bar + bottom pager; avoid over-subtracting.
                height: max(10, geo.size.height - 18)
              )

              let uiFont = preferences.font.uiFont(size: CGFloat(preferences.fontSize))
              let style = TextPaginator.Style(
                font: uiFont,
                lineSpacing: CGFloat(preferences.fontSize)
                  * CGFloat(max(0, preferences.lineSpacing - 1))
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
                // Resolve latest reading position explicitly (robust even if the list endpoint didn't inline it).
                if resolvedStartPage == nil, let docID = book.remoteID, !docID.isEmpty {
                  if let pos = try? await readingPositionService.getReadingPosition(
                    documentID: docID)
                  {
                    let page = max(1, pos.pageNumber ?? book.currentPage)
                    resolvedStartPage = page
                    resolvedStartProgress = pos.progress
                  }
                }

                // Use resolved start position if available.
                var startBook = book
                if let resolvedStartPage {
                  startBook.currentPage = resolvedStartPage
                }
                if let resolvedStartProgress {
                  startBook.readingProgress = resolvedStartProgress
                }
                await viewModel.loadRemoteDocumentIfNeeded(
                  book: startBook,
                  documentsService: documentsService,
                  containerSize: containerSize,
                  style: style
                )
              }
            }
        }

        if !shouldUseContinuousScroll {
          bottomPager
        }
      }
      .frame(maxWidth: 720)  // iPad-friendly, keeps text comfortable.
      .frame(maxWidth: .infinity)
    }
    .toolbar(.hidden, for: .tabBar)
    .toolbar(.hidden, for: .navigationBar)
    .navigationBarBackButtonHidden(true)
    .preference(key: TabBarHiddenPreferenceKey.self, value: true)
    .sheet(isPresented: $showControls) {
      ReaderControlsSheetView()
        .environmentObject(preferences)
    }
    .overlay {
      if showHighlightEditor {
        HighlightShareEditorView(
          quote: selectedHighlightText,
          bookTitle: book.title,
          author: book.author,
          onDismiss: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              showHighlightEditor = false
            }
          }
        )
        .environmentObject(preferences)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showHighlightEditor)
  }

  private var topBar: some View {
    HStack(spacing: 10) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))
          .padding(10)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Back")

      Spacer(minLength: 0)

      HStack(spacing: 10) {
        Button {
          withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
            showSearch.toggle()
            if !showSearch { searchQuery = "" }
          }
        } label: {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
            .padding(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")

        Button {
          showControls = true
        } label: {
          Text("AA")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
              Capsule(style: .continuous)
                .fill(preferences.theme.surfaceText.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reading controls")

        Button {
          // Quick toggle: day <-> night (amber stays selectable in controls).
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            preferences.theme = (preferences.theme == .night) ? .day : .night
          }
        } label: {
          Image(systemName: preferences.theme == .night ? "sun.max.fill" : "moon.stars.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
            .padding(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle theme")
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 12)
    .padding(.bottom, 10)
  }

  private func content(containerWidth: CGFloat) -> some View {
    ScrollViewReader { proxy in
      ZStack {
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            Color.clear
              .frame(height: 0)
              .id(topAnchorID)

            // Continuous-scroll resume: restore contentOffset from saved progress (0..1).
            // Placed early in the content so it can reliably find the underlying UIScrollView.
            Color.clear
              .frame(height: 0)
              .background(
                _ReaderScrollOffsetRestorer(
                  enabled: shouldUseContinuousScroll && !viewModel.isLoading,
                  targetProgress: continuousRestoreProgress,
                  didRestore: $didRestoreContinuousScroll
                )
              )

            header
              .padding(.horizontal, 18)
              .padding(.top, 18)

            Divider()
              .opacity(0.12)
              .padding(.horizontal, 18)
              .padding(.top, 14)

            if showSearch {
              HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                  .foregroundStyle(preferences.theme.surfaceSecondaryText)
                TextField("Search in book", text: $searchQuery)
                  .textInputAutocapitalization(.never)
                  .disableAutocorrection(true)
                  .foregroundStyle(preferences.theme.surfaceText)
                if !searchQuery.isEmpty {
                  Button {
                    searchQuery = ""
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundStyle(preferences.theme.surfaceSecondaryText)
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(
                    preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.06 : 0.05)
                  )
              )
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
              )
              .padding(.horizontal, 18)
              .padding(.top, 12)
            }

            if viewModel.isLoading {
              VStack(spacing: 10) {
                ProgressView()
                  .tint(preferences.theme.accent)
                  .scaleEffect(1.1)
                Text("Loading your document")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
                Text("This usually takes a few seconds.")
                  .font(.system(size: 13, weight: .regular))
                  .foregroundStyle(preferences.theme.surfaceSecondaryText)
              }
              .frame(maxWidth: .infinity)
              .padding(.horizontal, 18)
              .padding(.top, 44)
              .padding(.bottom, 26)
            } else {
              if shouldUseContinuousScroll {
                VStack(alignment: .leading, spacing: 16) {
                  ForEach(viewModel.pages.indices, id: \.self) { idx in
                    SelectableTextView(
                      text: viewModel.pages[idx],
                      font: preferences.font.uiFont(size: CGFloat(preferences.fontSize)),
                      textColor: UIColor(preferences.theme.surfaceText),
                      lineSpacing: CGFloat(preferences.fontSize)
                        * CGFloat(max(0, preferences.lineSpacing - 1)),
                      highlightQuery: searchQuery.isEmpty ? nil : searchQuery,
                      onShareSelection: { selected in
                        selectedHighlightText = selected
                        showHighlightEditor = true
                      }
                    )
                    .id("page-\(idx)")
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
              } else {
                SelectableTextView(
                  text: currentPageText,
                  font: preferences.font.uiFont(size: CGFloat(preferences.fontSize)),
                  textColor: UIColor(preferences.theme.surfaceText),
                  lineSpacing: CGFloat(preferences.fontSize)
                    * CGFloat(max(0, preferences.lineSpacing - 1)),
                  highlightQuery: searchQuery.isEmpty ? nil : searchQuery,
                  onShareSelection: { selected in
                    selectedHighlightText = selected
                    showHighlightEditor = true
                  }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
              }
            }
          }
          .background(
            GeometryReader { geo in
              Color.clear
                // Track the content container position within the ScrollView.
                // Using a 0-height view for this doesn't update reliably, so we attach it here.
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
          scrollOffsetY = max(0, -minY)
          updateScrollProgress()
        }
        .onPreferenceChange(ReaderScrollContentHeightKey.self) { newValue in
          scrollContentHeight = max(1, newValue)
          updateScrollProgress()
        }
        .onPreferenceChange(ReaderScrollViewportHeightKey.self) { newValue in
          scrollViewportHeight = max(1, newValue)
          updateScrollProgress()
        }
        .overlay(alignment: .trailing) {
          if shouldUseContinuousScroll && !viewModel.isLoading {
            ReaderScrollIndicator(progress: scrollProgress, tint: preferences.theme.accent)
              .padding(.trailing, 8)
              .padding(.top, showSearch ? 106 : 72)
              .padding(.bottom, 16)
              .transition(.opacity)
          }
        }
      }
      .onChange(of: viewModel.currentIndex, initial: true) { _, newValue in
        // Paged mode: persist progress and jump to top for a clean "page" feel.
        guard !shouldUseContinuousScroll else { return }
        onProgressChange?(newValue + 1, max(1, viewModel.pages.count), nil)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          proxy.scrollTo(topAnchorID, anchor: .top)
        }
      }
      .onChange(of: shouldUseContinuousScroll, initial: true) { _, isContinuous in
        // Allow offset-based restore to run whenever continuous mode becomes active.
        if isContinuous {
          didRestoreContinuousScroll = false
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .center, spacing: 10) {
      Text(book.tags.first?.uppercased() ?? "DOCUMENT")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(3.0)

      Text(book.title.uppercased())
        .font(.custom("CinzelDecorative-Bold", size: 40))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.75)

      HStack(spacing: 28) {
        metaColumn(title: "DATE", value: formattedDate)
        metaColumn(title: "AUTHOR", value: book.author)
        metaColumn(title: "READ", value: "\(estimatedReadMinutes) min read")
      }
      .padding(.top, 6)
    }
    .frame(maxWidth: .infinity)
  }

  private func metaColumn(title: String, value: String)
    -> some View
  {
    VStack(alignment: .center, spacing: 6) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(2.0)
      Text(value)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }

  private var bottomPager: some View {
    HStack(spacing: 12) {
      Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          viewModel.goToPreviousPage()
        }
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(
            preferences.theme.surfaceText.opacity(viewModel.currentIndex > 0 ? 0.90 : 0.35)
          )
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preferences.theme.surfaceText.opacity(0.06))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.currentIndex <= 0)
      .accessibilityLabel("Previous page")

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        Text("\(max(1, viewModel.currentIndex + 1))/\(max(1, viewModel.pages.count))")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(
        Capsule(style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(0.06))
      )
      .overlay(
        Capsule(style: .continuous)
          .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
      )
      .accessibilityLabel(
        "Page \(max(1, viewModel.currentIndex + 1)) of \(max(1, viewModel.pages.count))")

      Spacer(minLength: 0)

      Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          viewModel.goToNextPage()
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(
            preferences.theme.surfaceText.opacity(
              viewModel.currentIndex < max(0, viewModel.pages.count - 1) ? 0.90 : 0.35)
          )
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preferences.theme.surfaceText.opacity(0.06))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.currentIndex >= max(0, viewModel.pages.count - 1))
      .accessibilityLabel("Next page")
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .padding(.bottom, 10)
  }

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMM yy"
    return formatter.string(from: Date())
  }

  private var estimatedReadMinutes: Int {
    let sourceText: String = {
      let joined = viewModel.pages.joined(separator: "\n\n")
      if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return joined
      }
      return BookTextProvider.fullText(for: book)
    }()

    let wordCount = sourceText.split { $0.isWhitespace || $0.isNewline }.count
    let wpm = 220.0
    return max(1, Int(ceil(Double(wordCount) / wpm)))
  }

  private var currentPageText: String {
    guard viewModel.pages.indices.contains(viewModel.currentIndex) else { return "" }
    return viewModel.pages[viewModel.currentIndex]
  }

  private var shouldUseContinuousScroll: Bool {
    preferences.continuousScrollForShortDocs
      && !viewModel.isLoading
      && viewModel.pages.count > 0
      && viewModel.pages.count < shortDocContinuousScrollMaxPages
  }

  private func updateScrollProgress() {
    guard shouldUseContinuousScroll else { return }
    let maxOffset = max(1, scrollContentHeight - scrollViewportHeight)
    let next = min(1.0, max(0.0, Double(scrollOffsetY / maxOffset)))
    if abs(next - scrollProgress) > 0.0005 {
      scrollProgress = next
      emitContinuousScrollProgressIfNeeded()
    }
  }

  private func emitContinuousScrollProgressIfNeeded() {
    guard shouldUseContinuousScroll else { return }
    let total = max(1, viewModel.pages.count)

    // Map scroll progress to a "page" so the rest of the app can keep showing page-based progress.
    let pageIndex = min(
      max(0, Int(round(scrollProgress * Double(max(0, total - 1))))), max(0, total - 1))
    let pageNumber = pageIndex + 1

    // Throttle emissions to reduce backend chatter (HomeViewModel also debounces network).
    if lastEmittedScrollProgress < 0
      || abs(scrollProgress - lastEmittedScrollProgress) >= 0.01
      || scrollProgress <= 0.001
      || scrollProgress >= 0.999
    {
      lastEmittedScrollProgress = scrollProgress
      onProgressChange?(pageNumber, total, scrollProgress)
    }
  }

  /// Best-effort restore target for continuous scroll.
  /// Prefer backend progress (0..1); fall back to mapping a page into progress when possible.
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

// MARK: - Scroll tracking

private struct ReaderScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ReaderScrollContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 1
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ReaderScrollViewportHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 1
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// (Debug overlay/probe removed)

// MARK: - Continuous scroll restore (contentOffset-based)
/// Sets the underlying ScrollView's contentOffset based on a 0..1 progress.
/// This is required to resume accurately in "continuous scroll" mode (especially when the doc collapses into one long page).
private struct _ReaderScrollOffsetRestorer: UIViewRepresentable {
  let enabled: Bool
  let targetProgress: Double?
  @Binding var didRestore: Bool

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    guard enabled, !didRestore, let targetProgress else { return }
    let p = min(1.0, max(0.0, targetProgress))

    DispatchQueue.main.async {
      guard enabled, !didRestore else { return }
      guard let scrollView = uiView.lectorFindNearestScrollView() else { return }
      guard scrollView.contentSize.height > 1, scrollView.bounds.height > 1 else { return }

      let topInset = scrollView.adjustedContentInset.top
      let bottomInset = scrollView.adjustedContentInset.bottom
      let minY = -topInset
      let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + bottomInset)
      let y = minY + CGFloat(p) * (maxY - minY)

      // Avoid micro-adjustments and fighting the user.
      if abs(scrollView.contentOffset.y - y) > 2 {
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: false)
      }
      didRestore = true
    }
  }
}

// MARK: - UIKit helpers
extension UIView {
  fileprivate func lectorFindNearestScrollView() -> UIScrollView? {
    // First: walk up the superview chain and return the first UIScrollView ancestor.
    var v: UIView? = self
    while let current = v {
      if let sv = current as? UIScrollView { return sv }
      v = current.superview
    }

    // Fallback: search the nearest available root (superview/window) for a UIScrollView.
    // This is more robust across SwiftUI internal view hierarchies.
    let root: UIView? = self.window ?? self.superview
    return root?.lectorFirstDescendant(ofType: UIScrollView.self)
  }

  fileprivate func lectorFirstDescendant<T: UIView>(ofType: T.Type) -> T? {
    var queue: [UIView] = [self]
    while !queue.isEmpty {
      let node = queue.removeFirst()
      if let match = node as? T { return match }
      queue.append(contentsOf: node.subviews)
    }
    return nil
  }
}

private struct ReaderScrollIndicator: View {
  let progress: Double
  let tint: Color

  var body: some View {
    GeometryReader { geo in
      let trackHeight = max(60, geo.size.height)
      let thumbHeight: CGFloat = 44
      let clamped = min(1.0, max(0.0, progress))
      let y = CGFloat(clamped) * max(0, trackHeight - thumbHeight)

      ZStack(alignment: .top) {
        Capsule(style: .continuous)
          .fill(Color.white.opacity(0.06))
          .frame(width: 3)

        Capsule(style: .continuous)
          .fill(tint.opacity(0.80))
          .frame(width: 3, height: thumbHeight)
          .offset(y: y)
          .shadow(color: tint.opacity(0.25), radius: 6, y: 2)
      }
      .frame(width: 12)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(width: 14)
    .allowsHitTesting(false)
  }
}

// MARK: - Preview

@MainActor
private func makeReaderPreviewPreferences() -> PreferencesViewModel {
  let prefs = PreferencesViewModel()
  prefs.theme = .night
  prefs.font = .georgia
  prefs.fontSize = 18
  prefs.lineSpacing = 1.15
  return prefs
}

#Preview("Reader • Test text") {
  let sampleText =
    """
    Capítulo 1 — Texto de prueba

    Este es un texto de prueba para previsualizar el lector. La idea es tener varios párrafos, con saltos de línea, para validar tipografía, espaciado y paginación.

    Cuando el usuario cambia el tamaño de letra (AA) o el tema, el contenido debe seguir siendo cómodo de leer. También queremos verificar cómo se ve un título largo y cómo se comporta el paginador.

    ——

    Párrafo extra: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec in urna sit amet massa viverra egestas. Sed at elit nec justo ullamcorper aliquet.

    Fin.

    \n\n——\n\n

    Capítulo 2 — Otra página de prueba

    Esta segunda sección existe para asegurar que el preview genere múltiples páginas y podamos probar navegación, search, y estilos en un bloque más largo.

    Un texto más largo ayuda a detectar cortes raros, saltos de línea inesperados, y problemas de layout. También permite probar la búsqueda dentro del libro con varias coincidencias.

    Repite: cthulhu cthulhu cthulhu.
    """

  let book = Book(
    title: "Reader Preview 2",
    author: "Fiodor Doestoyevski",
    pagesTotal: 10,
    currentPage: 4,
    sizeBytes: 0,
    lastOpenedDaysAgo: 0,
    isRead: false,
    isFavorite: false,
    tags: ["ARTICLE"]  // Tag de ejemplo para el preview
  )

  NavigationStack {
    ReaderView(book: book, initialText: sampleText)
      .environmentObject(makeReaderPreviewPreferences())
  }
}
