import SwiftUI

struct LanguageSelectionView: View {
    @AppStorage(AppPreferenceKeys.language) private var languageRawValue: String = AppLanguage.english.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRawValue) ?? .english },
            set: { languageRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: selection) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.title).tag(lang)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("This setting only affects the app UI. Document content is unchanged.")
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}

