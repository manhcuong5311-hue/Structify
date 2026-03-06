//
//  TimelineStore.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI
import Combine

class TimelineStore: ObservableObject {
    
    @Published var events: [EventItem] = [] {
        didSet { save() }
    }
    
    private let key = "timeline_events"
    
    init() {

        UserDefaults.standard.removeObject(forKey: key) // reset test

        load()
    }
    
    func load() {
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            events = defaultEvents
            return
        }
        
        if let decoded = try? JSONDecoder().decode([EventItem].self, from: data) {
            events = decoded
        }
    }
    
    func save() {
        
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private var defaultEvents: [EventItem] {
        
        [
            EventItem(minutes: 360, title: "Rise and Shine", icon: "alarm.fill", colorHex: "#FF9500"),
            
            // Event có duration 1h30
            EventItem(minutes: 420, duration: 90, title: "Workout", icon: "figure.strengthtraining.traditional", colorHex: "#FF3B30"),
            
            EventItem(minutes: 750, title: "Lunch", icon: "fork.knife", colorHex: "#34C759"),
            EventItem(minutes: 1410, title: "Wind Down", icon: "moon.fill", colorHex: "#007AFF")
        ]
    }
}


