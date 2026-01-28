import SwiftUI

private struct ReaderTopBarHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ReaderCollapsibleTopBar<Content: View>: View {
  let isVisible: Bool
  @Binding var measuredHeight: CGFloat
  @ViewBuilder var content: () -> Content

  var body: some View {
    let targetHeight: CGFloat? = {
      if !isVisible { return 0 }
      return measuredHeight > 0 ? measuredHeight : nil
    }()

    content()
      .background(
        GeometryReader { geo in
          Color.clear
            .preference(key: ReaderTopBarHeightKey.self, value: geo.size.height)
        }
      )
      .onPreferenceChange(ReaderTopBarHeightKey.self) { h in
        let next = max(0, h)
        guard next > 0.5 else { return }
        if abs(next - measuredHeight) > 0.5 { measuredHeight = next }
      }
      .frame(height: targetHeight, alignment: .top)
      .clipped()
      .opacity(isVisible ? 1 : 0)
      .allowsHitTesting(isVisible)
      .animation(.spring(response: 0.24, dampingFraction: 0.9), value: isVisible)
  }
}
