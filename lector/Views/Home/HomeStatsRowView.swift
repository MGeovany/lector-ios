import SwiftUI

struct HomeStatsRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let documentsCount: Int
    let usedBytes: Int64
    let maxStorageText: String

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "doc.text",
                title: "Documents",
                value: "\(documentsCount)",
                colorScheme: colorScheme
            )

            StatCard(
                icon: "externaldrive",
                title: "Storage",
                value: "\(formatBytes(usedBytes)) / \(maxStorageText)",
                colorScheme: colorScheme
            )
        }
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

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.parkinsansSemibold(size: 14))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.parkinsansSemibold(size: 12))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

                Text(value)
                    .font(.parkinsansSemibold(size: 14))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.90) : .primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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

