import Foundation

/// Mirrors `reader-go/internal/domain/user.go` (SupabaseUser).
struct UserProfile: Codable, Equatable {
  let id: String
  let email: String
  let userMetadata: [String: JSONValue]?
  let createdAt: String?
  let updatedAt: String?

  enum CodingKeys: String, CodingKey {
    case id = "ID"
    case email = "Email"
    case userMetadata = "UserMetadata"
    case createdAt = "CreatedAt"
    case updatedAt = "UpdatedAt"
  }

  var displayName: String {
    // Common Supabase metadata keys
    if let name = userMetadata?["name"]?.stringValue, !name.isEmpty { return name }
    if let fullName = userMetadata?["full_name"]?.stringValue, !fullName.isEmpty { return fullName }
    if let emailName = email.split(separator: "@").first, !emailName.isEmpty {
      return String(emailName)
    }
    return "User"
  }

  /// Best-effort avatar URL from common OAuth/Supabase metadata keys.
  var avatarURL: URL? {
    let candidates: [String] = [
      "avatar_url",
      "picture",
      "avatar",
      "photo_url",
      "image_url",
    ]
    for key in candidates {
      if let raw = userMetadata?[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !raw.isEmpty,
        let url = URL(string: raw)
      {
        return url
      }
    }
    return nil
  }
}

extension JSONValue {
  fileprivate var stringValue: String? {
    switch self {
    case .string(let s): return s
    default: return nil
    }
  }
}
