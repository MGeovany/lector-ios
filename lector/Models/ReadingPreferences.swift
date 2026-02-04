import SwiftUI
import UIKit

enum ReadingTheme: String, CaseIterable, Identifiable {
  case day
  case night
  case amber

  var id: String { rawValue }

  var title: String {
    switch self {
    case .day: return "Day"
    case .night: return "Night"
    case .amber: return "Amber"
    }
  }

  var subtitle: String {
    switch self {
    case .day: return "Bright & crisp"
    case .night: return "Low glare"
    case .amber: return "Warm & comfy"
    }
  }

  /// Colors are for the reading surface (not the whole app).
  var surfaceBackground: Color {
    switch self {
    case .day:
      return Color.white
    case .night:
      return Color(red: 0.06, green: 0.06, blue: 0.08)
    case .amber:
      // Warm paper-like yellow, easy on the eyes.
      return Color(red: 0.98, green: 0.93, blue: 0.74)
    }
  }

  var surfaceText: Color {
    switch self {
    case .day:
      return Color.black.opacity(0.88)
    case .night:
      return Color.white.opacity(0.90)
    case .amber:
      return Color(red: 0.20, green: 0.14, blue: 0.05).opacity(0.92)
    }
  }

  var surfaceSecondaryText: Color {
    switch self {
    case .day:
      return Color.black.opacity(0.55)
    case .night:
      return Color.white.opacity(0.55)
    case .amber:
      return Color(red: 0.20, green: 0.14, blue: 0.05).opacity(0.55)
    }
  }

  var accent: Color {
    switch self {
    case .day:
      return Color.black.opacity(0.75)
    case .night:
      return Color.white.opacity(0.85)
    case .amber:
      return Color(red: 0.70, green: 0.45, blue: 0.05)
    }
  }

  var icon: String {
    switch self {
    case .day: return "sun.max.fill"
    case .night: return "moon.stars.fill"
    case .amber: return "sun.haze.fill"
    }
  }
}

enum ReadingTextAlignment: String, CaseIterable, Identifiable {
  case `default`
  case justify

  var id: String { rawValue }

  var title: String {
    switch self {
    case .default: return "Default"
    case .justify: return "Justify"
    }
  }

  var subtitle: String {
    switch self {
    case .default: return "Text lines up on the left"
    case .justify: return "Text spreads evenly"
    }
  }
}

enum ReadingFont: String, CaseIterable, Identifiable {
  case system
  case baskerville
  case georgia
  case palatino
  case avenir
  case menlo
  case iowan

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return "System"
    case .baskerville: return "Baskerville"
    case .georgia: return "Georgia"
    case .palatino: return "Palatino"
    case .avenir: return "Avenir"
    case .menlo: return "Menlo"
    case .iowan: return "Iowan"
    }
  }

  var subtitle: String {
    switch self {
    case .system: return "Balanced"
    case .baskerville: return "Elegant"
    case .georgia: return "Serif"
    case .palatino: return "Bookish"
    case .avenir: return "Modern"
    case .menlo: return "Mono"
    case .iowan: return "Classic"
    }
  }

  func font(size: CGFloat) -> Font {
    switch self {
    case .system:
      return .system(size: size, weight: .regular, design: .default)
    case .georgia:
      return .custom("Georgia", size: size)
    case .palatino:
      return .custom("Palatino", size: size)
    case .avenir:
      return .custom("Avenir Next", size: size)
    case .menlo:
      return .custom("Menlo", size: size)
    case .iowan:
      return .custom("Iowan Old Style", size: size)
    case .baskerville:
      return .custom("Baskerville", size: size)
    }
  }

  func uiFont(size: CGFloat) -> UIFont {
    switch self {
    case .system:
      return UIFont.systemFont(ofSize: size, weight: .regular)
    case .georgia:
      return UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size)
    case .palatino:
      // Palatino on iOS is usually "Palatino-Roman"
      return UIFont(name: "Palatino-Roman", size: size) ?? UIFont.systemFont(ofSize: size)
    case .avenir:
      return UIFont(name: "AvenirNext-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
    case .menlo:
      return UIFont(name: "Menlo-Regular", size: size)
        ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    case .iowan:
      // iOS ships Iowan as "IowanOldStyle-Roman" (fallback to system if missing)
      return UIFont(name: "IowanOldStyle-Roman", size: size) ?? UIFont.systemFont(ofSize: size)
    case .baskerville:
      return UIFont(name: "Baskerville", size: size) ?? UIFont.systemFont(ofSize: size)
    }
  }
}

