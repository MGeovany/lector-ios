import SwiftUI

struct HomeHeaderView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(AppSession.self) private var session
  @State private var searchText: String = ""

  var body: some View {
    VStack(alignment: .center, spacing: 10) {
      /*   HStack {
          Text("Lector")
            .font(.custom("CinzelDecorative-Bold", size: 20))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
            .padding(.bottom, 10)
      
          Spacer()
      
          Button(action: {
            // Handle notification tap
          }) {
            Image(systemName: "bell.fill")
              .font(.parkinsansSemibold(size: 18))
              .foregroundStyle(
                colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack
              )
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        } */

      /*  HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text("\(greeting), ")
          .font(.parkinsansBold(size: 28))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.22) : .secondary)

        Text("\(firstName)")
          .font(.parkinsansBold(size: 28))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
      }
      .lineLimit(2)
      .minimumScaleFactor(0.85)
 */

      VStack(alignment: .center, spacing: 16) {
        HStack(alignment: .center, spacing: 0) {
          Text("Library")
            .font(.parkinsansMedium(size: 83))
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.75) : AppColors.matteBlack)

          Spacer()

          Button(action: {
            // Handle add PDF action
          }) {
            Image(systemName: "plus")
              .padding(.top, 10)
              .font(.parkinsansSemibold(size: 44))
              .foregroundStyle(
                colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack
              )
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)

        // Search bar
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .font(.parkinsansMedium(size: 16))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : .secondary)

          TextField("Search", text: $searchText)
            .font(.parkinsansMedium(size: 16))
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.22) : AppColors.matteBlack
            )
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.22) : .secondary
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(

          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.80) : Color.white)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
              colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5),
              lineWidth: 1)
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.bottom, 2)
  }

  private var firstName: String {
    let fullName = session.profile?.displayName ?? "Geovany"
    return fullName.split(separator: " ").first.map(String.init) ?? fullName
  }

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: Date())
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
