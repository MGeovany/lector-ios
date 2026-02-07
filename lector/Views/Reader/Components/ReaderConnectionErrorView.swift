import SwiftUI

struct ReaderConnectionErrorView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  /// Optional detail message from the view model (e.g. "Can't connect", "Failed to process.").
  var detailMessage: String?

  var body: some View {
    VStack(spacing: 8) {
      Text("Couldn't load document.")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.9))

      Text(detailMessage ?? "Check your connection and try again.")
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.85))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
    .padding(.horizontal, 32)
  }
}
