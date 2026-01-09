import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var filter: ReadingFilter = .unread
    @State private var showPremiumSheet: Bool = false

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
            isFavorite: true,
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
            isFavorite: false,
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
            isFavorite: false,
            tags: ["Book"]
        )
    ]

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HomeHeaderView()

                    ReadingFilterTabsView(
                        filter: $filter,
                        unreadCount: books.filter { !$0.isRead }.count
                    )

                    HomeStatsRowView(
                        documentsCount: books.count,
                        usedBytes: books.reduce(Int64(0)) { $0 + $1.sizeBytes },
                        maxStorageText: "\(MAX_STORAGE_MB) MB"
                    )

                    LazyVStack(spacing: 14) {
                        ForEach(filteredBooks) { book in
                            BookCardView(
                                book: book,
                                onToggleRead: { toggleRead(bookID: book.id) },
                                onToggleFavorite: { toggleFavorite(bookID: book.id) }
                            )
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumUpsellSheetView()
                .environmentObject(subscription)
        }
    }

    private var background: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.06, green: 0.06, blue: 0.08),
                        Color(red: 0.03, green: 0.03, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
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

    private func toggleFavorite(bookID: UUID) {
        guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[idx].isFavorite.toggle()
    }
}
