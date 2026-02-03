import SwiftUI

struct ReaderSettingsMainSettingsView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  @Binding var isPresented: Bool
  @Binding var isLocked: Bool
  @Binding var searchVisible: Bool
  @Binding var searchQuery: String
  @Binding var screen: ReaderSettingsPanelScreen
  @Binding var fontPage: Int

  @Binding var audiobookEnabled: Bool
  let onEnableAudiobook: () -> Void
  let onDisableAudiobook: () -> Void

  @Binding var offlineEnabled: Bool
  let onEnableOffline: () -> Void
  let onDisableOffline: () -> Void
  let offlineSubtitle: String?
  let offlineIsAvailable: Bool

  var body: some View {
    let gap: CGFloat = 15

    let themeH: CGFloat = 80
    let searchH: CGFloat = 80
    let tallH: CGFloat = 180
    let bottomH: CGFloat = 80
    let textH: CGFloat = searchH + tallH - bottomH

    let totalH: CGFloat = themeH + gap + searchH + gap + tallH

    GeometryReader { geo in
      let totalW = geo.size.width
      let leftW = (totalW - gap) * 0.80
      let rightW = (totalW - gap) * 0.20

      let themePillW = leftW * 0.93
      let searchColW = leftW * 0.35
      let textColW = leftW - gap - searchColW

      HStack(alignment: .top, spacing: gap) {
        VStack(spacing: gap) {
          themePill
            .frame(width: themePillW)
            .frame(height: themeH)
            .frame(maxWidth: .infinity, alignment: .leading)

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

              textSizePill
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

          brightnessPill
            .frame(height: tallH)
        }
        .frame(width: rightW)
      }
    }
    .frame(height: totalH)
  }

  private var themePill: some View {
    ReaderSettingsThemePill(
      selected: Binding(
        get: { preferences.theme },
        set: { newTheme in
          withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
            preferences.theme = newTheme
          }
        }),
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      onEdit: {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          screen = .textCustomize
        }
      }
    )
  }

  private var voiceTile: some View {
    ReaderSettingsRoundToggleTile(
      title: "Voice",
      systemImage: "waveform",
      isSelected: audiobookEnabled,
      subtitle: nil,
      showsBadge: false,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      action: {
        let next = !audiobookEnabled
        audiobookEnabled = next
        if next {
          onEnableAudiobook()
        } else {
          onDisableAudiobook()
        }
      }
    )
  }

  private var searchTile: some View {
    ReaderSettingsRoundIconTile(
      title: "Search",
      systemImage: "doc.text.magnifyingglass",
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

  private var askAiTile: some View {
    ReaderSettingsRoundIconTile(
      title: "Ask AI",
      systemImage: "brain",
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      action: {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          // localDragOffset = 0
          screen = .askAI

        }
      }
    )
  }

  private var textTile: some View {
    ReaderSettingsTextCustomizeTile(
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

  private var offlineTile: some View {
    ReaderSettingsRoundToggleTile(
      title: "Offline",
      systemImage: offlineEnabled ? "wifi.slash" : "wifi",
      isSelected: offlineEnabled,
      subtitle: offlineSubtitle,
      showsBadge: offlineIsAvailable,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      action: {
        let next = !offlineEnabled
        offlineEnabled = next
        if next {
          onEnableOffline()
        } else {
          onDisableOffline()
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
          }
        }
      }
    )
    .accessibilityLabel(Text("Offline"))
  }

  private var lockTile: some View {
    ReaderSettingsRoundToggleTile(
      title: "Focus",
      systemImage: isLocked ? "viewfinder" : "viewfinder.circle",
      isSelected: isLocked,
      subtitle: nil,
      showsBadge: false,
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

  private var textSizePill: some View {
    ReaderSettingsVerticalPillSlider(
      title: "Text Size",
      systemImage: "textformat.size",
      value: Binding(
        get: { preferences.fontSize },
        set: { preferences.fontSize = min(26, max(14, $0)) }
      ),
      range: 14...26,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      step: 0.25
    )
  }

  private var brightnessPill: some View {
    ReaderSettingsVerticalPillSlider(
      title: "Brightness",
      systemImage: "sun.max",
      value: Binding(
        get: { preferences.brightness },
        set: {
          let clamped = min(1, max(0, $0))
          preferences.brightness = clamped
          ReaderActiveScreen.setBrightness(CGFloat(clamped))
        }
      ),
      range: 0...1,
      surfaceText: preferences.theme.surfaceText,
      secondaryText: preferences.theme.surfaceSecondaryText,
      isEnabled: true,
      step: 0.01
    )
  }
}
