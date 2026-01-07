import SwiftUI

struct ReadingFilterTabsView: View {
    @Binding var filter: ReadingFilter
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 10) {
            SegmentedTabButton(
                title: "Unread (\(unreadCount))",
                isSelected: filter == .unread,
                onTap: { filter = .unread }
            )

            SegmentedTabButton(
                title: "Read",
                isSelected: filter == .read,
                onTap: { filter = .read }
            )
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct SegmentedTabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.white : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReadingFilterTabsView(filter: .constant(.unread), unreadCount: 1)
        .padding()
}


