import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
  let text: String
  let font: UIFont
  let textColor: UIColor
  let lineSpacing: CGFloat
  let textAlignment: NSTextAlignment
  let highlightQuery: String?
  let highlightQuotes: [String]
  let showHighlightsInText: Bool
  let highlightColor: UIColor
  let highlightOpacity: CGFloat
  let clearSelectionToken: Int
  let onShareSelection: (String) -> Void

  #if DEBUG
  private static let debugScrollLogs: Bool = true
  #else
  private static let debugScrollLogs: Bool = false
  #endif

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiView: ShareableSelectionTextView,
    context: Context
  ) -> CGSize {
    let proposedWidth = proposal.width ?? (uiView.bounds.width > 0 ? uiView.bounds.width : 300)
    guard proposedWidth > 0 else { return CGSize(width: 0, height: 0) }

    uiView.textContainer.size = CGSize(width: proposedWidth, height: .greatestFiniteMagnitude)
    uiView.textContainer.widthTracksTextView = false
    uiView.textContainer.heightTracksTextView = false

    if uiView.attributedText.length == 0 && !text.isEmpty {
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineSpacing = lineSpacing
      paragraph.alignment = textAlignment
      paragraph.lineBreakMode = .byWordWrapping
      let attr = NSMutableAttributedString(
        string: text,
        attributes: [
          .font: font,
          .foregroundColor: textColor,
          .paragraphStyle: paragraph,
        ]
      )
      uiView.attributedText = attr
    }

    uiView.layoutManager.ensureLayout(for: uiView.textContainer)
    let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
    let height = ceil(usedRect.height)

    if Self.debugScrollLogs {
      print(
        "[SelectableTextView] sizeThatFits width=\(proposedWidth) usedHeight=\(height) textLen=\(text.count) uiBounds=\(uiView.bounds.size)"
      )
    }

    return CGSize(width: proposedWidth, height: max(height, 1))
  }

  func makeUIView(context: Context) -> ShareableSelectionTextView {
    let v = ShareableSelectionTextView()
    v.onShareSelection = onShareSelection
    v.isEditable = false
    v.isSelectable = true
    v.isScrollEnabled = false
    v.backgroundColor = .clear
    v.textContainerInset = .zero
    v.textContainer.lineFragmentPadding = 0
    v.textContainer.widthTracksTextView = false
    v.textContainer.heightTracksTextView = false
    v.adjustsFontForContentSizeCategory = true

    v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    v.setContentHuggingPriority(.defaultLow, for: .horizontal)
    v.setContentCompressionResistancePriority(.required, for: .vertical)
    v.setContentHuggingPriority(.required, for: .vertical)

    return v
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func updateUIView(_ uiView: ShareableSelectionTextView, context: Context) {
    uiView.onShareSelection = onShareSelection
    uiView.lectorPreferParentScrollViewForPans(debug: Self.debugScrollLogs)

    if context.coordinator.lastClearSelectionToken != clearSelectionToken {
      context.coordinator.lastClearSelectionToken = clearSelectionToken
      uiView.selectedRange = NSRange(location: 0, length: 0)
      uiView.resignFirstResponder()
    }

    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    paragraph.alignment = textAlignment
    paragraph.lineBreakMode = .byWordWrapping

    let attr = NSMutableAttributedString(
      string: text,
      attributes: [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraph,
      ]
    )

    if showHighlightsInText {
      let bgColor = highlightColor.withAlphaComponent(highlightOpacity)
      let full = text as NSString

      for quote in highlightQuotes {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        for range in Self.rangesOfQuote(trimmed, in: full) {
          attr.addAttribute(.backgroundColor, value: bgColor, range: range)
        }
      }

      if let highlightQuery,
        !highlightQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        let query = highlightQuery.lowercased()
        let fullLower = text.lowercased() as NSString
        var range = NSRange(location: 0, length: fullLower.length)
        while true {
          let found = fullLower.range(of: query, options: [], range: range)
          if found.location == NSNotFound { break }
          attr.addAttribute(.backgroundColor, value: highlightColor.withAlphaComponent(highlightOpacity), range: found)
          let nextLoc = found.location + max(1, found.length)
          if nextLoc >= fullLower.length { break }
          range = NSRange(location: nextLoc, length: fullLower.length - nextLoc)
        }
      }
    }

    if uiView.attributedText != attr {
      let currentSelection = uiView.selectedRange
      uiView.attributedText = attr
      if currentSelection.location != NSNotFound,
        currentSelection.location <= attr.length
      {
        let maxLen = max(0, attr.length - currentSelection.location)
        let len = min(currentSelection.length, maxLen)
        uiView.selectedRange = NSRange(location: currentSelection.location, length: len)
      }
      uiView.invalidateIntrinsicContentSize()
    }

    let containerWidth = max(1, uiView.bounds.width > 0 ? uiView.bounds.width : 300)
    uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
    uiView.textContainer.widthTracksTextView = false
    uiView.textContainer.heightTracksTextView = false

    uiView.layoutManager.ensureLayout(for: uiView.textContainer)
    uiView.invalidateIntrinsicContentSize()
    uiView.setNeedsLayout()
    uiView.layoutIfNeeded()

    if Self.debugScrollLogs {
      print(
        "[SelectableTextView] update bounds=\(uiView.bounds.size) attrLen=\(uiView.attributedText.length) scrollEnabled=\(uiView.isScrollEnabled)"
      )
    }
  }

  /// Finds all ranges of `quote` in `full` using case/diacritic-insensitive match, flexible whitespace regex, or longest substring when quote spans pages.
  private static func rangesOfQuote(_ quote: String, in full: NSString) -> [NSRange] {
    guard !quote.isEmpty, full.length > 0 else { return [] }
    let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    var out = rangesOfQuoteExact(trimmed, in: full)
    if !out.isEmpty { return out }
    out = rangesOfQuoteFlexibleWhitespace(trimmed, in: full)
    if !out.isEmpty { return out }
    return rangesOfQuoteLongestSubstring(trimmed, in: full)
  }

  private static func rangesOfQuoteExact(_ quote: String, in full: NSString) -> [NSRange] {
    var out: [NSRange] = []
    let opts: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    var searchRange = NSRange(location: 0, length: full.length)
    while searchRange.length > 0 {
      let found = full.range(of: quote, options: opts, range: searchRange)
      if found.location == NSNotFound { break }
      out.append(found)
      let nextLoc = found.location + max(1, found.length)
      if nextLoc >= full.length { break }
      searchRange = NSRange(location: nextLoc, length: full.length - nextLoc)
    }
    return out
  }

  private static func rangesOfQuoteFlexibleWhitespace(_ quote: String, in full: NSString) -> [NSRange] {
    let collapsed = quote.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !collapsed.isEmpty else { return [] }
    let pattern = NSRegularExpression.escapedPattern(for: collapsed)
      .replacingOccurrences(of: " ", with: "\\s+")
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
    var out: [NSRange] = []
    let range = NSRange(location: 0, length: full.length)
    regex.enumerateMatches(in: full as String, options: [], range: range) { match, _, _ in
      guard let m = match else { return }
      out.append(m.range)
    }
    return out
  }

  /// When the full quote spans pages, highlight the longest prefix or suffix of the quote that appears on this page.
  private static func rangesOfQuoteLongestSubstring(_ quote: String, in full: NSString) -> [NSRange] {
    let opts: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    let words = quote.split(separator: " ", omittingEmptySubsequences: false)
      .map(String.init)
    guard !words.isEmpty else { return [] }
    let maxWords = min(25, words.count)
    func trySubstring(_ substring: String) -> [NSRange]? {
      let t = substring.trimmingCharacters(in: .whitespacesAndNewlines)
      // Avoid highlighting extremely short/common fragments when a quote spans pages.
      // Example bug: fallback to "the" would highlight it everywhere.
      guard t.count >= 10 else { return nil }
      guard t.contains(" ") else { return nil } // require at least 2 words
      var out: [NSRange] = []
      var searchRange = NSRange(location: 0, length: full.length)
      while searchRange.length > 0 {
        let found = full.range(of: t, options: opts, range: searchRange)
        if found.location == NSNotFound { break }
        out.append(found)
        searchRange = NSRange(location: found.location + max(1, found.length), length: full.length - (found.location + max(1, found.length)))
      }
      return out.isEmpty ? nil : out
    }
    for len in (1 ... maxWords).reversed() {
      let prefix = words.prefix(len).joined(separator: " ")
      if let ranges = trySubstring(prefix) { return ranges }
      if len < words.count {
        let suffix = words.suffix(len).joined(separator: " ")
        if let ranges = trySubstring(suffix) { return ranges }
      }
    }
    return []
  }
}

