import SwiftUI

struct ReaderLoadingView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let title: String
  let subtitle: String

  init(
    title: String = "Loading your document",
    subtitle: String = "This usually takes a few seconds."
  ) {
    self.title = title
    self.subtitle = subtitle
  }

  var body: some View {
    VStack(spacing: 10) {
      ProgressView()
        .tint(preferences.theme.accent)
        .scaleEffect(1.1)
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
      Text(subtitle)
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }
}
