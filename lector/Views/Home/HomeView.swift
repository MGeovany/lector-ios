import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct HomeView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale
  @State private var viewModel: HomeViewModel
  @State private var addViewModel: AddViewModel = AddViewModel()
  @State private var showFilePicker: Bool = false
  @State private var pickedURL: URL?
  @State private var toast: UploadToastData?
  @StateObject private var networkMonitor = NetworkMonitor.shared
  @State private var selectedSection: LibrarySection = .allBooks
  @State private var isPreparingToOpenUploadedDoc: Bool = false
  @State private var prepareOpenTask: Task<Void, Never>?

  private static let allowedImportTypes: [UTType] = {
    var types: [UTType] = [.pdf]
    if let epub = UTType(filenameExtension: "epub") { types.append(epub) }
    types.append(.plainText)  // .txt
    if let md = UTType(filenameExtension: "md") { types.append(md) }
    return types
  }()

  init(viewModel: HomeViewModel? = nil, initialSection: LibrarySection = .current) {
    let vm = viewModel ?? HomeViewModel()
    // Library needs the full collection for section tabs.
    vm.filter = .all
    _viewModel = State(initialValue: vm)
    _selectedSection = State(initialValue: initialSection)
  }

  var body: some View {
    @Bindable var viewModel = viewModel
    homeNavigationStack(viewModel: viewModel, selectedBook: $viewModel.selectedBook)
      .onAppear { networkMonitor.startIfNeeded() }
      .fileImporter(
        isPresented: $showFilePicker,
        allowedContentTypes: Self.allowedImportTypes,
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let urls):
          if let url = urls.first {
            Task { await addViewModel.uploadPickedDocument(url) }
          }
        case .failure(let error):
          let message = error.localizedDescription
          Task { @MainActor in viewModel.alertMessage = message }
        }
      }
      .overlay(alignment: .top) {
        if viewModel.isLoading && !viewModel.filteredBooks.isEmpty {
          ProgressView()
            .tint(colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack)
            .padding(.top, 8)
        }
      }
      .overlay(alignment: .bottom) {
        if addViewModel.isUploading {
          HStack(spacing: 10) {
            ProgressView()
            Text("Uploading…")
              .font(.system(size: 13, weight: .semibold))
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(.ultraThinMaterial, in: Capsule(style: .continuous))
          .padding(.bottom, 86)
        }
      }
      .overlay(alignment: .top) {
        if let toast {
          UploadToastView(toast: toast)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .overlay {
        if isPreparingToOpenUploadedDoc {
          ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 10) {
              ProgressView()
              Text("Preparing your document…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                  colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
              .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .transition(.opacity)
        }
      }
      .onChange(of: addViewModel.didUploadSuccessfully) { _, didSucceed in
        guard didSucceed else { return }
        Task { @MainActor in
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            toast = UploadToastData(kind: .success, message: "Uploaded.")
          }
          addViewModel.didUploadSuccessfully = false
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { toast = nil }
        }
      }
      .onChange(of: addViewModel.alertMessage) { _, msg in
        let trimmed = (msg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            toast = UploadToastData(kind: .error, message: trimmed)
          }
          addViewModel.alertMessage = nil
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { toast = nil }
        }
      }
      .onChange(of: addViewModel.infoMessage) { _, msg in
        let trimmed = (msg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            toast = UploadToastData(kind: .info, message: trimmed)
          }
          addViewModel.infoMessage = nil
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { toast = nil }
        }
      }
      .onAppear {
        Task { await addViewModel.flushPendingUploadsIfPossible() }
      }
  }

  @ViewBuilder
  private func homeMainContent(viewModel: HomeViewModel) -> some View {
    ZStack {
      background.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 12) {
        HomeHeaderView(
          searchText: $viewModel.searchQuery,
          onAddTapped: { showFilePicker = true }
        )
        .padding(.horizontal, 18)
        .padding(.top, 14)
        if !networkMonitor.isOnline {
          Text(L10n.tr("Offline — showing cached library.", locale: locale))
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
        LibrarySectionTabsView(selected: $selectedSection)
        TabView(selection: $selectedSection) {
          ForEach(LibrarySection.allCases) { section in
            LibrarySectionPageView(
              section: section,
              colorScheme: colorScheme,
              onAddTapped: { showFilePicker = true }
            )
            .tag(section)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  @ViewBuilder
  private func homeNavigationStack(viewModel: HomeViewModel, selectedBook: Binding<Book?>)
    -> some View
  {
    NavigationStack {
      homeMainContent(viewModel: viewModel)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: selectedBook) { book in
          ReaderView(
            book: book,
            onProgressChange: { page, total, progressOverride in
              viewModel.updateBookProgress(
                bookID: book.id,
                page: page,
                totalPages: total,
                progressOverride: progressOverride
              )
            }
          )
        }
        .alert(
          L10n.tr("Error", locale: locale),
          isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { newValue in if !newValue { viewModel.alertMessage = nil } }
          )
        ) {
          Button(L10n.tr("OK", locale: locale), role: .cancel) {}
        } message: {
          Text(viewModel.alertMessage ?? "")
        }
        .onAppear { viewModel.onAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .openReaderForUploadedDocument)) {
          note in
          let remoteID = note.userInfo?["remoteID"] as? String
          guard let remoteID, !remoteID.isEmpty else { return }

          let loc = Locale(
            identifier: (UserDefaults.standard.string(forKey: AppPreferenceKeys.language)
              ?? AppLanguage.english.rawValue) == AppLanguage.spanish.rawValue ? "es" : "en")
          let title =
            (note.userInfo?["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? L10n.tr("Document", locale: loc)
          let author =
            (note.userInfo?["author"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? L10n.tr("Unknown", locale: loc)
          let pagesTotal = max(1, (note.userInfo?["pagesTotal"] as? Int) ?? 1)
          let createdAt = note.userInfo?["createdAt"] as? Date
          let sizeBytes = (note.userInfo?["sizeBytes"] as? Int64) ?? 0
          let stableID = UUID(uuidString: remoteID) ?? UUID()

          Task { @MainActor in
            prepareOpenTask?.cancel()
            isPreparingToOpenUploadedDoc = true
            prepareOpenTask = Task { @MainActor in
              do {
                _ = try await viewModel.waitForOptimizedReady(documentID: remoteID)
              } catch {
                isPreparingToOpenUploadedDoc = false
                return
              }
              isPreparingToOpenUploadedDoc = false

              if let existing = viewModel.books.first(where: { $0.remoteID == remoteID }) {
                viewModel.selectedBook = existing
                return
              }

              viewModel.selectedBook = Book(
                id: stableID,
                remoteID: remoteID,
                title: title,
                author: author,
                createdAt: createdAt,
                pagesTotal: pagesTotal,
                currentPage: 1,
                readingProgress: nil,
                sizeBytes: sizeBytes,
                lastOpenedAt: Date(),
                lastOpenedDaysAgo: 0,
                isRead: false,
                isFavorite: false,
                tags: []
              )

              Task { await viewModel.reload() }
            }
          }
        }
        .environment(viewModel)
    }
  }

  private var background: some View {
    Group {
      if colorScheme == .dark {
        LinearGradient(
          colors: [
            Color.black,
            Color(red: 0.06, green: 0.06, blue: 0.08),
            Color(red: 0.03, green: 0.03, blue: 0.04),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      } else {
        LinearGradient(
          colors: [
            Color(.systemGroupedBackground),
            Color(.systemBackground),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
  }

}

// MARK: - Upload Toast (non-blocking)

private struct LibrarySectionPageView: View {
  let section: LibrarySection
  let colorScheme: ColorScheme
  let onAddTapped: () -> Void
  @Environment(HomeViewModel.self) private var viewModel

  var body: some View {
    GeometryReader { geometry in
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 16) {
          let isSearching = !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
          let books = viewModel.libraryBooks(for: section)

          // Special layout for Current (dashboard sections) when not searching.
          if section == .current && !isSearching && !viewModel.books.isEmpty {
            CurrentLibraryDashboardView()
              .padding(.top, 4)
          } else if books.isEmpty && viewModel.isLoading {
            HomeSkeletonList()
              .padding(.top, 6)
              .frame(minHeight: geometry.size.height - 40)
          } else if !viewModel.isLoading && viewModel.books.isEmpty {
            EmptyLibraryPlaceholderView(colorScheme: colorScheme, onAddTapped: onAddTapped)
              .padding(.top, 22)
              .frame(minHeight: geometry.size.height - 40)
          } else if books.isEmpty {
            if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              EmptySearchPlaceholderView(colorScheme: colorScheme)
                .padding(.top, 22)
                .frame(minHeight: geometry.size.height - 40)
            } else {
              LibrarySectionEmptyStateView(section: section, colorScheme: colorScheme)
                .padding(.top, 22)
                .frame(minHeight: geometry.size.height - 40)
            }
          } else {
            // Minimal list style for All / To read / Finished (and search results).
            LazyVStack(spacing: 0) {
              ForEach(books) { book in
                let statusText: String? = {
                  switch section {
                  case .allBooks:
                    return book.completionStatusText ?? book.readingStatusText
                  case .finished:
                    return book.completionStatusText
                  default:
                    return nil
                  }
                }()
                MinimalBookRowView(
                  book: book,
                  showsOptions: section == .allBooks,
                  statusText: statusText,
                  onOpen: { viewModel.selectedBook = book }
                )
              }
            }
            .padding(.top, 6)
          }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 26)
      }
      .refreshable { await viewModel.reload() }
    }
  }
}

private struct CurrentLibraryDashboardView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale
  @Environment(HomeViewModel.self) private var viewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 26) {
      let inProgress = viewModel.libraryBooks(for: .current)
        .sorted { $0.lastOpenedSortDate > $1.lastOpenedSortDate }
      let resume = inProgress.first
      let nextUp = Array(inProgress.dropFirst())
      let recentlyAdded = viewModel.books
        .sorted { $0.createdSortDate > $1.createdSortDate }
        .prefix(12)

      sectionHeader(L10n.tr("RESUME READING", locale: locale))

      if let resume {
        ResumeReadingCardView(book: resume, onContinue: { viewModel.selectedBook = resume })
      } else {
        EmptyInlineHint(
          text: L10n.tr("Start reading a book and it will show up here.", locale: locale))
      }

      if !nextUp.isEmpty {
        sectionHeader(L10n.tr("NEXT UP", locale: locale))
        NextUpRowView(books: nextUp, onOpen: { viewModel.selectedBook = $0 })
      }

      if !recentlyAdded.isEmpty {
        sectionHeader(L10n.tr("RECENTLY ADDED", locale: locale))
        VStack(spacing: 0) {
          ForEach(Array(recentlyAdded)) { book in
            RecentlyAddedRowView(book: book, onOpen: { viewModel.selectedBook = book })
          }
        }
      }
    }
  }

  private func sectionHeader(_ text: String) -> some View {
    Text(text)
      .font(.parkinsansSemibold(size: 13))
      .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
      .kerning(1.2)
      .padding(.top, 2)
  }
}

private struct ResumeReadingCardView: View {
  let book: Book
  let onContinue: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    Button(action: onContinue) {
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 6) {
            Text(book.title.uppercased())
              .font(.parkinsansMedium(size: 34))
              .foregroundStyle(
                colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack
              )
              .lineLimit(3)
              .minimumScaleFactor(0.7)
              .padding(.trailing, 44)  // reserve space for options menu

            Text(book.author.uppercased())
              .font(.parkinsans(size: 14, weight: .semibold))
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.42) : .secondary)
              .lineLimit(1)
              .padding(.trailing, 44)
          }

          HStack {
            Text(
              String(
                format: L10n.tr("PAGE %d OF %d", locale: locale), book.currentPage, book.pagesTotal)
            )
            .font(.parkinsansSemibold(size: 13))
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.60) : AppColors.matteBlack.opacity(0.55))

            Spacer()

            Text("\(Int((book.progress * 100).rounded()))%")
              .font(.parkinsansSemibold(size: 13))
              .foregroundStyle(
                colorScheme == .dark
                  ? Color.white.opacity(0.60) : AppColors.matteBlack.opacity(0.55))
          }

          ProgressBarView(progress: book.progress)
            .frame(height: 9)
            .padding(.top, 2)

          HStack {
            Text(L10n.tr("CONTINUE", locale: locale))
              .font(.parkinsansSemibold(size: 14))
              .foregroundStyle(
                colorScheme == .dark ? Color.white.opacity(0.80) : AppColors.matteBlack
              )
              .underline()

            Spacer()

            Circle()
              .strokeBorder(
                colorScheme == .dark
                  ? Color.white.opacity(0.22) : AppColors.matteBlack.opacity(0.35), lineWidth: 1.25
              )
              .frame(width: 34, height: 34)
              .overlay(
                Image(systemName: "chevron.right")
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundStyle(
                    colorScheme == .dark
                      ? Color.white.opacity(0.82) : AppColors.matteBlack.opacity(0.82))
              )
          }
          .padding(.top, 2)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(
                colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.35),
                lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
    .overlay(alignment: .topTrailing) {
      BookOptionsMenu(book: book)
        .padding(10)
    }
  }
}

