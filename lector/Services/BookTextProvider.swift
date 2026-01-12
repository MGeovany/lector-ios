import Foundation

/// Fallback text provider used when a `Book` has no `remoteID` (or remote content can't be fetched).
/// This keeps the Reader working even without backend data.
enum BookTextProvider {
  static func fullText(for book: Book) -> String {
    """
    \(book.title)
    \(book.author)

    No content to display.
    """
  }

  static func pages(for book: Book) -> [String] {
    // Minimal single-page fallback; ReaderViewModel will paginate remote content when available.
    [fullText(for: book)]
  }
}

