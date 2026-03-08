import SwiftUI

struct OnboardingFocusPage: View {

    var body: some View {

        VStack(spacing: 20) {

            Spacer()

            Text("Stay focused")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("A minimal planner designed to keep you focused.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

        }
        .padding()
    }
}
