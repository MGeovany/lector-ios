//
//  lectorApp.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI

@main
struct lectorApp: App {
    init() {
        FontRegistrar.registerCinzelDecorativeIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
