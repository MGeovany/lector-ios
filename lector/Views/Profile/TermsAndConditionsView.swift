import SwiftUI

struct TermsAndConditionsView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text("Terms & Conditions")
          .font(.parkinsansBold(size: CGFloat(26)))

        Text(
          "By using Lector, you agree to use the app responsibly and in compliance with applicable laws. You are responsible for the documents you upload and store."
        )
        .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 6) {
          Link("Privacy Policy", destination: WebAppLinks.privacyPolicy)
          Link("Terms of Service", destination: WebAppLinks.termsOfService)
          Link("Terms of Use (Apple EULA)", destination: WebAppLinks.appleStandardEULA)
        }
        .font(.parkinsansSemibold(size: CGFloat(13)))
        .tint(.secondary)
        .padding(.top, 6)

        sectionTitle("Storage")
        Text(
          "Free and Premium plans have different storage limits. If you exceed your plan’s limit, you may need to delete files or upgrade."
        )
        .foregroundStyle(.secondary)

        sectionTitle("Subscriptions")
        Text(
          "Subscription plans, including one-time purchases, are subject to our terms of service. For complete details on subscription terms and potential changes, please refer to our Privacy Policy and Terms & Conditions available on our website."
        )
        .foregroundStyle(.secondary)

        sectionTitle("Support")
        Text(
          "Support is provided on a best‑effort basis. We may contact you using the email you provide when you reach out."
        )
        .foregroundStyle(.secondary)

        sectionTitle("Changes")
        Text(
          "We may update these terms over time. Continued use of the app means you accept the updated terms."
        )
        .foregroundStyle(.secondary)

        Text("Last updated: Jan 2026")
          .font(.parkinsansSemibold(size: CGFloat(12)))
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
      .font(.parkinsansSemibold(size: CGFloat(15)))
      .padding(.top, 6)
  }
}
