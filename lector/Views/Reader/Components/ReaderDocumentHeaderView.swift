import SwiftUI

struct ReaderDocumentHeaderView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let model: ReaderHeaderModel

  var body: some View {
    VStack(alignment: .center, spacing: 10) {
      Text(model.tag)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(3.0)

      Text(displayTitle)
        .font(.custom("CinzelDecorative-Bold", size: 40))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
        // Keep current size as the minimum; scale down only when title is long.
        // Also allow an extra line so we can avoid truncation.
        .lineLimit(3)
        .minimumScaleFactor(0.55)
        .allowsTightening(true)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)

      HStack(spacing: 28) {
        metaColumn(title: "DATE", value: model.dateText)
        metaColumn(title: "AUTHOR", value: model.author)
        metaColumn(title: "READ", value: model.readTimeText)
      }
      .padding(.top, 6)
    }
    .frame(maxWidth: .infinity)
  }

  private var displayTitle: String {
    // Defensive: prevent pathological filenames/titles from blowing up the layout.
    // For normal titles, we prefer showing the full text with autoscaling.
    let raw = model.title
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let collapsed = raw.replacingOccurrences(of: #" +""#, with: " ", options: .regularExpression)

    let maxChars = 120
    guard collapsed.count > maxChars else { return collapsed }

    // Try to cut at a word boundary near maxChars.
    let idx = collapsed.index(collapsed.startIndex, offsetBy: maxChars)
    let prefix = String(collapsed[..<idx])
    if let lastSpace = prefix.lastIndex(of: " ") {
      return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
    return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
  }

  private func metaColumn(title: String, value: String) -> some View {
    VStack(alignment: .center, spacing: 6) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(2.0)
      Text(value)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }
}
