import SwiftUI

struct OnboardingWelcomePage: View {

    @State private var appeared = false
    @Environment(\.colorScheme) private var scheme

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private struct Feature {
        let icon: String
        let titleKey: String.LocalizationValue
        let color: Color
    }

    private let features: [Feature] = [
        Feature(icon: "timeline.selection",   titleKey: "onboarding.feature.timeline.title", color: Color.orange),
        Feature(icon: "repeat.circle.fill",   titleKey: "onboarding.feature.habit.title",    color: Color.blue),
        Feature(icon: "chart.bar.fill",       titleKey: "onboarding.feature.stats.title",    color: Color.green),
        Feature(icon: "face.smiling.fill",    titleKey: "onboarding.feature.mood.title",     color: Color.yellow),
        Feature(icon: "square.grid.2x2.fill", titleKey: "onboarding.feature.icons.title",    color: Color.purple),
        Feature(icon: "paintpalette.fill",    titleKey: "onboarding.feature.colors.title",   color: Color.pink),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient.ignoresSafeArea()
                if isPad {
                    iPadLayout(geo: geo)
                } else {
                    iPhoneLayout(geo: geo)
                }
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - iPad: side-by-side hero + feature grid
    private func iPadLayout(geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Left — hero
            VStack(alignment: .leading, spacing: 28) {
                Spacer()
                heroIcon
                    .scaleEffect(appeared ? 1 : 0.75)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding.welcome_title"))
                        .font(.system(size: 46, weight: .bold, design: .serif))
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

                    Text(String(localized: "onboarding.welcome_subtitle"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .offset(y: appeared ? 0 : 14)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)
                }
                Spacer()
            }
            .frame(width: geo.size.width * 0.44)
            .padding(.horizontal, 52)

            // Right — 2×3 feature grid
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                    featureCard(icon: f.icon, title: String(localized: f.titleKey), color: f.color, delay: Double(i) * 0.07 + 0.3)
                }
            }
            .padding(.trailing, 52)
            .padding(.vertical, 60)
        }
    }

    // MARK: - iPhone: centered hero + 2-column grid
    private func iPhoneLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: geo.size.height * 0.06)

            heroIcon
                .scaleEffect(appeared ? 1 : 0.75)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

            Spacer().frame(height: 22)

            VStack(spacing: 8) {
                Text(String(localized: "onboarding.welcome_title"))
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 18)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

                Text(String(localized: "onboarding.welcome_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                    featureCard(icon: f.icon, title: String(localized: f.titleKey), color: f.color, delay: Double(i) * 0.07 + 0.35)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Hero Icon
    private var heroIcon: some View {
        ZStack {
            // Soft glow
            Circle()
                .fill(LinearGradient(
                    colors: [Color.orange.opacity(0.35), Color.yellow.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: isPad ? 160 : 120, height: isPad ? 160 : 120)
                .blur(radius: 28)

            // Icon card
            RoundedRectangle(cornerRadius: isPad ? 36 : 28, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.1) : Color.white)
                .frame(width: isPad ? 110 : 86, height: isPad ? 110 : 86)
                .shadow(color: Color.orange.opacity(0.22), radius: 20, y: 8)
                .overlay(
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: isPad ? 50 : 38, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                )
        }
    }

    // MARK: - Feature Card (icon + title, no subtitle)
    private func featureCard(icon: String, title: String, color: Color, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: isPad ? 48 : 40, height: isPad ? 48 : 40)
                Image(systemName: icon)
                    .font(.system(size: isPad ? 20 : 17, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.system(size: isPad ? 15 : 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isPad ? 16 : 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(scheme == .dark
                      ? Color.white.opacity(0.07)
                      : Color(.secondarySystemBackground))
        )
        .offset(y: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appeared)
    }

    // MARK: - Background
    private var backgroundGradient: LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.03, green: 0.03, blue: 0.10)
                ],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.yellow.opacity(0.08),
                    Color.orange.opacity(0.12)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
