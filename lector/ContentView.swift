//
//  ContentView.swift
//  lector
//
//  Created by Marlon Castro on 5/1/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// App-level theme (Settings / Profile): applies to the whole app. Reader view overrides status bar while visible, then restores this.
struct ContentView: View {
  @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue
  @AppStorage(AppPreferenceKeys.language) private var languageRawValue: String = AppLanguage.english
    .rawValue
  @AppStorage(AppPreferenceKeys.accountDisabled) private var accountDisabled: Bool = false
  @State private var session = AppSession()

  private var selectedScheme: ColorScheme {
    AppTheme(rawValue: themeRawValue)?.colorScheme ?? .dark
  }

  private var selectedLocale: Locale {
    let lang = AppLanguage(rawValue: languageRawValue) ?? .english
    return Locale(identifier: lang.localeIdentifier)
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
      Task {
        // 1) OAuth callback (custom scheme).
        if url.scheme == SupabaseConfig.redirectScheme {
          await session.handleOAuthCallback(url)
          return
        }
        // 2) Files opened via "Open in…" / Share Sheet (PDF/EPUB/TXT/MD).
        await handleIncomingFileURL(url)
      }
    }
    // Apply the selected theme at the root *view* level so it reliably updates
    // when AppStorage changes.
    .preferredColorScheme(selectedScheme)
    // Force the environment value too (more reliable across OS versions / containers).
    .environment(\.colorScheme, selectedScheme)
    // Force UI language from Settings (Language picker).
    .environment(\.locale, selectedLocale)
    .environment(session)
  }

  @MainActor
  private func handleIncomingFileURL(_ url: URL) async {
    guard isSupportedIncomingFileURL(url) else { return }
    // Reuse the same upload flow as the in-app file picker.
    // - If offline: queues the upload locally.
    // - If online: uploads and emits a "open reader" notification.
    await AddViewModel().uploadPickedDocument(url)
  }

  private func isSupportedIncomingFileURL(_ url: URL) -> Bool {
    // Some share providers give non-file URLs; ignore them here.
    if url.isFileURL { return true }
    guard
      let ext = url.pathExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        as String?,
      !ext.isEmpty
    else { return false }
    switch ext {
    case "pdf", "epub", "txt", "md", "markdown":
      return true
    default:
      // If the system provides a UTType for the extension, allow pdf/epub/text families.
      if let t = UTType(filenameExtension: ext) {
        return t.conforms(to: .pdf) || t.conforms(to: .text)
          || t.identifier == "org.idpf.epub-container"
      }
      return false
    }
  }
}

#Preview {
  ContentView()
    .environment(AppSession())
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}
