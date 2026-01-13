//
//  FavoritesHeaderView.swift
//  lector
//
//  Created by Marlon Castro on 8/1/26.
//

import SwiftUI

struct FavoritesHeaderView: View {
  @Environment(\.colorScheme) private var colorScheme
  let filteredFavorites: [Book]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {

        Text("Favorites")
          .font(.parkinsansBold(size: 32))
          .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

        Spacer(minLength: 0)

        Text("\(filteredFavorites.count)")
          .font(.parkinsansBold(size: 14))
          .foregroundStyle(
            colorScheme == .dark ? Color.white.opacity(0.65) : AppColors.matteBlack.opacity(0.65)
          )
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            Capsule(style: .continuous)
              .fill(
                colorScheme == .dark ? Color.white.opacity(0.10) : Color(.secondarySystemBackground)
              )
              .overlay(
                Capsule(style: .continuous)
                  .stroke(
                    colorScheme == .dark
                      ? Color.white.opacity(0.12) : Color(.separator).opacity(0.5), lineWidth: 1)
              )
          )
          .accessibilityLabel("\(filteredFavorites.count) favorites")
      }

      Text("Saved picks you can jump back into anytime.")
        .font(.parkinsansSemibold(size: 14))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 8)
    .padding(.bottom, 2)
  }
}
