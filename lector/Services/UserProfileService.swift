import Foundation

protocol UserProfileServicing {
  func getProfile() async throws -> UserProfile
}

final class GoUserProfileService: UserProfileServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func getProfile() async throws -> UserProfile {
    try await api.get("auth/profile")
  }
}
