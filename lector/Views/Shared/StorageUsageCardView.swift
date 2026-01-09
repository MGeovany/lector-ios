import SwiftUI

struct StorageUsageCardView: View {
    let usedBytes: Int64
    let maxBytes: Int64
    let isPremium: Bool
    let onUpgradeTapped: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard maxBytes > 0 else { return 0 }
        return min(1.0, max(0.0, Double(usedBytes) / Double(maxBytes)))
    }

    private var percentText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    private var usedText: String {
        formatBytes(usedBytes)
    }

    private var maxText: String {
        ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("\(usedText) / \(maxText)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                if isPremium {
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                                )
                        )
                } else if let onUpgradeTapped {
                    Button(action: onUpgradeTapped) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10, weight: .heavy))
                            Text("Go Premium")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderless)
                    .background(AppColors.primaryButtonFill(for: colorScheme), in: Capsule(style: .continuous))
                }
            }

            ProgressBarView(progress: progress)
                .frame(height: 9)

            HStack(spacing: 6) {
                Text("\(percentText) used")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(isPremium ? "More space" : "Upgrade to extend storage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
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
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 12) {
            StorageUsageCardView(
                usedBytes: 7 * 1024 * 1024,
                maxBytes: 15 * 1024 * 1024,
                isPremium: false,
                onUpgradeTapped: {}
            )
            StorageUsageCardView(
                usedBytes: 73 * 1024 * 1024,
                maxBytes: 250 * 1024 * 1024,
                isPremium: true,
                onUpgradeTapped: nil
            )
        }
        .padding()
    }
}

