import SwiftUI

struct ReaderSettingsTextCustomizeSettingsView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  @Binding var screen: ReaderSettingsPanelScreen

  let onBack: () -> Void

  var body: some View {
    ReaderSettingsTextCustomizeView(
      selectedFont: $preferences.font, selectedTextAlignment: $preferences.textAlignment,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      onBack: onBack)
  }
}

struct ReaderSettingsTextCustomizeView: View {
  let gap: CGFloat = 14
  @Binding var selectedFont: ReadingFont
  @Binding var selectedTextAlignment: ReadingTextAlignment
  let surfaceText: Color
  let secondaryText: Color
  let onBack: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: gap) {
      SelectFontSection(
        selectedFont: $selectedFont,
        surfaceText: surfaceText,
        secondaryText: secondaryText
      )

      TextAlignmentSection(
        selected: $selectedTextAlignment,
        surfaceText: surfaceText,
        secondaryText: secondaryText
      )

      BackPillButton(
        title: "Back",
        surfaceText: surfaceText,
        onTap: {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
            onBack()
          }
        })

    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  private struct SelectFontSection: View {
    @Binding var selectedFont: ReadingFont
    let surfaceText: Color
    let secondaryText: Color
    @State private var page: Int = 0

    private let pages: [[ReadingFont?]] = [
      [.georgia, .system, .iowan, .avenir],
      [.palatino, .menlo, .baskerville, nil],
    ]

    private let pageInset: CGFloat = 14
    private let cardGap: CGFloat = 8
    private let cardCorner: CGFloat = 20
    private let cardMaxW: CGFloat = 500
    private let cardExtraH: CGFloat = 10

    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        Text("Select Font")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(secondaryText.opacity(0.85))

        GeometryReader { geo in
          let rawW = (geo.size.width - (pageInset * 2) - (cardGap * 3)) / 4
          let cardW = min(cardMaxW, rawW)
          let cardH = cardW + cardExtraH

          VStack(spacing: 8) {
            TabView(selection: $page) {
              ForEach(0..<pages.count, id: \.self) { idx in
                fontPage(slots: pages[idx], cardW: cardW, cardH: cardH)
                  .tag(idx)
              }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
              ForEach(0..<pages.count, id: \.self) { i in
                dot(isActive: page == i)
              }
            }
            .frame(maxWidth: .infinity)
          }
        }
        .frame(height: 136)
      }
    }

    private func fontPage(slots: [ReadingFont?], cardW: CGFloat, cardH: CGFloat) -> some View {
      HStack(spacing: cardGap) {
        ForEach(0..<4, id: \.self) { i in
          if let font = slots[i] {
            fontCard(font, w: cardW, h: cardH)
          } else {
            Color.clear
              .frame(width: cardW, height: cardH)
          }
        }
      }

      .padding(.horizontal, pageInset)
      .frame(maxWidth: .infinity, alignment: .leading)

    }

    private func fontCard(_ font: ReadingFont, w: CGFloat, h: CGFloat) -> some View {
      let isSelected = selectedFont == font

      return Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          selectedFont = font
        }
      } label: {
        VStack(spacing: 6) {
          Text("Aa")
            .font(font.font(size: max(20, w * 0.3)))
            .foregroundStyle(surfaceText.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

          Text(font.title)
            .font(font.font(size: 14))
            .foregroundStyle(secondaryText.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .frame(width: w, height: h)
        .background(
          RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .fill(surfaceText.opacity(0.06))
        )
        .overlay(
          RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .stroke(isSelected ? Color.accentColor.opacity(0.40) : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
      }
      .buttonStyle(.plain)
    }

    private func dot(isActive: Bool) -> some View {
      Circle()
        .fill(isActive ? surfaceText.opacity(0.85) : secondaryText.opacity(0.5))
        .frame(width: 6, height: 6)
    }
  }

  private struct TextAlignmentSection: View {
    @Binding var selected: ReadingTextAlignment

    let surfaceText: Color
    let secondaryText: Color

    private let cardCorner: CGFloat = 22
    private let cardH: CGFloat = 120
    private let gap: CGFloat = 12

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("Text Alignment")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(secondaryText.opacity(0.55))

        HStack(spacing: gap) {
          alignmentCard(.default)
          alignmentCard(.justify)
        }
      }
    }

    private func alignmentCard(_ option: ReadingTextAlignment) -> some View {
      let isSelected = selected == option

      return Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.90)) {
          selected = option
        }
      } label: {
        HStack(alignment: .top, spacing: 10) {
          VStack(alignment: .leading, spacing: 6) {
            Text(option.title)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(surfaceText.opacity(0.92))

            Text(option.subtitle)
              .font(.system(size: 12.5, weight: .regular))
              .foregroundStyle(secondaryText.opacity(0.55))
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }

          Spacer(minLength: 0)

          Image(systemName: option == .justify ? "text.justify" : "text.alignleft")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(secondaryText.opacity(0.55))
            .padding(.top, 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: cardH)
        .background(
          RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .fill(surfaceText.opacity(0.04))
        )
        .overlay(
          RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .stroke(isSelected ? Color.accentColor.opacity(0.40) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private struct BackPillButton: View {
    let title: String
    let surfaceText: Color
    let onTap: () -> Void

    private let h: CGFloat = 40

    var body: some View {
      Button(action: onTap) {
        HStack(spacing: 8) {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))

          Text(title)
            .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(surfaceText.opacity(0.9))
        .padding(.horizontal, 16)
        .frame(height: h)
        .background(surfaceText.opacity(0.04), in: Capsule())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.top, 10)
    }
  }

}
