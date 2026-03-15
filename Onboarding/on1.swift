import SwiftUI

struct OnboardingWelcomePage: View {

    @State private var appeared = false
    @Environment(\.colorScheme) private var scheme
    @State private var idleBob = false
    
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // Title
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Welcome to\nStructify")
                            .font(.system(size: isPad ? 48 : 30, weight: .bold, design: .serif))
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)

                        Text("Plan your day visually. Build habits that stick. See your life take shape.")
                            .font(isPad ? .title3 : .body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: appeared)
                    }
                    .padding(.horizontal, isPad ? 48 : 24)

                    Spacer().frame(height: isPad ? 64 : 48)

                    // Feature pills — 2 column trên iPad
                    if isPad {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                            featureRow(icon: "timeline.selection",  title: "Visual Timeline",  subtitle: "Drag, drop and shape your day",          delay: 0.45)
                            featureRow(icon: "repeat.circle.fill",  title: "Habit Tracking",   subtitle: "Build consistency day by day",           delay: 0.55)
                            featureRow(icon: "chart.bar.fill",      title: "Progress Stats",   subtitle: "See how far you've come",                delay: 0.65)
                            featureRow(icon: "face.smiling.fill",   title: "Mood Journal",     subtitle: "Log how you feel, every day",            delay: 0.75)
                            featureRow(icon: "square.grid.2x2.fill",title: "200+ Icons",       subtitle: "Pick the perfect icon for every event",  delay: 0.85)
                            featureRow(icon: "paintpalette.fill",   title: "Custom Colors",    subtitle: "Make your timeline uniquely yours",      delay: 0.95)
                        }
                        .padding(.horizontal, 48)
                    } else {
                        VStack(spacing: 14) {
                            featureRow(icon: "timeline.selection",  title: "Visual Timeline",  subtitle: "Drag, drop and shape your day",          delay: 0.45)
                            featureRow(icon: "repeat.circle.fill",  title: "Habit Tracking",   subtitle: "Build consistency day by day",           delay: 0.55)
                            featureRow(icon: "chart.bar.fill",      title: "Progress Stats",   subtitle: "See how far you've come",                delay: 0.65)
                            featureRow(icon: "face.smiling.fill",   title: "Mood Journal",     subtitle: "Log how you feel, every day",            delay: 0.75)
                            featureRow(icon: "square.grid.2x2.fill",title: "200+ Icons",       subtitle: "Pick the perfect icon for every event",  delay: 0.85)
                            featureRow(icon: "paintpalette.fill",   title: "Custom Colors",    subtitle: "Make your timeline uniquely yours",      delay: 0.95)
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Swipe hint
                    VStack(spacing: 6) {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: isPad ? 18 : 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Swipe to get started")
                            .font(isPad ? .subheadline : .caption)
                            .foregroundStyle(.tertiary)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.9), value: appeared)
                    .padding(.bottom, geo.size.height * 0.06)
                }
            }
        }
        .onAppear {
            appeared = true
        }
    }

    // MARK: - Feature Row
    private func featureRow(icon: String, title: String, subtitle: String, delay: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scheme == .dark
                          ? Color.white.opacity(0.08)
                          : Color.black.opacity(0.06))
                    .frame(width: isPad ? 56 : 46, height: isPad ? 56 : 46)

                Image(systemName: icon)
                    .font(.system(size: isPad ? 24 : 20, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isPad ? 17 : 15, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: isPad ? 15 : 13))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(scheme == .dark
                      ? Color.white.opacity(0.06)
                      : Color(.secondarySystemBackground))
        )
        .offset(x: appeared ? 0 : 30)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appeared)
    }

    // MARK: - Background
    private var backgroundGradient: LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red:0.05,green:0.05,blue:0.12),
                    Color(red:0.08,green:0.06,blue:0.18),
                    Color(red:0.03,green:0.03,blue:0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.yellow.opacity(0.08),
                    Color.orange.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
