import SwiftUI

struct ReaderScrollIndicatorView: View {
  let progress: Double
  let tint: Color

  var body: some View {
    GeometryReader { geo in
      let trackHeight = max(60, geo.size.height)
      let thumbHeight: CGFloat = 44
      let clamped = min(1.0, max(0.0, progress))
      let y = CGFloat(clamped) * max(0, trackHeight - thumbHeight)

      ZStack(alignment: .top) {
        Capsule(style: .continuous)
          .fill(Color.white.opacity(0.06))
          .frame(width: 3)

        Capsule(style: .continuous)
          .fill(tint.opacity(0.80))
          .frame(width: 3, height: thumbHeight)
          .offset(y: y)
          .shadow(color: tint.opacity(0.25), radius: 6, y: 2)
      }
      .frame(width: 12)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(width: 14)
    .allowsHitTesting(false)
  }
}
