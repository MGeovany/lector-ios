import SwiftUI

enum HighlightShareFormat: String, CaseIterable, Identifiable {
  case wide
  case square

  var id: String { rawValue }

  var title: String {
    switch self {
    case .wide: return "Wide"
    case .square: return "Square"
    }
  }

  /// Output size aimed at Instagram exports.
  /// - Wide: Story (9:16)
  /// - Square: Feed (1:1)
  var outputSize: CGSize {
    switch self {
    case .wide: return CGSize(width: 1080, height: 1920)
    case .square: return CGSize(width: 1080, height: 1080)
    }
  }
}

struct HighlightShareDraft: Equatable {
  var quote: String
  var bookTitle: String
  var author: String
  var format: HighlightShareFormat = .wide
}

struct HighlightShareEditorView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let quote: String
  let bookTitle: String
  let author: String
  let documentID: String?
  let pageNumber: Int?
  let progress: Double?
  let onDismiss: () -> Void
  private let highlightsService: HighlightsServicing

  @State private var draft: HighlightShareDraft
  @State private var isSaving: Bool = false
  @State private var isPersistingOnly: Bool = false
  @State private var showToast: Bool = false
  @State private var toastMessage: String = "Couldn’t share image."
  @State private var shareImage: UIImage?
  @State private var showShareSheet: Bool = false

  /// Renders a share-ready image (Instagram-friendly) for a highlight.
  @MainActor
  static func renderShareImage(
    quote: String,
    bookTitle: String,
    author: String,
    font: ReadingFont,
    fontSize: Double,
    lineSpacing: Double,
    theme: ReadingTheme
  ) async throws -> UIImage {
    let draft = HighlightShareDraft(
      quote: quote,
      bookTitle: bookTitle,
      author: author,
      format: .wide
    )
    return try await HighlightShareRenderer.render(
      draft: draft,
      font: font,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      theme: theme
    )
  }

  init(
    quote: String,
    bookTitle: String,
    author: String,
    documentID: String? = nil,
    pageNumber: Int? = nil,
    progress: Double? = nil,
    highlightsService: HighlightsServicing = GoHighlightsService(),
    onDismiss: @escaping () -> Void = {}
  ) {
    self.quote = quote
    self.bookTitle = bookTitle
    self.author = author
    self.documentID = documentID
    self.pageNumber = pageNumber
    self.progress = progress
    self.highlightsService = highlightsService
    self.onDismiss = onDismiss
    _draft = State(
      initialValue: HighlightShareDraft(
        quote: quote,
        bookTitle: bookTitle,
        author: author,
        format: .wide
      )
    )
  }

  private var currentDraft: HighlightShareDraft {
    HighlightShareDraft(
      quote: quote,
      bookTitle: bookTitle,
      author: author,
      // Always export at the Instagram Stories "gold standard" size: 1080×1920 (9:16).
      format: .wide
    )
  }

  var body: some View {
    GeometryReader { geo in
      let maxOverlayHeight = geo.size.height * 0.60

      ZStack {
        // Dark background overlay
        Color.black.opacity(preferences.theme == .night ? 0.78 : 0.68)
          .ignoresSafeArea()
          .onTapGesture {
            onDismiss()
          }

        // Centered content
        VStack(spacing: 16) {
          previewCard
          buttons
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        // Keep it compact like the reference (content-driven height).
        .frame(maxWidth: 420)
        .frame(maxHeight: maxOverlayHeight)
        .sheet(isPresented: $showShareSheet) {
          if let shareImage {
            ShareSheet(activityItems: [shareImage])
          } else {
            ShareSheet(activityItems: [])
          }
        }

        // Toast message
        if showToast {
          VStack {
            Spacer()
            Text(toastMessage)
              .font(.parkinsans(size: CGFloat(15), weight: .medium))
              .foregroundStyle(.white)
              .padding(.horizontal, 20)
              .padding(.vertical, 12)
              .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(Color.black.opacity(0.8))
              )
              .padding(.bottom, 50)
          }
          .transition(.opacity.combined(with: .scale(scale: 0.9)))
          .zIndex(1)
        }
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showToast)
    }
  }

  private var previewCard: some View {
    HighlightCardView(
      quote: currentDraft.quote,
      author: currentDraft.author,
      title: currentDraft.bookTitle,
      font: preferences.font,
      fontSize: preferences.fontSize,
      lineSpacing: preferences.lineSpacing,
      theme: preferences.theme,
      // Modal: show a lot more text before truncating, but still respect user prefs.
      quoteScale: 1.0,
      metadataFontSize: CGFloat(preferences.fontSize * 0.8),
      maxQuoteLines: 16,
      maxWords: 280
    )
    .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
  }

  private var buttons: some View {
    VStack(spacing: 8) {
      Button {
        Task { await persistOnly() }
      } label: {
        HStack(spacing: 8) {
          if isPersistingOnly {
            ProgressView().tint(AppColors.primaryActionForeground)
          } else {
            Text("Save Highlight")
            Image(systemName: "bookmark.fill")
              .font(.system(size: 16, weight: .semibold))
          }
        }
      }
      .buttonStyle(LectorCompactCapsuleButtonStyle())
      .disabled(isSaving || isPersistingOnly)
      .opacity((isSaving || isPersistingOnly) ? 0.7 : 1.0)

      Button {
        Task { await shareOrSave() }
      } label: {
        HStack(spacing: 8) {
          if isSaving {
            ProgressView().tint(AppColors.primaryActionForeground)
          } else {
            Text("Share Highlight")
            Image("ActionShare")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 18, height: 18)
          }
        }
      }
      .buttonStyle(LectorCompactCapsuleButtonStyle())
      .disabled(isSaving || isPersistingOnly)
      .opacity((isSaving || isPersistingOnly) ? 0.7 : 1.0)
    }
  }

  private func persistOnly() async {
    guard !isPersistingOnly, !isSaving else { return }
    isPersistingOnly = true
    defer { isPersistingOnly = false }

    guard let documentID, !documentID.isEmpty else { return }
    let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    do {
      _ = try await highlightsService.createHighlight(
        documentID: documentID,
        quote: trimmed,
        pageNumber: pageNumber,
        progress: progress
      )

      PostHogAnalytics.capture("highlight_created", properties: ["document_id": documentID])
      toastMessage = "Highlight saved."
      withAnimation { showToast = true }
      try? await Task.sleep(nanoseconds: 1_250_000_000)
      withAnimation { showToast = false }
    } catch {
      let msg = (error as? LocalizedError)?.errorDescription ?? "Couldn’t save highlight."
      toastMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "create_highlight"])
      withAnimation { showToast = true }
      try? await Task.sleep(nanoseconds: 1_800_000_000)
      withAnimation { showToast = false }
    }
  }

  private func shareOrSave() async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }

    do {
      async let _ = persistHighlightIfPossible()

      let img = try await HighlightShareRenderer.render(
        draft: currentDraft,
        font: preferences.font,
        fontSize: preferences.fontSize,
        lineSpacing: preferences.lineSpacing,
        theme: preferences.theme
      )
      // Keep a reference for the share sheet.
      shareImage = img
      // Present the native iOS share sheet with all actions (Instagram, Save Image, etc).
      // If the user picks "Save Image", iOS will save to Photos.
      await MainActor.run { showShareSheet = true }
    } catch {
      let msg = (error as? LocalizedError)?.errorDescription ?? "Couldn’t share image."
      toastMessage = msg
      PostHogAnalytics.captureError(message: msg, context: ["action": "share_highlight"])
      // Show error toast
      withAnimation {
        showToast = true
      }

      try? await Task.sleep(nanoseconds: 2_000_000_000)

      withAnimation {
        showToast = false
      }
    }
  }

  private func persistHighlightIfPossible() async {
    guard let documentID, !documentID.isEmpty else { return }
    let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do {
      _ = try await highlightsService.createHighlight(
        documentID: documentID,
        quote: trimmed,
        pageNumber: pageNumber,
        progress: progress
      )
      PostHogAnalytics.capture("highlight_created", properties: ["document_id": documentID])
    } catch {
      PostHogAnalytics.captureError(
        message: (error as? LocalizedError)?.errorDescription ?? "Highlight persist failed.",
        context: ["action": "persist_highlight_share"]
      )
    }
  }
}

