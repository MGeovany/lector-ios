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
        VStack(alignment: .leading, spacing: 10) {
            Text("LECTOR")
                // Use the Bold font face (not synthetic weight) for the logo.
                .font(.custom("CinzelDecorative-Bold", size: 34))
                .foregroundStyle(colorScheme == .dark ? Color.white : .primary)
                .tracking(2.0)

            HStack(spacing: 8) {
                Text("Favorites")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : .primary)

                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.35) : Color(.separator))
                    .frame(width: 3, height: 3)

                Text("Your favs")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

