import SwiftUI

struct ReaderSearchBarView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  @Binding var query: String
  var onDismiss: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .symbolEffect(.pulse, value: !query.isEmpty)
      TextField("Search in book", text: $query)
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .foregroundStyle(preferences.theme.surfaceText)
      Button {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
          query = ""
          onDismiss?()
        }
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(preferences.theme.surfaceSecondaryText)
          .transition(.scale.combined(with: .opacity))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(preferences.theme.surfaceText.opacity(preferences.theme == .night ? 0.06 : 0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(
          !query.isEmpty
            ? preferences.theme.surfaceText.opacity(0.20)
            : preferences.theme.surfaceText.opacity(0.10),
          lineWidth: !query.isEmpty ? 1.5 : 1
        )
    )
  }
}
