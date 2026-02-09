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

  /// Locale identifier used to force the app UI language.
  /// Note: we intentionally keep `rawValue` stable (stored in UserDefaults).
  var localeIdentifier: String {
    switch self {
    case .english: return "en"
    case .spanish: return "es"
    }
  }

  var title: String {
    switch self {
    case .english: return "English"
    case .spanish: return "Español"
    }
  }
}

struct AppPreferenceKeys {
  static let theme = "lector_theme"
  static let language = "lector_language"
  static let accountDisabled = "lector_account_disabled"
  static let profileAvatarAssetName = "lector_profile_avatar_asset_name"
  static let profileAvatarHeadAssetName = "lector_profile_avatar_head_asset_name"
  static let profileAvatarFaceAssetName = "lector_profile_avatar_face_asset_name"
  static let profileAvatarAccessoryAssetName = "lector_profile_avatar_accessory_asset_name"
}
