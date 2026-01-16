import Foundation

#if canImport(Sentry)
  import Sentry
#endif

protocol AuthTokenProviding {
  func bearerToken() -> String?
}

struct KeychainAuthTokenProvider: AuthTokenProviding {
  func bearerToken() -> String? {
    KeychainStore.getString(account: KeychainKeys.authToken)
  }
}

enum APIError: LocalizedError, Equatable {
  case missingAuthToken
  case invalidResponse
  case server(statusCode: Int, message: String)
  case decoding
  case network
  case accountDisabled

  var errorDescription: String? {
    switch self {
    case .missingAuthToken:
      return
        "Missing auth token. Set a Supabase access_token in Keychain (account '\(KeychainKeys.authToken)')."
    case .invalidResponse:
      return "Invalid server response."
    case .server(_, let message):
      return message
    case .decoding:
      return "Failed to decode server response."
    case .network:
      return "Network error."
    case .accountDisabled:
      return "Account disabled"
    }
  }

  /// Returns true if this error represents an account disabled (403) response from backend.
  var isAccountDisabled: Bool {
    switch self {
    case .accountDisabled:
      return true
    case .server(403, let message) where message.lowercased().contains("account disabled"):
      return true
    default:
      return false
    }
  }
}

private struct APIErrorEnvelope: Decodable {
  let error: String
}

private struct EmptyResponse: Decodable {}

final class APIClient {
  private let baseURL: URL
  private let session: URLSession
  private let tokenProvider: AuthTokenProviding
  private let authService: SupabaseAuthServicing

  init(
    baseURL: URL = APIConfig.baseURL,
    session: URLSession = .shared,
    tokenProvider: AuthTokenProviding = KeychainAuthTokenProvider(),
    authService: SupabaseAuthServicing = SupabaseAuthService()
  ) {
    self.baseURL = baseURL
    self.session = session
    self.tokenProvider = tokenProvider
    self.authService = authService
  }

  func get<T: Decodable>(_ path: String) async throws -> T {
    var request = try makeRequest(path: path, method: "GET")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return try await send(request, decode: T.self)
  }

  func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> T {
    let url = try makeURL(path: path, queryItems: queryItems)
    var request = try makeRequest(url: url, method: "GET")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return try await send(request, decode: T.self)
  }

  func postMultipart<T: Decodable>(
    _ path: String,
    fileData: Data,
    fileName: String,
    fieldName: String = "file",
    mimeType: String = "application/pdf"
  ) async throws -> T {
    let boundary = "Boundary-\(UUID().uuidString)"
    var request = try makeRequest(path: path, method: "POST")
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    body.appendString("--\(boundary)\r\n")
    body.appendString(
      "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
    body.appendString("Content-Type: \(mimeType)\r\n\r\n")
    body.append(fileData)
    body.appendString("\r\n--\(boundary)--\r\n")

    request.httpBody = body
    return try await send(request, decode: T.self)
  }

  func postJSON<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
    var request = try makeRequest(path: path, method: "POST")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(body)
    return try await send(request, decode: T.self)
  }

  func postJSON<Body: Encodable>(_ path: String, body: Body) async throws {
    _ = try await postJSON(path, body: body) as EmptyResponse
  }

