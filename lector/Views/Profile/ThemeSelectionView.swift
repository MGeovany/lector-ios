import SwiftUI

struct ThemeSelectionView: View {
    @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue

    private var selection: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRawValue) ?? .dark },
            set: { themeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: selection) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("Choose Light or Dark appearance.")
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThemeSelectionView()
    }
}

