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
    @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue

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
