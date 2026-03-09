

import SwiftUI

@main
struct StructifyApp: App {
    
    @StateObject private var calendar = CalendarState()
    @StateObject private var timeline = TimelineStore()
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            
            Group {
                if hasSeenOnboarding {
                    ContentView()
                        
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(timeline)
            .environmentObject(calendar)
        }
        
    }
}


