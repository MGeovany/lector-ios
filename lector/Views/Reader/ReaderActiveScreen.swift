import UIKit

enum ReaderActiveScreen {
#if DEBUG
  private static let logPrefix = "[ReaderBrightness]"
  static var logsEnabled: Bool = true
#endif

  static func screen() -> UIScreen? {
    // Best-effort: pick the foreground-active scene's screen.
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
    // UIScreen.main is deprecated in iOS 26, but still useful as a fallback.
    add(UIScreen.main)
    for s in UIScreen.screens { add(s) }
    return out
  }

  private static func log(_ message: String) {
#if DEBUG
    guard logsEnabled else { return }
    print("\(logPrefix) \(message)")
#endif
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
      if screens.isEmpty {
        log("No screens available; cannot set brightness")
        return
      }

      let before = screens.map { $0.brightness }
      log("Set requested: \(String(format: "%.2f", Double(clamped))) | candidates: \(screens.count) | before: \(before.map { String(format: "%.2f", Double($0)) }.joined(separator: ","))")

      for s in screens {
        s.brightness = clamped
      }

      let after = screens.map { $0.brightness }
      log("After set: \(after.map { String(format: "%.2f", Double($0)) }.joined(separator: ","))")
    }

    if Thread.isMainThread {
      apply()
    } else {
      DispatchQueue.main.sync { apply() }
    }
  }

  static func installBrightnessChangeLogging() {
#if DEBUG
    guard logsEnabled else { return }
    NotificationCenter.default.addObserver(
      forName: UIScreen.brightnessDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      let screens = allCandidateScreens()
      let values = screens.map { String(format: "%.2f", Double($0.brightness)) }.joined(separator: ",")
      log("brightnessDidChangeNotification | now: \(values)")
    }
#endif
  }
}
