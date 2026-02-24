import SwiftUI

struct ReaderSettingsPanelSheet: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let containerHeight: CGFloat
  @Binding var isPresented: Bool
  @Binding var dragOffset: CGFloat
  @Binding var isLocked: Bool
  @Binding var searchVisible: Bool
  @Binding var searchQuery: String

  @Binding var localDragOffset: CGFloat
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

  @ObservedObject var askAI: ReaderAskAIViewModel

  private var maxPanelH: CGFloat {
    switch screen {
    case .askAI:
      if askAI.messages.isEmpty {
        return containerHeight * 0.25
      } else {
        return containerHeight * 0.62
      }
    case .main, .textCustomize:
      return containerHeight * 0.60
    }
  }

  private var minPanelH: CGFloat {
    containerHeight * 0.14
  }

  var body: some View {
    let maxH = maxPanelH
    let minH = minPanelH
    let collapseRange = max(1, maxH - minH)

    let clampedDrag = min(max(localDragOffset, 0), collapseRange)
    let currentH = maxH - clampedDrag

    VStack(spacing: 0) {
      ReaderSettingsPanelHeaderView(
        title: headerTitle,
        isPresented: $isPresented,
        dragOffset: $dragOffset,
        localDragOffset: $localDragOffset
      )

      Group {
        switch screen {
        case .askAI:
          ReaderSettingsAskAIView(
            viewModel: askAI,
            onBack: {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                screen = .main
              }
            }
          )

        case .main, .textCustomize:
          ScrollView {
            VStack(spacing: 14) {
              switch screen {
              case .main:
                ReaderSettingsMainSettingsView(
                  isPresented: $isPresented,
                  isLocked: $isLocked,
                  searchVisible: $searchVisible,
                  searchQuery: $searchQuery,
                  screen: $screen,
                  fontPage: $fontPage,
                  audiobookEnabled: $audiobookEnabled,
                  onEnableAudiobook: onEnableAudiobook,
                  onDisableAudiobook: onDisableAudiobook,
                  offlineEnabled: $offlineEnabled,
                  onEnableOffline: onEnableOffline,
                  onDisableOffline: onDisableOffline,
                  offlineSubtitle: offlineSubtitle,
                  offlineIsAvailable: offlineIsAvailable
                )

              case .textCustomize:
                ReaderSettingsTextCustomizeSettingsView(
                  screen: $screen,
                  onBack: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                      screen = .main
                    }
                  }
                )

              case .askAI:
                EmptyView()
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
          }
          .scrollDisabled(currentH <= (minH + 30))
          .opacity(currentH <= (minH + 10) ? 0 : 1)
        }
      }
      .clipped()
    }
    .frame(maxWidth: .infinity)
    .frame(height: currentH)
    .background(panelBackground)
    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
    .animation(.spring(response: 0.30, dampingFraction: 0.88), value: screen)
    .animation(.spring(response: 0.30, dampingFraction: 0.88), value: askAI.messages.count)
    .animation(nil, value: localDragOffset)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private var panelBackground: Color {
    if preferences.theme == .day {
      return Color(
        #colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1.0))
    }
    if preferences.theme == .night {
      return Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0)
    }
    return preferences.theme.surfaceBackground
  }

  private var headerTitle: String {
    switch screen {
    case .main:
      return "Reader Settings"
    case .textCustomize:
      return "Text Customize"
    case .askAI:
      return ""
    }
  }
}
