import Combine
import Foundation

// MARK: - Store (SOLID: dependency inversion)

struct ReadingPreferencesSnapshot: Equatable {
    var theme: ReadingTheme
    var font: ReadingFont
    var fontSize: Double
    var lineSpacing: Double
}

protocol ReadingPreferencesStoring {
    func load() -> ReadingPreferencesSnapshot
    func save(_ snapshot: ReadingPreferencesSnapshot)
}

struct UserDefaultsReadingPreferencesStore: ReadingPreferencesStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReadingPreferencesSnapshot {
        let themeRaw = defaults.string(forKey: PreferencesKeys.readingTheme) ?? ReadingPreferencesDefaults.theme.rawValue
        let fontRaw = defaults.string(forKey: PreferencesKeys.readingFont) ?? ReadingPreferencesDefaults.font.rawValue

        let theme = ReadingTheme(rawValue: themeRaw) ?? ReadingPreferencesDefaults.theme
        let font = ReadingFont(rawValue: fontRaw) ?? ReadingPreferencesDefaults.font

        let fontSize = defaults.object(forKey: PreferencesKeys.readingFontSize) as? Double ?? ReadingPreferencesDefaults.fontSize
        let lineSpacing = defaults.object(forKey: PreferencesKeys.readingLineSpacing) as? Double ?? ReadingPreferencesDefaults.lineSpacing

        return ReadingPreferencesSnapshot(
            theme: theme,
            font: font,
            fontSize: fontSize,
            lineSpacing: lineSpacing
        )
    }

    func save(_ snapshot: ReadingPreferencesSnapshot) {
        defaults.set(snapshot.theme.rawValue, forKey: PreferencesKeys.readingTheme)
        defaults.set(snapshot.font.rawValue, forKey: PreferencesKeys.readingFont)
        defaults.set(snapshot.fontSize, forKey: PreferencesKeys.readingFontSize)
        defaults.set(snapshot.lineSpacing, forKey: PreferencesKeys.readingLineSpacing)
    }
}

// MARK: - ViewModel (MVVM)

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var theme: ReadingTheme
    @Published var font: ReadingFont
    @Published var fontSize: Double
    @Published var lineSpacing: Double

    private let store: ReadingPreferencesStoring
    private var saved: ReadingPreferencesSnapshot

    convenience init() {
        self.init(store: UserDefaultsReadingPreferencesStore())
    }

    init(store: ReadingPreferencesStoring) {
        self.store = store
        let snapshot = store.load()

        self.theme = snapshot.theme
        self.font = snapshot.font
        self.fontSize = snapshot.fontSize
        self.lineSpacing = snapshot.lineSpacing

        self.saved = snapshot
    }

    var hasChanges: Bool {
        current != saved
    }

    func save() {
        store.save(current)
        saved = current
    }

    func restoreDefaults() {
        theme = ReadingPreferencesDefaults.theme
        font = ReadingPreferencesDefaults.font
        fontSize = ReadingPreferencesDefaults.fontSize
        lineSpacing = ReadingPreferencesDefaults.lineSpacing
    }

    private var current: ReadingPreferencesSnapshot {
        ReadingPreferencesSnapshot(
            theme: theme,
            font: font,
            fontSize: fontSize,
            lineSpacing: lineSpacing
        )
    }
}

