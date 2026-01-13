import SwiftUI

struct BookCardView: View {
  @Environment(\.colorScheme) private var colorScheme
  let book: Book
  let onOpen: () -> Void
  let onToggleRead: () -> Void
  let onToggleFavorite: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 14) {
        // cover

        VStack(alignment: .leading, spacing: 6) {
          Text(book.title.uppercased())
            .font(.parkinsansMedium(size: 42))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : .primary)
            .lineLimit(2)

          Text(book.author)
            .font(.parkinsansSemibold(size: 20))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.30) : .secondary)
            .padding(.bottom, 10)

          /*   Label(
            "\(book.lastOpenedDaysAgo)d ago • \(formatBytes(book.sizeBytes))",
            systemImage: "calendar"
          )
          .font(.parkinsansSemibold(size: 13))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
 */

          HStack(spacing: 6) {

            Label(
              "\(book.lastOpenedDaysAgo)d ago | ",
              systemImage: "calendar"
            )
            .font(.parkinsansSemibold(size: 13))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

            Label("\(book.currentPage) of \(book.pagesTotal)", systemImage: "book")
              .font(.parkinsansSemibold(size: 13))
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

          }
        }

        Spacer()

        HStack(spacing: 2) {
          Button(action: onToggleFavorite) {
            Image(systemName: book.isFavorite ? "heart.fill" : "heart")
              .font(.parkinsansSemibold(size: 16))
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
              // Mock action
            } label: {
              Label("Edit details", systemImage: "square.and.pencil")
            }

            Divider()

            Menu {
              ForEach(book.tags, id: \.self) { tag in
                Label(tag, systemImage: "tag")
              }

              Button {
                // Mock action
              } label: {
                Label("Create tag", systemImage: "plus")
              }
            } label: {
              Label("Tag", systemImage: "tag")
            }
          } label: {
            Image(systemName: "ellipsis")
              .font(.parkinsansSemibold(size: 18))
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.70) : .secondary)
              .frame(width: 36, height: 36)
              .contentShape(Rectangle())
          }
        }
      }

      HStack(spacing: 14) {
        /*   Label("Page \(book.currentPage) of \(book.pagesTotal)", systemImage: "book")
            .font(.parkinsansSemibold(size: 13))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
        
          Spacer() */

        Text("Progress: \(Int((book.progress * 100).rounded()))%")
          .font(.parkinsansBold(size: 13))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .primary)

      }

      ProgressBarView(progress: book.progress)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color(.systemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
              colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5),
              lineWidth: 1)
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .onTapGesture(perform: onOpen)
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
