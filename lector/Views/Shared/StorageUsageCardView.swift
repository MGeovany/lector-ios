import SwiftUI

struct StorageUsageCardView: View {
  let usedBytes: Int64
  let maxBytes: Int64
  let isPremium: Bool
  let onUpgradeTapped: (() -> Void)?
  let onMoreSpaceTapped: (() -> Void)?
  @Environment(\.colorScheme) private var colorScheme

  private var progress: Double {
    guard maxBytes > 0 else { return 0 }
    return min(1.0, max(0.0, Double(usedBytes) / Double(maxBytes)))
  }

  private var percentText: String {
    "\(Int((progress * 100).rounded()))%"
  }

  private var usedText: String {
    formatBytes(usedBytes)
  }

  private var maxText: String {
    ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "externaldrive")
          .font(.parkinsansSemibold(size: CGFloat(14)))
          .foregroundStyle(.secondary)
          .frame(width: 26, height: 26)
          .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .fill(Color(.secondarySystemBackground))
          )

        VStack(alignment: .leading, spacing: 2) {
          Text("Storage")
            .font(.parkinsansSemibold(size: CGFloat(12)))
            .foregroundStyle(.secondary)

          Text("\(usedText) / \(maxText)")
            .font(.parkinsansSemibold(size: CGFloat(13)))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }

        Spacer(minLength: 0)

        if isPremium {

        } else if let onUpgradeTapped {
          GoPremiumRingButton(action: onUpgradeTapped)
        }
      }

      ProgressBarView(progress: progress)
        .frame(height: 9)

      HStack(spacing: 6) {
        Text("\(percentText) used")
          .font(.parkinsansSemibold(size: CGFloat(11)))
          .foregroundStyle(.secondary)

        Spacer()

        if isPremium, let onMoreSpaceTapped {
          Button(action: onMoreSpaceTapped) {
            Text("More space")
              .font(.parkinsansSemibold(size: CGFloat(11)))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .buttonStyle(.plain)
        } else {
          Text(isPremium ? "More space" : "Upgrade to extend storage")
            .font(.parkinsansSemibold(size: CGFloat(11)))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, minHeight: 92)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(.secondarySystemGroupedBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
        )
    )
  }

  private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
  }
}

private struct GoPremiumRingButton: View {
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var ringRotation: Double = 0

  private let ringGradient = Gradient(colors: [
    Color(red: 0.89, green: 0.80, blue: 1.00),  // ~#E2CBFF
    Color(red: 0.22, green: 0.23, blue: 0.70),  // ~#393BB2
    Color(red: 0.89, green: 0.80, blue: 1.00),
  ])

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: "crown.fill")
          .font(.parkinsans(size: CGFloat(10), weight: .heavy))
        Text("Go Premium")
          .font(.parkinsans(size: CGFloat(10), weight: .heavy))
      }
      .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      // Match the app theme: dark pill on dark mode, white on light.
      .background(
        (colorScheme == .dark ? Color.black : Color.white),
        in: Capsule(style: .continuous)
      )
    }
    // Avoid the default pressed/disabled-looking highlight.
    .buttonStyle(GoPremiumRingButtonStyle())
    .padding(0.8)
    .background(
      AngularGradient(gradient: ringGradient, center: .center, angle: .degrees(ringRotation)),
      in: Capsule(style: .continuous)
    )
    .onAppear {
      ringRotation = 0
      withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
        ringRotation = 360
      }
    }
  }
}

private struct GoPremiumRingButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
  }
}

#Preview {
  ZStack {
    Color(.systemGroupedBackground).ignoresSafeArea()
    VStack(spacing: 12) {
      StorageUsageCardView(
        usedBytes: 7 * 1024 * 1024,
        maxBytes: 15 * 1024 * 1024,
        isPremium: false,
        onUpgradeTapped: {},
        onMoreSpaceTapped: nil
      )
      StorageUsageCardView(
        usedBytes: 73 * 1024 * 1024,
        maxBytes: 250 * 1024 * 1024,
        isPremium: true,
        onUpgradeTapped: nil,
        onMoreSpaceTapped: {}
      )
    }
    .padding()
  }
}