  func putJSON<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
    var request = try makeRequest(path: path, method: "PUT")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(body)
    return try await send(request, decode: T.self)
  }

  func putJSON<Body: Encodable>(_ path: String, body: Body) async throws {
    _ = try await putJSON(path, body: body) as EmptyResponse
  }

  func delete(_ path: String) async throws {
    let request = try makeRequest(path: path, method: "DELETE")
    _ = try await send(request, decode: EmptyResponse.self)
  }

  // MARK: - Internals

  private func makeRequest(path: String, method: String) throws -> URLRequest {
    let url = baseURL.appendingPathComponent(
      path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    return try makeRequest(url: url, method: method)
  }

  private func makeRequest(url: URL, method: String) throws -> URLRequest {
    guard let token = tokenProvider.bearerToken(), !token.isEmpty else {
      #if canImport(Sentry)
        let crumb = Breadcrumb(level: .warning, category: "api")
        crumb.message = "missing_auth_token"
        crumb.data = [
          "method": method,
          "url": url.absoluteString,
        ]
        SentrySDK.addBreadcrumb(crumb)
      #endif
      throw APIError.missingAuthToken
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30
    return request
  }

  private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
    let base = baseURL.appendingPathComponent(
      path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
      throw APIError.invalidResponse
    }
    components.queryItems = queryItems.isEmpty ? nil : queryItems
    guard let url = components.url else {
      throw APIError.invalidResponse
    }
    return url
  }

  private func send<T: Decodable>(_ request: URLRequest, decode: T.Type) async throws -> T {
    try await send(request, decode: decode, didRetryAfterRefresh: false)
  }

  private func send<T: Decodable>(
    _ request: URLRequest,
    decode: T.Type,
    didRetryAfterRefresh: Bool
  ) async throws -> T {
    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
      }

      if !(200...299).contains(http.statusCode) {
        #if canImport(Sentry)
          let crumb = Breadcrumb(level: http.statusCode >= 500 ? .error : .warning, category: "api")
          crumb.message = "http_error"
          crumb.data = [
            "status": http.statusCode,
            "method": request.httpMethod ?? "",
            "url": request.url?.absoluteString ?? "",
            "did_retry_after_refresh": didRetryAfterRefresh,
          ]
          SentrySDK.addBreadcrumb(crumb)
        #endif

        // Attempt a single refresh+retry on auth failures.
        if http.statusCode == 401, !didRetryAfterRefresh {
          if let refreshed = try? await refreshAccessTokenIfPossible() {
            var retry = request
            retry.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
            return try await send(retry, decode: decode, didRetryAfterRefresh: true)
          }
        }

        let message: String =
          (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error)
          ?? String(data: data, encoding: .utf8)
          ?? "Request failed."
        // Convert 403 "Account disabled" to a dedicated error case for easier UI handling.
        if http.statusCode == 403, message.lowercased().contains("account disabled") {
          throw APIError.accountDisabled
        }

        let err = APIError.server(statusCode: http.statusCode, message: message)
        if http.statusCode >= 500 {
          #if canImport(Sentry)
            let event = Event(error: err)
            event.level = .error
            event.extra = [
              "status": String(http.statusCode),
              "method": request.httpMethod ?? "",
              "url": request.url?.absoluteString ?? "",
              "did_retry_after_refresh": String(didRetryAfterRefresh),
            ]
            // Group by endpoint+status (helps spot repetition) without exploding cardinality.
            event.fingerprint = [
              "api_server_error",
              String(http.statusCode),
              request.httpMethod ?? "",
              request.url?.path ?? "",
            ]
            SentrySDK.capture(event: event)
          #endif
        }
        throw err
      }

      do {
        return try APIClient.jsonDecoder.decode(T.self, from: data)
      } catch {
        #if canImport(Sentry)
          let event = Event(error: APIError.decoding)
          event.level = .error
          event.extra = [
            "method": request.httpMethod ?? "",
            "url": request.url?.absoluteString ?? "",
          ]
          event.fingerprint = [
            "api_decoding_failed", request.httpMethod ?? "", request.url?.path ?? "",
          ]
          SentrySDK.capture(event: event)
        #endif
        throw APIError.decoding
      }
    } catch let apiError as APIError {
      throw apiError
    } catch {
      #if canImport(Sentry)
        let event = Event(error: error)
        event.level = .error
        event.extra = [
          "method": request.httpMethod ?? "",
          "url": request.url?.absoluteString ?? "",
        ]
        event.fingerprint = [
          "api_network_error", request.httpMethod ?? "", request.url?.path ?? "",
        ]
        SentrySDK.capture(event: event)
      #endif
      throw APIError.network
    }
  }

  private func refreshAccessTokenIfPossible() async throws -> String? {
    let refresh = KeychainStore.getString(account: KeychainKeys.refreshToken) ?? ""
    guard !refresh.isEmpty else { return nil }

    let newSession = try await authService.refreshSession(refreshToken: refresh)
    KeychainStore.setString(newSession.accessToken, account: KeychainKeys.authToken)
    if let newRefresh = newSession.refreshToken, !newRefresh.isEmpty {
      KeychainStore.setString(newRefresh, account: KeychainKeys.refreshToken)
    }
    KeychainStore.setString(newSession.userID, account: KeychainKeys.userID)
    return newSession.accessToken
  }

  private static let jsonDecoder: JSONDecoder = {
    let decoder = JSONDecoder()

    // RFC3339 / RFC3339Nano (with/without fractional seconds)
    let base = ISO8601DateFormatter()
    base.formatOptions = [.withInternetDateTime]

    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let str = try container.decode(String.self)
      if let d = fractional.date(from: str) ?? base.date(from: str) {
        return d
      }
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid date: \(str)")
    }

    return decoder
  }()
}

extension ISO8601DateFormatter {
  /// RFC3339 without fractional seconds (safe default for query params).
  static let lectorInternetDateTime: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()
}

extension Data {
  fileprivate mutating func appendString(_ string: String) {
    if let data = string.data(using: .utf8) {
      append(data)
    }
  }
}
