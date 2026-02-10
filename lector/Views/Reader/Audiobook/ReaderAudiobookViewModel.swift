import AVFoundation
import Combine
import Foundation
import NaturalLanguage

final class ReaderAudiobookViewModel: NSObject, ObservableObject {
  enum Phase: Equatable {
    case off
    case converting
    case ready
    case playing
    case paused
  }

  @Published private(set) var phase: Phase = .off
  @Published private(set) var pageProgress: Double = 0
  @Published private(set) var currentPageIndex: Int = 0

  var isEnabled: Bool { phase != .off }
  var isConverting: Bool { phase == .converting }
  var isPlaying: Bool { phase == .playing }

  private let synth = AVSpeechSynthesizer()
  private var pages: [String] = []
  private var pageIndex: Int = 0
  private var cursor: Int = 0
  private var utteranceStartCursor: Int = 0

  private var ignoreNextDidFinish: Bool = false

  private var resolvedLanguageCode: String? = nil

  private var pendingStart: Bool = false
  private var isSwitchingOrSeeking: Bool = false

  private var onRequestPageIndexChange: ((Int) -> Void)?

  override init() {
    super.init()
    synth.delegate = self
  }

  private func configureAudioSessionForSpokenAudioIfPossible() {
    let session = AVAudioSession.sharedInstance()
    do {
      // Use playback+spokenAudio so TTS works even when the device is muted
      // and behaves correctly with other audio sources.
      try session.setCategory(
        .playback,
        mode: .spokenAudio,
        options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
      )
      try session.setActive(true, options: [])
    } catch {
      // Best-effort: if this fails, AVSpeechSynthesizer may still speak depending on system state.
    }
  }

