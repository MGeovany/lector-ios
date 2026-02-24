import SwiftUI

private struct ReaderBarButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1.0)
      .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
  }
}

struct ReaderTopBarView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let horizontalPadding: CGFloat
  @Binding var showReaderSettings: Bool
  let onShowHighlights: () -> Void
  let onBack: () -> Void

  private static let touchTarget: CGFloat = 28
  private static let cornerRadius: CGFloat = 8
  private static let iconGraphicSize: CGFloat = 12

  private var isDarkTheme: Bool {
    preferences.theme == .night || preferences.theme == .amber
  }

  private var headerIconOpacity: Double {
    isDarkTheme ? 0.96 : 0.88
  }

  private var iconTint: Color {
    preferences.theme.surfaceText.opacity(headerIconOpacity)
  }

  private var chromeFill: Color {
    preferences.theme.surfaceText.opacity(preferences.theme == .day ? 0.06 : 0.12)
  }

  @ViewBuilder
  private func headerIconButton(
    accessibilityLabel: String,
    action: @escaping () -> Void,
    @ViewBuilder label: () -> some View
  ) -> some View {
    Button(action: action) {
      label()
        .frame(width: Self.touchTarget, height: Self.touchTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(ReaderBarButtonStyle())
    .background(chromeFill, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    .accessibilityLabel(accessibilityLabel)
  }

  var body: some View {
    HStack(spacing: 6) {
      headerIconButton(accessibilityLabel: "Back", action: onBack) {
        Image(systemName: "chevron.left")
          .font(.system(size: Self.iconGraphicSize, weight: .semibold))
          .foregroundStyle(iconTint)
      }

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        headerIconButton(accessibilityLabel: "Reader settings", action: {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showReaderSettings.toggle()
          }
        }) {
          Image("TabSettings")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.iconGraphicSize, height: Self.iconGraphicSize)
            .foregroundStyle(iconTint)
        }

        headerIconButton(accessibilityLabel: "Highlights", action: onShowHighlights) {
          Image(systemName: "bookmark")
            .font(.system(size: Self.iconGraphicSize, weight: .semibold))
            .foregroundStyle(iconTint)
        }

        headerIconButton(accessibilityLabel: "Cycle theme", action: {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            switch preferences.theme {
            case .day:
              preferences.theme = .night
            case .night:
              preferences.theme = .amber
            case .amber:
              preferences.theme = .day
            }
          }
        }) {
          let base = Image(systemName: preferences.theme.icon)
            .font(.system(size: Self.iconGraphicSize, weight: .semibold))
            .foregroundStyle(iconTint)

          if reduceMotion {
            base
          } else {
            base.symbolEffect(.bounce, value: preferences.theme)
          }
        }
      }
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, 6)
  }
}
