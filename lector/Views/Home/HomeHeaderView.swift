import SwiftUI

struct HomeHeaderView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var searchText: String
  var onAddTapped: (() -> Void)? = nil

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
            print("🔵 [HomeHeaderView] Plus button tapped")
            print("🔵 [HomeHeaderView] onAddTapped is nil: \(onAddTapped == nil)")
            onAddTapped?()
            print("🔵 [HomeHeaderView] onAddTapped called")
          }) {
            Image(systemName: "plus")
              .padding(.top, 14)
              .font(.parkinsans(size: 44, weight: .light))
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
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

          TextField("Search", text: $searchText)
            .font(.parkinsansMedium(size: 16))
            .foregroundStyle(
              colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack
            )
            .tint(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

          if !searchText.isEmpty {
            Button {
              searchText = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear search")
          }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(

          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color(.systemBackground))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
              colorScheme == .dark ? Color.white.opacity(0.14) : Color(.separator).opacity(0.35),
              lineWidth: 1)
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.bottom, 2)
  }

  // Note: we intentionally keep this header decoupled from session state for now.
}
