import SwiftUI

struct ReaderTopBarView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let horizontalPadding: CGFloat
  @Binding var showReaderSettings: Bool
  let onShowHighlights: () -> Void
  let onBack: () -> Void

  private let iconButtonSize: CGFloat = 34

  private var isDarkTheme: Bool {
    preferences.theme == .night || preferences.theme == .amber
  }

  private var headerIconOpacity: Double {
    isDarkTheme ? 0.96 : 0.88
  }

  @ViewBuilder
  private func headerIconButton(
    accessibilityLabel: String,
    action: @escaping () -> Void,
    @ViewBuilder label: () -> some View
  ) -> some View {
    Button(action: action) {
      label()
        .frame(width: iconButtonSize, height: iconButtonSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }

  var body: some View {
    HStack(spacing: 8) {
      Button(action: onBack) {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
          .padding(8)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Back")

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
            .frame(width: 19, height: 19)
            .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
        }

        headerIconButton(accessibilityLabel: "Highlights", action: onShowHighlights) {
          Image(systemName: "bookmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
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
          Image(systemName: preferences.theme.icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
            .symbolEffect(.bounce, value: preferences.theme)
        }
      }
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, 6)
  }
}
