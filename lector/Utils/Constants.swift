//
//  Constants.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import Foundation

// Storage limits (MB)
public let MAX_STORAGE_MB: Int = 15

// Total storage quota for paid tiers (Pro / Founder).
// Note: backend enforcement must also match this value.
public let MAX_STORAGE_PRO_GB: Int = 50
public let MAX_STORAGE_PREMIUM_MB: Int = 250

// Ask AI quota (tokens per month) for paid tiers.
// Note: backend enforcement must also match this value.
public let MAX_AI_TOKENS_PREMIUM_PER_MONTH: Int = 500_000

// Ask AI quota (tokens per month) during Pro free trial.
// Note: backend enforcement must also match this value.
public let MAX_AI_TOKENS_TRIAL_PER_MONTH: Int = 50_000

enum ReaderLimits {
  /// Continuous/infinite scroll will only apply to documents shorter than this page count.
  /// Kept as a shared constant so Preferences UI matches Reader behavior.
  static let continuousScrollMaxPages: Int = 10
}

enum APIConfig {
  /// Use Info.plist API_BASE_URL when set. Otherwise: local/TestFlight → dev backend; App Store / main → production.
  static var baseURL: URL {
    let value =
      (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
    let fallback = useDevBackendByDefault
      ? "https://reader-go-dev-383281059490.us-central1.run.app/api/v1"
      : "https://reader-go-383281059490.us-central1.run.app/api/v1"
    return normalizeHTTPURL(value?.isEmpty == false ? value! : fallback, fallback: fallback)
  }

  /// True when the app should use the dev backend: local (DEBUG) or TestFlight (sandbox receipt).
  private static var useDevBackendByDefault: Bool {
    #if DEBUG
    return true
    #else
    return hasSandboxReceipt
    #endif
  }

  /// TestFlight (and dev installs) use a sandbox receipt; App Store uses production receipt.
  private static var hasSandboxReceipt: Bool {
    guard let url = Bundle.main.appStoreReceiptURL else { return false }
    return url.lastPathComponent == "sandboxReceipt" || url.path.contains("sandboxReceipt")
  }

  /// Prefer Info.plist configuration (set via Xcode build settings). Falls back to a known test user.
  static var defaultUserID: String {
    let value =
      (Bundle.main.object(forInfoDictionaryKey: "DEFAULT_USER_ID") as? String)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
    return (value?.isEmpty == false) ? value! : "0eef79d5-4eca-4a28-a4fc-5bb95b885d03"
  }
}

enum KeychainKeys {
  /// Bearer token (Supabase `access_token`)
  static let authToken = "api.authToken"
  /// Supabase `refresh_token` (used to keep sessions alive across access-token expiry).
  static let refreshToken = "api.refreshToken"
  /// Authenticated Supabase user id (JWT `sub`)
  static let userID = "api.userID"
}

enum SupabaseConfig {
  static var url: URL {
    let value =
      (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
    let fallback = "https://uyurafcvuonxrbkbljpf.supabase.co"
    return normalizeHTTPURL(value?.isEmpty == false ? value! : fallback, fallback: fallback)
  }

  static var anonKey: String {
    let value =
      (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)?
      .trimmingCharacters(
        in: .whitespacesAndNewlines)
    // Public anon key is safe to ship in clients.
    let fallback =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV5dXJhZmN2dW9ueHJia2JsanBmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4MjMzMTUsImV4cCI6MjA4MTM5OTMxNX0.XVKdKyOBb7Baeos_ppvUmOX-jliOwtC-HXGmDBDqybQ"
    return (value?.isEmpty == false) ? value! : fallback
  }

  static let redirectScheme = "lector"
  static let redirectURL = URL(string: "\(redirectScheme)://auth-callback")!
}

enum WebAppLinks {
  /// Public website base URL (hosts privacy + terms pages).
  /// Configure via `WEB_APP_BASE_URL` in Info.plist.
  static var baseURL: URL {
    let value =
      (Bundle.main.object(forInfoDictionaryKey: "WEB_APP_BASE_URL") as? String)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
    let fallback = "https://lector.thefndrs.com"
    return normalizeHTTPURL(value?.isEmpty == false ? value! : fallback, fallback: fallback)
  }

  static var privacyPolicy: URL {
    baseURL.appendingPathComponent("privacy")
  }

  static var termsOfService: URL {
    baseURL.appendingPathComponent("terms")
  }

  static let appleStandardEULA = URL(
    string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
  )!
}

/// Ensures a valid absolute http/https URL even if the configured value is missing a scheme.
private func normalizeHTTPURL(_ raw: String, fallback: String) -> URL {
  let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  let withScheme: String = {
    if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
    // Common misconfig: host without scheme.
    return "https://\(trimmed)"
  }()
  return URL(string: withScheme) ?? URL(string: fallback)!
}

enum PreferencesKeys {
  static let readingTheme = "preferences.readingTheme"
  static let readingFont = "preferences.readingFont"
  static let readingFontSize = "preferences.readingFontSize"
  static let readingLineSpacing = "preferences.readingLineSpacing"
  static let readingTextAlignment = "preferences.readingTextAlignment"
  static let continuousScrollForShortDocs = "preferences.continuousScrollForShortDocs"
  static let readingBrightness = "preferences.readingBrightness"
  static let readingShowHighlightsInText = "preferences.readingShowHighlightsInText"
  static let readingHighlightColor = "preferences.readingHighlightColor"
}
