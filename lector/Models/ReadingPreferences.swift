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

enum ReadingFont: String, CaseIterable, Identifiable {
  case system
  case georgia
  case palatino
  case avenir
  case menlo

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return "System"
    case .georgia: return "Georgia"
    case .palatino: return "Palatino"
    case .avenir: return "Avenir"
    case .menlo: return "Menlo"
    }
  }

  var subtitle: String {
    switch self {
    case .system: return "Balanced"
    case .georgia: return "Serif"
    case .palatino: return "Bookish"
    case .avenir: return "Modern"
    case .menlo: return "Mono"
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
    }
  }
}

struct ReadingPreferencesDefaults {
  static let theme: ReadingTheme = .night
  static let font: ReadingFont = .system
  static let fontSize: Double = 17
  static let lineSpacing: Double = 1.12
}
