import SwiftUI

struct EditBookDetailsSheetView: View {
  let colorScheme: ColorScheme
  let availableTags: [String]

  let initialTitle: String
  let initialAuthor: String
  let initialTag: String
  let initialColor: BookCardColor

  let onCancel: () -> Void
  let onSave: (_ title: String, _ author: String, _ tag: String, _ color: BookCardColor) -> Void

  @State private var title: String
  @State private var author: String
  @State private var tag: String
  @State private var selectedColor: BookCardColor
  @State private var didAutoSaveOnDisappear: Bool = false

  init(
    colorScheme: ColorScheme,
    availableTags: [String],
    initialTitle: String,
    initialAuthor: String,
    initialTag: String,
    initialColor: BookCardColor,
    onCancel: @escaping () -> Void,
    onSave:
      @escaping (_ title: String, _ author: String, _ tag: String, _ color: BookCardColor) -> Void
  ) {
    self.colorScheme = colorScheme
    self.availableTags = availableTags
    self.initialTitle = initialTitle
    self.initialAuthor = initialAuthor
    self.initialTag = initialTag
    self.initialColor = initialColor
    self.onCancel = onCancel
    self.onSave = onSave

    _title = State(initialValue: initialTitle)
    _author = State(initialValue: initialAuthor)
    _tag = State(initialValue: initialTag)
    _selectedColor = State(initialValue: initialColor)
  }

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          sectionCard {
            field(title: "Title", placeholder: "Title", text: $title)
            Divider().opacity(0.15)
            field(title: "Author", placeholder: "Author", text: $author)
            Divider().opacity(0.15)
            tagField
          }

          sectionCard {
            Text("Card color")
              .font(.parkinsansSemibold(size: 14))
              .foregroundStyle(
                colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack)

            colorPickerRow
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
      }
      .background(
        Group {
          if colorScheme == .dark {
            Color.black
          } else {
            Color(.systemGroupedBackground)
          }
        }
        .ignoresSafeArea()
      )
      .navigationTitle("Edit details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back", action: onCancel)
        }
      }
      .onDisappear {
        // Auto-save: details persist without requiring an explicit "Save" action.
        // Also saves when the user dismisses via swipe.
        guard !didAutoSaveOnDisappear else { return }
        didAutoSaveOnDisappear = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)

        let didChange =
          trimmedTitle != initialTitle.trimmingCharacters(in: .whitespacesAndNewlines)
          || trimmedAuthor != initialAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
          || trimmedTag != initialTag.trimmingCharacters(in: .whitespacesAndNewlines)
          || selectedColor != initialColor

        guard didChange else { return }
        onSave(trimmedTitle, trimmedAuthor, trimmedTag, selectedColor)
      }
    }
  }

  private var tagField: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Tag")
        .font(.parkinsansSemibold(size: 12))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

      HStack(spacing: 10) {
        TextField("Tag", text: $tag)
          .font(.parkinsansSemibold(size: 15))
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)

        if !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Button {
            tag = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : .secondary)
          }
          .buttonStyle(.plain)
        }
      }

      if !availableTags.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(availableTags.prefix(12), id: \.self) { t in
              Button {
                tag = t
              } label: {
                Text(t)
                  .font(.parkinsansSemibold(size: 12))
                  .foregroundStyle(
                    colorScheme == .dark ? Color.white.opacity(0.85) : AppColors.matteBlack
                  )
                  .padding(.horizontal, 10)
                  .padding(.vertical, 8)
                  .background(
                    Capsule(style: .continuous)
                      .fill(
                        colorScheme == .dark
                          ? Color.white.opacity(0.10) : Color(.secondarySystemBackground))
                  )
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }

  private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.parkinsansSemibold(size: 12))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)

      TextField(placeholder, text: text)
        .font(.parkinsansSemibold(size: 15))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
        .textInputAutocapitalization(.sentences)
        .disableAutocorrection(false)
    }
  }

  private func sectionCard(@ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 14, content: content)
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

  private var colorPickerRow: some View {
    let options = BookCardColor.allCases
    return ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(options) { option in
          Button {
            selectedColor = option
          } label: {
            ZStack {
              Circle()
                .fill(option.color(for: colorScheme))
                .frame(width: 34, height: 34)
                .overlay(
                  Circle()
                    .stroke(
                      colorScheme == .dark
                        ? Color.white.opacity(0.18) : Color(.separator).opacity(0.35),
                      lineWidth: 1
                    )
                )

              if selectedColor == option {
                Image(systemName: "checkmark")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundStyle(
                    colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
              }
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(option.displayName)
        }
      }
    }
  }
}
