import SwiftUI

// Thin wrapper to preserve existing tab routing (`homeView()`) while the Home UI is componentized.
struct homeView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    homeView()
}

