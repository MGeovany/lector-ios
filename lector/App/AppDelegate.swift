import PostHog
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if PostHogAppConfig.isEnabled {
      let config = PostHogConfig(apiKey: PostHogAppConfig.apiKey, host: PostHogAppConfig.host)
      config.sessionReplay = true
      config.sessionReplayConfig.maskAllTextInputs = false
      config.sessionReplayConfig.screenshotMode = true
      config.flushAt = 1
      PostHogSDK.shared.setup(config)
      PostHogSDK.shared.capture("app_launched", properties: ["platform": "ios"])
      PostHogSDK.shared.flush()
    }
    return true
  }

  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    AppOrientationLock.currentMask
  }
}
