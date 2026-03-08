//
//  1.swift
//  Structify
//
//  Created by Sam Manh Cuong on 7/3/26.
//

import SwiftUI

struct OnboardingWelcomePage: View {

    var body: some View {

        VStack(spacing: 20) {

            Spacer()

            Text("Welcome to Structify")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Plan your day visually with a clean timeline.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

        }
        .padding()
    }
}
