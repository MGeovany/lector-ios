import SwiftUI

struct AccountDisabledView: View {
  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      Color.black.opacity(0.92).ignoresSafeArea()

      VStack(alignment: .leading, spacing: 14) {
        Text("Account Disabled")
          .font(.parkinsansBold(size: 26))
          .foregroundStyle(Color.white.opacity(0.92))

        Text(
          """
          Your account has been temporarily disabled while we process your deletion request.

          All of your data will be permanently deleted. You’ll receive an email confirmation once the process is complete.
          """
        )
        .font(.parkinsans(size: 15, weight: .regular))
        .foregroundStyle(Color.white.opacity(0.75))
        .fixedSize(horizontal: false, vertical: true)

        Button {
          if let url = supportEmailURL() {
            openURL(url)
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
            Text("Contact Support")
          }
          .font(.parkinsansSemibold(size: 15))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)

        Text("If you believe this is a mistake, please contact support.")
          .font(.parkinsans(size: 12, weight: .regular))
          .foregroundStyle(Color.white.opacity(0.55))
          .padding(.top, 2)
      }
      .padding(.horizontal, 20)
      .frame(maxWidth: 420, alignment: .leading)
    }
  }

  private func supportEmailURL() -> URL? {
    let email = "marlon.castro@thefndrs.com"
    let subject = "Lector — Account Disabled"
    let body = "Hi,\n\nMy account is disabled and I need help.\n\nThanks,\n"
    let encodedSubject =
      subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
    return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
      ?? URL(string: "mailto:\(email)")
  }
}

#Preview {
  AccountDisabledView()
}