  private func deactivateAudioSessionIfPossible() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setActive(false, options: [.notifyOthersOnDeactivation])
    } catch {
      // Best-effort.
    }
  }

  func setOnRequestPageIndexChange(_ handler: @escaping (Int) -> Void) {
    onRequestPageIndexChange = handler
  }

  func updatePages(_ pages: [String]) {
    self.pages = pages
    resolvedLanguageCode = Self.detectDominantLanguageCode(from: Self.sampleText(from: pages))
    if pendingStart, !pages.isEmpty {
      pendingStart = false
      startConversionThenPlay()
    }
  }

  func enable(startingAt index: Int) {
    pageIndex = max(0, index)
    cursor = 0
    utteranceStartCursor = 0
    pageProgress = 0
    currentPageIndex = pageIndex

    configureAudioSessionForSpokenAudioIfPossible()

    if pages.isEmpty {
      pendingStart = true
      setPhase(.converting)
      return
    }
    startConversionThenPlay()
  }

  func disable() {
    pendingStart = false
    stopSynthesizerImmediately()
    deactivateAudioSessionIfPossible()
    cursor = 0
    utteranceStartCursor = 0
    pageProgress = 0
    currentPageIndex = 0
    setPhase(.off)
  }

  func togglePlayPause() {
    switch phase {
    case .playing:
      pause()
    case .paused, .ready:
      play()
    case .converting, .off:
      break
    }
  }

  func play() {
    if synth.isPaused {
      synth.continueSpeaking()
      setPhase(.playing)
      return
    }
    speakCurrentPage(from: cursor)
  }

  func pause() {
    guard synth.isSpeaking else {
      setPhase(.paused)
      return
    }
    synth.pauseSpeaking(at: .word)
    setPhase(.paused)
  }

  func skipBackward5Seconds() {
    seek(seconds: -5)
  }

  func skipForward5Seconds() {
    seek(seconds: 5)
  }

  func previousPage() {
    transitionToPage(index: max(0, pageIndex - 1), shouldAutoPlay: false)
  }

  func nextPage() {
    transitionToPage(index: min(max(0, pages.count - 1), pageIndex + 1), shouldAutoPlay: false)
  }

  func userDidNavigate(to index: Int) {
    guard isEnabled else { return }
    let clamped = min(max(0, index), max(0, pages.count - 1))
    guard clamped != pageIndex else { return }
    transitionToPage(index: clamped, requestReaderPageChange: false)
  }

  private func startConversionThenPlay() {
    stopSynthesizerImmediately()

    setPhase(.converting)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
      guard let self else { return }
      guard self.phase == .converting else { return }
      self.setPhase(.ready)
      self.play()
    }
  }

  private func seek(seconds: Double) {
    guard isEnabled else { return }
    guard pages.indices.contains(pageIndex) else { return }

    let text = pages[pageIndex]
    let total = max(1, text.count)

    let estimatedCharsPerSecond: Double = 18
    let delta = Int((seconds * estimatedCharsPerSecond).rounded())
    let nextCursor = min(max(0, cursor + delta), max(0, total - 1))
    guard nextCursor != cursor else { return }

    cursor = nextCursor
    pageProgress = Double(cursor) / Double(total)

    guard phase == .playing else { return }
    stopSynthesizerImmediately()
    speakCurrentPage(from: cursor)
  }

  private func transitionToPage(
    index: Int,
    requestReaderPageChange: Bool = true,
    shouldAutoPlay: Bool = true
  ) {
    guard pages.indices.contains(index) else { return }
    guard index != pageIndex || cursor != 0 else { return }

    pageIndex = index
    cursor = 0
    utteranceStartCursor = 0
    pageProgress = 0
    currentPageIndex = pageIndex

    if requestReaderPageChange {
      onRequestPageIndexChange?(index)
    }

    let wasPlaying = phase == .playing
    stopSynthesizerImmediately()

    if shouldAutoPlay, wasPlaying {
      speakCurrentPage(from: 0)
    } else {
      setPhase(.paused)
    }
  }

  private func stopSynthesizerImmediately() {
    ignoreNextDidFinish = true
    isSwitchingOrSeeking = true
    synth.stopSpeaking(at: .immediate)
    isSwitchingOrSeeking = false
  }

  private func speakCurrentPage(from cursor: Int) {
    guard pages.indices.contains(pageIndex) else {
      setPhase(.paused)
      return
    }

    configureAudioSessionForSpokenAudioIfPossible()

    let full = pages[pageIndex]
    let safeCursor = min(max(0, cursor), max(0, full.count - 1))
    utteranceStartCursor = safeCursor
    let startIndex = full.index(full.startIndex, offsetBy: safeCursor)
    let slice = String(full[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !slice.isEmpty else {
      setPhase(.paused)
      return
    }

    let u = AVSpeechUtterance(string: slice)
    u.rate = 0.50
    u.pitchMultiplier = 1.0
    u.postUtteranceDelay = 0.05

    if let voice = resolvedSpeechVoice(for: slice) {
      u.voice = voice
    }

    setPhase(.playing)
    synth.speak(u)
  }

  private func resolvedSpeechVoice(for text: String) -> AVSpeechSynthesisVoice? {
    let code = resolvedLanguageCode
      ?? Self.detectDominantLanguageCode(from: text)
      ?? Locale.current.languageCode

    guard let code, !code.isEmpty else { return nil }
    guard let tag = Self.bestAvailableVoiceLanguageTag(for: code) else { return nil }
    return AVSpeechSynthesisVoice(language: tag)
  }

  private static func sampleText(from pages: [String]) -> String {
    if pages.isEmpty { return "" }
    var out = ""
    out.reserveCapacity(4096)
    for p in pages.prefix(3) {
      let trimmed = p.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      out.append(trimmed)
      out.append("\n\n")
      if out.count >= 8000 { break }
    }
    return String(out.prefix(8000))
  }

  private static func detectDominantLanguageCode(from text: String) -> String? {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.count >= 60 else { return nil }

    let recognizer = NLLanguageRecognizer()
    recognizer.processString(String(t.prefix(4000)))

    guard let lang = recognizer.dominantLanguage else { return nil }
    if lang == .undetermined { return nil }

    let confidence = recognizer.languageHypotheses(withMaximum: 1)[lang] ?? 0
    guard confidence >= 0.40 else { return nil }

    let raw = lang.rawValue
    if raw == "und" { return nil }
    return raw
  }

  private static func bestAvailableVoiceLanguageTag(for languageCode: String) -> String? {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    let code = languageCode.lowercased()
    if code.isEmpty { return nil }

    var candidates: [String] = []
    if let region = Locale.current.regionCode?.uppercased(), !region.isEmpty {
      candidates.append("\(code)-\(region)")
    }
    candidates.append(code)

    for tag in candidates {
      if AVSpeechSynthesisVoice(language: tag) != nil { return tag }
    }

    if let match = voices.first(where: { $0.language.lowercased().hasPrefix(code) }) {
      return match.language
    }
    return nil
  }

  private func setPhase(_ next: Phase) {
    if Thread.isMainThread {
      phase = next
    } else {
      DispatchQueue.main.async { [weak self] in self?.phase = next }
    }
  }
}

extension ReaderAudiobookViewModel: AVSpeechSynthesizerDelegate {
  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    guard isEnabled else { return }
    guard pages.indices.contains(pageIndex) else { return }

    let fullCount = max(1, pages[pageIndex].count)
    let absoluteCursor = utteranceStartCursor + characterRange.location
    let nextCursor = min(max(0, absoluteCursor), max(0, fullCount - 1))
    let progress = Double(nextCursor) / Double(fullCount)

    DispatchQueue.main.async { [weak self] in
      self?.cursor = nextCursor
      self?.pageProgress = progress
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    guard isEnabled else { return }
    if ignoreNextDidFinish {
      ignoreNextDidFinish = false
      return
    }
    guard !isSwitchingOrSeeking else { return }
    guard phase == .playing else { return }

    let next = pageIndex + 1
    guard pages.indices.contains(next) else {
      DispatchQueue.main.async { [weak self] in
        self?.setPhase(.paused)
      }
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.transitionToPage(index: next, requestReaderPageChange: true)
      self.setPhase(.playing)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    ignoreNextDidFinish = false
  }
}
