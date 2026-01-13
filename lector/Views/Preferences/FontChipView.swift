import SwiftUI

struct FontChipView: View {
    let option: ReadingFont
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.parkinsansBold(size: 14))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
                Text(option.subtitle)
                    .font(.parkinsansSemibold(size: 12))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
            }

            Spacer(minLength: 0)

            Text("Aa")
                .font(option.font(size: 18))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected
                        ? (colorScheme == .dark ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.55))
                        : (colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.6)),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }
}
