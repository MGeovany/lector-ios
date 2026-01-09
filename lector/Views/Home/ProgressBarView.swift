import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 9)

                Capsule(style: .continuous)
                    .fill(AppColors.progressFill(for: colorScheme))
                    .frame(width: max(10, geo.size.width * progress), height: 9)
            }
        }
        .frame(height: 9)
    }
}

#Preview {
    ProgressBarView(progress: 0.44)
        .frame(height: 8)
        .padding()
}


