//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct SettingsView: View {

    @State private var showPremium = false
    @State private var showDataManager = false
    @State private var showNotifications = false

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 24) {

                    premiumCard

                    settingsSection(
                        title: "DATA",
                        items: [
                            SettingItem(
                                icon: "externaldrive",
                                title: "Manage Data"
                            ) { showDataManager = true },

                            SettingItem(
                                icon: "bell.badge",
                                title: "Notifications"
                            ) { showNotifications = true },

                            SettingItem(
                                icon: "gearshape",
                                title: "System Preferences"
                            ) { }
                        ]
                    )

                    settingsSection(
                        title: "LEGAL",
                        items: [
                            SettingItem(
                                icon: "lock.shield",
                                title: "Privacy Policy"
                            ) { openURL("https://yourapp.com/privacy") },

                            SettingItem(
                                icon: "doc.text",
                                title: "Terms of Use"
                            ) { openURL("https://yourapp.com/terms") }
                        ]
                    )

                    settingsSection(
                        title: "ACCOUNT",
                        items: [
                            SettingItem(
                                icon: "creditcard",
                                title: "Manage Subscription"
                            ) { openSubscriptions() },

                            SettingItem(
                                icon: "arrow.clockwise",
                                title: "Restore Purchase"
                            ) { restorePurchases() }
                        ]
                    )

                    settingsSection(
                        title: "SUPPORT",
                        items: [
                            SettingItem(
                                icon: "envelope",
                                title: "Contact Support"
                            ) { contactSupport() },

                            SettingItem(
                                icon: "questionmark.circle",
                                title: "FAQ"
                            ) { },

                            SettingItem(
                                icon: "square.and.arrow.up",
                                title: "Share App"
                            ) { shareApp() },

                            SettingItem(
                                icon: "star",
                                title: "Rate App"
                            ) { rateApp() }
                        ]
                    )

                    aboutSection
                }
                .padding()
            }
            .navigationTitle("Settings")
        }
    }
}

extension SettingsView {

    var premiumCard: some View {

        Button {

            showPremium = true

        } label: {

            HStack {

                VStack(alignment: .leading, spacing: 6) {

                    Text("Upgrade to Premium")
                        .font(.headline)

                    Text("Unlock advanced scheduling features")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.title2)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple,.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

extension SettingsView {

    func settingsSection(
        title: String,
        items: [SettingItem]
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {

                ForEach(items) { item in

                    Button(action: item.action) {

                        HStack(spacing: 14) {

                            Image(systemName: item.icon)
                                .frame(width: 26)

                            Text(item.title)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(0.05),
                        radius: 8
                    )
            )
        }
    }
}

extension SettingsView {

    var aboutSection: some View {

        VStack(spacing: 6) {

            Text("Structify")
                .font(.headline)

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top,20)
    }
}

struct SettingItem: Identifiable {

    let id = UUID()
    let icon: String
    let title: String
    let action: () -> Void
}

extension SettingsView {

    func openURL(_ url: String) {

        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url)
    }

    func openSubscriptions() {

        if let url = URL(
            string:
            "https://apps.apple.com/account/subscriptions"
        ) {
            UIApplication.shared.open(url)
        }
    }

    func restorePurchases() {

        print("Restore purchases")
    }

    func contactSupport() {

        if let url = URL(
            string:"mailto:support@yourapp.com"
        ) {
            UIApplication.shared.open(url)
        }
    }

    func shareApp() {

        guard let url = URL(
            string: "https://apps.apple.com/app/idXXXXXXXX"
        ) else { return }

        let vc = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        guard let scene =
            UIApplication.shared.connectedScenes.first
            as? UIWindowScene,
              let root =
            scene.windows.first?.rootViewController
        else { return }

        root.present(vc, animated: true)
    }

    func rateApp() {

        guard let url = URL(
            string:"https://apps.apple.com/app/idXXXXXXXX?action=write-review"
        ) else { return }

        UIApplication.shared.open(url)
    }
}
