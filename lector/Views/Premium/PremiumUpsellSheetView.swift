import SwiftUI

struct PremiumUpsellSheetView: View {
  @EnvironmentObject private var subscription: SubscriptionStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @State private var billingCycle: BillingCycle = .monthly
  @State private var selectedPlan: SubscriptionPlan = .free
  @State private var showRestoreAlert: Bool = false
  @State private var restoreMessage: String?
  @State private var showDowngradeInfo: Bool = false
  let initialSelectedPlan: SubscriptionPlan?

  init(initialSelectedPlan: SubscriptionPlan? = nil) {
    self.initialSelectedPlan = initialSelectedPlan
  }

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          header
          billingToggle
          planList
          continueButton
          footer
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
              .font(.system(size: 20, weight: .regular))
              .foregroundStyle(AppColors.matteBlack)
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationBackground(Color(.systemGroupedBackground))
    .onAppear {
      // Default selection follows current subscription.
      if !subscription.isPremium, let initial = initialSelectedPlan {
        selectedPlan = initial
        billingCycle = (initial == .proYearly) ? .yearly : .monthly
      } else {
        selectedPlan = subscription.plan
        billingCycle = subscription.plan == .proYearly ? .yearly : .monthly
      }
      Task { await subscription.refreshFromStoreKit() }
    }
    .alert(
      "Subscription",
      isPresented: Binding(
        get: { subscription.lastErrorMessage != nil },
        set: { newValue in if !newValue { /* no-op */  } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(subscription.lastErrorMessage ?? "")
    }
    .alert("Downgrade", isPresented: $showDowngradeInfo) {
      Button("Manage subscription") {
        Task {
          await subscription.showManageSubscriptions()
        }
      }
      Button("Not now", role: .cancel) {}
    } message: {
      Text(downgradeInfoText)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(subscription.isPremium ? "Change your plan" : "Pick your plan")
        .font(.parkinsansBold(size: 34))
        .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

    }
    .frame(maxWidth: .infinity)
  }

  private var billingToggle: some View {
    Picker("Billing", selection: $billingCycle) {
      Text("Monthly").tag(BillingCycle.monthly)
      Text("Yearly").tag(BillingCycle.yearly)
    }
    .pickerStyle(.segmented)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: billingCycle)
  }

  private var planList: some View {
    VStack(spacing: 12) {
      PlanCard(
        title: "Free",
        priceText: "$0",
        subtitle: "Basic reading experience.",
        bullets: [
          "\(MAX_STORAGE_MB) MB total storage",
          "Clean reading",
          "Resume where you left off",
        ],
        badgeText: nil,
        isSelected: selectedPlan == .free,
        onTap: {
          // Founder is a lifetime one-time purchase (non-consumable), so "downgrading" doesn’t apply.
          guard !subscription.isFounder else { return }
          selectedPlan = .free
        }
      )

      PlanCard(
        title: "Pro",
        priceText: proPriceText,
        subtitle: "\(MAX_STORAGE_PRO_GB)GB storage, sync + backup, and Ask AI.",
        bullets: [
          "1‑month free trial (eligible users)",
          "\(MAX_STORAGE_PRO_GB)GB total storage",
          "Sync + backup",
          "Private stats (soon)",
          "Ask AI",
        ],
        badgeText: subscription.isPremium ? (billingCycle == .yearly ? "Popular" : nil) : "Free trial",
        isSelected: selectedPlan.isPro,
        onTap: {
          selectedPlan = (billingCycle == .monthly) ? .proMonthly : .proYearly
        }
      )

      PlanCard(
        title: "Founder",
        priceText: founderPriceText,
        subtitle: "A one‑time purchase to support Lector early.",
        bullets: [
          "Everything in Pro",
          "Ask AI",
          "Early access",
          "“Lector Founder” badge",
        ],
        badgeText: "One-time",
        isSelected: selectedPlan.isFounder,
        onTap: { selectedPlan = .founderLifetime }
      )
    }
  }