enum ReadingHighlightColor: String, CaseIterable, Identifiable {
  case yellow
  case green
  case blue
  case pink
  case orange
  case purple

  var id: String { rawValue }

  var title: String {
    switch self {
    case .yellow: return "Yellow"
    case .green: return "Green"
    case .blue: return "Blue"
    case .pink: return "Pink"
    case .orange: return "Orange"
    case .purple: return "Purple"
    }
  }

  /// Pastel highlight colors (muted, light) for comfortable reading.
  var uiColor: UIColor {
    switch self {
    case .yellow: return UIColor(red: 1.0, green: 0.98, blue: 0.72, alpha: 1.0)
    case .green: return UIColor(red: 0.78, green: 0.94, blue: 0.8, alpha: 1.0)
    case .blue: return UIColor(red: 0.74, green: 0.88, blue: 1.0, alpha: 1.0)
    case .pink: return UIColor(red: 1.0, green: 0.84, blue: 0.9, alpha: 1.0)
    case .orange: return UIColor(red: 1.0, green: 0.92, blue: 0.76, alpha: 1.0)
    case .purple: return UIColor(red: 0.88, green: 0.82, blue: 0.96, alpha: 1.0)
    }
  }

  /// Theme-aware highlight color so it looks good on day, amber, and dark backgrounds.
  func highlightUIColor(for theme: ReadingTheme) -> UIColor {
    switch (self, theme) {
    case (.yellow, .day): return UIColor(red: 1.0, green: 0.98, blue: 0.72, alpha: 1.0)
    case (.yellow, .amber): return UIColor(red: 0.98, green: 0.92, blue: 0.6, alpha: 1.0)
    case (.yellow, .night): return UIColor(red: 0.95, green: 0.88, blue: 0.45, alpha: 1.0)
    case (.green, .day): return UIColor(red: 0.78, green: 0.94, blue: 0.8, alpha: 1.0)
    case (.green, .amber): return UIColor(red: 0.68, green: 0.88, blue: 0.7, alpha: 1.0)
    case (.green, .night): return UIColor(red: 0.55, green: 0.82, blue: 0.6, alpha: 1.0)
    case (.blue, .day): return UIColor(red: 0.74, green: 0.88, blue: 1.0, alpha: 1.0)
    case (.blue, .amber): return UIColor(red: 0.6, green: 0.78, blue: 0.95, alpha: 1.0)
    case (.blue, .night): return UIColor(red: 0.45, green: 0.7, blue: 0.92, alpha: 1.0)
    case (.pink, .day): return UIColor(red: 1.0, green: 0.84, blue: 0.9, alpha: 1.0)
    case (.pink, .amber): return UIColor(red: 0.98, green: 0.72, blue: 0.82, alpha: 1.0)
    case (.pink, .night): return UIColor(red: 0.92, green: 0.6, blue: 0.72, alpha: 1.0)
    case (.orange, .day): return UIColor(red: 1.0, green: 0.92, blue: 0.76, alpha: 1.0)
    case (.orange, .amber): return UIColor(red: 0.98, green: 0.85, blue: 0.6, alpha: 1.0)
    case (.orange, .night): return UIColor(red: 0.95, green: 0.75, blue: 0.45, alpha: 1.0)
    case (.purple, .day): return UIColor(red: 0.88, green: 0.82, blue: 0.96, alpha: 1.0)
    case (.purple, .amber): return UIColor(red: 0.8, green: 0.72, blue: 0.92, alpha: 1.0)
    case (.purple, .night): return UIColor(red: 0.72, green: 0.62, blue: 0.88, alpha: 1.0)
    }
  }

  /// Opacity for the highlight overlay; tuned per theme for readability.
  func highlightOpacity(for theme: ReadingTheme) -> CGFloat {
    switch theme {
    case .day: return 0.35
    case .amber: return 0.42
    case .night: return 0.50
    }
  }

  var color: Color { Color(uiColor: uiColor) }
}

struct ReadingPreferencesDefaults {
  static let theme: ReadingTheme = .night
  static let font: ReadingFont = .system
  static let fontSize: Double = 17
  static let lineSpacing: Double = 1.12
  static let textAlignment: ReadingTextAlignment = .default
  static let continuousScrollForShortDocs: Bool = false
  static let brightness: Double = 1.0
  static let showHighlightsInText: Bool = true
  static let highlightColor: ReadingHighlightColor = .yellow
}
