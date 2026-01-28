import SwiftUI

struct ReaderBottomPagerView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let currentIndex: Int
  let totalPages: Int
  let onPrevious: () -> Void
  let onNext: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          onPrevious()
        }
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(currentIndex > 0 ? 0.90 : 0.35))
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preferences.theme.surfaceText.opacity(0.06))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(currentIndex <= 0)
      .accessibilityLabel("Previous page")
      .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in }.onEnded { _ in })

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        Text("\(max(1, currentIndex + 1))/\(max(1, totalPages))")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))
          .contentTransition(.numericText())
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(
        Capsule(style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(0.06))
      )
      .overlay(
        Capsule(style: .continuous)
          .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
      )
      .accessibilityLabel("Page \(max(1, currentIndex + 1)) of \(max(1, totalPages))")
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)

      Spacer(minLength: 0)

      Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          onNext()
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(
            preferences.theme.surfaceText.opacity(currentIndex < max(0, totalPages - 1) ? 0.90 : 0.35)
          )
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preferences.theme.surfaceText.opacity(0.06))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(currentIndex >= max(0, totalPages - 1))
      .accessibilityLabel("Next page")
      .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in }.onEnded { _ in })
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .padding(.bottom, 10)
  }
}
