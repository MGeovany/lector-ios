import SwiftUI

struct ReaderSettingsPanelHeaderView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let title: String
  @Binding var isPresented: Bool
  @Binding var dragOffset: CGFloat
  @Binding var localDragOffset: CGFloat

  var body: some View {
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
}
