import SwiftUI

struct ThemeOptionCardView: View {
  let option: ReadingTheme
  let isSelected: Bool
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: option.icon)
          .font(.parkinsansBold(size: CGFloat(16)))
          .foregroundStyle(option.accent)
          .frame(width: 26, height: 26)
          .background(
            Circle().fill(option.accent.opacity(0.15))
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.tr(option.title, locale: locale))
            .font(.parkinsansBold(size: CGFloat(14)))
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
          Text(L10n.tr(option.subtitle, locale: locale))
            .font(.parkinsansSemibold(size: CGFloat(12)))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
        }
        Spacer(minLength: 0)
      }

      ZStack(alignment: .bottomLeading) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(option.surfaceBackground)

        VStack(alignment: .leading, spacing: 4) {
          Text(L10n.tr("Preview", locale: locale))
            .font(.parkinsans(size: CGFloat(11), weight: .bold))
            .foregroundStyle(option.surfaceSecondaryText)
          Text(L10n.tr("Reading should feel calm.", locale: locale))
            .font(.parkinsans(size: CGFloat(13), weight: .semibold))
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
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          isSelected
            ? (colorScheme == .dark
              ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.55))
            : (colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5)),
          lineWidth: isSelected ? 1.5 : 1
        )
    )
  }
}