private struct ShareSheet: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct HighlightShareCanvasView: View {
  let draft: HighlightShareDraft
  let font: ReadingFont
  let fontSize: Double
  let lineSpacing: Double
  let theme: ReadingTheme

  var body: some View {
    GeometryReader { geo in
      ZStack {
        // Export style: keep the same layout, but match the current reading theme
        // (day/night/amber) instead of always exporting on a white canvas.
        theme.surfaceBackground

        let tuned = ShareTuning.make(quote: draft.quote, baseFontSize: fontSize)
        // Keep a "readable column" width. For Instagram Story (wide format),
        // we intentionally use a narrower column so the first line doesn't run too long.
        let widthRatio: CGFloat = {
          switch draft.format {
          case .wide:
            return 0.52
          case .square:
            return 0.74
          }
        }()
        let maxCardWidth: CGFloat = (draft.format == .wide) ? 600 : 760
        let cardWidth = min(geo.size.width * widthRatio, maxCardWidth)

        let contentPaddingHorizontal: CGFloat = (draft.format == .wide) ? 26 : 20

        HighlightCardView(
          quote: draft.quote,
          author: draft.author,
          title: draft.bookTitle,
          font: font,
          // Use an export-tuned base font size (not too small for long text).
          fontSize: tuned.exportFontSize,
          lineSpacing: lineSpacing,
          theme: theme,
          quoteScale: tuned.quoteScale,
          metadataFontSize: tuned.metadataFontSize,
          maxQuoteLines: tuned.maxQuoteLines,
          maxWords: tuned.maxWords,
          contentPaddingHorizontal: contentPaddingHorizontal,
          palette: .export(for: theme)
        )
        .frame(width: cardWidth)
        .shadow(color: Color.black.opacity(0.18), radius: 28, x: 0, y: 16)
      }
    }
  }
}