private struct NextUpRowView: View {
  let books: [Book]
  let onOpen: (Book) -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geo in
      let count = books.count
      let spacing: CGFloat = 14

      if count <= 3 {
        let w = (geo.size.width - spacing * CGFloat(max(0, count - 1))) / CGFloat(max(1, count))
        HStack(spacing: spacing) {
          ForEach(books) { book in
            NextUpTileView(book: book, onOpen: { onOpen(book) })
              .frame(width: w, alignment: .leading)
          }
        }
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: spacing) {
            ForEach(books) { book in
              NextUpTileView(book: book, onOpen: { onOpen(book) })
                .frame(width: 220, alignment: .leading)
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
    .frame(height: 120)
  }
}

private struct NextUpTileView: View {
  let book: Book
  let onOpen: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    Button(action: onOpen) { tileContent }
      .buttonStyle(.plain)
  }

  private var tileContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      titleText
      authorText
      progressRow
      ProgressBarView(progress: book.progress)
        .frame(height: 9)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tileBackground)
  }

  private var titleText: some View {
    ClippedMultilineLabel(
      text: displayTitle,
      font: titleUIFont,
      textColor: UIColor(titleColor),
      numberOfLines: 2
    )
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Avoid SwiftUI ellipsis rendering ("..."/":::" in some fonts) by truncating the string ourselves.
  private var displayTitle: String {
    let t = book.title.uppercased()
    // Conservative character cap to fit typical tile widths without triggering ellipsis.
    // (We prefer a hard cut over trailing dots.)
    let cap = 32
    if t.count <= cap { return t }
    return String(t.prefix(cap))
  }

  private var titleUIFont: UIFont {
    // Parkinsans-Regular is the only shipped variant; fallback to system semibold.
    UIFont(name: "Parkinsans-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .semibold)
  }

  private var authorText: some View {
    Text(book.author)
      .font(.parkinsans(size: 13, weight: .medium))
      .foregroundStyle(authorColor)
      .lineLimit(1)
  }

  private var progressRow: some View {
    HStack {
      Text(
        String(format: L10n.tr("PAGE %d OF %d", locale: locale), book.currentPage, book.pagesTotal))
      Spacer()
      Text("\(Int((book.progress * 100).rounded()))%")
    }
    .font(.parkinsans(size: 12, weight: .medium))
    .foregroundStyle(progressColor)
  }

  private var tileBackground: some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
      .fill(tileFill)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(tileStroke, lineWidth: 1)
      )
  }

  private var titleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack
  }

  private var authorColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.45) : .secondary
  }

  private var progressColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.55) : .secondary
  }

  private var tileFill: Color {
    colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground)
  }

  private var tileStroke: Color {
    colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.30)
  }
}

