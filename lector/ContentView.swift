//
//  ContentView.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI

/// App-level theme (Settings / Profile): applies to the whole app. Reader view overrides status bar while visible, then restores this.
struct ContentView: View {
  @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue
  @AppStorage(AppPreferenceKeys.accountDisabled) private var accountDisabled: Bool = false
  @State private var session = AppSession()

  private var selectedScheme: ColorScheme {
    AppTheme(rawValue: themeRawValue)?.colorScheme ?? .dark
  }

  var body: some View {
    ZStack {
      if accountDisabled {
        AccountDisabledView()
      } else if session.isAuthenticated {
        MainTabView()
      } else {
        WelcomeView()
      }
    }
    .onOpenURL { url in
      Task { await session.handleOAuthCallback(url) }
    }
    // Apply the selected theme at the root *view* level so it reliably updates
    // when AppStorage changes.
    .preferredColorScheme(selectedScheme)
    // Force the environment value too (more reliable across OS versions / containers).
    .environment(\.colorScheme, selectedScheme)
    .environment(session)
  }
}

#Preview {
  ContentView()
    .environment(AppSession())
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}
