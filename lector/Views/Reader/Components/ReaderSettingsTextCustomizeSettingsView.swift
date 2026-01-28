import SwiftUI

struct ReaderSettingsTextCustomizeSettingsView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  @Binding var screen: ReaderSettingsPanelScreen

  var body: some View {
    VStack(spacing: 16) {
      ReaderSettingsDebugBoxView(title: "Text Customize Screen")
        .frame(maxWidth: .infinity)
        .frame(height: 220)

      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          screen = .main
        }
      } label: {
        Text("Back")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          .padding(.horizontal, 18)
          .padding(.vertical, 12)
          .background(
            Capsule(style: .continuous)
              .fill(
                preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.10 : 0.06))
          )
          .overlay(
            Capsule(style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.12), lineWidth: 1)
          )
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.plain)
      .padding(.top, 6)
    }
  }
}
