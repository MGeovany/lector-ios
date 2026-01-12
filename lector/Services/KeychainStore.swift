import Foundation
import Security

enum KeychainStore {
  private static let service = Bundle.main.bundleIdentifier ?? "lector"

  static func getString(account: String) -> String? {
    var query: [String: Any] = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else { return nil }
    guard let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func setString(_ value: String, account: String) {
    let data = Data(value.utf8)
    let query = baseQuery(account: account)

    let attributes: [String: Any] = [
      kSecValueData as String: data
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var insert = query
      insert[kSecValueData as String] = data
      SecItemAdd(insert as CFDictionary, nil)
    }
  }

  static func delete(account: String) {
    let query = baseQuery(account: account)
    SecItemDelete(query as CFDictionary)
  }

  private static func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
