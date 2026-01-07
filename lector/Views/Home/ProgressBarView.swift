import SwiftUI

struct ProgressBarView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 8)

                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.75))
                    .frame(width: max(8, geo.size.width * progress), height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    ProgressBarView(progress: 0.44)
        .frame(height: 8)
        .padding()
}


