import SwiftUI

struct FontPickerView: View {
    @Binding var font: ReadingFont

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ReadingFont.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        font = option
                    }
                } label: {
                    FontChipView(option: option, isSelected: option == font)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityHint(option.subtitle)
            }
        }
    }
}
