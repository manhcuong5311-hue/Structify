import SwiftUI

struct SettingsView: View {

    @State private var showPremium = false
    @State private var showDataManager = false
    @State private var showNotifications = false
    
    @EnvironmentObject var store: TimelineStore
    
    
    
    
    @Environment(\.colorScheme) private var scheme

    
    
    
    
    
    
    
    
    @State private var footerTapCount = 0
    @State private var showOnboarding = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // MARK: - Profile / App Hero
                heroCard

                // MARK: - Premium
                premiumCard

                // MARK: - Sections
                settingsGroup(title: "Manage", items: [
                    .init(icon: "externaldrive.fill",    label: "Data",          color: .blue)   { showDataManager = true },
                    .init(icon: "bell.badge.fill",       label: "Notifications", color: .red)    { showNotifications = true },
                    .init(icon: "gearshape.2.fill",      label: "Preferences",   color: .gray)   { }
                ])

                settingsGroup(title: "Support", items: [
                    .init(icon: "envelope.fill",         label: "Contact Us",    color: .teal)   { contactSupport() },
                    .init(icon: "questionmark.bubble.fill", label: "FAQ",         color: .indigo) { },
                    .init(icon: "square.and.arrow.up.fill", label: "Share App",   color: .orange) { shareApp() },
                    .init(icon: "star.fill",             label: "Rate App",      color: .yellow) { rateApp() }
                ])

                settingsGroup(title: "Account", items: [
                    .init(icon: "creditcard.fill",       label: "Subscription",  color: .purple) { openSubscriptions() },
                    .init(icon: "arrow.clockwise",       label: "Restore Purchase", color: .green) { restorePurchases() }
                ])

                settingsGroup(title: "Legal", items: [
                    .init(icon: "lock.shield.fill",      label: "Privacy Policy", color: .cyan)  { openURL("https://yourapp.com/privacy") },
                    .init(icon: "doc.text.fill",         label: "Terms of Use",   color: .mint)  { openURL("https://yourapp.com/terms") }
                ])

                // MARK: - Footer
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showNotifications) {  // 👈 thêm
                  NotificationsSettingsView()
                      .environmentObject(store)
              }
    }
}

// MARK: - Hero Card
extension SettingsView {

    var heroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4F46E5"), Color(hex: "#7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(hex: "#4F46E5").opacity(0.4), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text("Structify")
                    .font(.title3.bold())
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Premium Card
extension SettingsView {

    var premiumCard: some View {
        Button { showPremium = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Unlock all features & themes")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#1D1D2E"),
                                    Color(hex: "#2D2B55")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Decorative glow
                    Circle()
                        .fill(Color(hex: "#7C3AED").opacity(0.35))
                        .frame(width: 100)
                        .blur(radius: 40)
                        .offset(x: 100, y: -10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Group
extension SettingsView {

    struct RowItem: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let color: Color
        let action: () -> Void

        init(icon: String, label: String, color: Color, action: @escaping () -> Void) {
            self.icon = icon
            self.label = label
            self.color = color
            self.action = action
        }
    }

    func settingsGroup(title: String, items: [RowItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    Button(action: item.action) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(item.color.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: item.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(item.color)
                            }

                            Text(item.label)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SettingsRowButtonStyle())

                    if idx < items.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Button Style
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                ? Color(.systemFill)
                : Color.clear
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Footer
extension SettingsView {
    var footer: some View {
        VStack(spacing: 6) {
            Text("Made with ♥ by Structify")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("© 2026 All rights reserved")
                .font(.caption2)
                .foregroundStyle(footerTapCount > 0 ? .secondary : .quaternary)
                .overlay(
                    // Hint dots khi đang tap
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(i < footerTapCount
                                      ? Color.primary.opacity(0.5)
                                      : Color.primary.opacity(0.12))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .offset(y: 14)
                    .opacity(footerTapCount > 0 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: footerTapCount)
                )
                .onTapGesture {
                    footerTapCount += 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    if footerTapCount >= 5 {
                        footerTapCount = 0
                        showOnboarding = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }

                    // Reset sau 3 giây nếu không tap đủ
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if footerTapCount > 0 && footerTapCount < 5 {
                            withAnimation { footerTapCount = 0 }
                        }
                    }
                }
        }
        .padding(.top, 8)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

// MARK: - Actions
extension SettingsView {

    func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    func openSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    func restorePurchases() {
        print("Restore purchases")
    }

    func contactSupport() {
        if let url = URL(string: "mailto:support@structify.app") {
            UIApplication.shared.open(url)
        }
    }

    func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/idXXXXXXXX") else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(vc, animated: true)
    }

    func rateApp() {
        guard let url = URL(string: "https://apps.apple.com/app/idXXXXXXXX?action=write-review") else { return }
        UIApplication.shared.open(url)
    }
}
