import SwiftUI

struct EditProfilePictureSheetView: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage(AppPreferenceKeys.profileAvatarHeadAssetName) private var headAssetName: String = ""
  @AppStorage(AppPreferenceKeys.profileAvatarFaceAssetName) private var faceAssetName: String = ""

  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        avatarPreview

        Text("You can randomly generate a new profile picture.")
          .font(.parkinsans(size: 13, weight: .regular))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button {
          _ = ProfileAvatarStore.randomize()
        } label: {
          HStack(spacing: 10) {
            Text("Random")
            Image(systemName: "shuffle")
          }
        }
        .buttonStyle(LectorPrimaryCapsuleButtonStyle())
        .padding(.top, 4)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .navigationTitle("Profile picture")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var avatarPreview: some View {
    ProfileAvatarView(selection: selection, size: 96, showBorder: true)
      .padding(.top, 2)
  }

  private var selection: ProfileAvatarSelection? {
    // Use stored fields if present; fall back to store migration if needed.
    let head = headAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
    let face = faceAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
    let direct = ProfileAvatarSelection(
      headAssetName: head, faceAssetName: face, accessoryAssetName: "")
    return direct.hasAny ? direct : ProfileAvatarStore.currentSelection()
  }
}
