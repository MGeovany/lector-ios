import SwiftUI

struct HomeView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var viewModel = HomeViewModel()

  var body: some View {
    NavigationStack {
      ZStack {
        background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 16) {
            HomeHeaderView()

            ReadingFilterTabsView(
              filter: $viewModel.filter,
              unreadCount: viewModel.books.filter { !$0.isRead }.count
            )

            HomeStatsRowView(
              documentsCount: viewModel.books.count,
              usedBytes: viewModel.books.reduce(Int64(0)) { $0 + $1.sizeBytes },
              maxStorageText: "\(MAX_STORAGE_MB) MB"
            )

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
          .padding(.horizontal, 18)
          .padding(.top, 14)
          .padding(.bottom, 26)
        }
        .refreshable {
          await viewModel.reload()
        }

        if viewModel.isLoading {
          ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15)
              .ignoresSafeArea()
            ProgressView("Loading…")
              .padding()
              .background(.ultraThinMaterial)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
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
