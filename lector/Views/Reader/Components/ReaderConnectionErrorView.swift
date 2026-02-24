import SwiftUI

struct ReaderConnectionErrorView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  @Environment(\.locale) private var locale
  /// Optional detail message from the view model (e.g. "Can't connect", "Failed to process.", or ReaderViewModel.offlineNotAvailableErrorKey).
  var detailMessage: String?

  private var isOfflineNotAvailable: Bool {
    detailMessage == ReaderViewModel.offlineNotAvailableErrorKey
  }

  var body: some View {
    VStack(spacing: 8) {
      Text(isOfflineNotAvailable ? L10n.tr("ReaderConnectionError.offlineNotAvailable.title", locale: locale) : "Couldn't load document.")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.9))

      Text(isOfflineNotAvailable ? L10n.tr("ReaderConnectionError.offlineNotAvailable.detail", locale: locale) : (detailMessage ?? "Check your connection and try again."))
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.85))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
    .padding(.horizontal, 32)
  }
}
