import Combine
import Foundation
import SwiftUI

// MARK: - Offline pin + download (Single Responsibility)
// Depends on abstractions: DocumentsServicing, NetworkMonitor.

@MainActor
final class ReaderOfflineCoordinator: ObservableObject {
  @Published private(set) var isEnabled: Bool = false
  @Published private(set) var isSaving: Bool = false
  @Published private(set) var saveMessage: String?
  @Published private(set) var subtitle: String?
  @Published private(set) var isAvailable: Bool = false
  @Published private(set) var availabilityToken: Int = 0

  private let documentID: String?
  private let documentsService: DocumentsServicing
  private let networkMonitor: NetworkMonitor
  private var meta: RemoteOptimizedDocument?
  private var lastAutoDownloadAt: Date?
  private var monitorTask: Task<Void, Never>?
  private var downloadTask: Task<Void, Never>?
  private var downloadGeneration: Int = 0

  init(
    documentID: String?,
    documentsService: DocumentsServicing = GoDocumentsService(),
    networkMonitor: NetworkMonitor = .shared
  ) {
    self.documentID = documentID
    self.documentsService = documentsService
    self.networkMonitor = networkMonitor
  }

  func bootstrapIfNeeded() {
    guard let id = documentID, !id.isEmpty else { return }
    isEnabled = OfflinePinStore.isPinned(remoteID: id)
    isAvailable = OptimizedPagesStore.hasLocalCopy(remoteID: id)
    refreshSubtitle()
  }

  func enable() {
    guard let id = documentID, !id.isEmpty else { return }
    OfflinePinStore.setPinned(remoteID: id, pinned: true)
    isEnabled = true
    lastAutoDownloadAt = nil
    isAvailable = OptimizedPagesStore.hasLocalCopy(remoteID: id)
    if !isAvailable, networkMonitor.isOnline, networkMonitor.isOnWiFi {
      startDownload()
    } else {
      cancelDownload()
    }
    startMonitor()
  }

  func disable() {
    guard let id = documentID, !id.isEmpty else { return }
    OfflinePinStore.setPinned(remoteID: id, pinned: false)
    isEnabled = false
    cancelDownload()
    OptimizedPagesStore.delete(remoteID: id)
    availabilityToken &+= 1
    isAvailable = false
    refreshSubtitle()
    stopMonitor()
  }

  func startMonitor() {
    guard let id = documentID else { return }
    stopMonitor()
    monitorTask = Task { @MainActor in
      while !Task.isCancelled {
        guard isEnabled, OfflinePinStore.isPinned(remoteID: id) else { return }
        if OptimizedPagesStore.hasLocalCopy(remoteID: id) {
          isSaving = false
          saveMessage = nil
          refreshSubtitle()
          availabilityToken &+= 1
          isAvailable = true
          return
        }
        if let opt = try? await documentsService.getOptimizedDocument(id: id) {
          meta = opt
          refreshSubtitle()
        }
        attemptAutoDownloadIfNeeded()
        refreshSubtitle()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
      }
    }
  }

  func stopMonitor() {
    monitorTask?.cancel()
    monitorTask = nil
  }

  private func startDownload() {
    guard let id = documentID else { return }
    cancelDownload()
    downloadGeneration &+= 1
    let gen = downloadGeneration
    downloadTask = Task { @MainActor in
      await runDownload(remoteID: id, generation: gen)
    }
  }

  private func cancelDownload() {
    downloadGeneration &+= 1
    downloadTask?.cancel()
    downloadTask = nil
    isSaving = false
    saveMessage = nil
  }

  private func runDownload(remoteID: String, generation: Int) async {
    guard generation == downloadGeneration, !Task.isCancelled else { return }
    guard OfflinePinStore.isPinned(remoteID: remoteID), !isSaving else { return }
    isSaving = true
    saveMessage = "Downloading…"
    refreshSubtitle()
    defer {
      isSaving = false
      saveMessage = nil
      refreshSubtitle()
    }

    do {
      var waited = 0
      let maxWait = 45
      let interval = 2
      while waited <= maxWait {
        guard generation == downloadGeneration, !Task.isCancelled else { return }
        guard OfflinePinStore.isPinned(remoteID: remoteID) else { return }

        let opt = try await documentsService.getOptimizedDocument(id: remoteID)
        guard generation == downloadGeneration else { return }
        meta = opt

        let total = opt.pages?.count ?? 0
        let ready = opt.pages?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count ?? 0
        if total > 0, let totalBytes = opt.optimizedSizeBytes {
          let ratio = min(1, max(0, Double(ready) / Double(total)))
          saveMessage = formatProgressMB(Int64((Double(totalBytes) * ratio).rounded(.down)))
        } else {
          saveMessage = "Downloading…"
        }
        refreshSubtitle()

        if let pages = opt.pages, !pages.isEmpty {
          try? OptimizedPagesStore.savePages(
            remoteID: remoteID,
            pages: pages,
            optimizedVersion: opt.optimizedVersion,
            optimizedChecksumSHA256: opt.optimizedChecksumSHA256
          )
          availabilityToken &+= 1
          isAvailable = true
          if opt.processingStatus == "ready" { return }
        }
        if opt.processingStatus == "failed" {
          saveMessage = "Failed."
          return
        }
        try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
        waited += interval
      }
      saveMessage = "Try again"
    } catch {
      saveMessage = "Failed"
    }
  }

  private func attemptAutoDownloadIfNeeded() {
    guard let id = documentID else { return }
    guard isEnabled, networkMonitor.isOnline, networkMonitor.isOnWiFi else { return }
    guard !OptimizedPagesStore.hasLocalCopy(remoteID: id), !isSaving else { return }
    let now = Date()
    if let last = lastAutoDownloadAt, now.timeIntervalSince(last) < 12 { return }
    lastAutoDownloadAt = now
    startDownload()
  }

  private func refreshSubtitle() {
    subtitle = isSaving ? progressLabelText() : nil
  }

  private func progressLabelText() -> String {
    if let meta = meta,
       let totalBytes = meta.optimizedSizeBytes,
       let pages = meta.pages, !pages.isEmpty,
       pages.count > 0
    {
      let ready = pages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
      let ratio = min(1, max(0, Double(ready) / Double(pages.count)))
      return formatProgressMB(Int64((Double(totalBytes) * ratio).rounded(.down)))
    }
    if let msg = saveMessage, !msg.isEmpty {
      let cleaned = msg.lowercased().replacingOccurrences(of: " ", with: "")
      if cleaned.contains(where: { $0.isNumber }) { return cleaned }
    }
    return "…"
  }

  private func formatProgressMB(_ bytes: Int64) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useMB]
    f.countStyle = .file
    f.includesUnit = true
    f.isAdaptive = false
    f.allowsNonnumericFormatting = false
    return f.string(fromByteCount: max(0, bytes))
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
  }
}
