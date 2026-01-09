import SwiftUI

struct FontChipView: View {
    let option: ReadingFont
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text(option.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            Text("Aa")
                .font(option.font(size: 18))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.55) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}
