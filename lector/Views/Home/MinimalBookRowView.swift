import SwiftUI

struct MinimalBookRowView: View {
  let book: Book
  let onOpen: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
          Text(book.title)
            .font(.parkinsansMedium(size: 20))
            .foregroundStyle(titleColor)
            .lineLimit(2)

          Text(book.author)
            .font(.parkinsans(size: 15, weight: .regular))
            .foregroundStyle(subtitleColor)
            .lineLimit(1)

          Text("\(book.pagesTotal) pages")
            .font(.parkinsans(size: 13, weight: .medium))
            .foregroundStyle(subtitleColor.opacity(0.85))
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        Circle()
          .strokeBorder(borderColor, lineWidth: 1.25)
          .frame(width: 34, height: 34)
          .overlay(
            Image(systemName: "arrow.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(arrowColor)
          )
      }
      .padding(.vertical, 18)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(rowBackground)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(separatorColor)
          .frame(height: 1)
      }
    }
    .buttonStyle(.plain)
  }

  private var rowBackground: Color {
    // Keep it neutral; screen background can provide overall tint.
    colorScheme == .dark ? Color.black.opacity(0.10) : Color.clear
  }

  private var titleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack.opacity(0.92)
  }

  private var subtitleColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.55)
  }

  private var borderColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.22) : AppColors.matteBlack.opacity(0.35)
  }

  private var arrowColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.82) : AppColors.matteBlack.opacity(0.82)
  }

  private var separatorColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.10) : AppColors.matteBlack.opacity(0.85)
  }
}

#Preview("Minimal row") {
  let book = Book(
    title: "Grid Systems",
    author: "Josef Müller-Brockmann",
    pagesTotal: 384,
    currentPage: 1,
    sizeBytes: 0,
    lastOpenedDaysAgo: 0,
    isRead: false,
    isFavorite: false,
    tags: []
  )
  return VStack(spacing: 0) {
    MinimalBookRowView(book: book, onOpen: {})
    MinimalBookRowView(book: book, onOpen: {})
  }
  .padding(.top, 14)
}

