import SwiftUI
import UIKit

/// A UIKit-backed selectable text view that exposes a custom "Share" menu item for the current selection.
struct SelectableTextView: UIViewRepresentable {
  let text: String
  let font: UIFont
  let textColor: UIColor
  let lineSpacing: CGFloat
  let highlightQuery: String?
  let onShareSelection: (String) -> Void

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiView: ShareableSelectionTextView,
    context: Context
  ) -> CGSize {
    // Use the proposed width, or fallback to the current bounds width, or a reasonable default
    let proposedWidth = proposal.width ?? (uiView.bounds.width > 0 ? uiView.bounds.width : 300)
    guard proposedWidth > 0 else { return CGSize(width: 0, height: 0) }

    // Configure text container for full layout calculation
    uiView.textContainer.size = CGSize(width: proposedWidth, height: .greatestFiniteMagnitude)
    uiView.textContainer.widthTracksTextView = false
    uiView.textContainer.heightTracksTextView = false

    // Ensure we have attributed text set
    if uiView.attributedText.length == 0 && !text.isEmpty {
      // If text isn't set yet, create it temporarily for measurement
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineSpacing = lineSpacing
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

    // Force layout to calculate the full height
    uiView.layoutManager.ensureLayout(for: uiView.textContainer)

    // Calculate the actual height needed for all text
    let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
    let height = ceil(usedRect.height)

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

    // Make the view expand vertically to fit content
    v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    v.setContentHuggingPriority(.defaultLow, for: .horizontal)
    v.setContentCompressionResistancePriority(.required, for: .vertical)
    v.setContentHuggingPriority(.required, for: .vertical)

    return v
  }

  func updateUIView(_ uiView: ShareableSelectionTextView, context: Context) {
    uiView.onShareSelection = onShareSelection

    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    paragraph.lineBreakMode = .byWordWrapping

    let attr = NSMutableAttributedString(
      string: text,
      attributes: [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraph,
      ]
    )

    if let highlightQuery,
      !highlightQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      let query = highlightQuery.lowercased()
      let full = text.lowercased() as NSString
      var range = NSRange(location: 0, length: full.length)
      while true {
        let found = full.range(of: query, options: [], range: range)
        if found.location == NSNotFound { break }
        attr.addAttribute(
          .backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.35), range: found)
        let nextLoc = found.location + max(1, found.length)
        if nextLoc >= full.length { break }
        range = NSRange(location: nextLoc, length: full.length - nextLoc)
      }
    }

    // Update when either the string OR styling changes (theme/font/spacing).
    // Preserve selection when possible.
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

    // Configure text container for proper layout
    let containerWidth = max(1, uiView.bounds.width > 0 ? uiView.bounds.width : 300)
    uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
    uiView.textContainer.widthTracksTextView = false
    uiView.textContainer.heightTracksTextView = false

    // Force layout update
    uiView.layoutManager.ensureLayout(for: uiView.textContainer)
    uiView.invalidateIntrinsicContentSize()
    uiView.setNeedsLayout()
    uiView.layoutIfNeeded()
  }
}

final class ShareableSelectionTextView: UITextView {
  var onShareSelection: ((String) -> Void)?

  override var canBecomeFirstResponder: Bool { true }

  @available(iOS 16.0, *)
  override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
    // This is the API used by the modern iOS 16+ selection "pill" menu.
    // `buildMenu(with:)` won't be called for this UI.
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

      // IMPORTANT: use the provided `textRange` content. By the time the action executes,
      // `selectedTextRange` can already be cleared by the system menu.
      self?.onShareSelection?(selected)
    }

    // Put our action at the front, keep the system actions after it.
    return UIMenu(children: [share] + suggestedActions)
  }

  override var intrinsicContentSize: CGSize {
    // Calculate intrinsic size based on text content
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
    // Invalidate intrinsic content size when bounds change
    if bounds.width > 0 {
      invalidateIntrinsicContentSize()
    }
  }

  override func buildMenu(with builder: UIMenuBuilder) {
    super.buildMenu(with: builder)

    // Only add share menu if there's a selection
    guard selectedRange.length > 0 else { return }
    // Capture selection now; `selectedTextRange` can change after the menu is built.
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

    // Insert the share menu at the start of the edit menu
    let menu = UIMenu(title: "", options: .displayInline, children: [share])
    builder.insertChild(menu, atStartOfMenu: .edit)
  }

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    // Ensure standard text selection actions work
    if action == #selector(copy(_:)) {
      return selectedRange.length > 0
    }
    return super.canPerformAction(action, withSender: sender)
  }

  override func becomeFirstResponder() -> Bool {
    // Ensure the view can become first responder for menu display
    return super.becomeFirstResponder()
  }

  fileprivate func shareCurrentSelection() {
    guard let range = selectedTextRange, let selected = text(in: range) else { return }
    let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onShareSelection?(trimmed)
  }
}
