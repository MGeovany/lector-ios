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

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 54, height: 54)

                if let avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let badge {
                    badgeView(badge)
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(email)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func badgeView(_ badge: ProfilePlanBadge) -> some View {
        let (text, fill): (String, Color) = {
            switch badge {
            case .pro: return ("PRO", Color(.systemBlue))
            case .founder: return ("F", Color(.systemOrange))
            }
        }()

        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .accessibilityLabel(badge == .pro ? "Pro plan" : "Founder plan")
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

