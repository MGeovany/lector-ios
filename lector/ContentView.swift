//
//  ContentView.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue
    
    private var selectedScheme: ColorScheme {
        AppTheme(rawValue: themeRawValue)?.colorScheme ?? .dark
    }

    var body: some View {
        MainTabView()
            // Apply the selected theme at the root *view* level so it reliably updates
            // when AppStorage changes.
            .preferredColorScheme(selectedScheme)
            // Force the environment value too (more reliable across OS versions / containers).
            .environment(\.colorScheme, selectedScheme)
    }
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionStore())
}
