import SwiftUI

struct SettingsRowView: View {
  let icon: String
  let title: String
  var trailingText: String? = nil
  var showsChevron: Bool = true

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.parkinsansSemibold(size: CGFloat(14)))
        .foregroundStyle(.secondary)
        .frame(width: 28, height: 28)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.secondarySystemBackground))
        )

      Text(LocalizedStringKey(title))
        .font(.parkinsans(size: CGFloat(15), weight: .regular))
        .foregroundStyle(.primary)

      Spacer()

      if let trailingText, !trailingText.isEmpty {
        Text(trailingText)
          .font(.parkinsans(size: CGFloat(13), weight: .regular))
          .foregroundStyle(.secondary)
      }

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.parkinsans(size: CGFloat(12), weight: .semibold))
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
