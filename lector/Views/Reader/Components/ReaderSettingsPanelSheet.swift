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
  // set to draggable range
  private var maxPanelH: CGFloat { containerHeight * 0.60 }
  private var minPanelH: CGFloat { containerHeight * 0.14 }

  var body: some View {
    let maxH = maxPanelH
    let minH = minPanelH
    let collapseRange = max(1, maxH - minH)

    let clampedDrag = min(max(localDragOffset, 0), collapseRange)

    let currentH = maxH - clampedDrag

    VStack(spacing: 0) {
      ReaderSettingsPanelHeaderView(
        title: screen == .main ? "Reader Settings" : "Text Customize",
        isPresented: $isPresented,
        dragOffset: $dragOffset,
        localDragOffset: $localDragOffset
      )

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
              fontPage: $fontPage
            )
          case .textCustomize:
            ReaderSettingsTextCustomizeSettingsView(screen: $screen)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
      }
      .clipped()
      .scrollDisabled(currentH <= (minH + 30))
      .opacity(currentH <= (minH + 10) ? 0 : 1)
    }
    .frame(maxWidth: .infinity)
    .frame(height: currentH)
    .background(panelBackground)
    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
    .animation(nil, value: localDragOffset)
    .transition(.move(edge: .bottom).combined(with: .opacity))

    .onChange(of: localDragOffset) { _, newValue in
      let clamped = min(max(newValue, 0), collapseRange)
      if clamped != newValue {
        localDragOffset = clamped
      }
    }
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
}
