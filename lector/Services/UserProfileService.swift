import Foundation

protocol UserProfileServicing {
  func getProfile() async throws -> UserProfile
  func requestAccountDeletion() async throws
}

final class GoUserProfileService: UserProfileServicing {
  private let api: APIClient

  init(api: APIClient = APIClient()) {
    self.api = api
  }

  func getProfile() async throws -> UserProfile {
    try await api.get("auth/profile")
  }

  func requestAccountDeletion() async throws {
    // Call backend endpoint to mark account_disabled = true in DB.
    try await api.postJSON("auth/account-deletion-request", body: EmptyRequest())
  }
}

private struct EmptyRequest: Encodable {}
