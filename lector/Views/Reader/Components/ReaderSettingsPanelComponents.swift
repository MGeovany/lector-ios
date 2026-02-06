import SwiftUI
import UIKit

struct ReaderSettingsThemePill: View {
  @Binding var selected: ReadingTheme

  let surfaceText: Color
  let secondaryText: Color
  let onEdit: () -> Void

  private let pillH: CGFloat = 54
  private let chipSize: CGFloat = 44
  private let dotSize: CGFloat = 16
  private let sidePadding: CGFloat = 14

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
          .fill(surfaceText.opacity(0.06))

        GeometryReader { geo in
          let w = geo.size.width
          let leftX = sidePadding + chipSize / 2
          let rightX = w - sidePadding - chipSize / 2
          let midX = w / 2
          let chipX: CGFloat = {
            switch selected {
            case .day: return leftX
            case .amber: return midX
            case .night: return rightX
            }
          }()

          ZStack {
            HStack {
              dotButton(theme: .day)
              Spacer(minLength: 0)
              dotButton(theme: .amber)
              Spacer(minLength: 0)
              dotButton(theme: .night)
            }
            .padding(.horizontal, sidePadding)

            chip(theme: selected)
              .position(x: chipX, y: pillH / 2)
              .animation(.spring(response: 0.30, dampingFraction: 0.80), value: selected)
          }
        }
      }
      .frame(height: pillH)

      Text("Theme")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(secondaryText.opacity(0.40))
    }
  }

  private func chip(theme: ReadingTheme) -> some View {
    ZStack {
      Circle()
        .fill(themeColor(theme).opacity(0.88))
        .frame(width: 90, height: chipSize)
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)

      Circle()
        .fill(themeColor(theme))
        .frame(width: dotSize, height: dotSize)
        .overlay(
          Circle().stroke(
            theme == .night ? Color.white.opacity(0.10) : Color.black.opacity(0.10),
            lineWidth: 1,
            antialiased: true
          )
        )
    }
    .contentShape(Circle())
    .onTapGesture {
      cycleTheme()
    }
  }

  private func dotButton(theme: ReadingTheme) -> some View {
    Button {
      withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
        selected = theme
      }
    } label: {
      Circle()
        .fill(themeColor(theme))
        .frame(width: dotSize, height: dotSize)
        .overlay(
          Circle().stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .opacity(selected == theme ? 1.0 : 0.85)
        .frame(width: chipSize, height: chipSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func themeColor(_ theme: ReadingTheme) -> Color {
    switch theme {
    case .day:
      return Color.white
    case .amber:
      return Color(red: 0.98, green: 0.93, blue: 0.74)
    case .night:
      return Color(red: 0.06, green: 0.06, blue: 0.08)
    }
  }

  private func cycleTheme() {
    let next: ReadingTheme = {
      switch selected {
      case .day: return .amber
      case .amber: return .night
      case .night: return .day
      }
    }()
    withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
      selected = next
    }
  }
}

struct ReaderSettingsRoundIconTile: View {
  let title: String
  let systemImage: String
  let surfaceText: Color
  let secondaryText: Color
  let isEnabled: Bool
  /// Controls whether taps are allowed. Use this when you want a "disabled" look
  /// but still want to intercept the tap (e.g. show upgrade/pricing).
  let isInteractable: Bool?
  let action: () -> Void
  
  init(
    title: String,
    systemImage: String,
    surfaceText: Color,
    secondaryText: Color,
    isEnabled: Bool,
    isInteractable: Bool? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.surfaceText = surfaceText
    self.secondaryText = secondaryText
    self.isEnabled = isEnabled
    self.isInteractable = isInteractable
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        ZStack {
          Circle()
            .fill(surfaceText.opacity(0.06))
            .frame(width: 56, height: 56)

          Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(surfaceText.opacity(isEnabled ? 0.85 : 0.35))
        }

        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(secondaryText.opacity(isEnabled ? 0.40 : 0.35))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(.plain)
    .disabled(!((isInteractable ?? isEnabled)))
    .opacity(isEnabled ? 1.0 : 0.85)
  }
}

struct ReaderSettingsTextCustomizeTile: View {
  let title: String
  let subtitle: String
  let footer: String
  let systemImage: String
  let surfaceText: Color
  let secondaryText: Color
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(surfaceText.opacity(0.75))

          Spacer(minLength: 0)

          Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(surfaceText.opacity(0.92))

          Text(subtitle)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryText.opacity(0.70))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(surfaceText.opacity(0.06))
        )

        Text(footer)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(secondaryText.opacity(0.35))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(.plain)
  }
}

