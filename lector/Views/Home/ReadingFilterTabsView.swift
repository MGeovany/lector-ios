import SwiftUI

struct ReadingFilterTabsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var filter: ReadingFilter

    var body: some View {
        HStack(spacing: 10) {
            SegmentedTabButton(
                title: "Recents",
                isSelected: filter == .recents,
                onTap: { filter = .recents },
                colorScheme: colorScheme
            )

            SegmentedTabButton(
                title: "All",
                isSelected: filter == .all,
                onTap: { filter = .all },
                colorScheme: colorScheme
            )

            SegmentedTabButton(
                title: "Read",
                isSelected: filter == .read,
                onTap: { filter = .read },
                colorScheme: colorScheme
            )
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.35), lineWidth: 1)
                )
        )
    }
}

private struct SegmentedTabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.parkinsansSemibold(size: 14))
                .foregroundStyle(
                    isSelected
                    ? (colorScheme == .dark ? Color.black : .primary)
                    : (colorScheme == .dark ? Color.white.opacity(0.75) : Color.black.opacity(0.55))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isSelected
                            ? (colorScheme == .dark ? Color.white : Color(.systemBackground))
                            : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReadingFilterTabsView(filter: .constant(.all))
        .padding()
}


