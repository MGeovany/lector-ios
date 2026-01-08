//
//  Book.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import Foundation

struct Book: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
    let author: String
    let pagesTotal: Int
    var currentPage: Int
    let sizeBytes: Int64
    let lastOpenedDaysAgo: Int
    var isRead: Bool
    var isFavorite: Bool
    var tags: [String]

    var progress: Double {
        guard pagesTotal > 0 else { return 0 }
        return min(1.0, max(0.0, Double(currentPage) / Double(pagesTotal)))
    }
}