/// UILabel wrapper that truncates by **clipping** (no ellipsis).
private struct ClippedMultilineLabel: UIViewRepresentable {
  let text: String
  let font: UIFont
  let textColor: UIColor
  let numberOfLines: Int

  func makeUIView(context: Context) -> UILabel {
    let label = UILabel()
    label.numberOfLines = numberOfLines
    label.lineBreakMode = .byClipping
    label.adjustsFontForContentSizeCategory = true
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    return label
  }

  func updateUIView(_ uiView: UILabel, context: Context) {
    uiView.text = text
    uiView.font = font
    uiView.textColor = textColor
  }
}

private struct RecentlyAddedRowView: View {
  let book: Book
  let onOpen: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(book.title.uppercased())
            .font(.parkinsansSemibold(size: 15))
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack
            )
            .lineLimit(2)

          Text(book.author)
            .font(.parkinsans(size: 13))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : .secondary)
            .lineLimit(1)

          Text(String(format: L10n.tr("%d pages", locale: locale), book.pagesTotal))
            .font(.parkinsans(size: 12, weight: .medium))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : .secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        BookOptionsMenu(book: book)

        Circle()
          .strokeBorder(
            colorScheme == .dark ? Color.white.opacity(0.22) : AppColors.matteBlack.opacity(0.35),
            lineWidth: 1.25
          )
          .frame(width: 34, height: 34)
          .overlay(
            Image(systemName: "arrow.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(
                colorScheme == .dark
                  ? Color.white.opacity(0.82) : AppColors.matteBlack.opacity(0.82))
          )
      }
      .padding(.vertical, 18)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(
            colorScheme == .dark ? Color.white.opacity(0.10) : AppColors.matteBlack.opacity(0.85)
          )
          .frame(height: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct EmptyInlineHint: View {
  let text: String
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Text(text)
      .font(.parkinsans(size: 14, weight: .medium))
      .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : .secondary)
      .padding(.vertical, 10)
  }
}

