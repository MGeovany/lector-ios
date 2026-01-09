import Combine
import Foundation

final class SubscriptionStore: ObservableObject {
    @Published var isPremium: Bool {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: Self.isPremiumKey)
        }
    }

    init() {
        self.isPremium = UserDefaults.standard.bool(forKey: Self.isPremiumKey)
    }

    var maxStorageBytes: Int64 {
        Int64(maxStorageMB) * 1024 * 1024
    }

    var maxStorageText: String {
        ByteCountFormatter.string(fromByteCount: maxStorageBytes, countStyle: .file)
    }

    var maxStorageMB: Int {
        isPremium ? MAX_STORAGE_PREMIUM_MB : MAX_STORAGE_MB
    }

    func upgradeToPremium() {
        isPremium = true
    }

    func downgradeToFree() {
        isPremium = false
    }

    private static let isPremiumKey = "lector_isPremium"
}
