//
//  Constants.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import Foundation

// Storage limits (MB)
public let MAX_STORAGE_MB: Int = 15
public let MAX_STORAGE_PREMIUM_MB: Int = 250

enum PreferencesKeys {
    static let readingTheme = "preferences.readingTheme"
    static let readingFont = "preferences.readingFont"
    static let readingFontSize = "preferences.readingFontSize"
    static let readingLineSpacing = "preferences.readingLineSpacing"
}
