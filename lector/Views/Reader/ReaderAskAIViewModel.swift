import Combine
import SwiftUI

struct ReaderChatMessage: Identifiable, Equatable {
  enum Role {
    case user
    case assistant
  }

  let id = UUID()
  let role: Role
  let text: String
  let citations: [Int]?
}

@MainActor
class ReaderAskAIViewModel: ObservableObject {
  @Published var prompt: String = ""
  @Published var messages: [ReaderChatMessage] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String? = nil
  @Published var sessionID: String? = nil
  @Published var showIngestButton: Bool = false
  @Published var isAutoIngesting: Bool = false

  let documentID: String
  private let aiService: AIServicing
  private var hasTriedAutoIngest: Bool = false

  /// Current page the user is viewing (1-based). Set by ReaderView so the AI can answer "what page am I on?".
  var currentPage: Int?
  /// Total pages in the document. Set by ReaderView.
  var totalPages: Int?

  /// Ask AI only works for documents synced to the server (has remote ID).
  var isDocumentAvailable: Bool { !documentID.isEmpty }

  init(documentID: String, aiService: AIServicing = AIService()) {
    self.documentID = documentID
    self.aiService = aiService
  }

  /// Call when Ask AI panel opens: ensures the document is ingested on the server so the AI has context.
  func tryAutoIngestIfNeeded() {
    guard isDocumentAvailable else { return }
    guard !hasTriedAutoIngest else { return }
    hasTriedAutoIngest = true
    isAutoIngesting = true
    Task {
      defer { isAutoIngesting = false }
      do {
        try await aiService.ingestDocument(documentID: documentID)
        showIngestButton = false
      } catch {
        showIngestButton = true
      }
    }
  }

  func loadHistory() {
    // TODO: Implement load history if we persist session ID locally
  }

  private static let minPromptLength = 2
  private static let maxPromptLength = 2000

  func send(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard trimmed.count >= Self.minPromptLength else {
      errorMessage = "Please ask a short question about the document."
      return
    }
    let promptToSend = String(trimmed.prefix(Self.maxPromptLength))

    let userMsg = ReaderChatMessage(role: .user, text: promptToSend, citations: nil)
    messages.append(userMsg)
    prompt = ""
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let response = try await aiService.ask(
          documentID: documentID,
          sessionID: sessionID,
          prompt: promptToSend,
          currentPage: currentPage,
          totalPages: totalPages
        )
        self.sessionID = response.sessionID
        let modelMsg = ReaderChatMessage(
          role: .assistant, text: response.message, citations: response.citations)
        self.messages.append(modelMsg)
        PostHogAnalytics.capture("ask_ai_used", properties: ["document_id": documentID])
      } catch {
        self.errorMessage = error.localizedDescription
        self.messages.append(
          ReaderChatMessage(
            role: .assistant, text: "Error: \(error.localizedDescription)", citations: nil))
        PostHogAnalytics.captureError(
          message: error.localizedDescription,
          context: ["action": "ask_ai", "document_id": documentID]
        )
        if error.localizedDescription.localizedCaseInsensitiveContains("no content") {
          self.showIngestButton = true
        }
      }
      self.isLoading = false
    }
  }

  func ingest() {
    isLoading = true
    Task {
      do {
        try await aiService.ingestDocument(documentID: documentID)
        self.messages.append(
          ReaderChatMessage(
            role: .assistant, text: "Document processed. You can now ask questions.", citations: nil
          ))
        self.showIngestButton = false
      } catch {
        self.errorMessage = error.localizedDescription
        self.showIngestButton = true
        self.messages.append(
          ReaderChatMessage(
            role: .assistant, text: "Ingest failed: \(error.localizedDescription)", citations: nil))
      }
      isLoading = false
    }
  }
}
