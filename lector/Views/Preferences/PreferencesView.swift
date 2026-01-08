//
//  preferencesView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.06, green: 0.06, blue: 0.08),
                        Color(red: 0.03, green: 0.03, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

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
                            .foregroundStyle(Color.white.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
            Text("SETTINGS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(2.0)

            Text("Reading preferences")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.white)

            Text("Set your default typography and theme for a comfortable reading experience.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MVVM: persistence + dirty-check is handled by `PreferencesViewModel`.
}

// MARK: - Components

private struct PreferenceSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}









