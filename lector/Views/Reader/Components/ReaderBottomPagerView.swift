import SwiftUI

struct ReaderBottomPagerView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let currentIndex: Int
  let totalPages: Int
  let onPrevious: () -> Void
  let onNext: () -> Void

  private var canGoPrevious: Bool { currentIndex > 0 }
  private var canGoNext: Bool { currentIndex < max(0, totalPages - 1) }
  private let hitSize: CGFloat = 42
  private let buttonClusterMaxWidth: CGFloat = 280

  private var footerBackground: Color {
    // Solid (no opacity), but follows the reading theme.
    preferences.theme.surfaceBackground
  }

  private var dividerOpacity: Double {
    preferences.theme == .night ? 0.22 : 0.10
  }

  private var labelOpacity: Double {
    preferences.theme == .night ? 0.55 : 0.42
  }

  private var arrowOpacityEnabled: Double {
    preferences.theme == .night ? 0.62 : 0.48
  }

  var body: some View {
    VStack(spacing: 0) {
      Divider()
        .opacity(dividerOpacity)

      ZStack {
        Text("\(max(1, currentIndex + 1))/\(max(1, totalPages))")
          .font(.system(size: 11, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(preferences.theme.surfaceSecondaryText.opacity(labelOpacity))
          .contentTransition(.numericText())
          .accessibilityLabel("Page \(max(1, currentIndex + 1)) of \(max(1, totalPages))")
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)

        HStack {
          Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
              onPrevious()
            }
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 14, weight: .semibold))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(
                preferences.theme.surfaceText.opacity(canGoPrevious ? arrowOpacityEnabled : 0.20)
              )
              .frame(width: hitSize, height: hitSize)
          }
          .buttonStyle(
            ReaderPagerPlainCircleButtonStyle(
              isEnabled: canGoPrevious,
              theme: preferences.theme
            )
          )
          .disabled(!canGoPrevious)
          .accessibilityLabel("Previous page")
          .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in }.onEnded { _ in })

          Spacer(minLength: 0)

          Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
              onNext()
            }
          } label: {
            Image(systemName: "chevron.right")
              .font(.system(size: 14, weight: .semibold))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(
                preferences.theme.surfaceText.opacity(canGoNext ? arrowOpacityEnabled : 0.20)
              )
              .frame(width: hitSize, height: hitSize)
          }
          .buttonStyle(
            ReaderPagerPlainCircleButtonStyle(
              isEnabled: canGoNext,
              theme: preferences.theme
            )
          )
          .disabled(!canGoNext)
          .accessibilityLabel("Next page")
          .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in }.onEnded { _ in })
        }
        .frame(maxWidth: buttonClusterMaxWidth)
      }
      .padding(.horizontal, 32)
      .padding(.vertical, 12)
    }
    .frame(maxWidth: .infinity)
    .background(
      footerBackground
        .ignoresSafeArea(edges: .bottom)
        // Shadow belongs to the footer background only (not the buttons).
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: -2)
    )
  }
}

/// Plain circle button (no blur / no opacity background).
private struct ReaderPagerPlainCircleButtonStyle: ButtonStyle {
  let isEnabled: Bool
  let theme: ReadingTheme

  private var buttonBackground: Color {
    // Solid, but adapts to theme. (Day looks white; night gets a dark surface.)
    switch theme {
    case .day:
      return Color.white
    case .night:
      return Color(white: 0.14)
    case .amber:
      return theme.surfaceBackground
    }
  }

  private var borderColor: Color {
    theme == .night ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
  }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Circle())
      .background(
        Circle()
          .fill(buttonBackground)
      )
      .overlay(
        Circle()
          .stroke(
            borderColor.opacity(isEnabled ? 1.0 : 0.65),
            lineWidth: 1
          )
      )
      // Ensure buttons never render with drop shadows.
      .shadow(color: .clear, radius: 0, x: 0, y: 0)
      .opacity(isEnabled ? 1.0 : 0.70)
      .opacity(configuration.isPressed ? 0.65 : 1.0)
      .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
      .animation(.spring(response: 0.16, dampingFraction: 0.9), value: configuration.isPressed)
  }
}
