import SwiftUI
import Combine

class TimelineStore: ObservableObject {
    
    @Published var events: [EventItem] = [] {
        didSet { save() }
    }
    
    private let key = "timeline_events"
    
    init() {
        UserDefaults.standard.removeObject(forKey: "timeline_events")
        load()
    }
    
    // MARK: Load
    
    func load() {
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            events = defaultEvents
            return
        }
        
        if let decoded = try? JSONDecoder().decode([EventItem].self, from: data) {
            
            events = decoded.sorted { $0.minutes < $1.minutes }
            
        } else {
            
            events = defaultEvents
        }
    }
    
    // MARK: Save
    
    func save() {
        
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func deleteEvent(_ event: EventItem) {
        
       
        events.removeAll { $0.id == event.id }
    }
    // MARK: Default Events
    
    private var defaultEvents: [EventItem] {

        [
            EventItem(
                minutes: 360,
                title: "Rise and Shine",
                icon: "alarm.fill",
                colorHex: "#FF9500",
                isSystemEvent: true
            ),

            EventItem(
                minutes: 420,
                duration: 90,
                title: "Workout",
                icon: "figure.strengthtraining.traditional",
                colorHex: "#FF3B30"
            ),

            EventItem(
                minutes: 750,
                title: "Lunch",
                icon: "fork.knife",
                colorHex: "#34C759"
            ),

            EventItem(
                minutes: 1410,
                title: "Wind Down",
                icon: "moon.fill",
                colorHex: "#007AFF",
                isSystemEvent: true
            )
        ]
    }
    
    // MARK: Add Event
    
    func addEvent(at gapIndex: Int) {

        guard gapIndex < events.count - 1 else { return }

        let current = events[gapIndex]
        let next = events[gapIndex + 1]

        let start = current.minutes + (current.duration ?? 0)
        let end = next.minutes

        let midpoint = start + (end - start) / 2

        let newEvent = EventItem(
            minutes: midpoint,
            duration: 30,
            title: "New Event",
            icon: "calendar",
            colorHex: "#FF3B30"
        )

        events.append(newEvent)
        events.sort { $0.minutes < $1.minutes }
    }
}