  private var continueButton: some View {
    Button {
      Task {
        // For auto-renewable subscriptions, downgrading happens in App Store (you keep access until period end).
        if selectedPlan == .free, subscription.plan.isPro {
          showDowngradeInfo = true
          return
        }
        await subscription.purchase(selectedPlan)
        if subscription.lastErrorMessage == nil {
          dismiss()
        }
      }
    } label: {
      ZStack {
        if subscription.isPurchasing {
          ProgressView()
            .tint(.white)
            .transition(.scale.combined(with: .opacity))
        } else {
          Text(buttonText)
            .font(.parkinsansBold(size: 16))
            .transition(.scale.combined(with: .opacity))
        }
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(
        AppColors.matteBlack,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
    }
    .buttonStyle(.plain)
    .disabled(subscription.isPurchasing || selectedPlan == subscription.plan)
    .scaleEffect(subscription.isPurchasing ? 0.98 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: subscription.isPurchasing)
    .padding(.top, 6)
  }

  private var buttonText: String {
    if selectedPlan == subscription.plan {
      return "Current plan"
    }
    if selectedPlan == .free {
      return "Downgrade to Free"
    }
    if subscription.isPremium && selectedPlan.isPremium {
      return "Change plan"
    }
    return "Continue"
  }

  private var footer: some View {
    VStack(spacing: 0) {
      Button {
        Task {
          await subscription.restorePurchases()
          if subscription.lastErrorMessage == nil {
            restoreMessage = "Restored."
          }
          showRestoreAlert = true
        }
      } label: {
        Text("Restore purchases")
          .font(.parkinsans(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
      }
      .buttonStyle(.plain)
      .alert("Restore purchases", isPresented: $showRestoreAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(restoreMessage ?? subscription.lastErrorMessage ?? "Done.")
      }
      HStack(spacing: 14) {
        Link("Privacy Policy", destination: WebAppLinks.privacyPolicy)
        Link("Terms of Use (EULA)", destination: WebAppLinks.appleStandardEULA)
      }
      .font(.parkinsans(size: 12, weight: .semibold))
      .padding(.top, 14)
      .padding(.bottom, 8)
      .tint(.secondary)

      Text(
        "Pro is an auto-renewing subscription. It renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings."
      )
      .font(.parkinsans(size: 12, weight: .regular))
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }

  private var proPriceText: String {
    let plan: SubscriptionPlan = billingCycle == .monthly ? .proMonthly : .proYearly
    guard let price = subscription.priceText(for: plan) else {
      return "Loading..."
    }
    let period = billingCycle == .monthly ? "/ month" : "/ year"
    if subscription.isPremium {
      return "\(price) \(period)"
    }
    return "$0, then \(price) \(period)"
  }

  private var founderPriceText: String {
    guard let price = subscription.priceText(for: .founderLifetime) else {
      return "Loading..."
    }
    return "\(price) one‑time"
  }

  private var downgradeInfoText: String {
    if let date = subscription.expirationDate {
      return
        "You’ll keep Pro until \(Self.shortDate(date)). After that, your plan will revert to Free. To cancel renewal, manage your subscription in the App Store."
    }
    return
      "You’ll keep Pro until the end of the current billing period. To cancel renewal, manage your subscription in the App Store."
  }

  private static func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: date)
  }
}

private struct PlanCard: View {
  let title: String
  let priceText: String
  let subtitle: String
  let bullets: [String]
  let badgeText: String?
  let isSelected: Bool
  let onTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private func handleTap() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      onTap()
    }
  }

  var body: some View {
    Button(action: handleTap) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
              Text(title)
                .font(.parkinsansBold(size: 16))
                .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

              if let badgeText {
                Text(badgeText)
                  .font(.parkinsansBold(size: 11))
                  .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(
                    (colorScheme == .dark ? Color.white : AppColors.matteBlack),
                    in: Capsule(style: .continuous)
                  )
              }
            }

            Text(subtitle)
              .font(.parkinsans(size: 12, weight: .regular))
              .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
          }

          Spacer(minLength: 0)

          VStack(alignment: .trailing, spacing: 2) {
            Text(priceText)
              .font(.parkinsansBold(size: 14))
              .foregroundStyle(colorScheme == .dark ? Color.white : AppColors.matteBlack)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(selectionIndicatorColor)
              .scaleEffect(isSelected ? 1.1 : 1.0)
              .symbolEffect(.bounce, value: isSelected)
          }
        }

        VStack(alignment: .leading, spacing: 6) {
          ForEach(bullets, id: \.self) { text in
            HStack(alignment: .top, spacing: 8) {
              Circle()
                .fill(
                  colorScheme == .dark ? Color.white.opacity(0.35) : Color(.separator).opacity(0.6)
                )
                .frame(width: 5, height: 5)
                .padding(.top, 6)

              Text(text)
                .font(.parkinsans(size: 13, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.75) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemBackground))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(strokeColor, lineWidth: isSelected ? 1.5 : 1)
      )
      .shadow(
        color: shadowColor,
        radius: isSelected ? 8 : 0,
        x: 0,
        y: isSelected ? 4 : 0
      )
    }
    .buttonStyle(.plain)
    // Use a ButtonStyle press effect so vertical drags still scroll the ScrollView.
    .buttonStyle(PlanCardPressStyle())
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
  }

  private var strokeColor: Color {
    if isSelected {
      return colorScheme == .dark
        ? Color.white.opacity(0.35)
        : AppColors.matteBlack.opacity(0.65)
    } else {
      return colorScheme == .dark
        ? Color.white.opacity(0.10)
        : Color(.separator).opacity(0.35)
    }
  }

  private var shadowColor: Color {
    if isSelected {
      return colorScheme == .dark
        ? Color.white.opacity(0.15)
        : AppColors.matteBlack.opacity(0.2)
    } else {
      return Color.clear
    }
  }

  private var selectionIndicatorColor: Color {
    if isSelected {
      return colorScheme == .dark ? Color.white.opacity(0.92) : AppColors.matteBlack
    } else {
      return colorScheme == .dark ? Color.white.opacity(0.22) : Color(.separator)
    }
  }
}

private struct PlanCardPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
      .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
  }
}

#Preview {
  PremiumUpsellSheetView()
    .environmentObject(SubscriptionStore())
}
