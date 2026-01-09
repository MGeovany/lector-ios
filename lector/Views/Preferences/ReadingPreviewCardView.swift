import SwiftUI

struct ReadingPreviewCardView: View {
    let theme: ReadingTheme
    let font: ReadingFont
    let fontSize: Double
    let lineSpacing: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 12, weight: .bold))
                    Text("\(theme.title) • \(font.title) • \(Int(fontSize))pt")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.55))
            }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Capítulo 1")
                            .font(font.font(size: 13))
                            .foregroundStyle(theme.surfaceSecondaryText)

                        Text("A veces, el mejor modo de leer es encontrar un ritmo suave: una luz amable, una tipografía clara y un espacio que respire.")
                            .font(font.font(size: fontSize))
                            .foregroundStyle(theme.surfaceText)
                            .lineSpacing(CGFloat(fontSize) * (lineSpacing - 1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.surfaceText.opacity(0.10), lineWidth: 1)
                )
                .frame(height: 190)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
