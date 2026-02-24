import SwiftUI

struct ReaderSettingsMainSettingsView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  @EnvironmentObject private var subscription: SubscriptionStore

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

  @State private var showPremiumSheet: Bool = false
  @State private var premiumInitialPlan: SubscriptionPlan? = nil
  @AppStorage(AppPreferenceKeys.askAIPromoBannerDismissed) private var askAIPromoBannerDismissed: Bool = false
  private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

  var body: some View {
    let gap: CGFloat = 15

    let themeH: CGFloat = 80
    let searchH: CGFloat = 80
    let tallH: CGFloat = 180
    let bottomH: CGFloat = 80
    let textH: CGFloat = searchH + tallH - bottomH

    let totalH: CGFloat = themeH + gap + searchH + gap + tallH

    let shouldShowAskAIPromo = !askAIPromoBannerDismissed && !subscription.isPremium

    return VStack(spacing: 12) {
      if shouldShowAskAIPromo {
        ReaderAskAIPromoBannerView(
          theme: preferences.theme,
          onTry: {
            askAIPromoBannerDismissed = true
            premiumInitialPlan = .proMonthly
            showPremiumSheet = true
          },
          onDismiss: {
            askAIPromoBannerDismissed = true
          }
        )
      }

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
    // On iPad, present full-screen so the subscription UI is bigger.
    .sheet(
      isPresented: Binding(
        get: { showPremiumSheet && !isPad },
        set: { newValue in
          if !newValue {
            showPremiumSheet = false
            premiumInitialPlan = nil
          } else {
            showPremiumSheet = true
          }
        }
      )
    ) {
      PremiumUpsellSheetView(initialSelectedPlan: premiumInitialPlan)
        .environmentObject(subscription)
    }
    .fullScreenCover(
      isPresented: Binding(
        get: { showPremiumSheet && isPad },
        set: { newValue in
          if !newValue {
            showPremiumSheet = false
            premiumInitialPlan = nil
          } else {
            showPremiumSheet = true
          }
        }
      )
    ) {
      PremiumUpsellSheetView(initialSelectedPlan: premiumInitialPlan)
        .environmentObject(subscription)
    }
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
      badgeColor: .green,
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          isPresented = false
        }
        // Wait a beat for the panel dismissal/layout to settle, then open search.
        // This ensures the reader scroll-to-top actually occurs even when the user is
        // at the very bottom of the document.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
          searchVisible = true
          if searchQuery.isEmpty { searchQuery = "" }
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
      isEnabled: subscription.isPremium,
      isInteractable: true,
      action: {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          if subscription.isPremium {
            // localDragOffset = 0
            screen = .askAI
          } else {
            premiumInitialPlan = .proMonthly
            showPremiumSheet = true
          }
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
    let badge: Color = {
      if offlineIsAvailable { return .green }
      if offlineEnabled, offlineSubtitle != nil { return .yellow }
      return Color.green.opacity(0.35)
    }()
    return ReaderSettingsRoundToggleTile(
      title: "Offline",
      systemImage: offlineEnabled ? "wifi.slash" : "wifi",
      isSelected: offlineEnabled,
      subtitle: offlineSubtitle,
      showsBadge: offlineEnabled,
      badgeColor: badge,
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
      badgeColor: .green,
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

private struct ReaderAskAIPromoBannerView: View {
  let theme: ReadingTheme
  let onTry: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(theme.accent.opacity(0.14))
          .frame(width: 38, height: 38)

        Image(systemName: "sparkles")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(theme.accent.opacity(0.95))
      }

      VStack(alignment: .leading, spacing: 3) {
        Text("Try Ask AI")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(theme.surfaceText.opacity(0.94))

        Text("Get instant answers and summaries while you read.")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(theme.surfaceSecondaryText.opacity(0.85))
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      Button(action: onTry) {
        Text("Try")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(theme.surfaceBackground)
          .padding(.horizontal, 12)
          .padding(.vertical, 9)
          .background(theme.surfaceText.opacity(0.92), in: Capsule(style: .continuous))
      }
      .buttonStyle(.plain)

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(theme.surfaceSecondaryText.opacity(0.70))
          .frame(width: 28, height: 28)
          .background(theme.surfaceText.opacity(0.06), in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dismiss")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(theme.surfaceText.opacity(theme == .night ? 0.06 : 0.045))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(theme.surfaceText.opacity(theme == .night ? 0.10 : 0.08), lineWidth: 1)
    )
  }
}
