//
//  FavoritesView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct FavoritesView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var query: String = ""
  @State private var selectedBook: Book?
  @State private var viewModel: HomeViewModel

  init(viewModel: HomeViewModel? = nil) {
    let vm = viewModel ?? HomeViewModel()
    // Favorites should load the full library (not recents) so favorite items always show up.
    vm.filter = .all
    _viewModel = State(initialValue: vm)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        background

        content
          .padding(.horizontal, 18)
          .padding(.top, 14)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $selectedBook) { book in
        ReaderView(
          book: book,
          onProgressChange: { page, total in
            viewModel.updateBookProgress(bookID: book.id, page: page, totalPages: total)
          }
        )
      }
      .onAppear { viewModel.onAppear() }
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
    .ignoresSafeArea()
  }

  private var content: some View {
    GeometryReader { geometry in
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 14) {
          FavoritesHeaderView(filteredFavorites: filteredFavorites)
          FavoritesSearchBar(text: $query)
          if filteredFavorites.isEmpty && viewModel.isLoading && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(spacing: 14) {
              ForEach(0..<3, id: \.self) { _ in
                FavoritesSkeletonCard()
                  .frame(height: 160)
              }
            }
            .frame(minHeight: geometry.size.height - 300)
          } else if filteredFavorites.isEmpty {
            inlineEmptyState
              .frame(minHeight: geometry.size.height - 300)
          } else {
            LazyVStack(spacing: 14) {
              ForEach(filteredFavorites) { book in
                BookCardView(
                  book: book,
                  onOpen: { selectedBook = book },
                  onToggleRead: { viewModel.toggleRead(bookID: book.id) },
                  onToggleFavorite: { viewModel.toggleFavorite(bookID: book.id) }
                )
              }
            }
          }
        }
        .padding(.bottom, 24)
      }
      .environment(viewModel)
    }
  }

  private struct FavoritesSkeletonCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -0.8

    var body: some View {
      let base = RoundedRectangle(cornerRadius: 20, style: .continuous)
      base
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.secondarySystemBackground))
        .overlay(
          base
            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color(.separator).opacity(0.18), lineWidth: 1)
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

  private var inlineEmptyState: some View {
    VStack(spacing: 20) {
      Spacer()

      VStack(spacing: 16) {
        Image(
          systemName:
            "\(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "heart" : "magnifyingglass")"
        )
        .font(.parkinsans(size: 26, weight: .light))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.60) : AppColors.matteBlack)

        VStack(spacing: 8) {
          Text(
            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? "No favorites yet" : "No Matches"
          )
          .font(.parkinsansBold(size: 20))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)

          Text(
            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? "Save books you love to find them faster here."
              : "Try a different search."
          )
          .font(.parkinsans(size: 15, weight: .regular))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.60) : .secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
        }
      }
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private var filteredFavorites: [Book] {
    let favoritesOnly = viewModel.books.filter { $0.isFavorite }

    let searched: [Book] = {
      let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return favoritesOnly }
      return favoritesOnly.filter { book in
        book.title.localizedCaseInsensitiveContains(trimmed)
          || book.author.localizedCaseInsensitiveContains(trimmed)
          || book.tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) })
      }
    }()

    // Default sort: recently opened
    return searched.sorted { $0.lastOpenedDaysAgo < $1.lastOpenedDaysAgo }
  }
}

private struct FavoritesSearchBar: View {
  @Binding var text: String
  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.parkinsansSemibold(size: 15))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

      TextField("Search favorites", text: $text)
        .font(.parkinsansMedium(size: 16))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
        .tint(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)

      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.parkinsansSemibold(size: 16))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color(.systemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
              colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5),
              lineWidth: 1)
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .onTapGesture { isFocused = true }
    .accessibilityLabel("Search favorites")
  }
}

#Preview {
  // Mock DocumentsService for preview with a favorite book
  struct MockDocumentsService: DocumentsServicing {
    func getDocumentsByUserID(_ userID: String) async throws -> [RemoteDocument] {
      // Return a mock favorite document for preview
      let jsonString = """
        {
          "id": "mock-fav-doc-1",
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
          "is_favorite": true,
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

    func getRecentDocumentsByUserID(_ userID: String, since: Date, limit: Int) async throws
      -> [RemoteDocument]
    {
      return try await getDocumentsByUserID(userID)
    }
  }

  let mockService = MockDocumentsService()
  let mockViewModel = HomeViewModel(documentsService: mockService, userID: "preview-user")

  return FavoritesView(viewModel: mockViewModel)
    .environment(mockViewModel)
    .environmentObject(PreferencesViewModel())
    .environment(AppSession())
    .task {
      await mockViewModel.reload()
    }
}
