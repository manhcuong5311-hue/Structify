import SwiftUI

struct OnboardingWakeTimePage: View {

    @Binding var wakeUp: Date
    @State private var lastHapticStep: Int = -1
    // minutes from 0 → 720 (12h)
    @State private var minutes: Double = 0
   
    var progress: Double {
        minutes / 720
    }

    var body: some View {

        GeometryReader { geo in

            VStack(spacing: 28) {

                topProgress

                titleSection

                skyAnimation
                    .frame(height: geo.size.height * 0.30)

                Spacer()

                timeSlider
                    .padding(.bottom, geo.size.height * 0.08) // đẩy slider lên 1/4 màn
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .background(backgroundGradient)
        }
        .onChange(of: minutes) { _, newValue in
            wakeUp = Calendar.current.startOfDay(for: Date())
                .addingTimeInterval(newValue * 60)
        }
    }
}

private extension OnboardingWakeTimePage {

    var titleSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(String(localized: "onboarding.wakeup.title"))
                .font(.system(size: 42, weight: .bold, design: .serif))
                .minimumScaleFactor(0.75)

            Text(String(localized: "onboarding.wakeup.subtitle"))
                .foregroundStyle(.secondary)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private extension OnboardingWakeTimePage {

    var skyAnimation: some View {

        GeometryReader { geo in

            let width = geo.size.width
            let height = geo.size.height

            ZStack {

                // SUN GLOW
                Circle()
                    .fill(Color.yellow.opacity(0.45))
                    .frame(width: 220, height: 220)
                    .blur(radius: 70)
                    .position(
                        x: width * (0.15 + progress * 0.7),
                        y: height * (0.65 - progress * 0.35)
                    )
                    .animation(.easeInOut(duration: 0.25), value: progress)

                // SUN
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.yellow)
                    .position(
                        x: width * (0.15 + progress * 0.7),
                        y: height * (0.65 - progress * 0.35)
                    )
                    .animation(.easeInOut(duration: 0.25), value: progress)

                // FAR CLOUD (slow movement)
                Image(systemName: "cloud")
                    .font(.system(size: 40))
                    .opacity(0.5)
                    .position(
                        x: width * (-0.3 + progress * 1.2),
                        y: height * 0.35
                    )
                    .animation(.linear(duration: 0.25), value: progress)

                // NEAR CLOUD (faster → parallax)
                Image(systemName: "cloud.fill")
                    .font(.system(size: 55))
                    .opacity(0.4)
                    .position(
                        x: width * (-0.4 + progress * 1.6),
                        y: height * 0.6
                    )
                    .animation(.linear(duration: 0.25), value: progress)

            }
        }
        .frame(height: 230)
    }
}


private extension OnboardingWakeTimePage {

    var backgroundGradient: LinearGradient {

        let sunrise = Color.yellow.opacity(0.15 + progress * 0.5)
        let sky = Color.orange.opacity(progress * 0.25)

        return LinearGradient(
            colors: [
                Color(.systemBackground),
                sunrise,
                sky
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

}

private extension OnboardingWakeTimePage {

    var timeSlider: some View {

        GeometryReader { geo in

            let width = geo.size.width
            let knobX = width * progress

            VStack(spacing: 18) {

                ZStack(alignment: .leading) {

                    Capsule()
                        .frame(height: 10)
                        .foregroundStyle(.gray.opacity(0.2))

                    Capsule()
                        .frame(width: knobX, height: 10)
                        .foregroundStyle(.black)
                        .animation(.interactiveSpring(), value: minutes)

                    // TIME BUBBLE
                    let bubbleX = min(max(knobX, 50), width - 50)

                    TimeBubble(
                        text: formattedTime(from: minutes, startHour: 0)
                    )
                    .position(x: bubbleX, y: -46)
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: minutes)

                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .overlay(
                            Circle()
                                .stroke(.black.opacity(0.1), lineWidth: 1)
                        )
                        .position(x: knobX, y: 5)
                        .animation(.interactiveSpring(), value: minutes)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in

                            let percent = max(
                                0,
                                min(1, value.location.x / width)
                            )

                            let newMinutes = percent * 720

                            // SNAP mỗi 5 phút
                            minutes = round(newMinutes / 5) * 5

                            // HAPTIC mỗi 15 phút
                            let step = Int(minutes / 15)

                            if step != lastHapticStep {

                                UIImpactFeedbackGenerator(style: .light)
                                    .impactOccurred()

                                lastHapticStep = step
                            }
                        }
                )

                tickMarks

                HStack {

                    Text(String(localized: "time.midnight"))
                    Spacer()

                    Text(String(localized: "time.six_am"))

                    Spacer()

                    Text(String(localized: "time.noon"))

                }
                .font(.caption)
                .foregroundStyle(.secondary)

            }

        }
        .frame(height: 110)
    }
}


private extension OnboardingWakeTimePage {

    var tickMarks: some View {

        GeometryReader { geo in

            let count = 24

            HStack(spacing: 0) {

                ForEach(0...count, id: \.self) { i in

                    Rectangle()
                        .frame(
                            width: 1,
                            height: i % 6 == 0 ? 12 : 6
                        )
                        .foregroundStyle(.gray.opacity(0.5))
                        .frame(maxWidth: .infinity)

                }
            }
        }
        .frame(height: 12)
    }
}


private extension OnboardingWakeTimePage {

    var topProgress: some View {

        ProgressView(value: 0.8)
            .progressViewStyle(.linear)
            .tint(.black)
    }

}

private func formattedTime(from minutes: Double, startHour: Int) -> String {

    let calendar = Calendar.current

    let base = calendar.startOfDay(for: Date())
        .addingTimeInterval(Double(startHour) * 3600)

    let date = base.addingTimeInterval(minutes * 60)

    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"

    return formatter.string(from: date)
}

struct TimeBubble: View {

    let text: String

    var body: some View {

        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(radius: 4)
    }
}