private struct LibrarySectionEmptyStateView: View {
  let section: LibrarySection
  let colorScheme: ColorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: iconName)
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(iconColor)
        .padding(.bottom, 2)

      Text(title)
        .font(.parkinsans(size: 18, weight: .semibold))
        .foregroundStyle(titleColor)

      Text(subtitle)
        .font(.parkinsans(size: 14, weight: .medium))
        .foregroundStyle(subtitleColor)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
  }

  private var iconName: String {
    switch section {
    case .allBooks: return "books.vertical"
    case .current: return "bookmark"
    case .toRead: return "book"
    case .finished: return "checkmark.seal"
    }
  }

  private var title: String {
    let key: String
    switch section {
    case .allBooks: key = "No books"
    case .current: key = "Nothing in progress"
    case .toRead: key = "Nothing to read yet"
    case .finished: key = "No finished books"
    }
    return L10n.tr(key, locale: locale)
  }

  private var subtitle: String {
    let key: String
    switch section {
    case .allBooks: key = "Add a book to get started."
    case .current: key = "Start reading a book and it will show up here."
    case .toRead: key = "Books you haven't started will appear here."
    case .finished: key = "Finish a book and it will show up here."
    }
    return L10n.tr(key, locale: locale)
  }

  private var titleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack.opacity(0.92)
  }

  private var subtitleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.55)
  }

  private var iconColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.60) : AppColors.matteBlack.opacity(0.40)
  }
}

