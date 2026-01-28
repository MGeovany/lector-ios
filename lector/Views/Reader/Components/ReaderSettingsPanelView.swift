import SwiftUI

struct ReaderSettingsPanelView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let containerHeight: CGFloat
  @Binding var isPresented: Bool
  @Binding var dragOffset: CGFloat
  @Binding var isLocked: Bool
  @Binding var searchVisible: Bool
  @Binding var searchQuery: String

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
        .frame(height: containerHeight * 0.55)
        .background(
          preferences.theme == .day
            ? Color(
              #colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1.0))
            : preferences.theme == .night
              ? Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0)
              : preferences.theme.surfaceBackground
        )
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .offset(y: max(0, localDragOffset))
        .animation(nil, value: localDragOffset)
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
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.40))
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
        .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(0.40))
        .padding(.bottom, 20)
    }
    .contentShape(Rectangle())
    .highPriorityGesture(
      DragGesture(minimumDistance: 2)
        .onChanged { value in
          if value.translation.height > 0 {
            localDragOffset = value.translation.height
          }
        }
        .onEnded { _ in
          let finalOffset = localDragOffset
          let threshold: CGFloat = 100

          if finalOffset > threshold {
            dragOffset = 0
            localDragOffset = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
              isPresented = false
            }
          } else {
            dragOffset = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
              localDragOffset = 0
            }
          }
        }
    )
  }

  private var mainSettings: some View {
    let gap: CGFloat = 16

    let themeH: CGFloat = 80
    let searchH: CGFloat = 80
    let tallH: CGFloat = 140
    let bottomH: CGFloat = 80
    let textH: CGFloat = searchH + tallH - bottomH

    let totalH: CGFloat = themeH + gap + searchH + gap + tallH

    return GeometryReader { geo in
      let totalW = geo.size.width
      let leftW = (totalW - gap) * 0.80
      let rightW = (totalW - gap) * 0.20

      let searchColW = rightW
      let textColW = leftW - gap - searchColW

      HStack(alignment: .top, spacing: gap) {
        VStack(spacing: gap) {
          themePill
            .frame(height: themeH)

          HStack(alignment: .top, spacing: gap) {
            VStack(spacing: gap) {
              textTile
                .frame(height: textH)

              HStack(spacing: gap) {
                offlineTile
                  .frame(maxWidth: .infinity)
                  .frame(height: bottomH)

                lockTile
                  .frame(maxWidth: .infinity)
                  .frame(height: bottomH)
              }
            }
            .frame(width: textColW)

            VStack(spacing: gap) {
              searchTile
                .frame(height: searchH)

              debugBox("Text Size")
                .frame(height: tallH)
            }
            .frame(width: searchColW)
          }
        }
        .frame(width: leftW)

        VStack(spacing: gap) {
          voiceTile
            .frame(height: themeH)

          askAiTile
            .frame(height: searchH)

          debugBox("Brightness")
            .frame(height: tallH)
        }
        .frame(width: rightW)
      }
    }
    .frame(height: totalH)
  }

  private func debugBox(_ title: String) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.blue, lineWidth: 3)

      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color.blue)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }
  }

  private var textCustomizeSettings: some View {
    VStack(spacing: 16) {
      debugBox("Text Customize Screen")
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

  /*
  * Theme Pill
  */
  private var themePill: some View {
    ThemePill(
      selected: Binding(
        get: { preferences.theme },
        set: { newTheme in
          withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
            preferences.theme = newTheme
          }
        }), surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      onEdit: {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { screen = .textCustomize }
      })
  }
  private struct ThemePill: View {
    @Binding var selected: ReadingTheme

    let surfaceText: Color
    let secondaryText: Color
    let onEdit: () -> Void

    private let pillH: CGFloat = 54
    private let chipSize: CGFloat = 44
    private let dotSize: CGFloat = 16
    private let sidePadding: CGFloat = 14

    var body: some View {
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(surfaceText.opacity(0.06))

          GeometryReader { geo in
            let w = geo.size.width
            let leftX = sidePadding + chipSize / 2
            let rightX = w - sidePadding - chipSize / 2
            let midX = w / 2
            let chipX: CGFloat = {
              switch selected {
              case .day: return leftX
              case .amber: return midX
              case .night: return rightX
              }
            }()

            ZStack {
              HStack {
                dotButton(theme: .day)
                Spacer(minLength: 0)
                dotButton(theme: .amber)
                Spacer(minLength: 0)
                dotButton(theme: .night)
              }
              .padding(.horizontal, sidePadding)

              chip(theme: selected)
                .position(x: chipX, y: pillH / 2)
                .animation(.spring(response: 0.30, dampingFraction: 0.80), value: selected)
            }
          }
        }
        .frame(height: pillH)

        Text("Theme")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(secondaryText.opacity(0.40))
      }
    }

    private func chip(theme: ReadingTheme) -> some View {
      ZStack {
        Circle()
          .fill(themeColor(theme).opacity(0.88))
          .frame(width: 90, height: chipSize)
          .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)

        Circle()
          .fill(themeColor(theme))
          .frame(width: dotSize, height: dotSize)
          .overlay(
            Circle().stroke(
              theme == .night ? Color.white.opacity(0.10) : Color.black.opacity(0.10),
              lineWidth: 1,
              antialiased: true
            )
          )
      }
      .contentShape(Circle())
      .onTapGesture {
        cycleTheme()
      }
    }

    private func dotButton(theme: ReadingTheme) -> some View {
      Button {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
          selected = theme
        }
      } label: {
        Circle()
          .fill(themeColor(theme))
          .frame(width: dotSize, height: dotSize)
          .overlay(
            Circle().stroke(Color.black.opacity(0.10), lineWidth: 1)
          )
          .opacity(selected == theme ? 1.0 : 0.85)
          .frame(width: chipSize, height: chipSize)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    private func themeColor(_ theme: ReadingTheme) -> Color {
      switch theme {
      case .day:
        return Color.white
      case .amber:
        return Color(red: 0.98, green: 0.93, blue: 0.74)
      case .night:
        return Color(red: 0.06, green: 0.06, blue: 0.08)
      }
    }

    private func cycleTheme() {
      let next: ReadingTheme = {
        switch selected {
        case .day: return .amber
        case .amber: return .night
        case .night: return .day
        }
      }()
      withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
        selected = next
      }
    }
  }

  /*
  * Voice Settings
  */
  private var voiceTile: some View {
    VoiceTile(
      title: "Voice",
      systemImage: "waveform",
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: false,
      action: {}
    )
  }

  private struct VoiceTile: View {
    let title: String
    let systemImage: String
    let surfaceText: Color
    let secondaryText: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        VStack(spacing: 10) {
          ZStack {
            Circle()
              .fill(surfaceText.opacity(0.06))
              .frame(width: 56, height: 56)
              .overlay(
                Circle().stroke(surfaceText.opacity(0.10), lineWidth: 1)
              )

            Image(systemName: systemImage)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(surfaceText.opacity(isEnabled ? 0.85 : 0.35))
          }

          Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryText.opacity(isEnabled ? 0.55 : 0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .opacity(isEnabled ? 1.0 : 0.85)
    }
  }

  /*
  * Search Tile
  */
  private var searchTile: some View {
    RoundIconTile(
      title: "Search",
      systemImage: "magnifyingglass",
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      action: {
        searchVisible = true
        if searchQuery.isEmpty { searchQuery = "" }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          isPresented = false
        }
      }
    )
  }

  /*
  * Ask AI Tile
  */

  private var askAiTile: some View {
    RoundIconTile(
      title: "Ask AI",
      systemImage: "sparkles",
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: false,
      action: {}
    )
  }

  private struct RoundIconTile: View {
    let title: String
    let systemImage: String
    let surfaceText: Color
    let secondaryText: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        VStack(spacing: 10) {
          ZStack {
            Circle()
              .fill(surfaceText.opacity(0.06))
              .frame(width: 56, height: 56)
              .overlay(
                Circle().stroke(surfaceText.opacity(0.10), lineWidth: 1)
              )

            Image(systemName: systemImage)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(surfaceText.opacity(isEnabled ? 0.85 : 0.35))
          }

          Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryText.opacity(isEnabled ? 0.55 : 0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .opacity(isEnabled ? 1.0 : 0.85)
    }
  }

  /*
  * Text Size Tile
  */
  private var textTile: some View {
    TextCustomizeTile(
      title: "Text",
      subtitle: "Customize",
      footer: "Advanced",
      systemImage: "textformat.size",
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      onTap: {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          screen = .textCustomize
        }
      }
    )
  }

  private struct TextCustomizeTile: View {
    let title: String
    let subtitle: String
    let footer: String
    let systemImage: String
    let surfaceText: Color
    let secondaryText: Color
    let onTap: () -> Void

    var body: some View {
      Button(action: onTap) {
        VStack(spacing: 10) {
          VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(surfaceText.opacity(0.75))

            Spacer(minLength: 0)

            Text(title)
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(surfaceText.opacity(0.92))

            Text(subtitle)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(secondaryText.opacity(0.70))
          }
          .padding(16)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
              .fill(surfaceText.opacity(0.04))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
              .stroke(surfaceText.opacity(0.08), lineWidth: 1)
          )

          Text(footer)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryText.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
    }
  }

  /*
  * Offline Tile
  */
  private var offlineTile: some View {
    RoundToggleTile(
      title: "Offline",
      systemImage: "wifi.slash",
      isSelected: false,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: false,
      action: {}
    )
  }

  /*
  * Lock Tile
  */
  private var lockTile: some View {
    RoundToggleTile(
      title: "Lock",
      systemImage: isLocked ? "lock.fill" : "lock.open",
      isSelected: isLocked,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      action: {
        isLocked.toggle()
        if isLocked {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
          }
        }
      }
    )
  }

  private struct RoundToggleTile: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let surfaceText: Color
    let secondaryText: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        VStack(spacing: 10) {
          ZStack {
            Circle()
              .fill(backgroundFill)
              .frame(width: 56, height: 56)
              .overlay(
                Circle().stroke(borderStroke, lineWidth: 1)
              )

            Image(systemName: systemImage)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(surfaceText.opacity(isEnabled ? 0.85 : 0.35))
          }

          Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryText.opacity(isEnabled ? 0.55 : 0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .opacity(isEnabled ? 1.0 : 0.85)
    }

    private var backgroundFill: Color {
      if isSelected {
        return surfaceText.opacity(0.10)
      }
      return surfaceText.opacity(0.06)
    }

    private var borderStroke: Color {
      if isSelected {
        return surfaceText.opacity(0.22)
      }
      return surfaceText.opacity(0.10)
    }
  }

}