final class Coordinator {
  var lastClearSelectionToken: Int = 0
}

// MARK: - Gesture coordination helpers
extension UIView {
  fileprivate func lectorNearestAncestorScrollView(excludingSelf: Bool = true) -> UIScrollView? {
    var v: UIView? = excludingSelf ? self.superview : self
    while let current = v {
      if let sv = current as? UIScrollView { return sv }
      v = current.superview
    }
    return nil
  }
}

extension UITextView {
  fileprivate func lectorPreferParentScrollViewForPans(debug: Bool) {
    guard let parent = self.lectorNearestAncestorScrollView(excludingSelf: true) else {
      if debug { print("[SelectableTextView] no parent UIScrollView ancestor found") }
      return
    }

    panGestureRecognizer.require(toFail: parent.panGestureRecognizer)
    panGestureRecognizer.cancelsTouchesInView = false

    if debug {
      print(
        "[SelectableTextView] gesture priority: textPan requires parentPan. parentContentSize=\(parent.contentSize) parentBounds=\(parent.bounds.size)"
      )
    }
  }
}

final class ShareableSelectionTextView: UITextView {
  var onShareSelection: ((String) -> Void)?

  override var canBecomeFirstResponder: Bool { true }

  @available(iOS 16.0, *)
  override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
    guard
      let selected = text(in: textRange)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !selected.isEmpty
    else {
      return super.editMenu(for: textRange, suggestedActions: suggestedActions)
    }

