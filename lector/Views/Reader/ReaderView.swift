import SwiftUI

struct ReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var preferences: PreferencesViewModel

  let book: Book
  var onProgressChange: ((Int, Int) -> Void)? = nil
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
  @State private var didStartLoading: Bool = false
  @State private var debugTextFrame: Bool = false

  init(
    book: Book,
    onProgressChange: ((Int, Int) -> Void)? = nil,
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
                await viewModel.loadRemoteDocumentIfNeeded(
                  book: book,
                  documentsService: documentsService,
                  containerSize: containerSize,
                  style: style
                )
              }
            }
        }

        bottomPager
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
      }
      .onChange(of: viewModel.currentIndex, initial: true) { _, newValue in
        onProgressChange?(newValue + 1, max(1, viewModel.pages.count))
        // New page => jump to top so header + page start are visible.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          proxy.scrollTo(topAnchorID, anchor: .top)
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
