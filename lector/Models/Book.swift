//
//  Book.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import Foundation

struct Book: Identifiable, Hashable {
  let id: UUID
  /// Backend document ID (`documents.id`). Useful for refresh and future calls (GET `/documents/{id}`).
  let remoteID: String?
  var title: String
  var author: String
  /// Backend `created_at` (used for "Recently added").
  let createdAt: Date?
  var pagesTotal: Int
  var currentPage: Int
  /// Optional backend progress (0..1). Used for continuous scroll resume/progress.
  var readingProgress: Double?
  let sizeBytes: Int64
  /// Used to render "minutes/hours ago" in the library UI.
  let lastOpenedAt: Date?
  let lastOpenedDaysAgo: Int
  var isRead: Bool
  var isFavorite: Bool
  var tags: [String]

  init(
    id: UUID = UUID(),
    remoteID: String? = nil,
    title: String,
    author: String,
    createdAt: Date? = nil,
    pagesTotal: Int,
    currentPage: Int,
    readingProgress: Double? = nil,
    sizeBytes: Int64,
    lastOpenedAt: Date? = nil,
    lastOpenedDaysAgo: Int,
    isRead: Bool,
    isFavorite: Bool,
    tags: [String]
  ) {
    self.id = id
    self.remoteID = remoteID
    self.title = title
    self.author = author
    self.createdAt = createdAt
    self.pagesTotal = pagesTotal
    self.currentPage = currentPage
    self.readingProgress = readingProgress
    self.sizeBytes = sizeBytes
    self.lastOpenedAt = lastOpenedAt
    self.lastOpenedDaysAgo = lastOpenedDaysAgo
    self.isRead = isRead
    self.isFavorite = isFavorite
    self.tags = tags
  }

  var lastOpenedDisplayText: String {
    let referenceDate: Date = {
      if let lastOpenedAt { return lastOpenedAt }
      // Fallback: keep legacy behavior.
      return Calendar.current.date(byAdding: .day, value: -lastOpenedDaysAgo, to: Date()) ?? Date()
    }()
    let seconds = Date().timeIntervalSince(referenceDate)
    if seconds < 60 { return "Just now" }
    if seconds < 60 * 60 {
      let mins = max(1, Int((seconds / 60).rounded(.down)))
      return "\(mins)m ago"
    }
    if seconds < 60 * 60 * 24 {
      let hrs = max(1, Int((seconds / (60 * 60)).rounded(.down)))
      return "\(hrs)h ago"
    }
    let days = max(1, Int((seconds / (60 * 60 * 24)).rounded(.down)))
    return "\(days)d ago"
  }

  var lastOpenedSortDate: Date {
    lastOpenedAt
      ?? Calendar.current.date(byAdding: .day, value: -lastOpenedDaysAgo, to: Date())
      ?? .distantPast
  }

  var createdSortDate: Date {
    createdAt ?? .distantPast
  }

  // MARK: - Status helpers (Completed / Reading)

  var completedAt: Date? {
    // Best available approximation: when the backend reading position was last updated
    // while the book is at 100%.
    guard isRead else { return nil }
    return lastOpenedAt
  }

  var completionStatusText: String? {
    guard let completedAt else { return nil }
    return "Completed \(Self.statusDateFormatter.string(from: completedAt))"
  }

  var readingStatusText: String? {
    // Treat very small progress as "not started" to avoid noisy "Reading 0%".
    let pct = Int((progress * 100).rounded())
    guard pct >= 2 && pct <= 99 else { return nil }
    return "Reading \(pct)%"
  }

  private static let statusDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d"
    return f
  }()

  var progress: Double {
    let pageProgress: Double = {
      guard pagesTotal > 0 else { return 0 }
      return min(1.0, max(0.0, Double(currentPage) / Double(pagesTotal)))
    }()

    // Some backends can return inconsistent progress (e.g. 1.0) while page_number is 1.
    // For UI display, prefer the page-based value when they disagree significantly.
    if let readingProgress {
      let rp = min(1.0, max(0.0, readingProgress))
      if pagesTotal > 1, currentPage < pagesTotal, rp > pageProgress + 0.05 {
        return pageProgress
      }
      return rp
    }

    return pageProgress
  }
}
