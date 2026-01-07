import SwiftUI

struct ReadingFilterTabsView: View {
    @Binding var filter: ReadingFilter
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 26) {
            FilterTabButton(
                title: "Unread (\(unreadCount))",
                isSelected: filter == .unread,
                onTap: { filter = .unread }
            )

            FilterTabButton(
                title: "Read",
                isSelected: filter == .read,
                onTap: { filter = .read }
            )

            Spacer()
        }
        .padding(.top, 4)
    }
}

private struct FilterTabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.92 : 0.55))

                Rectangle()
                    .fill(isSelected ? Color.black : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReadingFilterTabsView(filter: .constant(.unread), unreadCount: 1)
        .padding()
}


