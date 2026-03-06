

import SwiftUI

@main
struct StructifyApp: App {

    @StateObject private var calendar = CalendarState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendar)
        }
    }
}
