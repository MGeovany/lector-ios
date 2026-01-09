//
//  preferencesView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct PreferencesView: View {
  @StateObject private var viewModel = PreferencesViewModel()
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    NavigationStack {
      ZStack {
        background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 16) {
            header

            ReadingPreviewCardView(
              theme: viewModel.theme,
              font: viewModel.font,
              fontSize: viewModel.fontSize,
              lineSpacing: viewModel.lineSpacing
            )

            PreferenceSectionCard(
              icon: "moon.circle",
              title: "Theme",
              subtitle: "Pick a surface that feels good for long sessions."
            ) {
              ThemePickerView(theme: $viewModel.theme)
            }

            PreferenceSectionCard(
              icon: "textformat.size",
              title: "Typography",
              subtitle: "Choose a font and size that feels natural."
            ) {
              VStack(alignment: .leading, spacing: 14) {
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
              subtitle: "Fine‑tune readability."
            ) {
              VStack(alignment: .leading, spacing: 14) {
                SizeSliderView(
                  title: "Line spacing",
                  value: $viewModel.lineSpacing,
                  range: 0.95...1.45,
                  step: 0.01,
                  valueText: { String(format: "%.2f", $0) }
                )
              }
            }

            Button(role: .destructive, action: viewModel.restoreDefaults) {
              HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise")
                Text("Restore defaults")
                  .font(.system(size: 14, weight: .semibold))
              }
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : .red)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
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
            .padding(.top, 6)

            Spacer(minLength: 30)
          }
          .padding(.horizontal, 18)
          .padding(.top, 14)
          .padding(.bottom, 26)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: viewModel.save) {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
              Text("Save")
            }
            .font(.system(size: 14, weight: .semibold))
          }
          .disabled(!viewModel.hasChanges)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {

      Text("Reading preferences")
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)
        .kerning(-0.2)

      Text("Set your default typography theme.")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.60) : .secondary)
        .fixedSize(horizontal: false, vertical: true)
        .lineSpacing(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 8)
    .padding(.bottom, 6)
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
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(
            colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack.opacity(0.85))

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

          Text(subtitle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)
      }

      content
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(
          colorScheme == .dark ? Color.white.opacity(0.10) : Color(.separator).opacity(0.5),
          lineWidth: 1)
    )
  }
}
