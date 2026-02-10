//
//  PostHogAnalytics.swift
//  lector
//

import Foundation
import PostHog

enum PostHogAnalytics {

  /// Sends an error to PostHog Error Tracking (dashboard shows it as an issue).
  static func captureError(
    message: String,
    type: String = "AppError",
    context: [String: String] = [:]
  ) {
    var props: [String: Any] = [
      "$exception_message": message,
      "$exception_type": type,
    ]
    for (k, v) in context {
      props[k] = v
    }
    PostHogSDK.shared.capture("$exception", properties: props)
  }

  /// Sends a custom event for analytics and dashboards.
  static func capture(_ name: String, properties: [String: Any] = [:]) {
    PostHogSDK.shared.capture(name, properties: properties)
  }

  /// Associate subsequent events with a user (call after sign-in).
  static func identify(userId: String, traits: [String: Any] = [:]) {
    PostHogSDK.shared.identify(userId, userProperties: traits)
  }
}
