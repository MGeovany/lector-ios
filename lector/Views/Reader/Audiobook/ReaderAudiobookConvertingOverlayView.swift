import SwiftUI

struct ReaderAudiobookConvertingOverlayView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  var body: some View {
    ZStack {
      preferences.theme.surfaceBackground
        .opacity(preferences.theme == .night ? 0.92 : 0.88)
        .ignoresSafeArea()

      VStack(spacing: 14) {
        ProgressView()
          .tint(preferences.theme.accent)
          .scaleEffect(1.1)

        Text("Your file is being converted to audiobook")
          .font(.parkinsansSemibold(size: 14))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 26)

        Text("This may take a few seconds")
          .font(.parkinsans(size: 12, weight: .regular))
          .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.85))
      }
      .padding(.vertical, 18)
      .padding(.horizontal, 18)
      .background {
        if preferences.theme == .night {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
        } else {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.92))
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(
            preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.14 : 0.10),
            lineWidth: 1)
      )
      .shadow(
        color: preferences.theme == .night ? Color.black.opacity(0.30) : Color.black.opacity(0.10),
        radius: 24,
        x: 0,
        y: 12
      )
      .padding(.horizontal, 24)
    }
    .transition(.opacity)
  }
}
