import Foundation

enum LibrarySection: Int, CaseIterable, Hashable, Identifiable {
  case allBooks
  case current
  case toRead
  case finished

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .allBooks: return "All books"
    case .current: return "Current"
    case .toRead: return "To read"
    case .finished: return "Finished"
    }
  }
}

