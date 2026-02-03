import Foundation
import Observation

#if canImport(AuthenticationServices)
  import AuthenticationServices
#endif

#if canImport(Sentry)
  import Sentry
#endif

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
    if !token.isEmpty {
      print("🟠 [AppSession] JWT from Keychain (Supabase access_token): \(token)")
    }
    isAuthenticated = !token.isEmpty && !userID.isEmpty
    #if canImport(Sentry)
      if isAuthenticated {
        SentrySDK.setUser(User(userId: userID))
      } else {
        SentrySDK.setUser(nil as User?)
      }
    #endif
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
      print(
        "🟠 [AppSession] Session refreshed – JWT (Supabase access_token): \(newSession.accessToken)")
      KeychainStore.setString(newSession.accessToken, account: KeychainKeys.authToken)
      if let newRefresh = newSession.refreshToken, !newRefresh.isEmpty {
        KeychainStore.setString(newRefresh, account: KeychainKeys.refreshToken)
      }
      KeychainStore.setString(newSession.userID, account: KeychainKeys.userID)
      isAuthenticated = true
      #if canImport(Sentry)
        SentrySDK.setUser(User(userId: newSession.userID))
      #endif
      // Sync account status with backend after successful refresh.
      await syncAccountStatus()
    } catch {
      // If refresh token is invalid/revoked, user must sign in again.
      #if canImport(Sentry)
        let event = Event(error: error)
        event.level = .error
        event.extra = [
          "has_refresh_token": String(!refresh.isEmpty)
        ]
        event.fingerprint = ["auth_refresh_failed", String(describing: type(of: error))]
        SentrySDK.capture(event: event)
      #endif
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
      // If profile fetch succeeds (200), account is not disabled; reset local flag.
      UserDefaults.standard.set(false, forKey: AppPreferenceKeys.accountDisabled)
    } catch {
      // Check if error is 403 "Account disabled" from middleware.
      if let apiError = error as? APIError, apiError.isAccountDisabled {
        // Account is disabled on backend; sync local flag.
        UserDefaults.standard.set(true, forKey: AppPreferenceKeys.accountDisabled)
      } else {
        #if canImport(Sentry)
          let event = Event(error: error)
          event.level = .error
          event.fingerprint = ["profile_fetch_failed", String(describing: type(of: error))]
          SentrySDK.capture(event: event)
        #endif
      }
      // Don't block the app on profile fetch; fallback to Guest UI.
      profile = nil
    }
  }

  /// Syncs account_disabled status with backend.
  /// Called after successful login/refresh to ensure local AppStorage matches server state.
  private func syncAccountStatus() async {
    guard isAuthenticated else { return }
    do {
      // Try to fetch profile. If successful (200), account is enabled.
      _ = try await profileService.getProfile()
      // Backend responded 200; account is not disabled. Reset local flag.
      UserDefaults.standard.set(false, forKey: AppPreferenceKeys.accountDisabled)
    } catch {
      // Check if error is 403 "Account disabled" from middleware.
      if let apiError = error as? APIError, apiError.isAccountDisabled {
        // Backend responded 403; account is disabled. Sync local flag.
        UserDefaults.standard.set(true, forKey: AppPreferenceKeys.accountDisabled)
      }
      // For other errors (401, 500, etc.), don't change account status.
      // User might have network issues or expired token; preserve current state.
    }
  }

  func beginGoogleSignIn() {
    print("🟠 [AppSession] beginGoogleSignIn() called")
    let start = authService.beginGoogleOAuth()
    print("🟠 [AppSession] OAuth URL generated: \(start.url.absoluteString)")
    print("🟠 [AppSession] PKCE verifier length: \(start.pkceVerifier.count)")
    pkceVerifier = start.pkceVerifier
    lastOAuthURLString = start.url.absoluteString
    #if canImport(Sentry)
      let crumb = Breadcrumb(level: .info, category: "auth")
      crumb.message = "begin_google_sign_in"
      crumb.data = [
        "url_host": start.url.host ?? "",
        "url_scheme": start.url.scheme ?? "",
      ]
      SentrySDK.addBreadcrumb(crumb)
    #endif

    // `ASWebAuthenticationSession` requires an http/https URL and supports custom-scheme callbacks.
    let scheme = start.url.scheme?.lowercased()
    let host = start.url.host ?? ""
    let urlString = start.url.absoluteString
    let isValidForWebAuth =
      (scheme == "http" || scheme == "https")
      && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !urlString.contains(" ")

    print(
      "🟠 [AppSession] URL validation - scheme: \(scheme ?? "nil"), host: \(host), isValid: \(isValidForWebAuth)"
    )

    guard isValidForWebAuth else {
      print("🔴 [AppSession] Invalid OAuth URL: \(urlString)")
      #if canImport(Sentry)
        let crumb = Breadcrumb(level: .warning, category: "auth")
        crumb.message = "invalid_oauth_url"
        crumb.data = ["url": urlString]
        SentrySDK.addBreadcrumb(crumb)
      #endif
      alertMessage =
        "Couldn't start sign-in. Invalid authorization URL.\n\nURL: \(urlString)\n\nCheck SUPABASE_URL configuration."
      isShowingOAuth = false
      oauthURL = nil
      return
    }

    // Run the OAuth flow and handle the callback in-app.
    print("🟠 [AppSession] Starting OAuth web auth session")
    print("🟠 [AppSession] Redirect scheme: \(SupabaseConfig.redirectScheme)")
    isAuthenticating = true
    Task {
      do {
        print("🟠 [AppSession] Calling OAuthWebAuthSession.shared.start()")
        let callbackURL = try await OAuthWebAuthSession.shared.start(
          url: start.url,
          callbackScheme: SupabaseConfig.redirectScheme
        )
        print("🟠 [AppSession] OAuth callback received: \(callbackURL.absoluteString)")
        await handleOAuthCallback(callbackURL)
      } catch {
        print("🔴 [AppSession] OAuth error: \(error)")
        print(
          "🔴 [AppSession] Error description: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
        )
        await MainActor.run {
          #if canImport(Sentry)
            let event = Event(error: error)
            event.level = .error
            event.fingerprint = ["oauth_web_auth_failed", String(describing: type(of: error))]
            SentrySDK.capture(event: event)
          #endif
          self.pkceVerifier = nil
          self.isAuthenticating = false
          self.alertMessage =
            (error as? LocalizedError)?.errorDescription ?? "Failed to sign in."
        }
      }
    }
  }

  func signInWithApple(idToken: String, nonce: String) {
    isAuthenticating = true
    Task {
      do {
        let session = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
        print(
          "🟠 [AppSession] Sign in with Apple – JWT (Supabase access_token): \(session.accessToken)")

        KeychainStore.setString(session.accessToken, account: KeychainKeys.authToken)
        if let refresh = session.refreshToken, !refresh.isEmpty {
          KeychainStore.setString(refresh, account: KeychainKeys.refreshToken)
        }
        KeychainStore.setString(session.userID, account: KeychainKeys.userID)
        isAuthenticated = true
        #if canImport(Sentry)
          SentrySDK.setUser(User(userId: session.userID))
          let crumb = Breadcrumb(level: .info, category: "auth")
          crumb.message = "apple_sign_in_completed"
          SentrySDK.addBreadcrumb(crumb)
        #endif

        await refreshProfileIfNeeded()
        await syncAccountStatus()
      } catch {
        #if canImport(Sentry)
          let event = Event(error: error)
          event.level = .error
          event.fingerprint = ["apple_sign_in_failed", String(describing: type(of: error))]
          SentrySDK.capture(event: event)
        #endif
        alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to sign in."
      }
      isAuthenticating = false
    }
  }

  func cancelOAuth() {
    isShowingOAuth = false
    oauthURL = nil
    pkceVerifier = nil
  }

  func handleOAuthCallback(_ url: URL) async {
    print("🟠 [AppSession] handleOAuthCallback called with URL: \(url.absoluteString)")
    print(
      "🟠 [AppSession] URL scheme: \(url.scheme ?? "nil"), expected: \(SupabaseConfig.redirectScheme)"
    )
    // Only handle our OAuth callback.
    guard url.scheme == SupabaseConfig.redirectScheme else {
      print("🔴 [AppSession] Callback URL scheme mismatch. Ignoring callback.")
      return
    }

    // Dismiss the browser as soon as we get the callback.
    isShowingOAuth = false
    oauthURL = nil

    isAuthenticating = true
    defer { isAuthenticating = false }

    do {
      print("🟠 [AppSession] Completing OAuth with callback URL")
      print("🟠 [AppSession] Has PKCE verifier: \(pkceVerifier != nil)")
      let session = try await authService.completeOAuth(
        callbackURL: url, pkceVerifier: pkceVerifier)
      print("🟠 [AppSession] OAuth completed successfully")
      print("🟠 [AppSession] User ID: \(session.userID)")
      print("🟠 [AppSession] Has refresh token: \(session.refreshToken != nil)")
      print("🟠 [AppSession] JWT (Supabase access_token): \(session.accessToken)")
      pkceVerifier = nil

      KeychainStore.setString(session.accessToken, account: KeychainKeys.authToken)
      if let refresh = session.refreshToken, !refresh.isEmpty {
        KeychainStore.setString(refresh, account: KeychainKeys.refreshToken)
      }
      KeychainStore.setString(session.userID, account: KeychainKeys.userID)
      isAuthenticated = true
      print("🟠 [AppSession] Session saved to keychain, isAuthenticated = true")
      #if canImport(Sentry)
        SentrySDK.setUser(User(userId: session.userID))

        let crumb = Breadcrumb(level: .info, category: "auth")
        crumb.message = "oauth_completed"
        SentrySDK.addBreadcrumb(crumb)
      #endif
      await refreshProfileIfNeeded()
      // Sync account status with backend after successful login.
      await syncAccountStatus()
    } catch {
      print("🔴 [AppSession] Error completing OAuth: \(error)")
      print(
        "🔴 [AppSession] Error description: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
      )
      pkceVerifier = nil
      #if canImport(Sentry)
        let event = Event(error: error)
        event.level = .error
        event.fingerprint = ["oauth_complete_failed", String(describing: type(of: error))]
        SentrySDK.capture(event: event)
      #endif
      alertMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to sign in."
    }
  }

  func signOut() {
    #if canImport(Sentry)
      let crumb = Breadcrumb(level: .info, category: "auth")
      crumb.message = "sign_out"
      SentrySDK.addBreadcrumb(crumb)
    #endif
    KeychainStore.delete(account: KeychainKeys.authToken)
    KeychainStore.delete(account: KeychainKeys.refreshToken)
    KeychainStore.delete(account: KeychainKeys.userID)
    isAuthenticated = false
    profile = nil
    #if canImport(Sentry)
      SentrySDK.setUser(nil as User?)
    #endif
    NotificationCenter.default.post(name: .documentsDidChange, object: nil)
  }
}