private struct EmptyLibraryPlaceholderView: View {
  let colorScheme: ColorScheme
  let onAddTapped: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 14) {
        Spacer()

        Text(L10n.tr("How about to start with a book?", locale: locale))
          .font(.parkinsans(size: 20, weight: .light))
          .foregroundStyle(
            colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack.opacity(0.90)
          )
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 14)

        Button {
          onAddTapped()
        } label: {
          HStack(spacing: 10) {
            Text(L10n.tr("Add File", locale: locale))
            Image(systemName: "plus.circle.fill")
          }

        }
        .buttonStyle(LectorPrimaryRoundedButtonStyle(cornerRadius: 12))
        .fixedSize(horizontal: true, vertical: false)
        .padding(.top, 8)

        Spacer()
      }
      .frame(maxWidth: .infinity)
      .frame(height: geometry.size.height)
      .padding(.horizontal, 8)
    }
    .frame(minHeight: 400)
  }

  private var titleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack.opacity(0.92)
  }

  private var subtitleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.55)
  }

  private var iconColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.60) : AppColors.matteBlack.opacity(0.40)
  }
}

private struct EmptySearchPlaceholderView: View {
  let colorScheme: ColorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(iconColor)
        .padding(.bottom, 2)

      Text(L10n.tr("No results", locale: locale))
        .font(.parkinsans(size: 18, weight: .semibold))
        .foregroundStyle(titleColor)

