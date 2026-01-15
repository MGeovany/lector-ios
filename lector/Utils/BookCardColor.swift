import Foundation
import SwiftUI

/// Pastel-ish card background options. Stored as raw string in UserDefaults.
enum BookCardColor: String, CaseIterable, Identifiable {
  case `default`
  case mist
  case blush
  case peach
  case butter
  case mint
  case sky
  case lavender
  case sand

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .default: return "Default"
    case .mist: return "Mist"
    case .blush: return "Blush"
    case .peach: return "Peach"
    case .butter: return "Butter"
    case .mint: return "Mint"
    case .sky: return "Sky"
    case .lavender: return "Lavender"
    case .sand: return "Sand"
    }
  }

  func color(for scheme: ColorScheme) -> Color {
    switch self {
    case .default:
      return scheme == .dark ? .black : .white

    // Light mode pastels
    case .mist:
      return scheme == .dark
        ? Color(red: 0.16, green: 0.18, blue: 0.22)
        : Color(red: 0.95, green: 0.96, blue: 0.98)
    case .blush:
      return scheme == .dark
        ? Color(red: 0.22, green: 0.14, blue: 0.16)
        : Color(red: 0.99, green: 0.93, blue: 0.94)
    case .peach:
      return scheme == .dark
        ? Color(red: 0.24, green: 0.17, blue: 0.12)
        : Color(red: 0.99, green: 0.94, blue: 0.90)
    case .butter:
      return scheme == .dark
        ? Color(red: 0.23, green: 0.21, blue: 0.12)
        : Color(red: 0.99, green: 0.98, blue: 0.90)
    case .mint:
      return scheme == .dark
        ? Color(red: 0.12, green: 0.22, blue: 0.18)
        : Color(red: 0.91, green: 0.98, blue: 0.94)
    case .sky:
      return scheme == .dark
        ? Color(red: 0.12, green: 0.18, blue: 0.26)
        : Color(red: 0.90, green: 0.95, blue: 0.99)
    case .lavender:
      return scheme == .dark
        ? Color(red: 0.18, green: 0.15, blue: 0.26)
        : Color(red: 0.94, green: 0.92, blue: 0.99)
    case .sand:
      return scheme == .dark
        ? Color(red: 0.22, green: 0.20, blue: 0.14)
        : Color(red: 0.98, green: 0.96, blue: 0.92)
    }
  }
}

enum BookCardColorStore {
  private static func key(for documentKey: String) -> String {
    "bookCardColor.\(documentKey)"
  }

  static func documentKey(for book: Book) -> String {
    (book.remoteID?.isEmpty == false) ? (book.remoteID!) : book.id.uuidString
  }

  static func get(for documentKey: String) -> BookCardColor {
    let raw =
      UserDefaults.standard.string(forKey: key(for: documentKey)) ?? BookCardColor.default.rawValue
    return BookCardColor(rawValue: raw) ?? .default
  }

  static func set(_ color: BookCardColor, for documentKey: String) {
    UserDefaults.standard.set(color.rawValue, forKey: key(for: documentKey))
  }

  static func delete(for documentKey: String) {
    UserDefaults.standard.removeObject(forKey: key(for: documentKey))
  }
}
