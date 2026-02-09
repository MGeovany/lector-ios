import Foundation
import SwiftUI

/// In-app localization using the app's selected locale (from Settings).
/// Use with `@Environment(\.locale)` so the view updates when language changes.
enum L10n {
  static func tr(_ key: String, locale: Locale) -> String {
    let code = locale.identifier.hasPrefix("es") ? "es" : "en"
    let bundle: Bundle
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let b = Bundle(path: path)
    {
      bundle = b
    } else {
      bundle = .main
    }
    return bundle.localizedString(forKey: key, value: key, table: nil)
  }
}
