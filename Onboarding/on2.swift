import SwiftUI

struct OnboardingTimelinePage: View {

    @State private var appeared = false
    @State private var animateEvents = false
    @Environment(\.colorScheme) private var scheme

    let demoEvents: [(String, String, Color, String, Bool)] = [
        ("06:30", "sun.max.fill",        Color(red: 1.0, green: 0.75, blue: 0.25), String(localized: "demo.event.morning_start"), false),
        ("08:00", "briefcase.fill",      Color(red: 0.35, green: 0.55, blue: 0.90), String(localized: "demo.event.deep_work"),    true),
        ("10:30", "cup.and.saucer.fill", Color(red: 0.65, green: 0.45, blue: 0.30), String(localized: "demo.event.coffee_break"), false),
        ("12:00", "fork.knife",          Color(red: 0.90, green: 0.45, blue: 0.35), String(localized: "demo.event.lunch"),        true),
        ("14:00", "figure.run",          Color(red: 0.35, green: 0.80, blue: 0.55), String(localized: "demo.event.workout"),      true),
        ("22:00", "moon.stars.fill",     Color(red: 0.40, green: 0.35, blue: 0.75), String(localized: "demo.event.wind_down"),    false),
    ]

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

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
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { animateEvents = true }
            }
        }
    }

    // MARK: - iPad: Left text column + Right timeline card
    private func iPadLayout(geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Left — text + feature bullets
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                progressBar
                    .padding(.bottom, 32)

                titleBlock(size: 44)

                Spacer().frame(height: 36)

                VStack(alignment: .leading, spacing: 14) {
                    bulletRow(icon: "hand.draw.fill",     text: String(localized: "onboarding.timeline.bullet.drag"))
                    bulletRow(icon: "checkmark.circle.fill", text: String(localized: "onboarding.timeline.bullet.track"))
                    bulletRow(icon: "arrow.clockwise",    text: String(localized: "onboarding.timeline.bullet.repeat"))
                }

                Spacer()
            }
            .frame(width: geo.size.width * 0.42)
            .padding(.horizontal, 52)

            // Right — timeline card
            timelineCard
                .frame(maxWidth: .infinity)
                .padding(.trailing, 52)
                .padding(.vertical, 60)
                .offset(x: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
        }
    }

    // MARK: - iPhone: stacked progress / title / card
    private func iPhoneLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Spacer().frame(height: 28)

            titleBlock(size: 36)
                .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            timelineCard
                .padding(.horizontal, 20)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)

            Spacer()
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        ProgressView(value: 0.2)
            .progressViewStyle(.linear)
            .tint(scheme == .dark ? Color.white.opacity(0.6) : .primary.opacity(0.8))
    }

    // MARK: - Title Block
    private func titleBlock(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "onboarding.timeline.title"))
                .font(.system(size: size, weight: .bold, design: .serif))
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: appeared ? 0 : 18)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

            Text(String(localized: "onboarding.timeline.subtitle"))
                .font(isPad ? .body : .subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: appeared ? 0 : 14)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
        }
    }

    // MARK: - Timeline as a glass card
    private var timelineCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(demoEvents.enumerated()), id: \.offset) { i, event in
                demoEventRow(
                    time: event.0, icon: event.1, color: event.2,
                    title: event.3, hasDuration: event.4, index: i
                )

                if i < demoEvents.count - 1 {
                    HStack(spacing: 0) {
                        Spacer().frame(width: isPad ? 56 + 16 + 26 : 44 + 16 + 21)
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 1.5, height: isPad ? 22 : 16)
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, isPad ? 16 : 12)
        .padding(.horizontal, isPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(scheme == .dark
                      ? Color.white.opacity(0.06)
                      : Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.3 : 0.06), radius: 16, y: 6)
    }

    // MARK: - Bullet Row (iPad only)
    private func bulletRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .offset(x: appeared ? 0 : -20)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: appeared)
    }

    // MARK: - Demo Event Row
    private func demoEventRow(
        time: String, icon: String, color: Color,
        title: String, hasDuration: Bool, index: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {

            Text(time)
                .frame(width: isPad ? 52 : 40, alignment: .trailing)
                .font(.system(size: isPad ? 13 : 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: isPad ? 15 : 12, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: isPad ? 50 : 40, height: isPad ? 50 : 40)
                RoundedRectangle(cornerRadius: isPad ? 15 : 12, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
                    .frame(width: isPad ? 50 : 40, height: isPad ? 50 : 40)
                Image(systemName: icon)
                    .font(.system(size: isPad ? 19 : 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isPad ? 16 : 14, weight: .semibold))
                if hasDuration {
                    Text(String(localized: "common.duration_example"))
                        .font(.system(size: isPad ? 12 : 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1.5))
        }
        .padding(.vertical, isPad ? 8 : 5)
        .offset(x: animateEvents ? 0 : 36)
        .opacity(animateEvents ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.07 + 0.15),
            value: animateEvents
        )
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
