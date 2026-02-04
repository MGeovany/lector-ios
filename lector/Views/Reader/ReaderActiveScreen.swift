import UIKit

enum ReaderActiveScreen {
  static func screen() -> UIScreen? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }

    if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
      return active.screen
    }

    return scenes.first?.screen ?? UIScreen.screens.first
  }

  private static func allCandidateScreens() -> [UIScreen] {
    var out: [UIScreen] = []
    var seen: Set<ObjectIdentifier> = []

    func add(_ s: UIScreen?) {
      guard let s else { return }
      let id = ObjectIdentifier(s)
      guard !seen.contains(id) else { return }
      seen.insert(id)
      out.append(s)
    }

    add(screen())
    add(UIScreen.main)
    for s in UIScreen.screens { add(s) }
    return out
  }

  static func getBrightness() -> CGFloat {
    let read: () -> CGFloat = {
      screen()?.brightness ?? UIScreen.main.brightness
    }

    if Thread.isMainThread { return read() }

    var value: CGFloat = 0.5
    DispatchQueue.main.sync { value = read() }
    return value
  }

  static func setBrightness(_ value: CGFloat) {
    let clamped = min(1, max(0, value))

    let apply: () -> Void = {
      let screens = allCandidateScreens()
      if screens.isEmpty { return }
      for s in screens {
        s.brightness = clamped
      }
    }

    if Thread.isMainThread {
      apply()
    } else {
      DispatchQueue.main.sync { apply() }
    }
  }

  static func installBrightnessChangeLogging() {}
}
