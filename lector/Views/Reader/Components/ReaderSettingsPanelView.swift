import SwiftUI

struct ReaderSettingsPanelView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let containerHeight: CGFloat
  @Binding var isPresented: Bool
  @Binding var dragOffset: CGFloat
  @Binding var isLocked: Bool
  @Binding var searchVisible: Bool
  @Binding var searchQuery: String

  // Local state for drag that doesn't trigger content re-renders
  @State private var localDragOffset: CGFloat = 0
  @State private var screen: Screen = .main
  @State private var fontPage: Int = 0

  private enum Screen {
    case main
    case textCustomize
  }

  var body: some View {
    VStack(spacing: 0) {
      if isPresented {
        VStack(spacing: 0) {
          header
          ScrollView {
            VStack(spacing: 14) {
              if screen == .main {
                mainSettings
              } else {
                textCustomizeSettings
              }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: containerHeight * 0.65)

        // .border(Color.red, width: 1)

        // TODO: Match to each theme's surfaceBackground
        .background(
          preferences.theme == .day
            ? Color(
              #colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1.0))
            : preferences.theme.surfaceBackground
        )
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .offset(y: max(0, localDragOffset))
        .animation(nil, value: localDragOffset)  // Disable animation during drag
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity, alignment: .bottom)
    .onChange(of: isPresented) { _, showing in
      if !showing {
        dragOffset = 0
        localDragOffset = 0
        screen = .main
        fontPage = 0
      } else {
        // Reset local offset when panel opens
        localDragOffset = 0
        screen = .main
        fontPage = 0
      }
    }
  }

  private var header: some View {
    VStack(spacing: 0) {
      Image(systemName: "chevron.down")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(
          Color(#colorLiteral(red: 207 / 255, green: 207 / 255, blue: 207 / 255, alpha: 1.0))
        )
        .frame(maxWidth: .infinity)
        .frame(height: 20)
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
            dragOffset = 0
          }
        }

      Text(screen == .main ? "Reader Settings" : "Text Customize")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(
          Color(#colorLiteral(red: 207 / 255, green: 207 / 255, blue: 207 / 255, alpha: 1.0))
        )
        .padding(.bottom, 20)
    }
    // .border(Color.red, width: 1)
    .contentShape(Rectangle())
    .highPriorityGesture(
      DragGesture(minimumDistance: 2)
        .onChanged { value in
          // Use translation directly for immediate response - it's more accurate for drag speed
          // Only allow dragging down (positive translation)
          if value.translation.height > 0 {
            // Update immediately without throttling for smooth, responsive drag
            localDragOffset = value.translation.height
          }
        }
        .onEnded { value in
          let finalOffset = localDragOffset

          let threshold: CGFloat = 100
          if finalOffset > threshold {
            // Sync with binding and close
            dragOffset = 0
            localDragOffset = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
              isPresented = false
            }
          } else {
            // Sync with binding and snap back
            dragOffset = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
              localDragOffset = 0
            }
          }
        }
    )
  }

  // MARK: - Main settings (image 1)

  private var mainSettings: some View {
    VStack(spacing: 14) {
      HStack(spacing: 12) {
        themeBar
          .frame(maxWidth: .infinity)

        circleAction(
          system: "waveform",
          title: "Voice",
          isEnabled: false,
          action: {}
        )
        .frame(width: 92)
      }

      HStack(spacing: 12) {
        textCustomizeCard
          .frame(width: 150, height: 150)

        VStack(spacing: 12) {
          circleAction(
            system: "magnifyingglass",
            title: "Search",
            isEnabled: true,
            action: {
              // Show search in reader content, close settings.
              searchVisible = true
              if searchQuery.isEmpty { searchQuery = "" }
              withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isPresented = false
              }
            }
          )

          circleAction(
            system: "sparkles",
            title: "Ask AI",
            isEnabled: false,
            action: {}
          )
        }
        .frame(maxWidth: .infinity)
      }

      HStack(spacing: 12) {
        circleAction(
          system: "wifi.slash",
          title: "Offline",
          isEnabled: false,
          action: {}
        )

        circleAction(
          system: isLocked ? "lock.fill" : "lock.open",
          title: "Lock",
          isEnabled: true,
          isSelected: isLocked,
          action: {
            isLocked.toggle()
            if isLocked {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isPresented = false
              }
            }
          }
        )

        pillAction(
          system: "textformat.size",
          title: "Text Size",
          value: "\(Int(preferences.fontSize.rounded()))",
          onMinus: { preferences.fontSize = max(14, preferences.fontSize - 1) },
          onPlus: { preferences.fontSize = min(26, preferences.fontSize + 1) }
        )
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var themeBar: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Theme")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)

      HStack(spacing: 10) {
        themeDot(title: "Light", theme: .day)
        themeDot(title: "Dark", theme: .night)
        themeDot(title: "Amber", theme: .amber)
      }
    }
    .padding(14)
    .background(cardBackground)
    .overlay(cardStroke)
  }

  private func themeDot(title: String, theme: ReadingTheme) -> some View {
    let isSelected = preferences.theme == theme
    return Button {
      withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
        preferences.theme = theme
      }
    } label: {
      VStack(spacing: 6) {
        Circle()
          .fill(isSelected ? preferences.theme.accent : preferences.theme.surfaceText.opacity(0.18))
          .frame(width: 10, height: 10)
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(isSelected ? 0.92 : 0.65))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(isSelected ? 0.08 : 0.04))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(
            isSelected
              ? preferences.theme.accent.opacity(0.35)
              : preferences.theme.surfaceText.opacity(0.06),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }

  private var textCustomizeCard: some View {
    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        screen = .textCustomize
      }
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "textformat.size")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))

        Spacer(minLength: 0)

        Text("Text")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))

        Text("Customize")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
      }
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(cardBackground)
      .overlay(cardStroke)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Text customize (image 2)

  private var textCustomizeSettings: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Select Font")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)

        TabView(selection: $fontPage) {
          fontPageView(fonts: [.system, .georgia, .palatino, .avenir])
            .tag(0)
          fontPageView(fonts: [.iowan, .menlo])
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        HStack(spacing: 6) {
          Circle()
            .fill(
              fontPage == 0
                ? preferences.theme.surfaceText.opacity(0.85)
                : preferences.theme.surfaceText.opacity(0.18)
            )
            .frame(width: 6, height: 6)
          Circle()
            .fill(
              fontPage == 1
                ? preferences.theme.surfaceText.opacity(0.85)
                : preferences.theme.surfaceText.opacity(0.18)
            )
            .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
      }

      pillAction(
        system: "textformat.size",
        title: "Font Size",
        value: "\(Int(preferences.fontSize.rounded()))",
        onMinus: { preferences.fontSize = max(14, preferences.fontSize - 1) },
        onPlus: { preferences.fontSize = min(26, preferences.fontSize + 1) }
      )

      textAlignmentCards

      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          screen = .main
        }
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
          Text("Back")
            .font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
          Capsule(style: .continuous)
            .fill(preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.10 : 0.06))
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

  private func fontPageView(fonts: [ReadingFont]) -> some View {
    HStack(spacing: 12) {
      ForEach(fonts) { f in
        fontCard(f)
      }
      // If page has only 2 fonts, fill remaining space to keep sizing consistent
      if fonts.count == 2 {
        Spacer(minLength: 0)
      }
    }
    .padding(.vertical, 6)
  }

  private func fontCard(_ font: ReadingFont) -> some View {
    let isSelected = preferences.font == font
    return Button {
      withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
        preferences.font = font
      }
    } label: {
      VStack(spacing: 6) {
        Text("Aa")
          .font(font.font(size: 30))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))

        Text(font.title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
      }
      .frame(width: 86, height: 74)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(isSelected ? 0.08 : 0.04))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(
            isSelected
              ? preferences.theme.accent.opacity(0.45)
              : preferences.theme.surfaceText.opacity(0.08),
            lineWidth: 2
          )
      )
    }
    .buttonStyle(.plain)
  }

  private var textAlignmentCards: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Text Alignment")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)

      HStack(spacing: 12) {
        alignmentCard(
          title: "Default",
          description: "Text lines up on the left.",
          value: .default
        )
        alignmentCard(
          title: "Justify",
          description: "Text spreads evenly across lines.",
          value: .justify
        )
      }
    }
  }

  private func alignmentCard(
    title: String,
    description: String,
    value: ReadingTextAlignment
  ) -> some View {
    let isSelected = preferences.textAlignment == value
    return Button {
      withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
        preferences.textAlignment = value
      }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          Spacer()
          Image(systemName: "line.3.horizontal.decrease")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceSecondaryText)
        }

        Text(description)
          .font(.system(size: 11, weight: .regular))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(isSelected ? 0.10 : 0.04))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(
            isSelected
              ? preferences.theme.accent.opacity(0.45)
              : preferences.theme.surfaceText.opacity(0.08),
            lineWidth: 2
          )
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Small building blocks

  private func circleAction(
    system: String,
    title: String,
    isEnabled: Bool,
    isSelected: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: system)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(isEnabled ? 0.90 : 0.25))
          .frame(width: 54, height: 54)
          .background(
            Circle()
              .fill(preferences.theme.surfaceText.opacity(isSelected ? 0.10 : 0.06))
          )
          .overlay(
            Circle()
              .stroke(preferences.theme.surfaceText.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
          )
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(isEnabled ? 1 : 0.35))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(cardBackground)
      .overlay(cardStroke)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }

  private func pillAction(
    system: String,
    title: String,
    value: String,
    onMinus: @escaping () -> Void,
    onPlus: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: system)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.70))

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
        Text(value)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.92))
          .monospacedDigit()
      }

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        iconCircle(system: "minus", action: onMinus)
        iconCircle(system: "plus", action: onPlus)
      }
    }
    .padding(14)
    .background(cardBackground)
    .overlay(cardStroke)
  }

  private func iconCircle(system: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.88))
        .frame(width: 32, height: 32)
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

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
      .fill(preferences.theme == .night ? Color.white.opacity(0.06) : Color.white.opacity(0.92))
  }

  private var cardStroke: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
      .stroke(
        preferences.theme == .night ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
        lineWidth: 1
      )
  }
}
