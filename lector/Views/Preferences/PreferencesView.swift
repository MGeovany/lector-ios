//
//  preferencesView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct PreferencesView: View {
  @EnvironmentObject private var viewModel: PreferencesViewModel
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale
  @State private var isShowingContinuousScrollInfo: Bool = false

  var body: some View {
    NavigationStack {
      ZStack {
        background.ignoresSafeArea()

        GeometryReader { geometry in
          ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
              header
                .padding(.bottom, 4)

              CompactPreviewCardView(
                theme: viewModel.theme,
                font: viewModel.font,
                fontSize: viewModel.fontSize,
                lineSpacing: viewModel.lineSpacing
              )

              PreferenceSectionCard(
                icon: "moon.circle",
                title: L10n.tr("Theme", locale: locale),
                subtitle: ""
              ) {
                ThemePickerView(theme: $viewModel.theme)
              }

              PreferenceSectionCard(
                icon: "textformat.size",
                title: L10n.tr("Typography", locale: locale),
                subtitle: ""
              ) {
                VStack(alignment: .leading, spacing: 10) {
                  FontPickerView(font: $viewModel.font)

                  SizeSliderView(
                    title: L10n.tr("Size", locale: locale),
                    value: $viewModel.fontSize,
                    range: 14...26,
                    step: 1,
                    valueText: { "\(Int($0)) pt" }
                  )
                }
              }

              PreferenceSectionCard(
                icon: "arrow.up.and.down.text.horizontal",
                title: L10n.tr("Layout", locale: locale),
                subtitle: ""
              ) {
                SizeSliderView(
                  title: L10n.tr("Line spacing", locale: locale),
                  value: $viewModel.lineSpacing,
                  range: 0.95...1.45,
                  step: 0.01,
                  valueText: { String(format: "%.2f", $0) }
                )
              }

              PreferenceSectionCard(
                icon: "text.book.closed.fill",
                title: L10n.tr("Reading", locale: locale),
                subtitle: String(format: L10n.tr("Continuous scroll shows the book as one long page. It only applies to documents under %d pages.", locale: locale), ReaderLimits.continuousScrollMaxPages)
              ) {
                Toggle(
                  L10n.tr("Continuous scroll", locale: locale),
                  isOn: $viewModel.continuousScrollForShortDocs
                )
                .font(.parkinsansSemibold(size: 13))
                .tint(preferencesAccent)
              }

              PreferenceSectionCard(
                icon: "highlighter",
                title: L10n.tr("Highlights", locale: locale),
                subtitle: L10n.tr("Show search matches in the text and choose their color.", locale: locale)
              ) {
                VStack(alignment: .leading, spacing: 12) {
                  Toggle(L10n.tr("Show highlights in text", locale: locale), isOn: $viewModel.showHighlightsInText)
                    .font(.parkinsansSemibold(size: 13))
                    .tint(preferencesAccent)

                  HStack(spacing: 8) {
                    Text(L10n.tr("Color", locale: locale))
                      .font(.parkinsans(size: 13, weight: .medium))
                      .foregroundStyle(
                        colorScheme == .dark
                          ? Color.white.opacity(0.75) : AppColors.matteBlack.opacity(0.75))
                    Spacer(minLength: 8)
                    HStack(spacing: 8) {
                      ForEach(ReadingHighlightColor.allCases) { color in
                        Button {
                          viewModel.highlightColor = color
                        } label: {
                          Circle()
                            .fill(color.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                              Circle()
                                .stroke(
                                  viewModel.highlightColor == color
                                    ? preferencesAccent.opacity(colorScheme == .dark ? 0.45 : 0.25)
                                    : Color.clear,
                                  lineWidth: 2.5
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(color.title))
                        .accessibilityAddTraits(
                          viewModel.highlightColor == color ? .isSelected : [])
                      }
                    }
                  }
                }
              }

              Button(role: .destructive, action: viewModel.restoreDefaults) {
                HStack(spacing: 8) {
                  Image(systemName: "arrow.counterclockwise")
                  Text(L10n.tr("Restore defaults", locale: locale))
                    .font(.parkinsansSemibold(size: 13))
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : .red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                      colorScheme == .dark
                        ? Color.white.opacity(0.08) : Color(.secondarySystemBackground))
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                      colorScheme == .dark
                        ? Color.white.opacity(0.10) : Color(.separator).opacity(0.6), lineWidth: 1)
                )
              }
              .buttonStyle(.plain)
              .padding(.bottom, 24)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .frame(minHeight: geometry.size.height)
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: viewModel.theme) { _, _ in
        viewModel.save()
      }
      .onChange(of: viewModel.font) { _, _ in
        viewModel.save()
      }
      .onChange(of: viewModel.fontSize) { _, _ in
        viewModel.save()
      }
      .onChange(of: viewModel.lineSpacing) { _, _ in
        viewModel.save()
      }
      .onChange(of: viewModel.continuousScrollForShortDocs) { oldValue, newValue in
        if !oldValue, newValue {
          isShowingContinuousScrollInfo = true
        }
        viewModel.save()
      }
      .onChange(of: viewModel.showHighlightsInText) { _, _ in
        viewModel.save()
      }
      .onChange(of: viewModel.highlightColor) { _, _ in
        viewModel.save()
      }
      .alert(L10n.tr("Continuous scroll", locale: locale), isPresented: $isShowingContinuousScrollInfo) {
        Button(L10n.tr("Got it", locale: locale), role: .cancel) {}
      } message: {
        Text(
          String(format: L10n.tr("This reads like an \"infinite\" page instead of paged swipes. It will only show in the reader for documents under %d pages.", locale: locale), ReaderLimits.continuousScrollMaxPages)
        )
      }
    }
  }

  private var header: some View {
    Text(L10n.tr("Settings", locale: locale))
      .font(.parkinsansMedium(size: 70))
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .foregroundStyle(
        colorScheme == .dark ? Color.white.opacity(0.75) : AppColors.matteBlack)
  }

  private var background: some View {
    Group {
      if colorScheme == .dark {
        LinearGradient(
          colors: [
            Color.black,
            Color(red: 0.06, green: 0.06, blue: 0.08),
            Color(red: 0.03, green: 0.03, blue: 0.04),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      } else {
        LinearGradient(
          colors: [
            Color(.systemGroupedBackground),
            Color(.systemBackground),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
  }

  private var preferencesAccent: Color {
    // Reuse reading accent to keep the UI consistent with the reader.
    viewModel.theme.accent
  }

  // MVVM: persistence + dirty-check is handled by `PreferencesViewModel`.
}

// MARK: - Components

private struct PreferenceSectionCard<Content: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  @ViewBuilder let content: Content
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: icon)
          .font(.parkinsansSemibold(size: 14))
          .foregroundStyle(
            colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack.opacity(0.85))

        Text(title)
          .font(.parkinsansBold(size: 15))
          .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

        Spacer(minLength: 0)
      }

      if !subtitle.isEmpty {
        Text(subtitle)
          .font(.parkinsans(size: 12, weight: .regular))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, -6)
      }

      content
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5),
          lineWidth: 1)
    )
  }
}

