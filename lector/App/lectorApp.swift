//
//  lectorApp.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI

#if canImport(Sentry)
  import Sentry
#endif

@main
struct lectorApp: App {
  @StateObject private var preferences = PreferencesViewModel()
  @StateObject private var subscription = SubscriptionStore()

  init() {
    FontRegistrar.registerCinzelDecorativeIfNeeded()
    FontRegistrar.registerParkinsansIfNeeded()

    #if canImport(Sentry)
      let dsn =
        (Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      // If the build setting isn't provided, the Info.plist may contain the literal
      // "$(SENTRY_DSN)". Treat that as "missing" and skip initializing Sentry.
      if !dsn.isEmpty, !dsn.hasPrefix("$(") {
        SentrySDK.start { options in
          options.dsn = dsn

          #if DEBUG
            options.environment = "debug"
            options.debug = true
          #else
            options.environment = "release"
            options.debug = false
          #endif

          let short =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0"
          let build =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
          let bundleID = Bundle.main.bundleIdentifier ?? "lector"
          options.releaseName = "\(bundleID)@\(short)+\(build)"

          // Focus on crashes/errors; keep performance sampling off by default.
          options.tracesSampleRate = 0.0
          options.attachStacktrace = true
        }

        let crumb = Breadcrumb(level: .info, category: "app")
        crumb.message = "app_launched"
        SentrySDK.addBreadcrumb(crumb)
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        // Base typography for the whole app (views can override with `.font(...)`).
        .environment(\.font, .custom("Parkinsans-Regular", size: 16))
        .environmentObject(preferences)
        .environmentObject(subscription)
    }
  }
}
