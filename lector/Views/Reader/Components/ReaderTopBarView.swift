import SwiftUI

struct ReaderTopBarView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let horizontalPadding: CGFloat
  @Binding var showReaderSettings: Bool
  let onShowHighlights: () -> Void
  let onBack: () -> Void

  private var isDarkTheme: Bool {
    preferences.theme == .night || preferences.theme == .amber
  }

  private var headerIconOpacity: Double {
    isDarkTheme ? 0.96 : 0.88
  }

  var body: some View {
    HStack(spacing: 10) {
      Button(action: onBack) {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
          .padding(8)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Back")

      Spacer(minLength: 0)

      HStack {
        Button {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showReaderSettings.toggle()
          }
        } label: {
          Image("TabSettings")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reader settings")

        Button(action: onShowHighlights) {
          Image(systemName: "bookmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
            .padding(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Highlights")

        Button {
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
        } label: {
          Image(systemName: preferences.theme.icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(headerIconOpacity))
            .padding(8)
            .symbolEffect(.bounce, value: preferences.theme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cycle theme")
      }
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, 6)
  }
}
