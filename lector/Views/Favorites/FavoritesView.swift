//
//  favoritesView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct FavoritesView: View {
    @State private var query: String = ""

    // Mock favorites for now (UX-focused). Replace with persistence later.
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
            title: "Meditations",
            author: "Marcus Aurelius",
            pagesTotal: 256,
            currentPage: 128,
            sizeBytes: 1_542_300,
            lastOpenedDaysAgo: 2,
            isRead: false,
            isFavorite: true,
            tags: ["Philosophy"]
        ),
        Book(
            title: "The Pragmatic Programmer",
            author: "Andrew Hunt",
            pagesTotal: 352,
            currentPage: 352,
            sizeBytes: 2_320_100,
            lastOpenedDaysAgo: 30,
            isRead: true,
            isFavorite: true,
            tags: ["Dev"]
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                background

                Group {
                    if filteredFavorites.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.06, green: 0.06, blue: 0.08),
                Color(red: 0.03, green: 0.03, blue: 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                FavoritesHeaderView(filteredFavorites: filteredFavorites)
                FavoritesSearchBar(text: $query)
                LazyVStack(spacing: 14) {
                    ForEach(filteredFavorites) { book in
                        BookCardView(
                            book: book,
                            onToggleRead: { toggleRead(bookID: book.id) },
                            onToggleFavorite: { toggleFavorite(bookID: book.id) }
                        )
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
    
   


    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Image(systemName: "heart")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
            }

            VStack(spacing: 6) {
                Text("No favorites yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Text(query.isEmpty ? "Save books you love to find them faster here." : "No matches. Try a different search.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)

            if !query.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        query = ""
                    }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }

    private var filteredFavorites: [Book] {
        let favoritesOnly = books.filter { $0.isFavorite }

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

    private func toggleRead(bookID: UUID) {
        guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[idx].isRead.toggle()
    }

    private func toggleFavorite(bookID: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            guard let idx = books.firstIndex(where: { $0.id == bookID }) else { return }
            books[idx].isFavorite.toggle()
        }
    }
}

private struct FavoritesSearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))

            TextField("Search favorites", text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
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
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { isFocused = true }
        .accessibilityLabel("Search favorites")
    }
}


#Preview{
    FavoritesView()
}
