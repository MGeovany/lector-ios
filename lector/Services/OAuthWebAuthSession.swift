import AuthenticationServices
import UIKit

/// Runs OAuth flows using `ASWebAuthenticationSession`, which correctly supports custom-scheme
/// callbacks (e.g. `lector://auth-callback`). Using `SFSafariViewController` for these flows
/// often results in "Safari cannot open the page because the address is invalid" when the
/// provider redirects back to the custom scheme.
@MainActor
final class OAuthWebAuthSession: NSObject {
  static let shared = OAuthWebAuthSession()

  private var session: ASWebAuthenticationSession?

  func start(url: URL, callbackScheme: String) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let webAuth = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { callbackURL, error in
        if let callbackURL {
          continuation.resume(returning: callbackURL)
          return
        }
        if let error = error as? ASWebAuthenticationSessionError,
          error.code == .canceledLogin
        {
          continuation.resume(throwing: SupabaseAuthError.cancelled)
          return
        }
        continuation.resume(throwing: error ?? SupabaseAuthError.missingCallbackURL)
      }

      webAuth.presentationContextProvider = self
      // Ephemeral is nicer for testing; avoids persisting sessions/cookies unexpectedly.
      webAuth.prefersEphemeralWebBrowserSession = true

      self.session = webAuth
      _ = webAuth.start()
    }
  }
}

extension OAuthWebAuthSession: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    // Best-effort: pick the foreground-active key window.
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    for scene in scenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) {
        return window
      }
      if let window = scene.windows.first {
        return window
      }
    }

    // Fallback; shouldn't happen in normal app usage.
    if let anyScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
      .first
    {
      return anyScene.windows.first ?? UIWindow(windowScene: anyScene)
    }

    // Last resort (should basically never happen).
    return UIWindow()
  }
}
