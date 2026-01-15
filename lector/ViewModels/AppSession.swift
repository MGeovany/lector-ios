import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
  private(set) var isAuthenticated: Bool = false
  private(set) var isAuthenticating: Bool = false
  private(set) var isShowingOAuth: Bool = false
  private(set) var oauthURL: URL?
  private(set) var lastOAuthURLString: String?
  private(set) var profile: UserProfile?
  var alertMessage: String?

  private let authService: SupabaseAuthServicing
  private let profileService: UserProfileServicing
  private var pkceVerifier: String?

  init(
    authService: SupabaseAuthServicing? = nil,
    profileService: UserProfileServicing? = nil
  ) {
    self.authService = authService ?? SupabaseAuthService()
    self.profileService = profileService ?? GoUserProfileService()
    refreshFromKeychain()
    Task { await refreshSessionIfNeeded() }
    Task { await refreshProfileIfNeeded() }
  }

  func refreshFromKeychain() {
    let token = KeychainStore.getString(account: KeychainKeys.authToken) ?? ""
    let userID = KeychainStore.getString(account: KeychainKeys.userID) ?? ""
    isAuthenticated = !token.isEmpty && !userID.isEmpty
  }

  /// Keeps sessions alive across app restarts/device reboots by refreshing access tokens when needed.
  func refreshSessionIfNeeded() async {
    guard isAuthenticated else { return }
    let token = KeychainStore.getString(account: KeychainKeys.authToken) ?? ""
    let refresh = KeychainStore.getString(account: KeychainKeys.refreshToken) ?? ""
    guard !token.isEmpty else { return }

    // If we don't have a refresh token (older installs), the access token will expire and
    // the backend will return "Invalid token". Ask the user to sign in once to enable persistence.
    guard !refresh.isEmpty else {
      if let exp = SupabaseAuthService.accessTokenExpiration(token), exp <= Date() {
        alertMessage = "Session expired. Please sign in again."
        signOut()
      }
      return
    }

    // Refresh if token is expired or close to expiring.
    let exp = SupabaseAuthService.accessTokenExpiration(token)
    let needsRefresh = (exp == nil) || (exp! <= Date().addingTimeInterval(5 * 60))
    guard needsRefresh else { return }

    do {
      let newSession = try await authService.refreshSession(refreshToken: refresh)
      KeychainStore.setString(newSession.accessToken, account: KeychainKeys.authToken)
      if let newRefresh = newSession.refreshToken, !newRefresh.isEmpty {
        KeychainStore.setString(newRefresh, account: KeychainKeys.refreshToken)
      }
      KeychainStore.setString(newSession.userID, account: KeychainKeys.userID)
      isAuthenticated = true
    } catch {
      // If refresh token is invalid/revoked, user must sign in again.
      alertMessage = "Session expired. Please sign in again."
      signOut()
    }
  }

  func refreshProfileIfNeeded() async {
    guard isAuthenticated else {
      profile = nil
      return
    }
    do {
      profile = try await profileService.getProfile()
    } catch {
      // Don't block the app on profile fetch; fallback to Guest UI.
      profile = nil
    }
  }

  func beginGoogleSignIn() {
    let start = authService.beginGoogleOAuth()
    pkceVerifier = start.pkceVerifier
    lastOAuthURLString = start.url.absoluteString

    // `ASWebAuthenticationSession` requires an http/https URL and supports custom-scheme callbacks.
    let scheme = start.url.scheme?.lowercased()
    let host = start.url.host ?? ""
    let urlString = start.url.absoluteString
    let isValidForWebAuth =
      (scheme == "http" || scheme == "https")
      && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !urlString.contains(" ")

    guard isValidForWebAuth else {
      alertMessage =
        "Couldn't start sign-in. Invalid authorization URL.\n\nURL: \(urlString)\n\nCheck SUPABASE_URL configuration."
      isShowingOAuth = false
      oauthURL = nil
      return
    }

    // Run the OAuth flow and handle the callback in-app.
    isAuthenticating = true
    Task {
      do {
        let callbackURL = try await OAuthWebAuthSession.shared.start(
          url: start.url,
          callbackScheme: SupabaseConfig.redirectScheme
        )
        await handleOAuthCallback(callbackURL)
      } catch {
        await MainActor.run {
          self.pkceVerifier = nil
          self.isAuthenticating = false
          self.alertMessage =
            (error as? LocalizedError)?.errorDescription ?? "Failed to sign in."
        }
      }
    }
  }

  func cancelOAuth() {
    isShowingOAuth = false
    oauthURL = nil
    pkceVerifier = nil
  }

  func handleOAuthCallback(_ url: URL) async {
    // Only handle our OAuth callback.
    guard url.scheme == SupabaseConfig.redirectScheme else { return }

    // Dismiss the browser as soon as we get the callback.
    isShowingOAuth = false
    oauthURL = nil

    isAuthenticating = true
    defer { isAuthenticating = false }

    do {
      let session = try await authService.completeOAuth(
        callbackURL: url, pkceVerifier: pkceVerifier)
      pkceVerifier = nil

      KeychainStore.setString(session.accessToken, account: KeychainKeys.authToken)
      if let refresh = session.refreshToken, !refresh.isEmpty {
        KeychainStore.setString(refresh, account: KeychainKeys.refreshToken)
      }
      KeychainStore.setString(session.userID, account: KeychainKeys.userID)
      isAuthenticated = true
      await refreshProfileIfNeeded()
    } catch {
      pkceVerifier = nil
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to sign in."
    }
  }

  func signOut() {
    KeychainStore.delete(account: KeychainKeys.authToken)
    KeychainStore.delete(account: KeychainKeys.refreshToken)
    KeychainStore.delete(account: KeychainKeys.userID)
    isAuthenticated = false
    profile = nil
    NotificationCenter.default.post(name: .documentsDidChange, object: nil)
  }
}
