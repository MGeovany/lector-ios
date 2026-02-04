import SwiftUI

struct ReaderAudiobookControlsView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let isPlaying: Bool
  let progress: Double
  let pageLabel: String

  let onPreviousPage: () -> Void
  let onBack5: () -> Void
  let onPlayPause: () -> Void
  let onForward5: () -> Void
  let onNextPage: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      HStack(alignment: .center, spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Audiobook")
            .font(.parkinsansSemibold(size: 14))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))

          Text(pageLabel)
            .font(.parkinsans(size: 12, weight: .regular))
            .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.85))
        }

        Spacer(minLength: 0)

        controls
      }

      progressBar
    }
    .padding(14)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.14 : 0.10), lineWidth: 1)
    )
    .shadow(
      color: preferences.theme == .night ? Color.black.opacity(0.35) : Color.black.opacity(0.10),
      radius: 18,
      x: 0,
      y: 10
    )
  }

  private var background: some View {
    ZStack {
      if preferences.theme == .night {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(.ultraThinMaterial)
      } else {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color.white.opacity(0.95))
      }

      RadialGradient(
        colors: [
          preferences.theme.accent.opacity(preferences.theme == .night ? 0.18 : 0.12),
          Color.clear,
        ],
        center: .topLeading,
        startRadius: 30,
        endRadius: 240
      )
      .blendMode(.plusLighter)
      .allowsHitTesting(false)
    }
  }

  private var controls: some View {
    HStack(spacing: 10) {
      iconButton(system: "backward.end.fill", accessibility: "Previous page", action: onPreviousPage)
      iconButton(system: "gobackward.5", accessibility: "Back 5 seconds", action: onBack5)

      Button(action: onPlayPause) {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          .frame(width: 44, height: 44)
          .background(
            Circle()
              .fill(preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.14 : 0.08))
          )
          .overlay(
            Circle()
              .stroke(preferences.theme.surfaceText.opacity(0.14), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isPlaying ? "Pause" : "Play")

      iconButton(system: "goforward.5", accessibility: "Forward 5 seconds", action: onForward5)
      iconButton(system: "forward.end.fill", accessibility: "Next page", action: onNextPage)
    }
  }

  private func iconButton(system: String, accessibility: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
        .frame(width: 36, height: 36)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.10 : 0.06))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(preferences.theme.surfaceText.opacity(0.12), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibility)
  }

  private var progressBar: some View {
    GeometryReader { geo in
      let w = max(1, geo.size.width)
      let p = min(1.0, max(0.0, progress))

      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.10 : 0.08))
        Capsule(style: .continuous)
          .fill(preferences.theme.accent.opacity(0.95))
          .frame(width: CGFloat(p) * w)
      }
    }
    .frame(height: 6)
  }
}
