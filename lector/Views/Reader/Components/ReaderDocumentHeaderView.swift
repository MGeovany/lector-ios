import SwiftUI

struct ReaderDocumentHeaderView: View {
  @EnvironmentObject private var preferences: PreferencesViewModel

  let model: ReaderHeaderModel

  var body: some View {
    VStack(alignment: .center, spacing: 10) {
      Text(model.tag)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(3.0)

      Text(model.title)
        .font(.custom("CinzelDecorative-Bold", size: 40))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.75)

      HStack(spacing: 28) {
        metaColumn(title: "DATE", value: model.dateText)
        metaColumn(title: "AUTHOR", value: model.author)
        metaColumn(title: "READ", value: model.readTimeText)
      }
      .padding(.top, 6)
    }
    .frame(maxWidth: .infinity)
  }

  private func metaColumn(title: String, value: String) -> some View {
    VStack(alignment: .center, spacing: 6) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceSecondaryText)
        .tracking(2.0)
      Text(value)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(preferences.theme.surfaceText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }
}
