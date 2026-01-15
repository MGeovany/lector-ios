import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var viewModel: HomeViewModel
  @State private var addViewModel: AddViewModel = AddViewModel()
  @State private var showFilePicker: Bool = false
  @State private var pickedURL: URL?

  init(viewModel: HomeViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? HomeViewModel())
  }

  var body: some View {
    NavigationStack {
      ZStack {
        background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 16) {
            HomeHeaderView(onAddTapped: { showFilePicker = true })

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
          onProgressChange: { page, total in
            viewModel.updateBookProgress(bookID: book.id, page: page, totalPages: total)
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
    .alert(
      "Upload",
      isPresented: Binding(
        get: { addViewModel.alertMessage != nil || addViewModel.didUploadSuccessfully },
        set: { newValue in
          if !newValue {
            addViewModel.alertMessage = nil
            addViewModel.didUploadSuccessfully = false
          }
        }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(addViewModel.alertMessage ?? (addViewModel.didUploadSuccessfully ? "Uploaded." : ""))
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

#Preview {
  // Mock DocumentsService for preview that doesn't require authentication
  struct MockDocumentsService: DocumentsServicing {
    func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument] {
      // Return a mock document for preview using JSONDecoder
      let jsonString = """
        {
          "id": "mock-doc-1",
          "user_id": "\(userID)",
          "title": "The Art of SwiftUI",
          "author": "Jane Smith",
          "description": "A comprehensive guide to building modern iOS apps",
          "content": null,
          "metadata": {
            "original_title": "The Art of SwiftUI",
            "original_author": "Jane Smith",
            "language": "en",
            "page_count": 245,
            "word_count": 45000,
            "file_size": 2500000,
            "format": "pdf",
            "source": "upload",
            "has_password": false
          },
          "tag": "programming",
          "is_favorite": false,
          "created_at": "2024-01-15T10:00:00Z",
          "updated_at": "2024-01-15T10:00:00Z"
        }
        """

      let jsonData = jsonString.data(using: .utf8)!
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let mockDocument = try decoder.decode(RemoteDocument.self, from: jsonData)
      return [mockDocument]
    }

    func getDocument(id: String) async throws -> RemoteDocumentDetail {
      throw NSError(domain: "Preview", code: 0)
    }

    func updateDocument(documentID: String, title: String?, author: String?, tag: String?)
      async throws
      -> RemoteDocumentDetail
    {
      throw NSError(domain: "Preview", code: 0)
    }

    func uploadDocument(pdfData: Data, fileName: String) async throws -> RemoteDocument {
      throw NSError(domain: "Preview", code: 0)
    }

    func setFavorite(documentID: String, isFavorite: Bool) async throws {
      // No-op for preview
    }

    func getDocumentTags() async throws -> [String] {
      ["programming", "fiction", "work"]
    }

    func createDocumentTag(name: String) async throws {}

    func deleteDocumentTag(name: String) async throws {}
  }

  let mockService = MockDocumentsService()
  let mockViewModel = HomeViewModel(documentsService: mockService, userID: "preview-user")

  return HomeView(viewModel: mockViewModel)
    .environmentObject(PreferencesViewModel())
    .environment(AppSession())
}
