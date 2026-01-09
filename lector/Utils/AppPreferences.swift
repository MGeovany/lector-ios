import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        }
    }
}

struct AppPreferenceKeys {
    static let theme = "lector_theme"
    static let language = "lector_language"
}

