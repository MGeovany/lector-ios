import SwiftUI

struct BookCardView: View {
    let book: Book
    let onToggleRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title.uppercased())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .lineLimit(2)

                    Text("\(book.author) • \(book.pagesTotal) pages • \(formatBytes(book.sizeBytes))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onToggleRead) {
                        Image(systemName: book.isRead ? "checkmark.circle" : "minus.circle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.45))
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button {
                            onToggleRead()
                        } label: {
                            Label(book.isRead ? "Mark as unread" : "Mark as read", systemImage: "checkmark")
                        }

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
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.45))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
            }

            HStack(spacing: 18) {
                Label("\(book.lastOpenedDaysAgo)w ago", systemImage: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))

                Label("Page \(book.currentPage) of \(book.pagesTotal)", systemImage: "book")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))

                Spacer()
            }

            ProgressBarView(progress: book.progress)

            Text("\(Int((book.progress * 100).rounded()))% read")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.70))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
        )
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

#Preview {
    BookCardView(
        book: Book(
            title: "Noches Blancas",
            author: "J.A.C.",
            pagesTotal: 32,
            currentPage: 14,
            sizeBytes: 157_400,
            lastOpenedDaysAgo: 14,
            isRead: false,
            tags: ["Book"]
        ),
        onToggleRead: {}
    )
    .padding()
    .background(Color.white)
}


