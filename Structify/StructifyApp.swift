import SwiftUI

@main
struct StructifyApp: App {
    
    @StateObject private var calendar = CalendarState()
    @StateObject private var timeline = TimelineStore()
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(timeline)
                .environmentObject(calendar)
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}

// MARK: - RootView
struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var showLaunch = true
    @State private var launchOpacity: Double = 1
    @State private var contentOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Content underneath
            Group {
                if hasSeenOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .opacity(contentOpacity)

            // Launch overlay
            if showLaunch {
                launchScreen
                    .opacity(launchOpacity)
                    .ignoresSafeArea()
            }
        }
        .onAppear { startLaunchSequence() }
    }
    
    // Thêm computed var vào RootView (cạnh body):
    var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return UIImage(named: "AppIcon") }
        return UIImage(named: name)
    }
    

    // MARK: - Launch Screen
    var launchScreen: some View {
        ZStack {
            // Background
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            // Ambient glow
            Circle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.15))
                .blur(radius: 100)
                .frame(width: 400)
                .offset(x: -60, y: -180)
                .scaleEffect(glowPulse ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)

            Circle()
                .fill(Color(red: 0.4, green: 0.3, blue: 0.85).opacity(0.08))
                .blur(radius: 120)
                .frame(width: 350)
                .offset(x: 100, y: 120)

            // Logo
            VStack(spacing: 20) {
                // TÌM toàn bộ ZStack logo, ĐỔI THÀNH:

                ZStack {
                    // Glow — tách riêng, không ảnh hưởng icon
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(hex: PreferencesStore().accentHex).opacity(0.3))
                        .frame(width: 108, height: 108)
                        .blur(radius: 24)
                        .allowsHitTesting(false)

                    // AppIcon đọc từ Info.plist
                    if let icon = appIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
                    } else {
                        // Fallback nếu không đọc được icon
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(hex: PreferencesStore().accentHex))
                            .frame(width: 88, height: 88)
                            .overlay(
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Structify")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Plan your day with intention")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .opacity(logoOpacity)
                .offset(y: logoScale < 1 ? 8 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.15), value: logoScale)
            }
        }
    }

    // MARK: - Animation Sequence
    func startLaunchSequence() {
        // Glow pulse
        withAnimation { glowPulse = true }

        // Logo appears
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Hold → then fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            // Fade content in
            withAnimation(.easeIn(duration: 0.3)) {
                contentOpacity = 1
            }
            // Fade launch out slightly later
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                launchOpacity = 0
            }
            // Remove launch view after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showLaunch = false
            }
        }
    }
}
