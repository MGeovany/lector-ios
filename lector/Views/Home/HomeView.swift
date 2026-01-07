import SwiftUI

struct HomeView: View {
    @State private var filter: ReadingFilter = .unread

    // Mock data for now
    @State private var books: [Book] = [
        Book(
            title: "Noches Blancas",
            author: "J.A.C.",
            pagesTotal: 32,
            currentPage: 14,
            sizeBytes: 157_400,
            lastOpenedDaysAgo: 14,
            isRead: false,
            tags: ["Book"]
        ),
        Book(
            title: "Noches Blancas",
            author: "J.A.C.",
            pagesTotal: 32,
            currentPage: 14,
            sizeBytes: 157_400,
            lastOpenedDaysAgo: 14,
            isRead: false,
            tags: ["Book"]
        ),
        Book(
            title: "Noches Blancas",
            author: "J.A.C.",
            pagesTotal: 32,
            currentPage: 14,
            sizeBytes: 157_400,
            lastOpenedDaysAgo: 14,
            isRead: false,
            tags: ["Book"]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HomeHeaderView()

                ReadingFilterTabsView(
                    filter: $filter,
                    unreadCount: books.filter { !$0.isRead }.count
                )

                HomeStatsRowView(
                    documentsCount: books.count,
                    usedBytes: books.reduce(Int64(0)) { $0 + $1.sizeBytes },
                    maxStorageText: "\(MAX_STORAGE) MB"
                )

                LazyVStack(spacing: 14) {
                    ForEach(filteredBooks) { book in
                        BookCardView(
                            book: book,
                            onToggleRead: { toggleRead(bookID: book.id) }
                        )
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }

    private var filteredBooks: [Book] {
        switch filter {
        case .unread:
            return books.filter { !$0.isRead }
        case .read:
            return books.filter { $0.isRead }
        }
    }

    private func toggleRead(bookID: UUID) {
        guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[idx].isRead.toggle()
    }
}

#Preview {
    HomeView()
}
