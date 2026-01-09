import SwiftUI

struct UpgradeToPremiumCardView: View {
    let storageText: String
    let onUpgradeTapped: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let buttonFill = AppColors.primaryButtonFill(for: colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color(.secondarySystemBackground))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5), lineWidth: 1)
                        )

                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Upgrade to Premium")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("PREMIUM")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(buttonFill, in: Capsule(style: .continuous))
                    }

                    Text("More storage for your library.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Label(storageText, systemImage: "externaldrive.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("Cancel anytime")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
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
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(buttonFill)
                )
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12), radius: 14, x: 0, y: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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