    let share = UIAction(
      title: "Share highlight",
      image: UIImage(systemName: "square.and.arrow.up")
    ) { [weak self] _ in
      self?.onShareSelection?(selected)
    }

    return UIMenu(children: [share] + suggestedActions)
  }

  override var intrinsicContentSize: CGSize {
    guard attributedText.length > 0 else {
      return CGSize(width: UIView.noIntrinsicMetric, height: 1)
    }

    let width = bounds.width > 0 ? bounds.width : 300
    textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
    textContainer.widthTracksTextView = false
    textContainer.heightTracksTextView = false

    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    let height = ceil(usedRect.height)
    return CGSize(width: UIView.noIntrinsicMetric, height: max(height, 1))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0 {
      invalidateIntrinsicContentSize()
    }
  }

  override func buildMenu(with builder: UIMenuBuilder) {
    super.buildMenu(with: builder)

    guard selectedRange.length > 0 else { return }
    let selectedNow: String? = {
      guard let range = selectedTextRange, let selected = text(in: range) else { return nil }
      let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }()
    guard let selectedNow else { return }

    let share = UIAction(
      title: "Share highlight",
      image: UIImage(systemName: "square.and.arrow.up")
    ) { [weak self] _ in
      self?.onShareSelection?(selectedNow)
    }

    let menu = UIMenu(title: "", options: .displayInline, children: [share])
    builder.insertChild(menu, atStartOfMenu: .edit)
  }

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(copy(_:)) {
      return selectedRange.length > 0
    }
    return super.canPerformAction(action, withSender: sender)
  }

  override func becomeFirstResponder() -> Bool {
    return super.becomeFirstResponder()
  }

  fileprivate func shareCurrentSelection() {
    guard let range = selectedTextRange, let selected = text(in: range) else { return }
    let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onShareSelection?(trimmed)
  }
}
