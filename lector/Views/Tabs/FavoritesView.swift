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
  @State private var viewModel = HomeViewModel()

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
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 14) {
        FavoritesHeaderView(filteredFavorites: filteredFavorites)
        FavoritesSearchBar(text: $query)
        if filteredFavorites.isEmpty {
          inlineEmptyState
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
  }

  private var inlineEmptyState: some View {
    VStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(
            colorScheme == .dark
              ? Color.white.opacity(0.10) : Color(.secondarySystemGroupedBackground)
          )
          .frame(width: 56, height: 56)
          .overlay(
            Circle()
              .stroke(
                colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5),
                lineWidth: 1)
          )

        Image(
          systemName: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "heart" : "magnifyingglass"
        )
        .font(.parkinsansSemibold(size: 22))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.90) : .secondary)
      }

      VStack(spacing: 4) {
        Text(
          query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No favorites yet" : "No matches"
        )
        .font(.parkinsansBold(size: 18))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : .primary)

        Text(
          query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Save books you love to find them faster here."
            : "Try a different search."
        )
        .font(.parkinsansSemibold(size: 14))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.60) : .secondary)
        .multilineTextAlignment(.center)
      }

      if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            query = ""
          }
        } label: {
          Label("Reset", systemImage: "arrow.counterclockwise")
            .font(.parkinsansSemibold(size: 15))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.90) : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
              Capsule(style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color(.systemBackground))
                .overlay(
                  Capsule(style: .continuous)
                    .stroke(
                      colorScheme == .dark
                        ? Color.white.opacity(0.14) : Color(.separator).opacity(0.5), lineWidth: 1)
                )
            )
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: 420)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
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
        .focused($isFocused)
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .submitLabel(.search)
        .font(.parkinsansSemibold(size: 15))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : .primary)

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
  FavoritesView()
}