      Text(L10n.tr("Try a different search term.", locale: locale))
        .font(.parkinsans(size: 14, weight: .medium))
        .foregroundStyle(subtitleColor)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
  }

  private var titleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack.opacity(0.92)
  }

  private var subtitleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.55)
  }

  private var iconColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.60) : AppColors.matteBlack.opacity(0.40)
  }
}

private struct UploadToastData: Equatable {
  enum Kind: Equatable {
    case success
    case error
    case info

    var iconName: String {
      switch self {
      case .success: return "checkmark.circle.fill"
      case .error: return "xmark.octagon.fill"
      case .info: return "clock.badge.checkmark"
      }
    }

    var iconColor: Color {
      switch self {
      case .success: return .green
      case .error: return .red
      case .info: return .blue
      }
    }
  }

  let kind: Kind
  let message: String
}

private struct UploadToastView: View {
  let toast: UploadToastData
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: toast.kind.iconName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(toast.kind.iconColor)

      Text(toast.message)
        .font(.parkinsans(size: CGFloat(13), weight: .semibold))
        .foregroundStyle(textColor)
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    .overlay(
      Capsule(style: .continuous)
        .stroke(borderColor, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 10, y: 6)
    .padding(.horizontal, 18)
    .accessibilityLabel(toast.message)
  }

  private var textColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.90) : AppColors.matteBlack.opacity(0.90)
  }

  private var borderColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.35)
  }
}

// MARK: - Skeletons (Home)

private struct HomeSkeletonList: View {
  var body: some View {
    VStack(spacing: 14) {
      ForEach(0..<4, id: \.self) { _ in
        HomeSkeletonCard()
          .frame(height: 160)
      }
    }
  }
}

private struct HomeSkeletonCard: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var phase: CGFloat = -0.8

  var body: some View {
    let base = RoundedRectangle(cornerRadius: 20, style: .continuous)
    base
      .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.secondarySystemBackground))
      .overlay(
        base
          .stroke(
            colorScheme == .dark ? Color.white.opacity(0.08) : Color(.separator).opacity(0.18),
            lineWidth: 1
          )
      )
      .overlay(
        GeometryReader { geo in
          LinearGradient(
            colors: [
              Color.white.opacity(0.00),
              Color.white.opacity(colorScheme == .dark ? 0.10 : 0.35),
              Color.white.opacity(0.00),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .rotationEffect(.degrees(18))
          .frame(width: geo.size.width * 0.7)
          .offset(x: geo.size.width * phase)
        }
        .clipShape(base)
        .allowsHitTesting(false)
        .opacity(colorScheme == .dark ? 1 : 0.6)
      )
      .onAppear {
        withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
          phase = 1.2
        }
      }
  }
}