private struct CompactPreviewCardView: View {
  let theme: ReadingTheme
  let font: ReadingFont
  let fontSize: Double
  let lineSpacing: Double
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Preview")
          .font(.parkinsansSemibold(size: 13))
          .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
        Spacer()
        HStack(spacing: 6) {
          Image(systemName: theme.icon)
            .font(.system(size: 11, weight: .bold))
          Text("\(theme.title) • \(font.title) • \(Int(fontSize))pt")
            .font(.parkinsans(size: 11, weight: .regular))
        }
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
      }

      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(theme.surfaceBackground)

        VStack(alignment: .leading, spacing: 6) {
          Text("Chapter 1")
            .font(font.font(size: 11))
            .foregroundStyle(theme.surfaceSecondaryText)

          Text(
            "Sometimes, the best way to read is to find a gentle rhythm: warm light, clear type, and a little space to breathe."
          )
          .font(font.font(size: fontSize))
          .foregroundStyle(theme.surfaceText)
          .lineSpacing(CGFloat(fontSize) * (lineSpacing - 1))
          .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(height: 120)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(theme.surfaceText.opacity(0.10), lineWidth: 1)
      )
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5),
          lineWidth: 1)
    )
  }
}

#Preview {
  PreferencesView()
    .environmentObject(PreferencesViewModel())
}
