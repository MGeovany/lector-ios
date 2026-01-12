import CryptoKit
import Foundation

enum SupabaseAuthError: LocalizedError, Equatable {
  case missingCallbackURL
  case missingAuthCodeOrToken
  case pkceExchangeFailed(message: String)
  case invalidAccessToken
  case cancelled

  var errorDescription: String? {
    switch self {
    case .missingCallbackURL:
      return "Authentication failed: missing callback URL."
    case .missingAuthCodeOrToken:
      return "Authentication failed: missing auth code/token."
    case .pkceExchangeFailed(let message):
      return message.isEmpty
        ? "Authentication failed while exchanging PKCE code."
        : "Authentication failed while exchanging PKCE code: \(message)"
    case .invalidAccessToken:
      return "Authentication succeeded but returned an invalid access token."
    case .cancelled:
      return "Authentication cancelled."
    }
  }
}

struct SupabaseSession: Equatable {
  let accessToken: String
  let userID: String
}

protocol SupabaseAuthServicing {
  func beginGoogleOAuth() -> (url: URL, pkceVerifier: String)
  func completeOAuth(callbackURL: URL, pkceVerifier: String?) async throws -> SupabaseSession
}

final class SupabaseAuthService: NSObject, SupabaseAuthServicing {
  private let url: URL
  private let anonKey: String

  init(url: URL = SupabaseConfig.url, anonKey: String = SupabaseConfig.anonKey) {
    self.url = url
    self.anonKey = anonKey
  }

  func beginGoogleOAuth() -> (url: URL, pkceVerifier: String) {
    let verifier = PKCE.codeVerifier()
    let challenge = PKCE.codeChallenge(from: verifier)
    return (makeAuthorizeURL(codeChallenge: challenge), verifier)
  }

  func completeOAuth(callbackURL: URL, pkceVerifier: String?) async throws -> SupabaseSession {
    // Implicit flow (#access_token)
    if let accessToken = callbackURL.fragmentParameters["access_token"], !accessToken.isEmpty {
      return try Self.sessionFromAccessToken(accessToken)
    }

    // PKCE code flow (?code=...)
    if let code = callbackURL.queryParameters["code"], !code.isEmpty {
      guard let pkceVerifier, !pkceVerifier.isEmpty else {
        throw SupabaseAuthError.missingAuthCodeOrToken
      }
      let accessToken = try await exchangePKCECode(code: code, verifier: pkceVerifier)
      return try Self.sessionFromAccessToken(accessToken)
    }

    throw SupabaseAuthError.missingAuthCodeOrToken
  }

  // MARK: - OAuth

  private func makeAuthorizeURL(codeChallenge: String) -> URL {
    var components = URLComponents(url: url.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "provider", value: "google"),
      URLQueryItem(name: "redirect_to", value: SupabaseConfig.redirectURL.absoluteString),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
    ]
    return components.url!
  }

  private func exchangePKCECode(code: String, verifier: String) async throws -> String {
    var components = URLComponents(url: url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "grant_type", value: "pkce")
    ]
    guard let tokenURL = components.url else {
      throw SupabaseAuthError.pkceExchangeFailed(message: "Invalid token URL.")
    }

    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let body: [String: String] = [
      "auth_code": code,
      "code_verifier": verifier,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw SupabaseAuthError.pkceExchangeFailed(message: "Invalid response.")
    }
    guard (200...299).contains(http.statusCode) else {
      let message = (try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data).message)
        ?? String(data: data, encoding: .utf8)
        ?? "HTTP \(http.statusCode)"
      throw SupabaseAuthError.pkceExchangeFailed(message: message)
    }

    let token = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
    guard !token.accessToken.isEmpty else {
      throw SupabaseAuthError.pkceExchangeFailed(message: "Empty access_token.")
    }
    return token.accessToken
  }

  // MARK: - Token parsing

  private static func sessionFromAccessToken(_ accessToken: String) throws -> SupabaseSession {
    guard let userID = JWT.subject(fromAccessToken: accessToken) else {
      throw SupabaseAuthError.invalidAccessToken
    }
    return SupabaseSession(accessToken: accessToken, userID: userID)
  }
}

private struct SupabaseTokenResponse: Decodable {
  let accessToken: String

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
  }
}

private struct SupabaseErrorResponse: Decodable {
  let message: String

  enum CodingKeys: String, CodingKey {
    case message = "error_description"
  }
}

private enum PKCE {
  static func codeVerifier() -> String {
    // 32 bytes -> base64url (43 chars-ish), meets PKCE requirements.
    let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
    return Data(bytes).base64URLEncodedString()
  }

  static func codeChallenge(from verifier: String) -> String {
    let data = Data(verifier.utf8)
    let digest = SHA256.hash(data: data)
    return Data(digest).base64URLEncodedString()
  }
}

private enum JWT {
  static func subject(fromAccessToken token: String) -> String? {
    let parts = token.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    let payloadPart = String(parts[1])
    guard let payloadData = Data(base64URLEncoded: payloadPart) else { return nil }
    guard
      let obj = try? JSONSerialization.jsonObject(with: payloadData, options: []),
      let dict = obj as? [String: Any]
    else { return nil }
    return dict["sub"] as? String
  }
}

private extension URL {
  var queryParameters: [String: String] {
    URLComponents(url: self, resolvingAgainstBaseURL: false)?
      .queryItems?
      .reduce(into: [:]) { $0[$1.name] = $1.value } ?? [:]
  }

  var fragmentParameters: [String: String] {
    guard let fragment, !fragment.isEmpty else { return [:] }
    return fragment
      .split(separator: "&")
      .reduce(into: [String: String]()) { acc, pair in
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        acc[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
      }
  }
}

private extension Data {
  func base64URLEncodedString() -> String {
    return self.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  init?(base64URLEncoded string: String) {
    var base64 = string
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let remainder = base64.count % 4
    if remainder > 0 {
      base64 += String(repeating: "=", count: 4 - remainder)
    }

    self.init(base64Encoded: base64)
  }
}

