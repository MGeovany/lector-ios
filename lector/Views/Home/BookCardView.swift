import SwiftUI

struct BookCardView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(HomeViewModel.self) private var homeViewModel
  @StateObject private var networkMonitor = NetworkMonitor.shared
  let book: Book
  let onOpen: () -> Void
  let onToggleRead: () -> Void
  let onToggleFavorite: () -> Void
  @State private var isShowingCreateTag: Bool = false
  @State private var newTagName: String = ""
  @State private var isShowingEditDetails: Bool = false
  @State private var isShowingDeleteConfirm: Bool = false

  var body: some View {
    let documentKey = BookCardColorStore.documentKey(for: book)
    let backgroundColor = BookCardColorStore.get(for: documentKey).color(for: colorScheme)

    let isOfflineBlocked: Bool = {
      // When offline, only allow opening books that have a local optimized copy.
      guard !networkMonitor.isOnline else { return false }
      guard let remoteID = book.remoteID, !remoteID.isEmpty else { return false }
      return !OptimizedPagesStore.hasLocalCopy(remoteID: remoteID)
    }()

    let isPendingUpload: Bool = {
      // Local-only placeholder for queued uploads.
      return book.remoteID == nil && book.author == "Queued"
    }()

    let tagText: String? =
      (book.tags.first?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      }

    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 14) {
        // cover

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            if let tagText {
              Text(tagText)
                .font(.parkinsans(size: 12))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.65) : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                  Capsule(style: .continuous)
                    .fill(
                      colorScheme == .dark
                        ? Color.white.opacity(0.10) : Color(.secondarySystemBackground))
                )
            }

            if isPendingUpload {
              offlineBadge(text: "Queued", systemImage: "clock")
            } else if !networkMonitor.isOnline {
              if let remoteID = book.remoteID, !remoteID.isEmpty,
                OptimizedPagesStore.hasLocalCopy(remoteID: remoteID)
              {
                offlineBadge(text: "Offline", systemImage: "wifi")
              } else {
                offlineBadge(text: "Not offline", systemImage: "wifi.slash")
              }
            }
          }
          .padding(.bottom, 2)

          Text(book.title.uppercased())
            .font(.parkinsansMedium(size: 42))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : .primary)
            .lineLimit(2)

          Text(book.author)
            .font(.parkinsans(size: 20))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.30) : .secondary)
            .padding(.bottom, 3)

          HStack(spacing: 6) {

            Label(
              "\(book.lastOpenedDisplayText) | ",
              systemImage: "calendar"
            )
            .font(.parkinsans(size: 13))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

            Label("\(book.currentPage) of \(book.pagesTotal)", systemImage: "book")
              .font(.parkinsans(size: 13))
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

          }
        }

        Spacer()

        HStack(spacing: 2) {
          Button(action: onToggleFavorite) {
            Image(systemName: book.isFavorite ? "heart.fill" : "heart")
              .font(.parkinsansMedium(size: 16))
              .foregroundStyle(
                book.isFavorite
                  ? Color.red.opacity(0.90)
                  : (colorScheme == .dark ? Color.white.opacity(0.70) : .secondary)
              )
              .frame(width: 36, height: 36)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(book.isFavorite ? "Remove from favorites" : "Add to favorites")

          Menu {
            Button(action: onToggleRead) {
              Label(book.isRead ? "Mark as unread" : "Mark as read", systemImage: "checkmark")
            }

            Divider()

            Button {
              isShowingEditDetails = true
            } label: {
              Label("Edit details", systemImage: "square.and.pencil")
            }

            Divider()

            Menu {
              if !book.tags.isEmpty {
                ForEach(book.tags, id: \.self) { tag in
                  Label(tag, systemImage: "tag")
                }
                Divider()
              }

              ForEach(homeViewModel.availableTags, id: \.self) { tag in
                Button {
                  Task { await homeViewModel.setTag(bookID: book.id, tag: tag) }
                } label: {
                  if book.tags.contains(tag) {
                    Label(tag, systemImage: "checkmark")
                  } else {
                    Label(tag, systemImage: "tag")
                  }
                }
              }

              if !homeViewModel.availableTags.isEmpty {
                Divider()
                Menu {
                  ForEach(homeViewModel.availableTags, id: \.self) { tag in
                    Button {
                      Task { await homeViewModel.deleteTag(name: tag) }
                    } label: {
                      Label(tag, systemImage: "xmark")
                    }
                  }
                } label: {
                  Label("Delete tag", systemImage: "xmark")
                }
              }

              if !book.tags.isEmpty {
                Divider()
                Button(role: .destructive) {
                  Task { await homeViewModel.setTag(bookID: book.id, tag: "") }
                } label: {
                  Label("Clear tag", systemImage: "xmark")
                }
              }

              Divider()
              Button {
                newTagName = ""
                isShowingCreateTag = true
              } label: {
                Label("Create tag", systemImage: "plus")
              }
            } label: {
              Label("Tag", systemImage: "tag")
            }

            Divider()

            Button(role: .destructive) {
              isShowingDeleteConfirm = true
            } label: {
              Label("Delete", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis")
              .font(.parkinsans(size: 18))
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.70) : .secondary)
              .frame(width: 36, height: 36)
              .contentShape(Rectangle())
          }
        }
      }

      HStack(spacing: 14) {

        Text("Progress: \(Int((book.progress * 100).rounded()))%")
          .font(.parkinsans(size: 13))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
          .padding(.top, 10)

      }

      ProgressBarView(progress: book.progress)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(backgroundColor)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
              colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5),
              lineWidth: 1)
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .opacity(isOfflineBlocked ? 0.55 : 1)
    .onTapGesture {
      guard !isOfflineBlocked else { return }
      guard !isPendingUpload else { return }
      onOpen()
    }
    .onAppear {
      networkMonitor.startIfNeeded()
    }
    .alert("Create tag", isPresented: $isShowingCreateTag) {
      TextField("Tag name", text: $newTagName)
      Button("Cancel", role: .cancel) {
        newTagName = ""
      }
      Button("Create") {
        let name = newTagName
        newTagName = ""
        Task {
          await homeViewModel.createTag(name: name)
          let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmed.isEmpty {
            await homeViewModel.setTag(bookID: book.id, tag: trimmed)
          }
        }
      }
    } message: {
      Text("Create a new tag and assign it to this document.")
    }
    .sheet(isPresented: $isShowingEditDetails) {
      let initialColor = BookCardColorStore.get(for: documentKey)
      EditBookDetailsSheetView(
        colorScheme: colorScheme,
        availableTags: homeViewModel.availableTags,
        initialTitle: book.title,
        initialAuthor: book.author,
        initialTag: book.tags.first ?? "",
        initialColor: initialColor,
        onCancel: { isShowingEditDetails = false },
        onSave: { title, author, tag, color in
          BookCardColorStore.set(color, for: documentKey)
          isShowingEditDetails = false
          Task {
            await homeViewModel.updateBookDetails(
              bookID: book.id, title: title, author: author, tag: tag)
          }
        },
        onDeleteTag: { tagName in
          Task {
            await homeViewModel.deleteTag(name: tagName)
          }
        },
        onCreateTag: { tagName in
          Task {
            await homeViewModel.createTag(name: tagName)
            await homeViewModel.refreshTags()
          }
        }
      )
    }
    .alert("Delete this document?", isPresented: $isShowingDeleteConfirm) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        // Clear any per-document local UI state.
        BookCardColorStore.delete(for: documentKey)
        Task { await homeViewModel.deleteBook(bookID: book.id) }
      }
    } message: {
      Text("This will permanently delete it from your library.")
    }
  }

  private func offlineBadge(text: String, systemImage: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
      Text(text)
        .font(.parkinsans(size: 12))
    }
    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.55))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
  }

  /*   private var cover: some View {
      ZStack {
        let lightTint = AppColors.matteBlack
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                (colorScheme == .dark ? Color.white.opacity(0.18) : lightTint.opacity(0.18)),
                (colorScheme == .dark ? Color.white.opacity(0.06) : lightTint.opacity(0.06)),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(
                colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5),
                lineWidth: 1)
          )
  
        Text(initials(from: book.title))
          .font(.parkinsansBold(size: 16))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .primary)
      }
      .frame(width: 56, height: 72)
    } */

  private func initials(from title: String) -> String {
    let parts =
      title
      .split(separator: " ")
      .prefix(2)
      .map { String($0.prefix(1)).uppercased() }
    return parts.joined()
  }

  private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
  }
}
