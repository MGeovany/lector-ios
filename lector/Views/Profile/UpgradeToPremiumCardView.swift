import SwiftUI

struct UpgradeToPremiumCardView: View {
    let storageText: String
    let onUpgradeTapped: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Upgrade to Premium")
                .font(.parkinsansBold(size: 18))
                .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

            Text(storageText)
                .font(.parkinsans(size: 14, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.60) : .secondary)

            Button(action: onUpgradeTapped) {
                Text("Upgrade")
            }
            .buttonStyle(LectorPrimaryRoundedButtonStyle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        UpgradeToPremiumCardView(storageText: "250 MB storage", onUpgradeTapped: {})
            .padding()
    }
}

