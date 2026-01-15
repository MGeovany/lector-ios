//
//  ProfileView.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct ProfileView: View {
  @EnvironmentObject private var subscription: SubscriptionStore
  @Environment(AppSession.self) private var session
  @State private var showPremiumSheet: Bool = false
  @State private var showDeleteAccountConfirm: Bool = false
  @State private var showLogoutConfirm: Bool = false
  @State private var showAccountDeletedAlert: Bool = false
  @State private var showLoggedOutAlert: Bool = false
  @State private var showSubscriptionErrorAlert: Bool = false

  @AppStorage(AppPreferenceKeys.language) private var languageRawValue: String = AppLanguage.english
    .rawValue
  @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue

  var body: some View {

    NavigationStack {
      List {
        Section {
          if session.isAuthenticated {
            if let profile = session.profile {
              ProfileHeaderRowView(
                name: profile.displayName,
                email: profile.email,
                avatarURL: profile.avatarURL,
                badge: profileBadge
              )
            } else {
              ProfileHeaderRowView(
                name: "Loading…",
                email: "Retrieving your profile",
                badge: profileBadge
              )
            }
          } else {
            ProfileHeaderRowView(
              name: "Marlon Castro",
              email: "marlon.castro@thefndrs.com",
              badge: profileBadge
            )
          }
        }

        Section("Subscription") {
          HStack {
            Text("Plan")
            Spacer()
            Text(planTitle)
              .foregroundStyle(.secondary)
          }

          if let statusText = planStatusText {
            HStack {
              Text("Status")
              Spacer()
              Text(statusText)
                .foregroundStyle(.secondary)
            }
          }

          Button {
            Task {
              await subscription.showManageSubscriptions()
              if subscription.lastErrorMessage != nil {
                showSubscriptionErrorAlert = true
              }
            }
          } label: {
            SettingsRowView(
              icon: "creditcard",
              title: "Manage subscription",
              trailingText: subscription.isPremium ? "Cancel" : nil,
              showsChevron: true
            )
          }
          .buttonStyle(.plain)

          Text("Cancel or change your plan in the App Store.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if subscription.isFounder {
          Section("Founder") {
            VStack(alignment: .leading, spacing: 6) {
              Text("Lector Founder")
                .font(.system(size: 16, weight: .semibold))
              Text(
                "Thanks for supporting Lector early. You’ll get early access to new features as they ship."
              )
              .font(.system(size: 13, weight: .regular))
              .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
          }
        }

        Section("Storage") {
          StorageUsageCardView(
            usedBytes: 0,
            maxBytes: subscription.maxStorageBytes,
            isPremium: subscription.isPremium,
            onUpgradeTapped: subscription.isPremium ? nil : { showPremiumSheet = true }
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
          .listRowBackground(Color.clear)
        }

        Section("Preferences") {
          NavigationLink {
            LanguageSelectionView()
          } label: {
            SettingsRowView(
              icon: "globe",
              title: "Language",
              trailingText: (AppLanguage(rawValue: languageRawValue) ?? .english).title,
              showsChevron: false
            )
          }

          NavigationLink {
            ThemeSelectionView()
          } label: {
            SettingsRowView(
              icon: "moon.stars",
              title: "Theme",
              trailingText: (AppTheme(rawValue: themeRawValue) ?? .dark).title,
              showsChevron: false
            )
          }

          NavigationLink {
            AboutUsView()
          } label: {
            SettingsRowView(icon: "info.circle", title: "About Us", showsChevron: false)
          }
        }

        Section("Support") {
          NavigationLink {
            HelpCenterView()
          } label: {
            SettingsRowView(icon: "questionmark.circle", title: "Help Center", showsChevron: false)
          }

          Link(destination: contactSupportURL) {
            SettingsRowView(
              icon: "envelope",
              title: "Contact Support",
              trailingText: "Email",
              showsChevron: false
            )
          }
        }

        Section("Legal") {
          NavigationLink {
            TermsAndConditionsView()
          } label: {
            SettingsRowView(icon: "doc.text", title: "Terms & Conditions", showsChevron: false)
          }
        }

        Section {
          Button(role: .destructive) {
            showDeleteAccountConfirm = true
          } label: {
            SettingsRowView(
              icon: "trash",
              title: "Delete Account",
              trailingText: nil,
              showsChevron: false
            )
          }

          Button {
            showLogoutConfirm = true
          } label: {
            SettingsRowView(
              icon: "rectangle.portrait.and.arrow.right",
              title: "Log out",
              trailingText: nil,
              showsChevron: false
            )
          }
        }
      }
      .listStyle(.insetGrouped)
      .listSectionSpacing(8)
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Color.clear.frame(height: 62)
      }
      .sheet(isPresented: $showPremiumSheet) {
        PremiumUpsellSheetView()
          .environmentObject(subscription)
      }
      .task { await subscription.refreshFromStoreKit() }
      .alert("Subscription", isPresented: $showSubscriptionErrorAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(subscription.lastErrorMessage ?? "Something went wrong.")
      }
      .overlay {
        if showDeleteAccountConfirm {
          CenteredConfirmationModal(
            title: "Delete account?",
            message: "This is a mock action for now. It will clear local app data on this device.",
            confirmTitle: "Delete Account",
            isDestructive: true,
            onConfirm: {
              showDeleteAccountConfirm = false
              deleteAccountLocally()
              showAccountDeletedAlert = true
            },
            onCancel: { showDeleteAccountConfirm = false }
          )
          .transition(.scale(scale: 0.98).combined(with: .opacity))
        }

        if showLogoutConfirm {
          CenteredConfirmationModal(
            title: "Log out?",
            message: "This will sign you out on this device.",
            confirmTitle: "Log out",
            isDestructive: true,
            onConfirm: {
              showLogoutConfirm = false
              session.signOut()
              showLoggedOutAlert = true
            },
            onCancel: { showLogoutConfirm = false }
          )
          .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showDeleteAccountConfirm)
      .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showLogoutConfirm)
      .alert("Account deleted", isPresented: $showAccountDeletedAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Local data cleared on this device.")
      }
    }
    .task(id: session.isAuthenticated) {
      await session.refreshProfileIfNeeded()
    }
  }

  private var contactSupportURL: URL {
    let email = "marlon.castro@thefndrs.com"
    let subject = "Lector Support"
    let body = "Hi Marlon,\n\nI need help with:\n\n"
    let encodedSubject =
      subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
    return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
      ?? URL(string: "mailto:\(email)")
      ?? URL(string: "mailto:")
      ?? URL(fileURLWithPath: "/")
  }

  private func deleteAccountLocally() {
    // Ensure the UI immediately reflects free-tier state (SubscriptionStore caches isPremium in memory).
    subscription.downgradeToFree()

    UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.language)
    UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.theme)
    UserDefaults.standard.removeObject(forKey: SubscriptionStore.legacyIsPremiumKey)
    UserDefaults.standard.removeObject(forKey: SubscriptionStore.planKey)
  }

  private var profileBadge: ProfilePlanBadge? {
    if subscription.isFounder { return .founder }
    if subscription.isPro { return .pro }
    return nil
  }

  private var planTitle: String {
    switch subscription.plan {
    case .free: return "Free"
    case .proMonthly: return "Pro (Monthly)"
    case .proYearly: return "Pro (Yearly)"
    case .founderLifetime: return "Founder (Lifetime)"
    }
  }

  private var planStatusText: String? {
    if subscription.isFounder { return "Active" }
    guard subscription.isPremium else { return nil }
    guard subscription.isAutoRenewable else { return "Active" }

    if let days = subscription.remainingDaysInPeriod, let date = subscription.expirationDate {
      return "\(days)d left • Renews \(Self.shortDate(date))"
    }
    if let date = subscription.expirationDate {
      return "Renews \(Self.shortDate(date))"
    }
    return "Active"
  }

  private static func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: date)
  }
}

#Preview {
  let previewSubscription = SubscriptionStore(initialPlan: .proYearly, persistToDefaults: false)
  ProfileView()
    .environment(AppSession())
    .environmentObject(previewSubscription)
}
