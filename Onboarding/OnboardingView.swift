import SwiftUI

struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var page = 0
   
    @EnvironmentObject var timeline: TimelineStore
    
    // Trong OnboardingView — default hợp lý thay vì Date():
    @State private var wakeUp: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 6; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    @State private var sleep: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 22; c.minute = 30
        return Calendar.current.date(from: c) ?? Date()
    }()
    
    private let totalPages = 6

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

            OnboardingPremiumPage {
                finishOnboarding()
            }
            .tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            continueButton
        }
    }

    private var continueButton: some View {
        Group {
            if page < totalPages - 1 {
                Button {
                    if page == totalPages - 2 {
                        // Trang cuối trước premium → next
                        withAnimation(.easeInOut) { page += 1 }
                    } else {
                        withAnimation(.easeInOut) { page += 1 }
                    }
                } label: {
                    Text("Continue")
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
            // Trang premium tự có nút riêng → ẩn nút chung
        }
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true

        let cal = Calendar.current
        let wakeMinutes = cal.component(.hour, from: wakeUp) * 60 + cal.component(.minute, from: wakeUp)
        let rawSleepMinutes = cal.component(.hour, from: sleep) * 60 + cal.component(.minute, from: sleep)
        let sleepMinutes = rawSleepMinutes < wakeMinutes ? rawSleepMinutes + 1440 : rawSleepMinutes

        // Guard: phải cách nhau ít nhất 1 tiếng
        guard sleepMinutes - wakeMinutes >= 60 else {
            timeline.updateSystemEvents(wakeMinutes: 360, sleepMinutes: 1410) // fallback an toàn
            return
        }

        timeline.updateSystemEvents(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
    }
}
