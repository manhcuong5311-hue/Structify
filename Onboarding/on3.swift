import SwiftUI
import Combine

struct OnboardingFocusPage: View {

    @State private var appeared = false
    @State private var pulseRing = false
    @State private var progressValue: CGFloat = 0
    @State private var currentTime = Date()
    @Environment(\.colorScheme) private var scheme
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: currentTime)
    }

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 1.8)) { progressValue = 0.62 }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseRing = true }
            }
        }
        .onReceive(timer) { t in currentTime = t }
    }

    // MARK: - iPad: Left text + Right big focus card
    private func iPadLayout(geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Left column
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                progressBar
                    .padding(.bottom, 32)

                titleBlock(titleSize: 44)

                Spacer().frame(height: 36)

                VStack(spacing: 12) {
                    featurePill(icon: "lock.fill",        text: String(localized: "feature.lock_past_events"),    delay: 0.45)
                    featurePill(icon: "waveform.path.ecg", text: String(localized: "feature.live_progress"),      delay: 0.55)
                    featurePill(icon: "bell.slash.fill",  text: String(localized: "feature.smart_notifications"), delay: 0.65)
                }

                Spacer()
            }
            .frame(width: geo.size.width * 0.42)
            .padding(.horizontal, 52)

            // Right column — big focus card
            VStack {
                Spacer()
                focusCard
                    .frame(maxWidth: 480)
                    .scaleEffect(appeared ? 1 : 0.90)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.65, dampingFraction: 0.75).delay(0.3), value: appeared)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 52)
        }
    }

    // MARK: - iPhone: Compact title + prominent focus card + pills
    private func iPhoneLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Spacer().frame(height: 24)

            titleBlock(titleSize: 34)
                .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            focusCard
                .padding(.horizontal, 20)
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3), value: appeared)

            Spacer().frame(height: 18)

            VStack(spacing: 10) {
                featurePill(icon: "lock.fill",        text: String(localized: "feature.lock_past_events"),    delay: 0.5)
                featurePill(icon: "waveform.path.ecg", text: String(localized: "feature.live_progress"),      delay: 0.6)
                featurePill(icon: "bell.slash.fill",  text: String(localized: "feature.smart_notifications"), delay: 0.7)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        ProgressView(value: 0.4)
            .progressViewStyle(.linear)
            .tint(.primary.opacity(0.8))
    }

    // MARK: - Title Block
    private func titleBlock(titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "onboarding.focus.title"))
                .font(.system(size: titleSize, weight: .bold, design: .serif))
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: appeared ? 0 : 18)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

            Text(String(localized: "onboarding.focus.subtitle"))
                .font(isPad ? .body : .subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: appeared ? 0 : 14)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
        }
    }

    // MARK: - Focus Card
    var focusCard: some View {
        VStack(spacing: 0) {

            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "timeline.now_running"))
                        .font(.system(size: isPad ? 11 : 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(1.2)
                    Text(timeString)
                        .font(.system(size: isPad ? 18 : 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.90, blue: 0.55))
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulseRing ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseRing)
                    Text(String(localized: "timeline.live"))
                        .font(.system(size: isPad ? 13 : 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, isPad ? 24 : 20)
            .padding(.top, isPad ? 20 : 16)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.12))

            // Current event
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: isPad ? 16 : 14, style: .continuous)
                        .fill(Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.3))
                        .frame(width: isPad ? 64 : 52, height: isPad ? 64 : 52)
                    RoundedRectangle(cornerRadius: isPad ? 16 : 14, style: .continuous)
                        .stroke(Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.5), lineWidth: 1.5)
                        .frame(width: isPad ? 64 : 52, height: isPad ? 64 : 52)
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: isPad ? 26 : 22, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 1.0))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "demo.event.deep_work"))
                        .font(.system(size: isPad ? 22 : 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(localized: "timeline.time_left_example"))
                        .font(.system(size: isPad ? 14 : 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: isPad ? 38 : 32, height: isPad ? 38 : 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: isPad ? 13 : 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, isPad ? 24 : 20)
            .padding(.vertical, isPad ? 18 : 14)

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("08:00")
                        .font(.system(size: isPad ? 12 : 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()
                    Spacer()
                    Text("62%")
                        .font(.system(size: isPad ? 12 : 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 1.0))
                    Spacer()
                    Text("09:30")
                        .font(.system(size: isPad ? 12 : 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()
                }

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.55, green: 0.75, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: g.size.width * progressValue, height: 6)
                            .animation(.easeInOut(duration: 1.8), value: progressValue)
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.8), radius: 4)
                            .offset(x: g.size.width * progressValue - 6, y: -3)
                            .animation(.easeInOut(duration: 1.8), value: progressValue)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, isPad ? 24 : 20)
            .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.08))

            // Up next
            HStack(spacing: 10) {
                Text(String(localized: "timeline.up_next"))
                    .font(.system(size: isPad ? 10 : 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.2)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: isPad ? 13 : 11))
                    .foregroundStyle(Color(red: 0.75, green: 0.55, blue: 0.35).opacity(0.8))
                Text(String(localized: "demo.event.coffee_break_next"))
                    .font(.system(size: isPad ? 13 : 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            .padding(.horizontal, isPad ? 24 : 20)
            .padding(.vertical, isPad ? 14 : 11)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.18).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: Color(red: 0.25, green: 0.40, blue: 0.80).opacity(0.22), radius: 28, y: 14)
    }

    // MARK: - Feature Pill
    private func featurePill(icon: String, text: String, delay: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: isPad ? 15 : 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: isPad ? 22 : 18)
            Text(text)
                .font(.system(size: isPad ? 15 : 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, isPad ? 18 : 14)
        .padding(.vertical, isPad ? 13 : 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark
                      ? Color.white.opacity(0.06)
                      : Color(.secondarySystemBackground))
        )
        .offset(x: appeared ? 0 : 28)
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
