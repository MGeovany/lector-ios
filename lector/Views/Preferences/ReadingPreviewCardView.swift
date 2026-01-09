import SwiftUI

struct ReadingPreviewCardView: View {
  let theme: ReadingTheme
  let font: ReadingFont
  let fontSize: Double
  let lineSpacing: Double
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Preview")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
        Spacer()
        HStack(spacing: 8) {
          Image(systemName: theme.icon)
            .font(.system(size: 12, weight: .bold))
          Text("\(theme.title) • \(font.title) • \(Int(fontSize))pt")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
      }

      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(theme.surfaceBackground)

        VStack(alignment: .leading, spacing: 10) {
          Text("Capítulo 1")
            .font(font.font(size: 13))
            .foregroundStyle(theme.surfaceSecondaryText)

          Text(
            "Sometimes, the best way to read is to find a gentle rhythm: warm light, clear type, and a little space to breathe."
          )
          .font(font.font(size: fontSize))
          .foregroundStyle(theme.surfaceText)
          .lineSpacing(CGFloat(fontSize) * (lineSpacing - 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(height: 190)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(theme.surfaceText.opacity(0.10), lineWidth: 1)
      )
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(
          colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5),
          lineWidth: 1)
    )
  }
}