struct ReaderSettingsRoundToggleTile: View {
  let title: String
  let systemImage: String
  let isSelected: Bool
  let subtitle: String?
  let showsBadge: Bool
  let surfaceText: Color
  let secondaryText: Color
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        ZStack {
          Circle()
            .fill(backgroundFill)
            .frame(width: 56, height: 56)

          Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(surfaceText.opacity(isEnabled ? 0.85 : 0.35))

          if showsBadge {
            Circle()
              .fill(Color.green)
              .frame(width: 10, height: 10)
              .overlay(
                Circle().stroke(Color.white.opacity(0.95), lineWidth: 2)
              )
              .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
              .offset(x: 18, y: -18)
          }
        }

        VStack(spacing: 2) {
          if !title.isEmpty {
            Text(title)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(secondaryText.opacity(isSelected ? 0.44 : 0.38))
          }

          if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(secondaryText.opacity(0.28))
              .lineLimit(2)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 92)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1.0 : 0.85)
  }

  private var backgroundFill: Color {
    surfaceText.opacity(0.06)
  }
}

struct ReaderSettingsVerticalPillSlider: View {
  let title: String
  let systemImage: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let surfaceText: Color
  let secondaryText: Color
  let isEnabled: Bool
  let step: Double

  private let pillCorner: CGFloat = 999
  private let labelGap: CGFloat = 10
  private let pillW: CGFloat = 55

  private let iconSize: CGFloat = 18

  @State private var isDragging: Bool = false
  @State private var lastHapticValue: Double = -1
  @State private var lastHapticTime: Date = .distantPast

  private static let hapticThrottleInterval: TimeInterval = 0.06

  var body: some View {
    let lo = min(range.lowerBound, range.upperBound)
    let hi = max(range.lowerBound, range.upperBound)

    VStack(spacing: labelGap) {
      GeometryReader { geo in
        let h = geo.size.height

        let t = normalized(lo: lo, hi: hi)  // 0...1
        let fillH = CGFloat(t) * h

        ZStack {
          RoundedRectangle(cornerRadius: pillCorner, style: .continuous)
            .fill(surfaceText.opacity(isEnabled ? 0.06 : 0.04))

          Rectangle()
            .fill(surfaceText.opacity(isEnabled ? 0.12 : 0.07))
            .frame(height: fillH)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .mask(RoundedRectangle(cornerRadius: pillCorner, style: .continuous))
            .animation(
              isDragging ? nil : .spring(response: 0.22, dampingFraction: 0.95),
              value: value
            )

          VStack(spacing: 0) {
            Spacer(minLength: 0)
            Image(systemName: systemImage)
              .font(.system(size: iconSize, weight: .semibold))
              .foregroundStyle(surfaceText.opacity(isEnabled ? 0.80 : 0.35))
              .padding(.bottom, 20)

          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: pillW)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: pillCorner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: pillCorner, style: .continuous))
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { g in
              guard isEnabled else { return }
              isDragging = true

              let localY = min(max(0, g.location.y), h)
              let progress = 1.0 - Double(localY / h)  // 0...1 (top=1)

              let raw = lo + progress * (hi - lo)
              let newValue = snapped(raw, lo: lo, hi: hi)
              let now = Date()
              let valueDelta = abs(newValue - lastHapticValue)
              let timeSinceLastHaptic = now.timeIntervalSince(lastHapticTime)
              let shouldHaptic = (lastHapticValue < 0 || valueDelta >= max(step * 0.5, 0.015))
                && timeSinceLastHaptic >= Self.hapticThrottleInterval
              if shouldHaptic {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred(intensity: 0.5)
                lastHapticValue = newValue
                lastHapticTime = now
              }
              value = newValue
            }
            .onEnded { _ in
              isDragging = false
            }
        )
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(accessibilityValue(lo: lo, hi: hi)))
        .accessibilityAdjustableAction { direction in
          guard isEnabled else { return }
          switch direction {
          case .increment:
            value = min(hi, value + step)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
          case .decrement:
            value = max(lo, value - step)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
          @unknown default:
            break
          }
        }
      }

      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(secondaryText.opacity(isEnabled ? 0.40 : 0.35))
    }
    .opacity(isEnabled ? 1.0 : 0.85)
  }

  private func normalized(lo: Double, hi: Double) -> Double {
    guard hi != lo else { return 0 }
    let t = (value - lo) / (hi - lo)
    return min(1, max(0, t))
  }

  private func snapped(_ v: Double, lo: Double, hi: Double) -> Double {
    let clamped = min(hi, max(lo, v))
    guard step > 0 else { return clamped }
    let steps = (clamped - lo) / step
    let rounded = steps.rounded()
    return lo + rounded * step
  }

  private func accessibilityValue(lo: Double, hi: Double) -> String {
    if lo == 0, hi == 1 {
      return "\(Int((normalized(lo: lo, hi: hi) * 100).rounded()))%"
    }
    return "\(value)"
  }
}

struct ReaderSettingsDebugBoxView: View {
  let title: String

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.blue, lineWidth: 3)

      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color.blue)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }
  }
}
