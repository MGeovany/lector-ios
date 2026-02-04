import Foundation
import Combine
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
  static let shared = NetworkMonitor()

  @Published private(set) var isOnline: Bool = true
  @Published private(set) var isOnWiFi: Bool = false

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "NetworkMonitor")
  private var started: Bool = false

  func startIfNeeded() {
    guard !started else { return }
    started = true

    monitor.pathUpdateHandler = { path in
      let online = (path.status == .satisfied)
      let onWiFi = path.usesInterfaceType(.wifi)
      Task { @MainActor in
        NetworkMonitor.shared.isOnline = online
        NetworkMonitor.shared.isOnWiFi = onWiFi
      }
    }
    monitor.start(queue: queue)
  }
}
