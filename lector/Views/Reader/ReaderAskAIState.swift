import SwiftUI

struct ReaderSettingsAskAIView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel
  @ObservedObject var viewModel: ReaderAskAIViewModel
  let onBack: () -> Void

  @FocusState private var isFocused: Bool

  var body: some View {
    let hasMessages = !viewModel.messages.isEmpty

    VStack(spacing: hasMessages ? 12 : 0) {
      if !viewModel.isDocumentAvailable {
        unsyncedDocumentMessage
      } else {
        if viewModel.isAutoIngesting {
          autoIngestProgress
        }
        if hasMessages {
          messageList
            .frame(maxHeight: .infinity)
        }

        if viewModel.showIngestButton {
          Button("Analyze Document") {
            viewModel.ingest()
          }
          .buttonStyle(.borderedProminent)
          .padding(.vertical, 8)
        }

        composer
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hasMessages ? .top : .bottom)
    .padding(.horizontal, 20)
    .padding(.top, hasMessages ? 8 : 0)
    .padding(.bottom, 12)
    .onAppear {
      viewModel.tryAutoIngestIfNeeded()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
        if viewModel.messages.isEmpty && viewModel.isDocumentAvailable {
          isFocused = true
        }
      }
    }
  }

  private var unsyncedDocumentMessage: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "cloud.slash")
        .font(.system(size: 40))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.5))
      Text("Ask AI is only available for documents saved to the cloud.")
        .font(.parkinsans(size: 15, weight: .regular))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      Spacer()
    }
  }

  private var autoIngestProgress: some View {
    HStack(spacing: 8) {
      ProgressView()
        .scaleEffect(0.8)
      Text("Preparing document...")
        .font(.parkinsans(size: 13))
        .foregroundStyle(preferences.theme.surfaceText.opacity(0.6))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }

  private var messageList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 12) {
          ForEach(viewModel.messages) { message in
            messageRow(for: message)
              .id(message.id)
          }
          if viewModel.isLoading {
            HStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("Thinking...")
                .font(.parkinsans(size: 12))
                .foregroundStyle(preferences.theme.surfaceText.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .id("loading")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 6)
      }
      .onAppear { scrollToBottom(proxy) }
      .onChange(of: viewModel.messages) { _, _ in scrollToBottom(proxy) }
      .onChange(of: viewModel.isLoading) { _, loading in
        if loading {
          withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
        } else {
          scrollToBottom(proxy)
        }
      }
    }
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        HStack(spacing: 10) {
          TextField("Ask about the document…", text: $viewModel.prompt, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.parkinsans(size: 15, weight: .regular))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.95))
            .focused($isFocused)
            .lineLimit(1...4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(inputBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        Button {
          let text = viewModel.prompt
          withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            viewModel.send(text)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
          }
        } label: {
          Image(systemName: "arrow.up")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(canSend ? 0.92 : 0.35))
            .frame(width: 38, height: 38)
            .background(preferences.theme.surfaceText.opacity(0.09), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend || viewModel.isLoading)
      }

    }
  }

  private var canSend: Bool {
    let t = viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.count >= 2 && !t.isEmpty
  }

  private var inputBackground: some ShapeStyle {
    if preferences.theme == .night {
      return AnyShapeStyle(Color.white.opacity(0.08))
    }
    return AnyShapeStyle(Color.black.opacity(0.05))
  }

  private func messageRow(for message: ReaderChatMessage) -> some View {
    HStack {
      if message.role == .assistant {
        messageBubble(message, isUser: false)
        Spacer(minLength: 20)
      } else {
        Spacer(minLength: 20)
        messageBubble(message, isUser: true)
      }
    }
  }

  private func messageBubble(_ message: ReaderChatMessage, isUser: Bool) -> some View {
    VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
      Text(message.text)
        .font(.parkinsans(size: 14, weight: .regular))
        .foregroundStyle(isUser ? userTextColor : preferences.theme.surfaceText.opacity(0.92))
        .fixedSize(horizontal: false, vertical: true)  // Wrap text properly

      if let citations = message.citations, !citations.isEmpty {
        Text("Source pages: " + citations.map(String.init).joined(separator: ", "))
          .font(.parkinsans(size: 10))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.6))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      bubbleBackground(isUser: isUser), in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
    .frame(maxWidth: 420, alignment: isUser ? .trailing : .leading)
  }

  private func bubbleBackground(isUser: Bool) -> some ShapeStyle {
    if isUser {
      return AnyShapeStyle(preferences.theme.accent)
    }
    let opacity = preferences.theme == .night ? 0.14 : 0.08
    return AnyShapeStyle(preferences.theme.surfaceText.opacity(opacity))
  }

  private var userTextColor: Color {
    if preferences.theme == .night {
      return Color.black.opacity(0.85)
    }
    return Color.white
  }

  private func scrollToBottom(_ proxy: ScrollViewProxy) {
    guard let last = viewModel.messages.last else { return }
    DispatchQueue.main.async {
      withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
        proxy.scrollTo(last.id, anchor: .bottom)
      }
    }
  }
}
