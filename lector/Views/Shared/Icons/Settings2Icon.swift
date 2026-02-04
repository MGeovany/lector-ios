import SwiftUI

/// A reusable icon component representing the settings-2 icon (sliders with circles).
/// Based on Lucide's settings-2 icon SVG.
struct Settings2Icon: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geometry in
      let size = min(geometry.size.width, geometry.size.height)
      let scale = size / 24.0  // Original SVG viewBox is 24x24

      ZStack {
        // Top horizontal line: extended wider (from 2,7 to 22,7)
        Path { path in
          path.move(to: CGPoint(x: 2 * scale, y: 7 * scale))
          path.addLine(to: CGPoint(x: 22 * scale, y: 7 * scale))
        }
        .stroke(style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))

        // Bottom horizontal line: extended wider (from 2,17 to 22,17)
        Path { path in
          path.move(to: CGPoint(x: 2 * scale, y: 17 * scale))
          path.addLine(to: CGPoint(x: 22 * scale, y: 17 * scale))
        }
        .stroke(style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))

        // Top circle: moved further to left end (cx="1" cy="7" r="3")
        Circle()
          .stroke(style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
          .frame(width: 6 * scale, height: 6 * scale)
          .position(x: 1 * scale, y: 7 * scale)

        // Bottom circle: moved further to right end (cx="23" cy="17" r="3")
        Circle()
          .stroke(style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
          .frame(width: 6 * scale, height: 6 * scale)
          .position(x: 23 * scale, y: 17 * scale)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

#Preview {
  VStack(spacing: 20) {
    Settings2Icon()
      .frame(width: 24, height: 24)
      .foregroundStyle(.blue)

    Settings2Icon()
      .frame(width: 32, height: 32)
      .foregroundStyle(.red)

    Settings2Icon()
      .frame(width: 48, height: 48)
      .foregroundStyle(.green)
  }
  .padding()
}
