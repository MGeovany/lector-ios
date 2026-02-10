//
//  lectorApp.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI

@main
struct lectorApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var preferences = PreferencesViewModel()
  @StateObject private var subscription = SubscriptionStore()

  init() {
    FontRegistrar.registerCinzelDecorativeIfNeeded()
    FontRegistrar.registerParkinsansIfNeeded()
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
