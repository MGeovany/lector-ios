import SwiftUI

struct AboutUsView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("About Lector")
          .font(.parkinsansBold(size: CGFloat(28)))

        Text(
          "Lector is a focused reading space designed to keep your documents organized and easy to access — without noise. Import, save, and return to what matters: reading."
        )
        .font(.parkinsans(size: CGFloat(15), weight: .regular))
        .foregroundStyle(.secondary)
        .lineSpacing(4)

        VStack(alignment: .leading, spacing: 10) {
          bullet("A clean library for your PDFs and books")
          bullet("Quick access to favorites")
          bullet("Storage limits that grow with Premium")
        }
        .padding(.top, 4)

        Text("Thanks for using Lector :)")
          .font(.parkinsans(size: CGFloat(15), weight: .semibold))
          .padding(.top, 10)
      }
      .padding(18)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("About Us")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func bullet(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.secondary)
        .font(.parkinsans(size: CGFloat(14), weight: .semibold))
        .padding(.top, 2)

      Text(text)
        .font(.parkinsans(size: CGFloat(15), weight: .regular))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

#Preview {
  NavigationStack {
    AboutUsView()
  }
}
