//
//  profileVie.swift
//  lector
//
//  Created by Marlon Castro on 7/1/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var subscription: SubscriptionStore
    @State private var showPremiumSheet: Bool = false
    @State private var showDeleteAccountConfirm: Bool = false
    @State private var showLogoutConfirm: Bool = false
    @State private var showAccountDeletedAlert: Bool = false
    @State private var showLoggedOutAlert: Bool = false

    @AppStorage(AppPreferenceKeys.language) private var languageRawValue: String = AppLanguage.english.rawValue
    @AppStorage(AppPreferenceKeys.theme) private var themeRawValue: String = AppTheme.dark.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileHeaderRowView(
                        name: "Your Name",
                        email: "you@example.com"
                    )
                }

                if !subscription.isPremium {
                    Section {
                        UpgradeToPremiumCardView(
                            storageText: "\(MAX_STORAGE_PREMIUM_MB) MB storage",
                            onUpgradeTapped: { showPremiumSheet = true }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        HStack {
                            Label("Premium active", systemImage: "crown.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(subscription.maxStorageText)
                                .foregroundStyle(.secondary)
                        }
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
                            trailingText: (AppLanguage(rawValue: languageRawValue) ?? .english).title
                            ,
                            showsChevron: false
                        )
                    }

                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        SettingsRowView(
                            icon: "moon.stars",
                            title: "Theme",
                            trailingText: (AppTheme(rawValue: themeRawValue) ?? .dark).title
                            ,
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
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 86)
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumUpsellSheetView()
                    .environmentObject(subscription)
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
                        message: "This is a mock logout for now.",
                        confirmTitle: "Log out",
                        isDestructive: true,
                        onConfirm: {
                            showLogoutConfirm = false
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
            .alert("Logged out", isPresented: $showLoggedOutAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This is a mock logout for now.")
            }
        }
    }

    private var contactSupportURL: URL {
        let email = "marlon.castro@thefndrs.com"
        let subject = "Lector Support"
        let body = "Hi Marlon,\n\nI need help with:\n\n"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")!
    }

    private func deleteAccountLocally() {
        UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.language)
        UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.theme)
        UserDefaults.standard.removeObject(forKey: "lector_isPremium")
    }
}

#Preview {
    ProfileView()
        .environmentObject(SubscriptionStore())
}