// MARK: - Filter Tabs with Animation

struct FilterTabsView: View {
  @Binding var filter: ReadingFilter
  let colorScheme: ColorScheme
  let onFilterChange: () -> Void

  private let filters: [ReadingFilter] = [.recents, .read, .all]

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        ForEach(filters, id: \.self) { filterOption in
          Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              filter = filterOption
            }
            onFilterChange()
          }) {
            Text(filterOption.rawValue)
              .font(.parkinsansSemibold(size: 16))
              .foregroundStyle(
                filter == filterOption
                  ? (colorScheme == .dark ? Color.black : Color.white)
                  : (colorScheme == .dark
                    ? Color.white.opacity(0.75) : AppColors.matteBlack.opacity(0.55))
              )
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .padding(.horizontal, 28)
          }
          .buttonStyle(.plain)
        }
      }
      .background(
        // Animated background indicator
        HStack(spacing: 0) {
          if let selectedIndex = filters.firstIndex(of: filter) {
            Spacer()
              .frame(width: geometry.size.width / CGFloat(filters.count) * CGFloat(selectedIndex))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(
                colorScheme == .dark ? Color.white : AppColors.matteBlack
              )
              .frame(width: geometry.size.width / CGFloat(filters.count) - 12)
              .padding(.horizontal, 6)
              .padding(.vertical, 6)

            Spacer()
              .frame(
                width: geometry.size.width / CGFloat(filters.count)
                  * CGFloat(filters.count - selectedIndex - 1))
          }
        }
      )
    }
    .frame(height: 52)
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(
          colorScheme == .dark
            ? Color.white.opacity(0.08) : Color(.secondarySystemBackground)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
              colorScheme == .dark
                ? Color.white.opacity(0.10) : Color(.separator).opacity(0.35), lineWidth: 1)
        )
    )
  }

  // MARK: - Skeletons

  private struct HomeSkeletonList: View {
    var body: some View {
      VStack(spacing: 14) {
        ForEach(0..<4, id: \.self) { _ in
          SkeletonCard()
            .frame(height: 160)
        }
      }
    }
  }

  private struct SkeletonCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -0.8

    var body: some View {
      let base = RoundedRectangle(cornerRadius: 20, style: .continuous)
      base
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.secondarySystemBackground))
        .overlay(
          base
            .stroke(
              colorScheme == .dark ? Color.white.opacity(0.08) : Color(.separator).opacity(0.18),
              lineWidth: 1)
        )
        .overlay(
          GeometryReader { geo in
            LinearGradient(
              colors: [
                Color.white.opacity(0.00),
                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.35),
                Color.white.opacity(0.00),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
            .rotationEffect(.degrees(18))
            .frame(width: geo.size.width * 0.7)
            .offset(x: geo.size.width * phase)
          }
          .clipShape(base)
          .allowsHitTesting(false)
          .opacity(colorScheme == .dark ? 1 : 0.6)
        )
        .onAppear {
          withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
            phase = 1.2
          }
        }
    }
  }
}

#Preview("Home (Empty)") {
  HomeView()
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}

