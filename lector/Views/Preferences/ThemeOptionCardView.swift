import SwiftUI

struct ThemeOptionCardView: View {
    let option: ReadingTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: option.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(option.accent)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(option.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text(option.subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer(minLength: 0)
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(option.surfaceBackground)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(option.surfaceSecondaryText)
                    Text("El lector busca calma.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(option.surfaceText)
                        .lineLimit(2)
                }
                .padding(10)
            }
            .frame(height: 74)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(option.surfaceText.opacity(0.10), lineWidth: 1)
            )
        }
        .padding(14)
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.55) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}
