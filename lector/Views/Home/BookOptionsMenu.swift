import SwiftUI

struct BookOptionsMenu: View {
  let book: Book
  @Environment(\.colorScheme) private var colorScheme
  @Environment(HomeViewModel.self) private var viewModel

  @State private var isShowingCreateTag: Bool = false
  @State private var newTagName: String = ""
  @State private var isShowingEditDetails: Bool = false
  @State private var isShowingDeleteConfirm: Bool = false

  var body: some View {
    Menu {
      Button {
        viewModel.toggleFavorite(bookID: book.id)
      } label: {
        Label(book.isFavorite ? "Remove from favorites" : "Add to favorites",
              systemImage: book.isFavorite ? "heart.fill" : "heart")
      }

      Button {
        viewModel.toggleRead(bookID: book.id)
      } label: {
        Label(book.isRead ? "Mark as incomplete" : "Mark as complete", systemImage: "checkmark")
      }

      Divider()

      Button {
        isShowingEditDetails = true
      } label: {
        Label("Edit details", systemImage: "square.and.pencil")
      }

      Divider()

      tagMenu

      Divider()

      Button(role: .destructive) {
        isShowingDeleteConfirm = true
      } label: {
        Label("Delete", systemImage: "trash")
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(iconColor)
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
        .accessibilityLabel("Options")
    }
    .buttonStyle(.plain)
    .alert("Create tag", isPresented: $isShowingCreateTag) {
      TextField("Tag name", text: $newTagName)
      Button("Cancel", role: .cancel) { newTagName = "" }
      Button("Create") {
        let name = newTagName
        newTagName = ""
        Task {
          await viewModel.createTag(name: name)
          let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmed.isEmpty {
            await viewModel.setTag(bookID: book.id, tag: trimmed)
          }
        }
      }
    } message: {
      Text("Create a new tag and assign it to this document.")
    }
    .sheet(isPresented: $isShowingEditDetails) {
      EditBookDetailsSheetView(
        colorScheme: colorScheme,
        availableTags: viewModel.availableTags,
        initialTitle: book.title,
        initialAuthor: book.author,
        initialTag: book.tags.first ?? "",
        onCancel: { isShowingEditDetails = false },
        onSave: { title, author, tag in
          isShowingEditDetails = false
          Task {
            await viewModel.updateBookDetails(
              bookID: book.id, title: title, author: author, tag: tag
            )
          }
        },
        onDeleteTag: { tagName in
          Task { await viewModel.deleteTag(name: tagName) }
        },
        onCreateTag: { tagName in
          Task {
            await viewModel.createTag(name: tagName)
            await viewModel.refreshTags()
          }
        }
      )
    }
    .alert("Delete this document?", isPresented: $isShowingDeleteConfirm) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteBook(bookID: book.id) }
      }
    } message: {
      Text("This will permanently delete it from your library.")
    }
  }

  private var tagMenu: some View {
    Menu {
      if !book.tags.isEmpty {
        ForEach(book.tags, id: \.self) { tag in
          Label(tag, systemImage: "tag")
        }
        Divider()
      }

      ForEach(viewModel.availableTags, id: \.self) { tag in
        Button {
          Task { await viewModel.setTag(bookID: book.id, tag: tag) }
        } label: {
          if book.tags.contains(tag) {
            Label(tag, systemImage: "checkmark")
          } else {
            Label(tag, systemImage: "tag")
          }
        }
      }

      if !viewModel.availableTags.isEmpty {
        Divider()
        Menu {
          ForEach(viewModel.availableTags, id: \.self) { tag in
            Button {
              Task { await viewModel.deleteTag(name: tag) }
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
          Task { await viewModel.setTag(bookID: book.id, tag: "") }
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
  }

  private var iconColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.70) : AppColors.matteBlack.opacity(0.70)
  }
}