#Preview("Home (Empty • Dark)") {
  HomeView()
    .preferredColorScheme(.dark)
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}

  private enum LibraryPreviewData {
    static var books: [Book] {
      let now = Date()
      return [
        // To read
        Book(
          id: UUID(),
          remoteID: UUID().uuidString,
          title: "Atomic Habits",
          author: "James Clear",
          createdAt: Calendar.current.date(byAdding: .day, value: -14, to: now),
          pagesTotal: 320,
          currentPage: 1,
          readingProgress: nil,
          sizeBytes: 5_200_000,
          lastOpenedAt: Calendar.current.date(byAdding: .day, value: -4, to: now),
          lastOpenedDaysAgo: 4,
          isRead: false,
          isFavorite: false,
          tags: ["Book"]
        ),
        Book(
          id: UUID(),
          remoteID: UUID().uuidString,
          title: "The Pragmatic Programmer",
          author: "Andy Hunt",
          createdAt: Calendar.current.date(byAdding: .day, value: -2, to: now),
          pagesTotal: 352,
          currentPage: 1,
          readingProgress: 0.0,
          sizeBytes: 7_100_000,
          lastOpenedAt: Calendar.current.date(byAdding: .day, value: -10, to: now),
          lastOpenedDaysAgo: 10,
          isRead: false,
          isFavorite: true,
          tags: ["Tech"]
        ),

        // Current (in progress)
        Book(
          id: UUID(),
          remoteID: UUID().uuidString,
          title: "Milk and Honey",
          author: "Rupi Kaur",
          createdAt: Calendar.current.date(byAdding: .day, value: -30, to: now),
          pagesTotal: 204,
          currentPage: 35,
          readingProgress: 0.171,
          sizeBytes: 3_900_000,
          lastOpenedAt: Calendar.current.date(byAdding: .hour, value: -3, to: now),
          lastOpenedDaysAgo: 0,
          isRead: false,
          isFavorite: true,
          tags: ["Poetry"]
        ),
        Book(
          id: UUID(),
          remoteID: UUID().uuidString,
          title: "Dune",
          author: "Frank Herbert",
          createdAt: Calendar.current.date(byAdding: .day, value: -6, to: now),
          pagesTotal: 688,
          currentPage: 120,
          readingProgress: 0.174,
          sizeBytes: 12_800_000,
          lastOpenedAt: Calendar.current.date(byAdding: .hour, value: -26, to: now),
          lastOpenedDaysAgo: 1,
          isRead: false,
          isFavorite: false,
          tags: ["Sci‑Fi"]
        ),

        // Finished
        Book(
          id: UUID(),
          remoteID: UUID().uuidString,
          title: "1984",
          author: "George Orwell",
          createdAt: Calendar.current.date(byAdding: .day, value: -40, to: now),
          pagesTotal: 328,
          currentPage: 328,
          readingProgress: 1.0,
          sizeBytes: 4_600_000,
          lastOpenedAt: Calendar.current.date(byAdding: .day, value: -2, to: now),
          lastOpenedDaysAgo: 2,
          isRead: true,
          isFavorite: false,
          tags: ["Classic"]
        ),
        Book(
          id: UUID(),
          remoteID: UUID().uuidString,
          title: "Sapiens",
          author: "Yuval Noah Harari",
          createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now),
          pagesTotal: 498,
          currentPage: 498,
          readingProgress: 1.0,
          sizeBytes: 9_400_000,
          lastOpenedAt: Calendar.current.date(byAdding: .day, value: -18, to: now),
          lastOpenedDaysAgo: 18,
          isRead: true,
          isFavorite: true,
          tags: ["Essay"]
        ),
      ]
    }

    static func viewModel() -> HomeViewModel {
      HomeViewModel.previewLibrary(books: books)
    }
  }

  #Preview("Library • All books") {
    HomeView(viewModel: LibraryPreviewData.viewModel(), initialSection: .allBooks)
      .environmentObject(PreferencesViewModel())
      .environmentObject(SubscriptionStore())
  }

  #Preview("Library • Current") {
    HomeView(viewModel: LibraryPreviewData.viewModel(), initialSection: .current)
      .environmentObject(PreferencesViewModel())
      .environmentObject(SubscriptionStore())
  }

  #Preview("Library • To read") {
    HomeView(viewModel: LibraryPreviewData.viewModel(), initialSection: .toRead)
      .environmentObject(PreferencesViewModel())
      .environmentObject(SubscriptionStore())
  }

  #Preview("Library • Finished") {
    HomeView(viewModel: LibraryPreviewData.viewModel(), initialSection: .finished)
      .environmentObject(PreferencesViewModel())
      .environmentObject(SubscriptionStore())
  }
