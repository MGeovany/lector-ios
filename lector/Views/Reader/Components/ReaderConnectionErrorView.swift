import SwiftUI

struct ReaderConnectionErrorView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  var body: some View {
    VStack(spacing: 8) {
      Text("Server unavailable.")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.9))

      Text("Check your connection and try again.")
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.85))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
    .padding(.horizontal, 32)
  }
}
