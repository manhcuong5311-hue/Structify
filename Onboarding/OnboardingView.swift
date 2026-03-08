import SwiftUI

struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var page = 0
    @State private var wakeUp = Date()
    @State private var sleep = Date()
    @EnvironmentObject var timeline: TimelineStore
    
    
    
    private let totalPages = 5

    var body: some View {

        TabView(selection: $page) {

            OnboardingWelcomePage()
                .tag(0)

            OnboardingTimelinePage()
                .tag(1)

            OnboardingFocusPage()
                .tag(2)

            OnboardingWakeTimePage(wakeUp: $wakeUp)
                .tag(3)

            OnboardingSleepTimePage(sleep: $sleep)
                .tag(4)

        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            continueButton
        }
    }

    private var continueButton: some View {

        Button {

            if page == totalPages - 1 {
                finishOnboarding()
            } else {
                withAnimation(.easeInOut) {
                    page += 1
                }
            }

        } label: {

            Text(page == totalPages - 1 ? "Get Started" : "Continue")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.black)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func finishOnboarding() {

        hasSeenOnboarding = true

        let calendar = Calendar.current

        let wakeMinutes =
            calendar.component(.hour, from: wakeUp) * 60 +
            calendar.component(.minute, from: wakeUp)

        let rawSleepMinutes =
            calendar.component(.hour, from: sleep) * 60 +
            calendar.component(.minute, from: sleep)

        // Normalize nếu sleep qua nửa đêm
        let sleepMinutes =
            rawSleepMinutes < wakeMinutes
            ? rawSleepMinutes + 1440
            : rawSleepMinutes

        timeline.updateSystemEvents(
            wakeMinutes: wakeMinutes,
            sleepMinutes: sleepMinutes
        )
    }
}
