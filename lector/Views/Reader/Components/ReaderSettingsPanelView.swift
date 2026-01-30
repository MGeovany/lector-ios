import SwiftUI

struct ReaderSettingsPanelView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let containerHeight: CGFloat
  @Binding var isPresented: Bool
  @Binding var dragOffset: CGFloat
  @Binding var isLocked: Bool
  @Binding var searchVisible: Bool
  @Binding var searchQuery: String

  @Binding var audiobookEnabled: Bool
  let onEnableAudiobook: () -> Void
  let onDisableAudiobook: () -> Void

  @Binding var offlineEnabled: Bool
  let onEnableOffline: () -> Void
  let onDisableOffline: () -> Void
  let offlineSubtitle: String?
  let offlineIsAvailable: Bool

  @State private var localDragOffset: CGFloat = 0
  @State private var screen: ReaderSettingsPanelScreen = .main
  @State private var fontPage: Int = 0

  var body: some View {
    VStack(spacing: 0) {
      if isPresented {
        ReaderSettingsPanelSheet(
          containerHeight: containerHeight,
          isPresented: $isPresented,
          dragOffset: $dragOffset,
          isLocked: $isLocked,
          searchVisible: $searchVisible,
          searchQuery: $searchQuery,
          localDragOffset: $localDragOffset,
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
        .environmentObject(preferences)
      }
    }
    .frame(maxWidth: .infinity, alignment: .bottom)
    .onChange(of: isPresented) { _, showing in
      resetState(showing: showing)
    }
  }

  private func resetState(showing: Bool) {
    if !showing {
      dragOffset = 0
      localDragOffset = 0
      screen = .main
      fontPage = 0
      return
    }

    localDragOffset = 0
    screen = .main
    fontPage = 0
  }

}
