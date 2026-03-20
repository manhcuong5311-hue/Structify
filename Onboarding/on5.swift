import SwiftUI

struct OnboardingSleepTimePage: View {

    @Binding var sleep: Date
    @State private var lastHapticStep: Int = -1
    // 0 → 720 minutes (6PM → 6AM)
    @State private var minutes: Double = 0

    var progress: Double {
        minutes / 360
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
                    .padding(.bottom, geo.size.height * 0.10)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .background(backgroundGradient)
        }
        .onChange(of: minutes) { _, newValue in

            let start = Calendar.current.startOfDay(for: Date())
                .addingTimeInterval(18 * 3600)

            sleep = start.addingTimeInterval(newValue * 60)
        }
    }
}

private extension OnboardingSleepTimePage {

    var titleSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(String(localized: "onboarding.sleep.title"))
                .font(.system(size: 42, weight: .bold, design: .serif))

            Text(String(localized: "onboarding.sleep.subtitle"))
                .foregroundStyle(.secondary)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension OnboardingSleepTimePage {

    var skyAnimation: some View {

        GeometryReader { geo in

            let width = geo.size.width
            let height = geo.size.height

            ZStack {

                // MOON GLOW
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 200, height: 200)
                    .blur(radius: 70)
                    .position(
                        x: width * (0.2 + progress * 0.6),
                        y: height * (0.65 - progress * 0.35)
                    )
                    .animation(.easeInOut(duration: 0.25), value: progress)

                // MOON
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .position(
                        x: width * (0.2 + progress * 0.6),
                        y: height * (0.65 - progress * 0.35)
                    )
                    .animation(.easeInOut(duration: 0.25), value: progress)

                // FAR CLOUD
                Image(systemName: "cloud")
                    .font(.system(size: 40))
                    .opacity(0.45)
                    .position(
                        x: width * (-0.3 + progress * 1.2),
                        y: height * 0.35
                    )
                    .animation(.linear(duration: 0.25), value: progress)

                // NEAR CLOUD
                Image(systemName: "cloud.fill")
                    .font(.system(size: 55))
                    .opacity(0.35)
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

private extension OnboardingSleepTimePage {

    var backgroundGradient: LinearGradient {

        let sunset = Color.orange.opacity(0.4 * (1 - progress))
        let dusk = Color.purple.opacity(0.3 * progress)
        let night = Color.black.opacity(0.45 * progress)

        return LinearGradient(
            colors: [
                sunset,
                dusk,
                night
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private extension OnboardingSleepTimePage {

    var timeSlider: some View {

        GeometryReader { geo in

            let width = geo.size.width
            let knobX = width * progress

            VStack(spacing: 18) {

                ZStack(alignment: .leading) {

                    // TRACK
                    Capsule()
                        .frame(height: 10)
                        .foregroundStyle(.gray.opacity(0.25))

                    // PROGRESS
                    Capsule()
                        .frame(width: knobX, height: 10)
                        .foregroundStyle(.black)
                        .animation(.interactiveSpring(), value: minutes)

                    // TIME BUBBLE
                    TimeBubble(
                        text: formattedTime(from: minutes, startHour: 18)
                    )
                    .position(x: knobX, y: -18)
                    .animation(.spring(response: 0.25), value: minutes)

                    // KNOB
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.3), radius: 6)
                        .overlay(
                            Circle().stroke(.black.opacity(0.1))
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

                            let newMinutes = percent * 360

                            // SNAP + clamp trong khoảng 0 → 360
                            minutes = min(360, max(0, round(newMinutes / 5) * 5))

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

                    Text(String(localized: "time.six_pm"))

                    Spacer()

                    Text(String(localized: "time.nine_pm"))

                    Spacer()

                    Text(String(localized: "time.midnight"))

                }
                .font(.caption)
                .foregroundStyle(.secondary)

            }

        }
        .frame(height: 90)
    }
}

private extension OnboardingSleepTimePage {

    var tickMarks: some View {

        GeometryReader { geo in

            let count = 12

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

private extension OnboardingSleepTimePage {

    var topProgress: some View {

        ProgressView(value: 1.0)
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
