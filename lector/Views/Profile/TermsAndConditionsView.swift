import SwiftUI

struct TermsAndConditionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Terms & Conditions")
                    .font(.system(size: 26, weight: .bold))

                Text("By using Lector, you agree to use the app responsibly and in compliance with applicable laws. You are responsible for the documents you upload and store.")
                    .foregroundStyle(.secondary)

                sectionTitle("Storage")
                Text("Free and Premium plans have different storage limits. If you exceed your plan’s limit, you may need to delete files or upgrade.")
                    .foregroundStyle(.secondary)

                sectionTitle("Support")
                Text("Support is provided on a best‑effort basis. We may contact you using the email you provide when you reach out.")
                    .foregroundStyle(.secondary)

                sectionTitle("Changes")
                Text("We may update these terms over time. Continued use of the app means you accept the updated terms.")
                    .foregroundStyle(.secondary)

                Text("Last updated: Jan 2026")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Terms")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.top, 6)
    }
}

