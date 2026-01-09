import SwiftUI

struct HelpCenterView: View {
    private let supportEmail = "marlon.castro@thefndrs.com"

    var body: some View {
        List {
            Section {
                Text("Need help with imports, storage, or Premium? Send us a message and we’ll get back to you as soon as possible.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Section("Contact") {
                Link(destination: mailtoURL(subject: "Lector Help", body: "Hi Marlon,\n\nI need help with:\n\n")) {
                    HStack {
                        Label("Email support", systemImage: "envelope")
                        Spacer()
                        Text(supportEmail)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Tips") {
                tipRow(title: "Storage", subtitle: "Upgrade to Premium to extend your storage limit.")
                tipRow(title: "Troubleshooting", subtitle: "Try closing and reopening the app after an import.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tipRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func mailtoURL(subject: String, body: String) -> URL {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        return URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") ?? URL(string: "mailto:\(supportEmail)")!
    }
}

#Preview {
    NavigationStack {
        HelpCenterView()
    }
}

