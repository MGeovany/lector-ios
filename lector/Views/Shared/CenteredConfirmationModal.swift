import SwiftUI

struct CenteredConfirmationModal: View {
  let title: String
  let message: String
  let confirmTitle: String
  let isDestructive: Bool
  let onConfirm: () -> Void
  let onCancel: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      Color.black.opacity(0.45)
        .ignoresSafeArea()
        .onTapGesture { onCancel() }

      VStack(alignment: .leading, spacing: 10) {
        Text(title)
          .font(.parkinsansSemibold(size: 17))
          .foregroundStyle(.primary)

        Text(message)
          .font(.parkinsans(size: 14))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
          Button("Cancel") { onCancel() }
            .buttonStyle(CenteredModalButtonStyle(variant: .secondary))

          Button(confirmTitle) { onConfirm() }
            .buttonStyle(CenteredModalButtonStyle(variant: isDestructive ? .destructive : .primary))
        }
        .padding(.top, 6)
      }
      .padding(16)
      .frame(maxWidth: 340)
      .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color(.separator), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(colorScheme == .light ? 0.25 : 0.6), radius: 24, x: 0, y: 10)
      .padding(.horizontal, 24)
    }
    .accessibilityAddTraits(.isModal)
  }
}

private struct CenteredModalButtonStyle: ButtonStyle {
  enum Variant {
    case primary
    case secondary
    case destructive
  }

  let variant: Variant
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.parkinsansSemibold(size: 15))
      .foregroundStyle(foregroundStyle)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(backgroundFill.opacity(configuration.isPressed ? 0.75 : 1.0))
      )
  }

  private var backgroundFill: Color {
    switch variant {
    case .primary:
      // Primary CTA uses unified 3D black style. Background here is only used as a fill color,
      // so we use the "bottom" tone to match the button style closely.
      return AppColors.primaryActionBackgroundBottom
    case .secondary:
      return Color(.secondarySystemBackground)
    case .destructive:
      return Color.red
    }
  }

  private var foregroundStyle: Color {
    switch variant {
    case .primary:
      return AppColors.primaryActionForeground
    case .destructive:
      return .white
    case .secondary:
      return Color.primary
    }
  }
}

#Preview {
  ZStack {
    Color(.systemBackground).ignoresSafeArea()
    Button("Show") {}
  }
  .overlay {
    CenteredConfirmationModal(
      title: "Delete account?",
      message: "This is a mock action for now. It will clear local app data on this device.",
      confirmTitle: "Delete Account",
      isDestructive: true,
      onConfirm: {},
      onCancel: {}
    )
  }
}

