import SwiftUI

enum AppColors {
    /// Matte black used as the primary tint in Light Mode. Hex: #333333
    static let matteBlack = Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255)

    // Unified primary button styling (same across themes).
    static let primaryActionBackgroundTop = Color(red: 0.16, green: 0.16, blue: 0.17)   // ~#29292B
    static let primaryActionBackgroundBottom = Color(red: 0.08, green: 0.08, blue: 0.09) // ~#141416
    static let primaryActionForeground = Color.white
    static let primaryActionBorder = Color.white.opacity(0.14)
    static let primaryActionHighlight = Color.white.opacity(0.22)

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

