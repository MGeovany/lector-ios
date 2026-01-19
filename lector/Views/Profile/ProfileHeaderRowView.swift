import SwiftUI

enum ProfilePlanBadge: Equatable {
  case pro
  case founder
}

struct ProfileHeaderRowView: View {
  let name: String
  let email: String
  var avatarURL: URL? = nil
  var badge: ProfilePlanBadge? = nil
  @AppStorage(AppPreferenceKeys.profileAvatarHeadAssetName) private var headAssetName: String = ""
  @AppStorage(AppPreferenceKeys.profileAvatarFaceAssetName) private var faceAssetName: String = ""

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        if let selection, selection.hasAny {
          ProfileAvatarView(selection: selection, size: 54, showBorder: false)
        } else if let avatarURL {
          AsyncImage(url: avatarURL) { phase in
            switch phase {
            case .success(let image):
              image
                .resizable()
                .scaledToFill()
            default:
              Image(systemName: "person.crop.circle.fill")
                .font(.parkinsans(size: CGFloat(34), weight: .regular))
                .foregroundStyle(.secondary)
            }
          }
          .frame(width: 54, height: 54)
          .clipShape(Circle())
        } else {
          Image(systemName: "person.crop.circle.fill")
            .font(.parkinsans(size: CGFloat(34), weight: .regular))
            .foregroundStyle(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 8) {
          Text(name)
            .font(.parkinsansSemibold(size: CGFloat(17)))
            .foregroundStyle(.primary)

          if let badge {
            badgeSquare(badge)
          }
        }

        Text(email)
          .font(.parkinsans(size: CGFloat(13), weight: .regular))
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 2)
  }

  private var selection: ProfileAvatarSelection? {
    let head = headAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
    let face = faceAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
    let direct = ProfileAvatarSelection(headAssetName: head, faceAssetName: face, accessoryAssetName: "")
    return direct.hasAny ? direct : ProfileAvatarStore.currentSelection()
  }

  @ViewBuilder
  private func badgeSquare(_ badge: ProfilePlanBadge) -> some View {
    switch badge {
    case .pro:
      AnimatedBorderBadge(
        text: "PRO",
        colors: [
          Color(red: 0.89, green: 0.80, blue: 1.00),  // ~#E2CBFF
          Color(red: 0.22, green: 0.23, blue: 0.70),  // ~#393BB2
          Color(red: 0.89, green: 0.80, blue: 1.00),
        ],
        textColor: .black,
        innerFill: .white
      )
      .accessibilityLabel("Pro plan")

    case .founder:
      AnimatedBorderBadge(
        text: "FOUNDER",
        colors: [
          Color(red: 1.00, green: 0.86, blue: 0.62),  // light orange
          Color(red: 1.00, green: 0.46, blue: 0.14),  // deep orange
          Color(red: 1.00, green: 0.86, blue: 0.62),
        ],
        textColor: .black,
        innerFill: .white
      )
      .accessibilityLabel("Founder plan")
    }
  }
}

private struct AnimatedBorderBadge: View {
  let text: String
  let colors: [Color]
  let textColor: Color
  let innerFill: Color
  private let cornerRadius: CGFloat = 100  // pill shape

  @State private var rotation: Double = 0

  var body: some View {
    Text(text)
      .font(.parkinsans(size: CGFloat(12), weight: .bold))
      .foregroundStyle(textColor)
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(innerFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .padding(2)
      .background(
        AngularGradient(
          gradient: Gradient(colors: colors),
          center: .center,
          angle: .degrees(rotation)
        ),
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
      .onAppear {
        rotation = 0
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      }
  }
}

#Preview {
  NavigationStack {
    List {
      Section {
        ProfileHeaderRowView(
          name: "Ronald Richards",
          email: "ronaldrichards@gmail.com",
          avatarURL: URL(string: "https://example.com/avatar.png"),
          badge: .pro
        )
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Profile")
  }
}
