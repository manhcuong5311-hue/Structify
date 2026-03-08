//
//  2.swift
//  Structify
//
//  Created by Sam Manh Cuong on 7/3/26.
//

import SwiftUI

struct OnboardingTimelinePage: View {

    var body: some View {

        VStack(spacing: 20) {

            Spacer()

            Text("See your day as a timeline")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Tasks appear as blocks in time.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

        }
        .padding()
    }
}
