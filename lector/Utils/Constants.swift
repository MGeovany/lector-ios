//
//  Constants.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import Foundation

// Storage limits (MB)
public let MAX_STORAGE_MB: Int = 15
public let MAX_STORAGE_PREMIUM_MB: Int = 250

enum APIConfig {
  /// Prefer Info.plist configuration (set via Xcode build settings). Falls back to hardcoded defaults.
  static var baseURL: URL {
    let value =
      (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
    let fallback = "https://reader-go-383281059490.us-central1.run.app/api/v1"
    return normalizeHTTPURL(value?.isEmpty == false ? value! : fallback, fallback: fallback)
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
}
