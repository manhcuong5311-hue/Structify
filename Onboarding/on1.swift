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
                        Text(String(localized: "onboarding.welcome_title"))
                            .font(.system(size: isPad ? 48 : 30, weight: .bold, design: .serif))
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)

                        Text(String(localized: "onboarding.welcome_subtitle"))
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
                            featureRow(
                                   icon: "timeline.selection",
                                   title: String(localized: "onboarding.feature.timeline.title"),
                                   subtitle: String(localized: "onboarding.feature.timeline.subtitle"),
                                   delay: 0.45
                               )

                               featureRow(
                                   icon: "repeat.circle.fill",
                                   title: String(localized: "onboarding.feature.habit.title"),
                                   subtitle: String(localized: "onboarding.feature.habit.subtitle"),
                                   delay: 0.55
                               )

                               featureRow(
                                   icon: "chart.bar.fill",
                                   title: String(localized: "onboarding.feature.stats.title"),
                                   subtitle: String(localized: "onboarding.feature.stats.subtitle"),
                                   delay: 0.65
                               )

                               featureRow(
                                   icon: "face.smiling.fill",
                                   title: String(localized: "onboarding.feature.mood.title"),
                                   subtitle: String(localized: "onboarding.feature.mood.subtitle"),
                                   delay: 0.75
                               )

                               featureRow(
                                   icon: "square.grid.2x2.fill",
                                   title: String(localized: "onboarding.feature.icons.title"),
                                   subtitle: String(localized: "onboarding.feature.icons.subtitle"),
                                   delay: 0.85
                               )

                               featureRow(
                                   icon: "paintpalette.fill",
                                   title: String(localized: "onboarding.feature.colors.title"),
                                   subtitle: String(localized: "onboarding.feature.colors.subtitle"),
                                   delay: 0.95
                               )
                        }
                        .padding(.horizontal, 48)
                    } else {
                        VStack(spacing: 14) {
                            featureRow(
                                   icon: "timeline.selection",
                                   title: String(localized: "onboarding.feature.timeline.title"),
                                   subtitle: String(localized: "onboarding.feature.timeline.subtitle"),
                                   delay: 0.45
                               )

                               featureRow(
                                   icon: "repeat.circle.fill",
                                   title: String(localized: "onboarding.feature.habit.title"),
                                   subtitle: String(localized: "onboarding.feature.habit.subtitle"),
                                   delay: 0.55
                               )

                               featureRow(
                                   icon: "chart.bar.fill",
                                   title: String(localized: "onboarding.feature.stats.title"),
                                   subtitle: String(localized: "onboarding.feature.stats.subtitle"),
                                   delay: 0.65
                               )

                               featureRow(
                                   icon: "face.smiling.fill",
                                   title: String(localized: "onboarding.feature.mood.title"),
                                   subtitle: String(localized: "onboarding.feature.mood.subtitle"),
                                   delay: 0.75
                               )

                               featureRow(
                                   icon: "square.grid.2x2.fill",
                                   title: String(localized: "onboarding.feature.icons.title"),
                                   subtitle: String(localized: "onboarding.feature.icons.subtitle"),
                                   delay: 0.85
                               )

                               featureRow(
                                   icon: "paintpalette.fill",
                                   title: String(localized: "onboarding.feature.colors.title"),
                                   subtitle: String(localized: "onboarding.feature.colors.subtitle"),
                                   delay: 0.95
                               )
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

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
