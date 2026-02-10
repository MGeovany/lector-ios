import SwiftUI

struct LibrarySectionTabsView: View {
  @Binding var selected: LibrarySection
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .firstTextBaseline, spacing: 34) {
          ForEach(LibrarySection.allCases) { section in
            Button {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                selected = section
              }
            } label: {
              tabLabel(for: section)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .id(section.id)
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 2)
      }
      .onAppear {
        proxy.scrollTo(selected.id, anchor: .center)
      }
      .onChange(of: selected) { _, next in
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          proxy.scrollTo(next.id, anchor: .center)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func tabLabel(for section: LibrarySection) -> some View {
    let isSelected = selected == section
    return HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(L10n.tr(section.title, locale: locale))
        .font(.custom("serif", size: 34))
        .foregroundStyle(titleColor(isSelected: isSelected))
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Text(sectionIndexText(for: section))
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(indexColor(isSelected: isSelected))
        .baselineOffset(18)
    }
    .padding(.vertical, 8)
    .accessibilityLabel(L10n.tr(section.title, locale: locale))
  }

  private func sectionIndexText(for section: LibrarySection) -> String {
    // Matches the "03" superscript feel in the reference.
    String(format: "%02d", section.rawValue + 1)
  }

  private func titleColor(isSelected: Bool) -> Color {
    if isSelected {
      return colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack.opacity(0.92)
    }
    return colorScheme == .dark ? Color.white.opacity(0.20) : AppColors.matteBlack.opacity(0.22)
  }

  private func indexColor(isSelected: Bool) -> Color {
    if isSelected {
      return colorScheme == .dark ? Color.white.opacity(0.55) : AppColors.matteBlack.opacity(0.40)
    }
    return colorScheme == .dark ? Color.white.opacity(0.18) : AppColors.matteBlack.opacity(0.16)
  }
}

#Preview("Library Tabs") {
  @Previewable @State var selected: LibrarySection = .allBooks
  return VStack(spacing: 18) {
    LibrarySectionTabsView(selected: $selected)
    Text("Selected: \(selected.title)")
      .font(.parkinsansSemibold(size: 14))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
    Spacer()
  }
  .padding(.top, 18)
}

#Preview("Library Tabs • Dark") {
  @Previewable @State var selected: LibrarySection = .current
  return VStack(spacing: 18) {
    LibrarySectionTabsView(selected: $selected)
    Text("Selected: \(selected.title)")
      .font(.parkinsansSemibold(size: 14))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
    Spacer()
  }
  .padding(.top, 18)
  .preferredColorScheme(.dark)
}
