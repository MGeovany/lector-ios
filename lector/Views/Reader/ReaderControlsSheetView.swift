import SwiftUI

/// Minimal, custom-styled reader controls sheet (doesn't reuse Preferences UI).
/// Keeps the Reader UI feeling modern/original while still using app preferences as state.
struct ReaderControlsSheetView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var preferences: PreferencesViewModel

  var body: some View {
    ZStack {
      background
        .ignoresSafeArea()

      VStack(spacing: 14) {
        handle

        header

        VStack(spacing: 12) {
          themeCard
          typographyCard
        }
        .padding(.horizontal, 18)

        Spacer(minLength: 6)
      }
      .padding(.top, 16)
      .padding(.bottom, 12)
    }
    .presentationDetents([.height(300)])
    .presentationDragIndicator(.hidden)
  }

  private var background: some View {
    ZStack {
      // Soft base
      preferences.theme.surfaceBackground
        .opacity(0.92)

      // Modern glow accents (subtle)
      RadialGradient(
        colors: [
          preferences.theme.accent.opacity(0.16),
          preferences.theme.accent.opacity(0.02),
          Color.clear,
        ],
        center: .topLeading,
        startRadius: 40,
        endRadius: 420
      )
      .blendMode(.plusLighter)

      LinearGradient(
        colors: [
          Color.white.opacity(preferences.theme == .night ? 0.06 : 0.10),
          Color.black.opacity(preferences.theme == .night ? 0.10 : 0.02),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .blendMode(.overlay)
    }
  }

  private var handle: some View {
    RoundedRectangle(cornerRadius: 99, style: .continuous)
      .fill(preferences.theme.surfaceText.opacity(0.12))
      .frame(width: 44, height: 5)
      .accessibilityHidden(true)
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Reading")
          .font(.parkinsansBold(size: CGFloat(18)))
          .foregroundStyle(preferences.theme.surfaceText)
          .padding(.top, 20)
        Text("Quick controls")
          .font(.parkinsansSemibold(size: CGFloat(12)))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
      }

      Spacer(minLength: 0)

      Button(action: dismiss.callAsFunction) {
        Image(systemName: "xmark")
          .font(.parkinsansBold(size: CGFloat(12)))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
          .frame(width: 32, height: 32)
          .background(
            Circle()
              .fill(preferences.theme.surfaceText.opacity(0.07))
          )
          .overlay(
            Circle()
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Close")
    }
    .padding(.horizontal, 18)
  }

  private var themeCard: some View {
    GlassCard {
      HStack(spacing: 10) {
        Image(systemName: preferences.theme.icon)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(preferences.theme.accent.opacity(0.95))

        Text("Theme")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))

        Spacer(minLength: 0)

        HStack(spacing: 8) {
          themeChip(.day, title: "Day")
          themeChip(.night, title: "Night")
          themeChip(.amber, title: "Amber")
        }
      }
    }
  }

  private var typographyCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 10) {
          Image(systemName: "textformat")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(preferences.theme.accent.opacity(0.95))
          Text("Typography")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))
          Spacer(minLength: 0)
        }

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(ReadingFont.allCases) { f in
              fontChip(f)
            }
          }
          .padding(.horizontal, 2)
        }

        HStack(spacing: 10) {
          stepperCapsule(
            title: "Size",
            value: "\(Int(preferences.fontSize.rounded()))",
            onMinus: { preferences.fontSize = max(14, preferences.fontSize - 1) },
            onPlus: { preferences.fontSize = min(26, preferences.fontSize + 1) }
          )

          stepperCapsule(
            title: "Line",
            value: String(format: "%.2f", preferences.lineSpacing),
            onMinus: { preferences.lineSpacing = max(0.95, preferences.lineSpacing - 0.05) },
            onPlus: { preferences.lineSpacing = min(1.45, preferences.lineSpacing + 0.05) }
          )
        }
      }
    }
  }

  private func themeChip(_ theme: ReadingTheme, title: String) -> some View {
    let isSelected = preferences.theme == theme
    return Button {
      withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
        preferences.theme = theme
      }
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(isSelected ? preferences.theme.accent : preferences.theme.surfaceText.opacity(0.18))
          .frame(width: 6, height: 6)
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(isSelected ? 0.92 : 0.70))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(isSelected ? 0.09 : 0.05))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(
            isSelected
              ? preferences.theme.accent.opacity(0.35)
              : preferences.theme.surfaceText.opacity(0.08),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }

  private func fontChip(_ font: ReadingFont) -> some View {
    let isSelected = preferences.font == font
    return Button {
      withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
        preferences.font = font
      }
    } label: {
      Text(font.title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(isSelected ? 0.92 : 0.70))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(preferences.theme.surfaceText.opacity(isSelected ? 0.09 : 0.05))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
              isSelected
                ? preferences.theme.accent.opacity(0.35)
                : preferences.theme.surfaceText.opacity(0.08),
              lineWidth: 1
            )
        )
    }
    .buttonStyle(.plain)
  }

  private func stepperCapsule(
    title: String, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 1) {
        Text(title.uppercased())
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
          .tracking(1.6)
        Text(value)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          .monospacedDigit()
      }

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        iconButton(system: "minus", action: onMinus)
        iconButton(system: "plus", action: onPlus)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(preferences.theme.surfaceText.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(preferences.theme.surfaceText.opacity(0.08), lineWidth: 1)
    )
  }

  private func iconButton(system: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.88))
        .frame(width: 30, height: 30)
        .background(
          Circle()
            .fill(preferences.theme.surfaceText.opacity(0.06))
        )
        .overlay(
          Circle()
            .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }
}

private struct GlassCard<Content: View>: View {
  @ViewBuilder let content: Content
  @EnvironmentObject private var preferences: PreferencesViewModel

  var body: some View {
    content
      .padding(14)
      .background {
        if preferences.theme == .night {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
        } else {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.92))
        }
      }
      .shadow(
        color: preferences.theme == .night ? Color.clear : Color.black.opacity(0.06),
        radius: 18,
        x: 0,
        y: 10
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(
            preferences.theme == .night ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
            lineWidth: 1
          )
      )
  }
}
