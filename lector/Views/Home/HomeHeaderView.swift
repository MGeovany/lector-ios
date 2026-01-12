import SwiftUI

struct HomeHeaderView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(AppSession.self) private var session

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Lector")
          .font(.custom("CinzelDecorative-Bold", size: 16))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : .primary)
        Spacer()
      }

      Text("\(greeting), \(session.profile?.displayName ?? "Reader")")
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)

      Text("Your library")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 8)
    .padding(.bottom, 2)
  }

  private var greeting: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return "Good morning"
    case 12..<18: return "Good afternoon"
    default: return "Good evening"
    }
  }
}
