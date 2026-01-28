import SwiftUI

struct ReaderLoadingView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  var body: some View {
    VStack(spacing: 10) {
      ProgressView()
        .tint(preferences.theme.accent)
        .scaleEffect(1.1)
      Text("Loading your document")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
      Text("This usually takes a few seconds.")
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
    }
    .frame(maxWidth: .infinity)
  }
}
