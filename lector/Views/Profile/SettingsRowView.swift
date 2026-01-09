import SwiftUI

struct SettingsRowView: View {
    let icon: String
    let title: String
    var trailingText: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        List {
            Section("Account") {
                SettingsRowView(icon: "lock", title: "Password & Security")
                SettingsRowView(icon: "globe", title: "Language", trailingText: "English")
            }
        }
        .listStyle(.insetGrouped)
    }
}

