import SwiftUI

struct OnboardingTimelinePage: View {

    @State private var appeared = false
    @State private var animateEvents = false
    @Environment(\.colorScheme) private var scheme
    let demoEvents: [(String, String, Color, String, Bool)] = [
        ("06:30", "sun.max.fill",    Color(red:1.0,green:0.75,blue:0.25), "Morning Start",  false),
        ("08:00", "briefcase.fill",  Color(red:0.35,green:0.55,blue:0.90), "Deep Work",     true),
        ("10:30", "cup.and.saucer.fill", Color(red:0.65,green:0.45,blue:0.30), "Coffee Break", false),
        ("12:00", "fork.knife",      Color(red:0.90,green:0.45,blue:0.35), "Lunch",         true),
        ("14:00", "figure.run",      Color(red:0.35,green:0.80,blue:0.55), "Workout",       true),
        ("22:00", "moon.stars.fill", Color(red:0.40,green:0.35,blue:0.75), "Wind Down",     false),
    ]
    
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {

                    // Top progress
                    ProgressView(value: 0.2)
                        .progressViewStyle(.linear)
                        .tint(scheme == .dark ? Color.white.opacity(0.6) : .primary.opacity(0.8))
                        .padding(.horizontal, isPad ? 48 : 24)
                        .padding(.top, 20)

                    Spacer().frame(height: 28)

                    // Title
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your day,\nas a timeline")
                            .font(.system(size: isPad ? 48 : 38, weight: .bold, design: .serif))
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: appeared ? 0 : 18)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                        Text("Every event and habit lives on your timeline. Drag to reschedule, tap to track.")
                            .font(isPad ? .title3 : .body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: appeared ? 0 : 14)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
                    }
                    .padding(.horizontal, isPad ? 48 : 24)
                    
                    Spacer().frame(height: 32)

                    // Timeline demo
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(demoEvents.enumerated()), id: \.offset) { i, event in
                                demoEventRow(
                                    time: event.0,
                                    icon: event.1,
                                    color: event.2,
                                    title: event.3,
                                    hasDuration: event.4,
                                    index: i
                                )

                                if i < demoEvents.count - 1 {
                                    // Connector line
                                    HStack(spacing: 0) {
                                        Spacer().frame(width: 24 + 16 + 25) // time + gap + half icon
                                        Rectangle()
                                            .fill(Color.primary.opacity(0.12))
                                            .frame(width: 2, height: 28)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, isPad ? 48 : 24)
                    }
                    .frame(maxWidth: isPad ? 600 : .infinity)  // 👈 thêm
                    .frame(maxWidth: .infinity)               // center
                    .frame(height: geo.size.height * (isPad ? 0.52 : 0.48))
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear,  location: 0),
                                .init(color: .black,  location: 0.06),
                                .init(color: .black,  location: 0.88),
                                .init(color: .clear,  location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    Spacer()

                    // Swipe hint
                    VStack(spacing: 6) {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: isPad ? 18 : 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Swipe to continue")
                            .font(isPad ? .subheadline : .caption)
                            .foregroundStyle(.tertiary)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.9), value: appeared)
                    .padding(.bottom, geo.size.height * 0.05)
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

    // MARK: - Demo Event Row
    private func demoEventRow(
        time: String,
        icon: String,
        color: Color,
        title: String,
        hasDuration: Bool,
        index: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {

            // Time
            Text(time)
                .frame(width: isPad ? 52 : 40, alignment: .trailing)
                .font(.system(size: isPad ? 14 : 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
              

            // Icon pill
            ZStack {
                RoundedRectangle(cornerRadius: isPad ? 16 : 14, style: .continuous)

                    .fill(color.opacity(0.15))
                    .frame(width: isPad ? 52 : 42, height: isPad ? 52 : 42)
                RoundedRectangle(cornerRadius: isPad ? 16 : 14, style: .continuous)

                    .stroke(color.opacity(0.3), lineWidth: 1)
                    .frame(width: isPad ? 52 : 42, height: isPad ? 52 : 42)
                Image(systemName: icon)
                    .font(.system(size: isPad ? 21 : 17, weight: .semibold))

                    .foregroundStyle(color)
            }

            // Title + duration badge
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: isPad ? 17 : 15, weight: .semibold))

                if hasDuration {
                    Text("1h 30m")
                         .font(.system(size: isPad ? 13 : 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Completion dot
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(color.opacity(0.5), lineWidth: 1.5)
                )
        }
        .padding(.vertical, isPad ? 10 : 6)
        .offset(x: animateEvents ? 0 : 40)
        .opacity(animateEvents ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8)
            .delay(Double(index) * 0.08 + 0.2),
            value: animateEvents
        )
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
