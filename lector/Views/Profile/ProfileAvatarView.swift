import SwiftUI

struct ProfileAvatarView: View {
  let selection: ProfileAvatarSelection?
  var size: CGFloat
  var showBorder: Bool = true

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      Circle()
        .fill(Color(.secondarySystemBackground))

      if let selection, selection.hasAny {
        GeometryReader { geo in
          let side = min(geo.size.width, geo.size.height)

          // Important: heads are taller than wide, so when fitted into a square they end up
          // using a narrower width. We size face based on that *effective* head width
          // so everything scales together consistently.
          let headFitWidth = side * CanonicalAspect.head
          let headFrame = CGSize(width: headFitWidth, height: side)

          let faceWidth = headFitWidth * 0.78
          let faceFrame = CGSize(width: faceWidth, height: faceWidth / CanonicalAspect.face)

          ZStack {
            partImage(selection.headAssetName, kind: .head, frame: headFrame, referenceSize: side)

            partImage(selection.faceAssetName, kind: .face, frame: faceFrame, referenceSize: side)
              .offset(x: side * 0.03, y: side * 0.10)
          }
          .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(size * 0.14)
      } else {
        Image(systemName: "person.crop.circle.fill")
          .font(.system(size: size * 0.56, weight: .regular))
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay {
      if showBorder {
        Circle()
          .stroke(Color(.separator).opacity(colorScheme == .dark ? 0.22 : 0.35), lineWidth: 1)
      }
    }
  }

  private var backgroundFill: Color {
    // Avoid a gray/dark background behind the avatar.
    .white
  }

  @ViewBuilder
  private func partImage(
    _ assetName: String,
    kind: PartKind = .face,
    frame: CGSize,
    referenceSize: CGFloat
  ) -> some View {
    let trimmed = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      Image(trimmed)
        // Heads contain filled shapes (e.g. a white background). If we render them as
        // `.template`, the whole fill gets tinted (often to black), producing a blob.
        // Using `.original` preserves the SVG's intended alpha/fills.
        .renderingMode(kind == .head ? .original : .template)
        .resizable()
        // Faces are template images; in Dark Mode `.primary` is white, which makes
        // facial expressions look "inverted". Use a theme-aware dark color for consistency.
        .foregroundStyle(
          kind == .face
            ? Color(white: colorScheme == .dark ? 0.15 : 0.0)
            : Color.primary
        )
        .scaledToFit()
        .frame(width: frame.width, height: frame.height)
        .scaleEffect(partTransform(for: trimmed, kind: kind).scale)
        .offset(partTransform(for: trimmed, kind: kind).offset(for: referenceSize))
    }
  }
}

// MARK: - Per-asset tuning

private enum PartKind {
  case head
  case face
}

private enum CanonicalAspect {
  // These are the viewBox aspect ratios of the asset sets currently in use.
  // Keeping them here lets us size layers consistently without editing the SVGs.
  static let head: CGFloat = 473.0 / 567.0
  static let face: CGFloat = 289.0 / 293.0
}

private struct PartTransform {
  var scale: CGFloat = 1
  /// Offset values expressed as a fraction of avatar `size`.
  var offsetXFactor: CGFloat = 0
  var offsetYFactor: CGFloat = 0

  func offset(for size: CGFloat) -> CGSize {
    CGSize(width: size * offsetXFactor, height: size * offsetYFactor)
  }
}

private func partTransform(for assetName: String, kind: PartKind) -> PartTransform {
  switch kind {
  case .head:
    return PartTransform()
  case .face:
    return PartTransform()
  }
}
