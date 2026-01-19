import CryptoKit
import Foundation

enum AppleSignInNonce {
  /// Generates a random nonce suitable for Sign in with Apple.
  static func random(length: Int = 32) -> String {
    precondition(length > 0)
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    result.reserveCapacity(length)
    for _ in 0..<length {
      result.append(charset[Int.random(in: 0..<charset.count)])
    }
    return result
  }

  /// SHA-256 hash (hex) used as `ASAuthorizationAppleIDRequest.nonce`.
  static func sha256(_ input: String) -> String {
    let digest = SHA256.hash(data: Data(input.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

