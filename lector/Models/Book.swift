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
  let title: String
  let author: String
  var pagesTotal: Int
  var currentPage: Int
  let sizeBytes: Int64
  let lastOpenedDaysAgo: Int
  var isRead: Bool
  var isFavorite: Bool
  var tags: [String]

  init(
    id: UUID = UUID(),
    remoteID: String? = nil,
    title: String,
    author: String,
    pagesTotal: Int,
    currentPage: Int,
    sizeBytes: Int64,
    lastOpenedDaysAgo: Int,
    isRead: Bool,
    isFavorite: Bool,
    tags: [String]
  ) {
    self.id = id
    self.remoteID = remoteID
    self.title = title
    self.author = author
    self.pagesTotal = pagesTotal
    self.currentPage = currentPage
    self.sizeBytes = sizeBytes
    self.lastOpenedDaysAgo = lastOpenedDaysAgo
    self.isRead = isRead
    self.isFavorite = isFavorite
    self.tags = tags
  }

  var progress: Double {
    guard pagesTotal > 0 else { return 0 }
    return min(1.0, max(0.0, Double(currentPage) / Double(pagesTotal)))
  }
}
