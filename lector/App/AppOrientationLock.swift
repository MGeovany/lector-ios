import UIKit

enum AppOrientationLock {
  private static var lockedMask: UIInterfaceOrientationMask? = nil

  static var currentMask: UIInterfaceOrientationMask {
    lockedMask ?? defaultMask
  }

  static var defaultMask: UIInterfaceOrientationMask {
    if UIDevice.current.userInterfaceIdiom == .pad {
      return .all
    }
    return [.portrait, .landscapeLeft, .landscapeRight]
  }

  static func lock(to mask: UIInterfaceOrientationMask) {
#if DEBUG
    print("[OrientationLock] lock -> \(mask)")
#endif
    lockedMask = mask
    apply(mask: mask)
  }

  static func unlock() {
#if DEBUG
    print("[OrientationLock] unlock")
#endif
    lockedMask = nil
    apply(mask: defaultMask)
  }

  private static func apply(mask: UIInterfaceOrientationMask) {
    DispatchQueue.main.async {
      // Ask UIKit to re-evaluate supported orientations.
      if let root = activeWindowScene()?
        .windows
        .first(where: { $0.isKeyWindow })?
        .rootViewController
      {
        root.setNeedsUpdateOfSupportedInterfaceOrientations()
      }

      // iOS 16+: best-effort request to keep current orientation aligned.
      if let scene = activeWindowScene() {
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        scene.requestGeometryUpdate(prefs) { error in
#if DEBUG
          print("[OrientationLock] requestGeometryUpdate error: \(error)")
#endif
        }
      }
    }
  }

  private static func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }

    if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
      return active
    }
    return scenes.first
  }
}
