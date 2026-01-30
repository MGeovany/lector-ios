import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var viewModel: HomeViewModel
  @State private var addViewModel: AddViewModel = AddViewModel()
  @State private var showFilePicker: Bool = false
  @State private var pickedURL: URL?
  @State private var toast: UploadToastData?
  @StateObject private var networkMonitor = NetworkMonitor.shared

  init(viewModel: HomeViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? HomeViewModel())
  }

  var body: some View {
    @Bindable var viewModel = viewModel
    NavigationStack {
      ZStack {
        background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 16) {
              HomeHeaderView(
                searchText: $viewModel.searchQuery,
                onAddTapped: {
                  showFilePicker = true
                })

            if !networkMonitor.isOnline {
              Text("Offline — showing cached library.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }

            // Filter buttons: Recents, All, Read
            // (Temporarily hidden per design review; keep logic intact.)
            if false {
              FilterTabsView(
                filter: $viewModel.filter,
                colorScheme: colorScheme,
                onFilterChange: {
                  Task { await viewModel.reload() }
                }
              )
            }

            // HomeStatsRowView(
            //   documentsCount: viewModel.books.count,
            //   usedBytes: viewModel.books.reduce(Int64(0)) { $0 + $1.sizeBytes },
            //   maxStorageText: "\(MAX_STORAGE_MB) MB"
            // )

            if viewModel.filteredBooks.isEmpty && viewModel.isLoading {
              HomeSkeletonList()
                .padding(.top, 6)
            } else if !viewModel.isLoading && viewModel.books.isEmpty {
              EmptyLibraryPlaceholderView(
                colorScheme: colorScheme,
                onAddTapped: {
                  showFilePicker = true
                }
              )
              .padding(.top, 22)
            } else if viewModel.filteredBooks.isEmpty {
              EmptySearchPlaceholderView(colorScheme: colorScheme)
                .padding(.top, 22)
            } else {
              LazyVStack(spacing: 14) {
                ForEach(viewModel.filteredBooks) { book in
                  BookCardView(
                    book: book,
                    onOpen: { viewModel.selectedBook = book },
                    onToggleRead: { viewModel.toggleRead(bookID: book.id) },
                    onToggleFavorite: { viewModel.toggleFavorite(bookID: book.id) }
                  )
                }
              }
              .padding(.top, 6)
            }
          }
          .padding(.horizontal, 18)
          .padding(.top, 14)
          .padding(.bottom, 26)
        }
        .refreshable {
          await viewModel.reload()
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(item: $viewModel.selectedBook) { book in
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
        "Error",
        isPresented: Binding(
          get: { viewModel.alertMessage != nil },
          set: { newValue in if !newValue { viewModel.alertMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.alertMessage ?? "")
      }
      .onAppear { viewModel.onAppear() }
      .environment(viewModel)
    }
    .onAppear {
      networkMonitor.startIfNeeded()
    }
    .fileImporter(
      isPresented: $showFilePicker,
      allowedContentTypes: [UTType.pdf],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          Task { await addViewModel.uploadPickedPDF(url) }
        }
      case .failure(let error):
        viewModel.alertMessage = error.localizedDescription
      }
    }
    .overlay(alignment: .top) {
      // Subtle, non-blocking loading indicator.
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
    .onChange(of: addViewModel.didUploadSuccessfully) { _, didSucceed in
      guard didSucceed else { return }
      withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
        toast = UploadToastData(kind: .success, message: "Uploaded.")
      }
      addViewModel.didUploadSuccessfully = false
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { toast = nil }
      }
    }
    .onChange(of: addViewModel.alertMessage) { _, msg in
      let trimmed = (msg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }
      withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
        toast = UploadToastData(kind: .error, message: trimmed)
      }
      addViewModel.alertMessage = nil
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { toast = nil }
      }
    }
    .onChange(of: addViewModel.infoMessage) { _, msg in
      let trimmed = (msg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }
      withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
        toast = UploadToastData(kind: .info, message: trimmed)
      }
      addViewModel.infoMessage = nil
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { toast = nil }
      }
    }
    .onAppear {
      Task { await addViewModel.flushPendingUploadsIfPossible() }
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

private struct EmptyLibraryPlaceholderView: View {
  let colorScheme: ColorScheme
  let onAddTapped: () -> Void

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 14) {
        Spacer()

        Text("How about to start with a book?")
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
            Text("Add File")
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

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(iconColor)
        .padding(.bottom, 2)

      Text("No results")
        .font(.parkinsans(size: 18, weight: .semibold))
        .foregroundStyle(titleColor)

      Text("Try a different search term.")
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
