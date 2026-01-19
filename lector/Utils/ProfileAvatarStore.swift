import Foundation

struct ProfileAvatarSelection: Equatable {
  var headAssetName: String
  var faceAssetName: String
  var accessoryAssetName: String

  var hasAny: Bool {
    !headAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !faceAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

enum ProfileAvatarStore {
  static func currentAssetName() -> String? {
    let raw = UserDefaults.standard.string(forKey: AppPreferenceKeys.profileAvatarAssetName) ?? ""
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func setAssetName(_ name: String?) {
    let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.profileAvatarAssetName)
    } else {
      UserDefaults.standard.set(trimmed, forKey: AppPreferenceKeys.profileAvatarAssetName)
    }
  }

  static func currentSelection() -> ProfileAvatarSelection? {
    migrateLegacyAvatarIfNeeded()

    let head =
      (UserDefaults.standard.string(forKey: AppPreferenceKeys.profileAvatarHeadAssetName) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let face =
      (UserDefaults.standard.string(forKey: AppPreferenceKeys.profileAvatarFaceAssetName) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let selection = ProfileAvatarSelection(
      headAssetName: head,
      faceAssetName: face,
      accessoryAssetName: ""
    )
    return selection.hasAny ? selection : nil
  }

  static func setSelection(_ selection: ProfileAvatarSelection?) {
    let head = (selection?.headAssetName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let face = (selection?.faceAssetName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let acc = (selection?.accessoryAssetName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    if head.isEmpty {
      UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.profileAvatarHeadAssetName)
    } else {
      UserDefaults.standard.set(head, forKey: AppPreferenceKeys.profileAvatarHeadAssetName)
    }

    if face.isEmpty {
      UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.profileAvatarFaceAssetName)
    } else {
      UserDefaults.standard.set(face, forKey: AppPreferenceKeys.profileAvatarFaceAssetName)
    }

    // Accessories removed - always clear
    UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.profileAvatarAccessoryAssetName)
  }

  static func randomize() -> ProfileAvatarSelection? {
    migrateLegacyAvatarIfNeeded()

    let heads = ProfileAvatarAssets.heads
    let faces = ProfileAvatarAssets.faces

    guard let head = heads.randomElement(), let face = faces.randomElement() else {
      setSelection(nil)
      return nil
    }

    let next = ProfileAvatarSelection(
      headAssetName: head, faceAssetName: face, accessoryAssetName: "")
    setSelection(next)
    return next
  }

  private static func migrateLegacyAvatarIfNeeded() {
    // If the new layered fields are empty but the legacy `Avatar*` key exists,
    // map it into a face-only selection and add a default head so the user sees a full avatar.
    let existingHead =
      (UserDefaults.standard.string(forKey: AppPreferenceKeys.profileAvatarHeadAssetName) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let existingFace =
      (UserDefaults.standard.string(forKey: AppPreferenceKeys.profileAvatarFaceAssetName) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard existingHead.isEmpty, existingFace.isEmpty else { return }
    guard let legacy = currentAssetName() else { return }

    let mappedFace: String? = {
      switch legacy {
      case "AvatarSmile": return "FaceSmile"
      case "AvatarCalm": return "FaceCalm"
      case "AvatarCheeky": return "FaceCheeky"
      case "AvatarCute": return "FaceCute"
      default: return nil
      }
    }()
    guard let mappedFace else { return }

    // Set a deterministic default head so it's stable after migration.
    let defaultHead = ProfileAvatarAssets.heads.first ?? ""
    setSelection(
      ProfileAvatarSelection(
        headAssetName: defaultHead, faceAssetName: mappedFace, accessoryAssetName: ""))
  }
}
