import SwiftUI

struct UpgradeToPremiumCardView: View {
    let storageText: String
    let onUpgradeTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("Upgrade to")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("PREMIUM")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor, in: Capsule(style: .continuous))

                Spacer()
            }

            Text("Get more storage for your library.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(storageText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button(action: onUpgradeTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Upgrade")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
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

