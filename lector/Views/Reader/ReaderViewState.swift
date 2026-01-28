import SwiftUI

struct ReaderSearchState: Equatable {
  var query: String = ""
  var isVisible: Bool = false

  mutating func close() {
    isVisible = false
    query = ""
  }
}

struct ReaderHighlightState: Equatable {
  var isPresented: Bool = false
  var selectedText: String = ""
  var pageNumber: Int? = nil
  var progress: Double? = nil
  var clearSelectionToken: Int = 0

  mutating func present(text: String, pageNumber: Int?, progress: Double?) {
    selectedText = text
    self.pageNumber = pageNumber
    self.progress = progress
    clearSelectionToken &+= 1
    isPresented = true
  }

  mutating func dismiss() {
    isPresented = false
  }
}

struct ReaderSettingsState: Equatable {
  var isPresented: Bool = false
  var dragOffset: CGFloat = 0
  var isLocked: Bool = false
}

struct ReaderChromeState: Equatable {
  var isVisible: Bool = true
  var measuredHeight: CGFloat = 0
  var lastScrollOffsetY: CGFloat = 0

  mutating func updateVisibility(scrollOffsetY: CGFloat, isSearchVisible: Bool) {
    if isSearchVisible {
      isVisible = true
      lastScrollOffsetY = scrollOffsetY
      return
    }

    if scrollOffsetY <= 6 {
      isVisible = true
      lastScrollOffsetY = scrollOffsetY
      return
    }

    let delta = scrollOffsetY - lastScrollOffsetY
    guard abs(delta) >= 10 else { return }

    if delta > 0 {
      isVisible = false
    } else {
      isVisible = true
    }
    lastScrollOffsetY = scrollOffsetY
  }
}

struct ReaderScrollState: Equatable {
  var offsetY: CGFloat = 0
  var contentHeight: CGFloat = 1
  var viewportHeight: CGFloat = 1
  var insetTop: CGFloat = 0
  var insetBottom: CGFloat = 0
  var progress: Double = 0
  var lastEmittedProgress: Double = -1
  var didRestoreContinuousScroll: Bool = false
  var didAttachKVOScrollMetrics: Bool = false
}