private struct ShareTuning {
  let exportFontSize: Double
  let quoteScale: CGFloat
  let metadataFontSize: CGFloat
  let maxQuoteLines: Int
  let maxWords: Int

  static func make(quote: String, baseFontSize: Double) -> ShareTuning {
    // Word count heuristic to keep long quotes readable without shrinking too much.
    let words = quote.split { $0.isWhitespace || $0.isNewline }
    let count = words.count

    // Make sure exports never start from a "tiny" base.
    let exportBase = max(baseFontSize, 20)

    // Longer text: slightly smaller scale + allow a few more lines.
    let quoteScale: CGFloat = {
      switch count {
      case 0...60: return 1.38
      case 61...120: return 1.30
      case 121...200: return 1.20
      default: return 1.12
      }
    }()

    let maxLines: Int = {
      switch count {
      case 0...120: return 14
      case 121...220: return 16
      default: return 18
      }
    }()

    let maxWords: Int = {
      // Keep the image compact; more words would force tiny text or excessive truncation.
      switch count {
      case 0...160: return 260
      default: return 320
      }
    }()

    return ShareTuning(
      exportFontSize: exportBase,
      quoteScale: quoteScale,
      metadataFontSize: CGFloat(exportBase * 0.95),
      maxQuoteLines: maxLines,
      maxWords: maxWords
    )
  }
}

private struct HighlightCardPalette: Equatable {
  let cardBackground: Color
  let primary: Color
  let secondary: Color
  let bar: Color
  let border: Color

  static func export(for theme: ReadingTheme) -> HighlightCardPalette {
    // Ensure exports always match the selected reading theme.
    // Use theme-aware colors for background/text, and use the theme accent for the bar.
    let primary = theme.surfaceText
    let border = primary.opacity(theme == .night ? 0.14 : 0.10)
    return HighlightCardPalette(
      cardBackground: theme.surfaceBackground,
      primary: primary,
      secondary: theme.surfaceSecondaryText,
      bar: theme.accent,
      border: border
    )
  }
}

private struct HighlightCardView: View {
  let quote: String
  let author: String
  let title: String
  let font: ReadingFont
  let fontSize: Double
  let lineSpacing: Double
  let theme: ReadingTheme
  let quoteScale: CGFloat
  let metadataFontSize: CGFloat
  let maxQuoteLines: Int
  let maxWords: Int
  let contentPaddingHorizontal: CGFloat
  let palette: HighlightCardPalette?

