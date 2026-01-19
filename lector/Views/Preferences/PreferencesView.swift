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
                title: "Theme",
                subtitle: ""
              ) {
                ThemePickerView(theme: $viewModel.theme)
              }

              PreferenceSectionCard(
                icon: "textformat.size",
                title: "Typography",
                subtitle: ""
              ) {
                VStack(alignment: .leading, spacing: 10) {
                  FontPickerView(font: $viewModel.font)

                  SizeSliderView(
                    title: "Size",
                    value: $viewModel.fontSize,
                    range: 14...26,
                    step: 1,
                    valueText: { "\(Int($0)) pt" }
                  )
                }
              }

              PreferenceSectionCard(
                icon: "arrow.up.and.down.text.horizontal",
                title: "Layout",
                subtitle: ""
              ) {
                SizeSliderView(
                  title: "Line spacing",
                  value: $viewModel.lineSpacing,
                  range: 0.95...1.45,
                  step: 0.01,
                  valueText: { String(format: "%.2f", $0) }
                )
              }

              PreferenceSectionCard(
                icon: "scroll",
                title: "Reading",
                subtitle:
                  "This will enable continuous scroll for short documents."
              ) {
                Toggle(
                  "Continuous scroll",
                  isOn: $viewModel.continuousScrollForShortDocs
                )
                .font(.parkinsansSemibold(size: 13))
                .tint(preferencesAccent)
              }

              Button(role: .destructive, action: viewModel.restoreDefaults) {
                HStack(spacing: 8) {
                  Image(systemName: "arrow.counterclockwise")
                  Text("Restore defaults")
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
      .onChange(of: viewModel.continuousScrollForShortDocs) { _, _ in
        viewModel.save()
      }
    }
  }

  private var header: some View {
    Text("Preferences")
      .font(.parkinsansMedium(size: 70))
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
