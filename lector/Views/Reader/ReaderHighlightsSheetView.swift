import SwiftUI

struct ReaderHighlightsSheetView: View {
  let book: Book
  @Binding var highlights: [RemoteHighlight]
  let onGoToHighlight: (RemoteHighlight) -> Void
  let onDeleteHighlight: (RemoteHighlight) async -> Void
  let onRefresh: () async -> Void

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var preferences: PreferencesViewModel

  @State private var shareItems: [Any] = []
  @State private var isShowingShareSheet: Bool = false
  @State private var deletingID: String? = nil

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        LazyVStack(alignment: .leading, spacing: 12) {
          if sortedHighlights.isEmpty {
            emptyState
              .padding(.top, 22)
          } else {
            ForEach(sortedHighlights) { h in
              HighlightRowView(
                highlight: h,
                book: book,
                onShare: { share(highlight: h) },
                onGoTo: {
                  onGoToHighlight(h)
                  dismiss()
                },
                onDelete: {
                  deletingID = h.id
                }
              )
              .opacity(deletingID == h.id ? 0.55 : 1)
              .animation(.spring(response: 0.25, dampingFraction: 0.9), value: deletingID)
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
      }
      .background(preferences.theme.surfaceBackground.ignoresSafeArea())
      .navigationTitle("Highlights")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
        }
      }
      .refreshable {
        await onRefresh()
      }
      .sheet(isPresented: $isShowingShareSheet) {
        ActivityShareSheet(items: shareItems)
      }
      .confirmationDialog(
        "Delete highlight?",
        isPresented: Binding(
          get: { deletingID != nil },
          set: { if !$0 { deletingID = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) {
          guard let id = deletingID else { return }
          guard let h = highlights.first(where: { $0.id == id }) else {
            deletingID = nil
            return
          }
          Task {
            await onDeleteHighlight(h)
            deletingID = nil
          }
        }
        Button("Cancel", role: .cancel) { deletingID = nil }
      } message: {
        Text("This will remove it from your highlights.")
      }
    }
  }

  private var sortedHighlights: [RemoteHighlight] {
    highlights.sorted { $0.createdAt > $1.createdAt }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "highlighter")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.6))

      Text("No highlights yet")
        .font(.parkinsansSemibold(size: 18))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))

      Text("Select text in the book and share it to create a highlight.")
        .font(.parkinsans(size: 14, weight: .medium))
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.8))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
  }

  private func share(highlight: RemoteHighlight) {
    var parts: [String] = []
    parts.append("“\(highlight.quote.trimmingCharacters(in: .whitespacesAndNewlines))”")
    parts.append("\(book.title) — \(book.author)")
    if let p = highlight.pageNumber {
      parts.append("Page \(p)")
    } else if let pr = highlight.progress {
      parts.append("\(Int((min(1, max(0, pr)) * 100).rounded()))%")
    }
    shareItems = [parts.joined(separator: "\n")]
    isShowingShareSheet = true
  }
}

private struct HighlightRowView: View {
  let highlight: RemoteHighlight
  let book: Book
  let onShare: () -> Void
  let onGoTo: () -> Void
  let onDelete: () -> Void

  @EnvironmentObject private var preferences: PreferencesViewModel
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d"
    return f
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("“\(highlight.quote.trimmingCharacters(in: .whitespacesAndNewlines))”")
        .font(.parkinsans(size: 15, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
        .lineLimit(6)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 10) {
        Text(metaText)
          .font(.parkinsans(size: 12, weight: .medium))
          .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.75))

        Spacer(minLength: 0)

        Button(action: onShare) {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(iconTint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share")

        Button(action: onGoTo) {
          Image(systemName: "arrow.turn.down.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(iconTint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to page")

        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(iconTint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
      }
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(preferences.theme.surfaceText.opacity(preferences.theme == .day ? 0.04 : 0.06))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
              preferences.theme.surfaceText.opacity(preferences.theme == .day ? 0.08 : 0.12),
              lineWidth: 1)
        )
    )
  }

  private var metaText: String {
    let dateText = Self.dateFormatter.string(from: highlight.createdAt)
    if let page = highlight.pageNumber {
      return "Page \(page) • \(dateText)"
    }
    if let progress = highlight.progress {
      return "\(Int((min(1, max(0, progress)) * 100).rounded()))% • \(dateText)"
    }
    return dateText
  }

  private var iconTint: Color {
    preferences.theme.surfaceSecondaryText.opacity(0.62)
  }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
