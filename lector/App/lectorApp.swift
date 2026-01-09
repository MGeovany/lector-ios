//
//  lectorApp.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI

@main
struct lectorApp: App {
  @StateObject private var subscription = SubscriptionStore()

  init() {
    FontRegistrar.registerCinzelDecorativeIfNeeded()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(subscription)
    }
  }
}
