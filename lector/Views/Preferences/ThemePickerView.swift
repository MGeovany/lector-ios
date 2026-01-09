import SwiftUI

struct ThemePickerView: View {
    @Binding var theme: ReadingTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ReadingTheme.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            theme = option
                        }
                    } label: {
                        ThemeOptionCardView(option: option, isSelected: option == theme)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityHint(option.subtitle)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
