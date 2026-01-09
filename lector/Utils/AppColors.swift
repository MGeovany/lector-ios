import SwiftUI

enum AppColors {
    /// Matte black used as the primary tint in Light Mode. Hex: #333333
    static let matteBlack = Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255)

    static func primaryButtonFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? matteBlack : Color.accentColor
    }

    static func progressFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? matteBlack : Color.accentColor
    }

    static func tabSelected(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? matteBlack : Color.white.opacity(0.92)
    }

    static func tabUnselected(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? matteBlack.opacity(0.55) : Color.white.opacity(0.55)
    }
}

