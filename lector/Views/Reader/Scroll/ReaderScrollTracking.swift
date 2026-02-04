import SwiftUI
import UIKit

// MARK: - Preference keys

struct ReaderScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ReaderScrollContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 1
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ReaderScrollViewportHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 1
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Continuous scroll restore (contentOffset-based)
struct ReaderScrollOffsetRestorer: UIViewRepresentable {
  let enabled: Bool
  let targetProgress: Double?
  @Binding var didRestore: Bool

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    guard enabled, !didRestore, let targetProgress else { return }
    let p = min(1.0, max(0.0, targetProgress))

    DispatchQueue.main.async {
      guard enabled, !didRestore else { return }
      guard let scrollView = uiView.lectorFindNearestScrollView() else { return }
      guard scrollView.contentSize.height > 1, scrollView.bounds.height > 1 else { return }

      let topInset = scrollView.adjustedContentInset.top
      let bottomInset = scrollView.adjustedContentInset.bottom
      let minY = -topInset
      let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + bottomInset)
      let y = minY + CGFloat(p) * (maxY - minY)

      if abs(scrollView.contentOffset.y - y) > 2 {
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: false)
      }
      didRestore = true
    }
  }
}

// MARK: - Scroll metrics bridge (KVO-based)
struct ReaderScrollMetricsBridge: UIViewRepresentable {
  let enabled: Bool
  let debugLogs: Bool
  @Binding var didAttach: Bool
  @Binding var offsetY: CGFloat
  @Binding var contentHeight: CGFloat
  @Binding var viewportHeight: CGFloat
  @Binding var insetTop: CGFloat
  @Binding var insetBottom: CGFloat

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    guard enabled else {
      context.coordinator.stop()
      if didAttach { didAttach = false }
      return
    }

    context.coordinator.startIfNeeded(
      from: uiView,
      debugLogs: debugLogs,
      onUpdate: { snap in
        let logicalOffsetY = max(0, snap.contentOffsetY + snap.insetTop)
        DispatchQueue.main.async {
          offsetY = logicalOffsetY
          contentHeight = max(1, snap.contentHeight)
          viewportHeight = max(1, snap.viewportHeight)
          insetTop = snap.insetTop
          insetBottom = snap.insetBottom
          if !didAttach { didAttach = true }
        }
      }
    )
  }

  final class Coordinator {
    private var offsetObs: NSKeyValueObservation?
    private var sizeObs: NSKeyValueObservation?
    private var boundsObs: NSKeyValueObservation?
    private weak var scrollView: UIScrollView?
    private var debugLogs: Bool = false
    private var onUpdate: ((Snapshot) -> Void)?

    struct Snapshot {
      let contentOffsetY: CGFloat
      let contentHeight: CGFloat
      let viewportHeight: CGFloat
      let insetTop: CGFloat
      let insetBottom: CGFloat
    }

    func startIfNeeded(from view: UIView, debugLogs: Bool, onUpdate: @escaping (Snapshot) -> Void) {
      if scrollView != nil { return }
      self.debugLogs = debugLogs
      self.onUpdate = onUpdate

      guard let sv = view.lectorFindNearestScrollView() else {
        if debugLogs { print("[ReaderScroll] metrics: could not find UIScrollView") }
        return
      }

      scrollView = sv
      emitSnapshot(from: sv)

      offsetObs = sv.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
        self?.emitSnapshot(from: sv)
      }
      sizeObs = sv.observe(\.contentSize, options: [.new]) { [weak self] sv, _ in
        self?.emitSnapshot(from: sv)
      }
      boundsObs = sv.observe(\.bounds, options: [.new]) { [weak self] sv, _ in
        self?.emitSnapshot(from: sv)
      }
    }

    private func emitSnapshot(from sv: UIScrollView) {
      let inset = sv.adjustedContentInset
      let snap = Snapshot(
        contentOffsetY: sv.contentOffset.y,
        contentHeight: sv.contentSize.height,
        viewportHeight: sv.bounds.height,
        insetTop: inset.top,
        insetBottom: inset.bottom
      )
      onUpdate?(snap)
      if debugLogs {
        print(
          "[ReaderScroll] KVO offsetY=\(Int(sv.contentOffset.y)) contentSizeH=\(Int(sv.contentSize.height)) boundsH=\(Int(sv.bounds.height))"
        )
      }
    }

    func stop() {
      offsetObs?.invalidate()
      sizeObs?.invalidate()
      boundsObs?.invalidate()
      offsetObs = nil
      sizeObs = nil
      boundsObs = nil
      scrollView = nil
      onUpdate = nil
    }
  }
}

// MARK: - UIKit helpers
extension UIView {
  fileprivate func lectorFindNearestScrollView() -> UIScrollView? {
    var v: UIView? = self
    while let current = v {
      if let sv = current as? UIScrollView { return sv }
      v = current.superview
    }

    let root: UIView? = self.window ?? self.superview
    return root?.lectorFirstDescendant(ofType: UIScrollView.self)
  }

  fileprivate func lectorFirstDescendant<T: UIView>(ofType: T.Type) -> T? {
    var queue: [UIView] = [self]
    while !queue.isEmpty {
      let node = queue.removeFirst()
      if let match = node as? T { return match }
      queue.append(contentsOf: node.subviews)
    }
    return nil
  }
}