  // Match the reference card: longer quote with trailing ellipsis when it overflows.
  private var truncatedQuote: String {
    let normalized = quote.replacingOccurrences(of: "\r\n", with: "\n")

    // Prefer showing up to ~2 paragraphs (blank-line separated), like the reference.
    let paragraphs =
      normalized
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    let base: String = {
      if paragraphs.count >= 2 {
        return paragraphs.prefix(2).joined(separator: "\n\n")
      }
      return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    // Then cap by word count so it doesn't get too long.
    let words = base.split { $0.isWhitespace || $0.isNewline }.map(String.init)
    guard words.count > maxWords else { return base }
    return words.prefix(maxWords).joined(separator: " ") + "…"
  }

  // Calculate quote font size (larger for emphasis)
  private var quoteFontSize: CGFloat {
    CGFloat(fontSize) * quoteScale
  }

  init(
    quote: String,
    author: String,
    title: String,
    font: ReadingFont,
    fontSize: Double,
    lineSpacing: Double,
    theme: ReadingTheme,
    quoteScale: CGFloat = 1.05,
    metadataFontSize: CGFloat = 13,
    maxQuoteLines: Int = 9,
    maxWords: Int = 170,
    contentPaddingHorizontal: CGFloat = 20,
    palette: HighlightCardPalette? = nil
  ) {
    self.quote = quote
    self.author = author
    self.title = title
    self.font = font
    self.fontSize = fontSize
    self.lineSpacing = lineSpacing
    self.theme = theme
    self.quoteScale = quoteScale
    self.metadataFontSize = metadataFontSize
    self.maxQuoteLines = maxQuoteLines
    self.maxWords = maxWords
    self.contentPaddingHorizontal = contentPaddingHorizontal
    self.palette = palette
  }

  var body: some View {
    let cardBackground = palette?.cardBackground ?? theme.surfaceBackground
    let primary = palette?.primary ?? theme.surfaceText
    let secondary = palette?.secondary ?? theme.surfaceSecondaryText
    let bar = palette?.bar ?? primary
    let border = palette?.border ?? primary.opacity(theme == .night ? 0.14 : 0.10)

    VStack(alignment: .leading, spacing: 12) {
      Text("Lector")
        .font(.custom("CinzelDecorative-Bold", size: 22))
        .foregroundStyle(primary)
        .lineLimit(1)
        .padding(.bottom, 16)
        .padding(.leading, 20)

      HStack(alignment: .top, spacing: 16) {

        // Thick vertical black line on the left.
        // IMPORTANT: give it an explicit height so it doesn't expand to fill the full-screen proposal.

        Rectangle()
          .fill(bar)
          .cornerRadius(16)
          .frame(width: 5)
          .padding(.top, 2)
          .padding(.bottom, 2)

        VStack(alignment: .leading, spacing: 12) {
          if quote.isEmpty {
            Text("No text selected")
              .font(font.font(size: quoteFontSize, weight: .bold))
              .foregroundStyle(secondary)
              .italic()
          } else {
            Text(truncatedQuote)
              .font(font.font(size: quoteFontSize, weight: .bold))
              .foregroundStyle(primary)
              .lineSpacing(CGFloat(fontSize * (lineSpacing - 1)))
              .lineLimit(maxQuoteLines)
              .truncationMode(.tail)
          }

          VStack(alignment: .leading, spacing: 2) {
            if !author.isEmpty {
              Text(author)
                .font(font.font(size: metadataFontSize, weight: .bold))
                .foregroundStyle(primary)
                .lineLimit(1)
                .padding(.top, 8)
            } else {
              Text("Unknown author")
                .font(font.font(size: metadataFontSize, weight: .bold))
                .foregroundStyle(primary)
                .lineLimit(1)
                .padding(.top, 8)
            }
            if !title.isEmpty {
              Text(title)
                .font(font.font(size: metadataFontSize, weight: .regular))
                .foregroundStyle(secondary)
                .lineLimit(1)
            }

          }
        }

        Spacer(minLength: 0)
      }
    }
    .padding(.vertical, 20)
    .padding(.horizontal, contentPaddingHorizontal)
    .background(
      cardBackground,
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(border, lineWidth: 1)
    )
    // Prevent the card from stretching vertically; keep it content-sized.
    .fixedSize(horizontal: false, vertical: true)
  }
}

private enum HighlightShareRenderer {
  @MainActor
  static func render(
    draft: HighlightShareDraft,
    font: ReadingFont,
    fontSize: Double,
    lineSpacing: Double,
    theme: ReadingTheme
  ) async throws -> UIImage {
    let size = draft.format.outputSize
    let view = HighlightShareCanvasView(
      draft: draft,
      font: font,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      theme: theme
    )
    .frame(width: size.width, height: size.height)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    if let img = renderer.uiImage {
      return img
    }
    struct RenderError: LocalizedError {
      var errorDescription: String? { "Failed to render image." }
    }
    throw RenderError()
  }
}
