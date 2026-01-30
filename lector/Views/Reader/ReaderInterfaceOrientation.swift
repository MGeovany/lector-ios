import UIKit

enum ReaderInterfaceOrientation {
  static var current: UIInterfaceOrientation? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }

    if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
      return active.effectiveGeometry.interfaceOrientation
    }
    return scenes.first?.effectiveGeometry.interfaceOrientation
  }

  static var currentIsLandscape: Bool {
    current?.isLandscape ?? false
  }
}
