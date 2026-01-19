import SwiftUI

/// Unified primary button styles for CTAs across the app.
/// Intentionally uses the same colors regardless of theme.

struct LectorPrimaryCapsuleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.parkinsansSemibold(size: 16))
      .foregroundStyle(AppColors.primaryActionForeground)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .background(
        Capsule(style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                AppColors.primaryActionBackgroundTop.opacity(configuration.isPressed ? 0.90 : 1.0),
                AppColors.primaryActionBackgroundBottom.opacity(
                  configuration.isPressed ? 0.90 : 1.0),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        Capsule(style: .continuous)
          .stroke(
            AppColors.primaryActionBorder.opacity(configuration.isPressed ? 0.25 : 0.6),
            lineWidth: 1
          )
      )
      // Subtle top highlight for 3D
      .overlay(
        Capsule(style: .continuous)
          .stroke(
            LinearGradient(
              colors: [AppColors.primaryActionHighlight, .clear],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1
          )
          .blendMode(.overlay)
      )
      // Depth
      .shadow(color: Color.black.opacity(0.38), radius: 14, x: 0, y: 10)
      .shadow(color: Color.white.opacity(0.06), radius: 1, x: 0, y: -1)
  }
}

struct LectorPrimaryRoundedButtonStyle: ButtonStyle {
  let cornerRadius: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.parkinsansSemibold(size: 16))
      .foregroundStyle(AppColors.primaryActionForeground)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                AppColors.primaryActionBackgroundTop.opacity(configuration.isPressed ? 0.90 : 1.0),
                AppColors.primaryActionBackgroundBottom.opacity(
                  configuration.isPressed ? 0.90 : 1.0),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            AppColors.primaryActionBorder.opacity(configuration.isPressed ? 0.25 : 0.6),
            lineWidth: 1
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [AppColors.primaryActionHighlight, .clear],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1
          )
          .blendMode(.overlay)
      )
      .shadow(color: Color.black.opacity(0.38), radius: 14, x: 0, y: 10)
      .shadow(color: Color.white.opacity(0.06), radius: 1, x: 0, y: -1)
  }
}
