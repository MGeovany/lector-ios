import SwiftUI

struct ReaderView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var preferences: PreferencesViewModel

  let book: Book
  var onProgressChange: ((Int, Int) -> Void)? = nil

  @StateObject private var viewModel = ReaderViewModel()
  @State private var showControls: Bool = false
  private let topAnchorID: String = "readerTop"
  private let documentsService: DocumentsServicing = GoDocumentsService()
  @State private var didStartLoading: Bool = false

  var body: some View {
    ZStack {
      preferences.theme.surfaceBackground
        .ignoresSafeArea()

      VStack(spacing: 0) {
        topBar

        GeometryReader { geo in
          content
            .onAppear {
              guard !didStartLoading else { return }
              didStartLoading = true

              // Approximate the text container size based on our padding.
              let containerSize = CGSize(
                width: max(10, geo.size.width - 36),
                height: max(10, geo.size.height - 80)
              )

              let uiFont = preferences.font.uiFont(size: CGFloat(preferences.fontSize))
              let style = TextPaginator.Style(
                font: uiFont,
                lineSpacing: CGFloat(preferences.fontSize)
                  * CGFloat(max(0, preferences.lineSpacing - 1))
              )

              Task {
                await viewModel.loadRemoteDocumentIfNeeded(
                  book: book,
                  documentsService: documentsService,
                  containerSize: containerSize,
                  style: style
                )
              }
            }
        }

        bottomPager
      }
      .frame(maxWidth: 720)  // iPad-friendly, keeps text comfortable.
      .frame(maxWidth: .infinity)
    }
    .toolbar(.hidden, for: .tabBar)
    .toolbar(.hidden, for: .navigationBar)
    .navigationBarBackButtonHidden(true)
    .preference(key: TabBarHiddenPreferenceKey.self, value: true)
    .sheet(isPresented: $showControls) {
      ReaderControlsSheetView()
        .environmentObject(preferences)
    }
  }

  private var topBar: some View {
    HStack(spacing: 10) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))
          .padding(10)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Back")

      Spacer(minLength: 0)

      HStack(spacing: 10) {
        Button {
          showControls = true
        } label: {
          Text("AA")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
              Capsule(style: .continuous)
                .fill(preferences.theme.surfaceText.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reading controls")

        Button {
          // Quick toggle: day <-> night (amber stays selectable in controls).
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            preferences.theme = (preferences.theme == .night) ? .day : .night
          }
        } label: {
          Image(systemName: preferences.theme == .night ? "sun.max.fill" : "moon.stars.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(preferences.theme.surfaceText.opacity(0.85))
            .padding(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle theme")
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 12)
    .padding(.bottom, 10)
  }

  private var content: some View {
    ScrollViewReader { proxy in
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
          Color.clear
            .frame(height: 0)
            .id(topAnchorID)

          header
            .padding(.horizontal, 18)
            .padding(.top, 18)

          Divider()
            .opacity(0.12)
            .padding(.horizontal, 18)
            .padding(.top, 14)

          Text(currentPageText)
            .font(preferences.font.font(size: CGFloat(preferences.fontSize)))
            .foregroundStyle(preferences.theme.surfaceText)
            .lineSpacing(
              CGFloat(preferences.fontSize) * CGFloat(max(0, preferences.lineSpacing - 1))
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
      }
      .onChange(of: viewModel.currentIndex, initial: true) { _, newValue in
        onProgressChange?(newValue + 1, max(1, viewModel.pages.count))
        // New page => jump to top so header + page start are visible.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          proxy.scrollTo(topAnchorID, anchor: .top)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .center, spacing: 10) {
      Text("DOCUMENT")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(3.0)

      Text(book.title.uppercased())
        .font(.custom("CinzelDecorative-Bold", size: 40))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.75)

      HStack(spacing: 28) {
        metaColumn(title: "DATE", value: formattedDate)
        metaColumn(title: "AUTHOR", value: book.author)
        metaColumn(title: "READ", value: "\(estimatedReadMinutes) min read")
      }
      .padding(.top, 6)
    }
    .frame(maxWidth: .infinity)
  }

  private func metaColumn(title: String, value: String) -> some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(2.0)
      Text(value)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText)
    }
    .frame(maxWidth: .infinity)
  }

  private var bottomPager: some View {
    HStack(spacing: 12) {
      Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          viewModel.goToPreviousPage()
        }
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(
            preferences.theme.surfaceText.opacity(viewModel.currentIndex > 0 ? 0.90 : 0.35)
          )
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preferences.theme.surfaceText.opacity(0.06))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.currentIndex <= 0)
      .accessibilityLabel("Previous page")

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        Text("\(max(1, viewModel.currentIndex + 1))/\(max(1, viewModel.pages.count))")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(preferences.theme.surfaceText.opacity(0.90))
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(
        Capsule(style: .continuous)
          .fill(preferences.theme.surfaceText.opacity(0.06))
      )
      .overlay(
        Capsule(style: .continuous)
          .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
      )
      .accessibilityLabel(
        "Page \(max(1, viewModel.currentIndex + 1)) of \(max(1, viewModel.pages.count))")

      Spacer(minLength: 0)

      Button {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
          viewModel.goToNextPage()
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(
            preferences.theme.surfaceText.opacity(
              viewModel.currentIndex < max(0, viewModel.pages.count - 1) ? 0.90 : 0.35)
          )
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(preferences.theme.surfaceText.opacity(0.06))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(preferences.theme.surfaceText.opacity(0.10), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(viewModel.currentIndex >= max(0, viewModel.pages.count - 1))
      .accessibilityLabel("Next page")
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .padding(.bottom, 10)
  }

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMM yy"
    return formatter.string(from: Date())
  }

  private var estimatedReadMinutes: Int {
    let sourceText: String = {
      let joined = viewModel.pages.joined(separator: "\n\n")
      if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return joined
      }
      return BookTextProvider.fullText(for: book)
    }()

    let wordCount = sourceText.split { $0.isWhitespace || $0.isNewline }.count
    let wpm = 220.0
    return max(1, Int(ceil(Double(wordCount) / wpm)))
  }

  private var currentPageText: String {
    guard viewModel.pages.indices.contains(viewModel.currentIndex) else { return "" }
    return viewModel.pages[viewModel.currentIndex]
  }
}
