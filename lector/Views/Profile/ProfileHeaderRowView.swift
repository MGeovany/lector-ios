import SwiftUI

struct ProfileHeaderRowView: View {
    let name: String
    let email: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 54, height: 54)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(.secondary)
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
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        List {
            Section {
                ProfileHeaderRowView(name: "Ronald Richards", email: "ronaldrichards@gmail.com")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
    }
}

