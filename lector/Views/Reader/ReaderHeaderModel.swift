import Foundation

struct ReaderHeaderModel: Equatable {
  let tag: String
  let title: String
  let dateText: String
  let author: String
  let readTimeText: String

  init(book: Book, pages: [String]) {
    tag = (book.tags.first?.uppercased() ?? "DOCUMENT")
    title = book.title.uppercased()
    author = book.author
    dateText = Self.formattedToday()
    readTimeText = "\(Self.estimatedReadMinutes(book: book, pages: pages)) min read"
  }

  private static func formattedToday() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMM yy"
    return formatter.string(from: Date())
  }

  private static func estimatedReadMinutes(book: Book, pages: [String]) -> Int {
    let sourceText: String = {
      let joined = pages.joined(separator: "\n\n")
      if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return joined
      }
      return BookTextProvider.fullText(for: book)
    }()

    let wordCount = sourceText.split { $0.isWhitespace || $0.isNewline }.count
    let wpm = 220.0
    return max(1, Int(ceil(Double(wordCount) / wpm)))
  }
}
