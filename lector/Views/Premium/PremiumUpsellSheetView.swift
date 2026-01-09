import SwiftUI

struct PremiumUpsellSheetView: View {
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    benefitsCard
                    ctaButtons
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 22)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upgrade to Premium")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)

            Text("Extend your storage limit for documents and books.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium benefits")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(MAX_STORAGE_PREMIUM_MB) MB storage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

              
            }

            VStack(alignment: .leading, spacing: 10) {
                benefitRow(icon: "externaldrive.fill", text: "More space for your PDFs")
                benefitRow(icon: "icloud.fill", text: "Keep your library ready to sync with your web app")
               
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
        )
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ctaButtons: some View {
        VStack(spacing: 10) {
            Button {
                subscription.upgradeToPremium()
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))

                    Text(subscription.isPremium ? "You're Premium" : "Go Premium")
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(subscription.isPremium)
            .opacity(subscription.isPremium ? 0.7 : 1.0)

            Button {
                dismiss()
            } label: {
                Text("Not now")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}

#Preview {
    PremiumUpsellSheetView()
        .environmentObject(SubscriptionStore())
}

