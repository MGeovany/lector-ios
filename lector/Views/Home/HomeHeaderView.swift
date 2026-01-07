import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LECTOR")
                // Use the Bold font face (not synthetic weight) for the logo.
                .font(.custom("CinzelDecorative-Bold", size: 32))
                .foregroundStyle(Color.black)
                .tracking(1.5)

            Text("Your library")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}



