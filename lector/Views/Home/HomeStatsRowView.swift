import SwiftUI

struct HomeStatsRowView: View {
    let documentsCount: Int
    let usedBytes: Int64
    let maxStorageText: String

    var body: some View {
        HStack(spacing: 22) {
            StatPill(title: "Documents:", value: "\(documentsCount)")
            StatPill(title: "Storage:", value: "\(formatBytes(usedBytes)) / \(maxStorageText)")
            Spacer()
        }
        .padding(.top, 2)
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

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.70))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.92))
        }
    }
}

#Preview {
    HomeStatsRowView(documentsCount: 1, usedBytes: 157_400, maxStorageText: "15.0 MB")
        .padding()
}


