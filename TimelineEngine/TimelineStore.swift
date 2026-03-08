import SwiftUI
import Combine

struct EventTemplate: Identifiable, Codable {

    var id = UUID()

    var minutes: Int
    var duration: Int?

    var title: String
    var icon: String
    var colorHex: String

    var recurrence: Recurrence
    var isSystemEvent: Bool = false
}


enum Recurrence: Codable {

    case daily
    case weekdays
    case specific([Int]) // weekday numbers
    case once(Date)
}

struct EventOverride: Codable {

    var templateID: UUID
    var dateKey: Int
    var minutes: Int
}

class TimelineStore: ObservableObject {
    

    private let wakeKey = "user_wake_minutes"
    private let sleepKey = "user_sleep_minutes"
    private let key = "timeline_events"
    @Published var templates: [EventTemplate] = []

    @Published var overrides: [EventOverride] = []
 
    private var overrideIndex: [Int: [EventOverride]] = [:]
    private var cache: [Int: [EventItem]] = [:]
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    
    init() {

        load()
        rebuildIndex()
        
        if templates.isEmpty {

            templates = [

                EventTemplate(
                    minutes: wakeMinutes,
                    title: "Rise and Shine",
                    icon: "alarm.fill",
                    colorHex: "#FF9500",
                    recurrence: .daily,
                    isSystemEvent: true
                ),

                EventTemplate(
                    minutes: sleepMinutes,
                    title: "Wind Down",
                    icon: "moon.fill",
                    colorHex: "#007AFF",
                    recurrence: .daily,
                    isSystemEvent: true
                )
            ]

            save()
        }
    }
    
    var wakeMinutes: Int {
        UserDefaults.standard.object(forKey: wakeKey) as? Int ?? 360
    }

    var sleepMinutes: Int {
        UserDefaults.standard.object(forKey: sleepKey) as? Int ?? 1410
    }
    
    // MARK: Load
    
    func load() {

        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: "templates"),
           let decoded = try? decoder.decode([EventTemplate].self, from: data) {

            templates = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "overrides"),
           let decoded = try? decoder.decode([EventOverride].self, from: data) {

            overrides = decoded
        }
    }
    
    func rebuildIndex() {

        overrideIndex = Dictionary(grouping: overrides) { $0.dateKey }

    }
    
    // MARK: Save
    
    func save() {

        let encoder = JSONEncoder()

        if let templateData = try? encoder.encode(templates) {
            UserDefaults.standard.set(templateData, forKey: "templates")
        }

        if let overrideData = try? encoder.encode(overrides) {
            UserDefaults.standard.set(overrideData, forKey: "overrides")
        }
    }
    
    func deleteEvent(templateID: UUID, date: Date) {

        let k = key(for: date)

        overrides.removeAll {
            $0.templateID == templateID &&
            $0.dateKey == k
        }

        overrides.append(
            EventOverride(
                templateID: templateID,
                dateKey: k,
                minutes: -1
            )
        )

        rebuildIndex()
        invalidateCache()
        save()
    }
    
    
    // MARK: Add Event
    
  
    
    func updateSystemEvents(wakeMinutes: Int, sleepMinutes: Int) {

        UserDefaults.standard.set(wakeMinutes, forKey: wakeKey)
        UserDefaults.standard.set(sleepMinutes, forKey: sleepKey)

        for i in templates.indices {

            if templates[i].title == "Rise and Shine" {
                templates[i].minutes = wakeMinutes
            }

            if templates[i].title == "Wind Down" {
                templates[i].minutes = sleepMinutes
            }
        }

        save()
        invalidateCache()
    }
    
    func events(for date: Date) -> [EventItem] {

        let k = key(for: date)

        if let cached = cache[k] {
            return cached
        }

        var result: [EventItem] = []

        for template in templates where template.matches(date: date) {
            result.append(template.toEvent())
        }

        applyOverrides(&result, date: date)

        result.sort { $0.minutes < $1.minutes }

        cache[k] = result

        return result
    }
    
    func applyOverrides(_ events: inout [EventItem], date: Date) {

        let k = key(for: date)

        guard let dayOverrides = overrideIndex[k] else { return }

        for override in dayOverrides {

            if let index = events.firstIndex(where: { $0.id == override.templateID }) {

                if override.minutes < 0 {
                    events.remove(at: index)
                } else {
                    events[index].minutes = override.minutes
                }
            }
        }
    }
    
    func key(for date: Date) -> Int {

        let c = Calendar.current.dateComponents([.year,.month,.day], from: date)

        guard let y = c.year,
              let m = c.month,
              let d = c.day else { return 0 }

        return y * 10000 + m * 100 + d
    }
    
    func overrideEventTime(templateID: UUID, date: Date, minutes: Int) {

        let k = key(for: date)

        overrides.removeAll {
            $0.templateID == templateID &&
            $0.dateKey == k
        }

        overrides.append(
            EventOverride(
                templateID: templateID,
                dateKey: k,
                minutes: minutes
            )
        )

        rebuildIndex()
        invalidateCache()
        save()
    }
    
    func moveEvent(templateID: UUID, date: Date, deltaMinutes: Int) {

        let events = events(for: date)

        guard let event = events.first(where: { $0.id == templateID }) else { return }

        let newMinutes = max(0, event.minutes + deltaMinutes)
        let snapped = (newMinutes / 5) * 5
        
        overrideEventTime(
            templateID: templateID,
            date: date,
            minutes: newMinutes
        )
    }
    
    func cleanupOverrides() {

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .year, value: -1, to: Date())!

        let cutoffKey = key(for: cutoff)

        overrides.removeAll { $0.dateKey < cutoffKey }

        rebuildIndex()
        invalidateCache()

        save()
    }
    
    func addEvent(
        title: String,
        icon: String,
        minutes: Int,
        duration: Int
    ) {

        let new = EventTemplate(
            minutes: minutes,
            duration: duration,
            title: title,
            icon: icon,
            colorHex: "#34C759",
            recurrence: .daily
        )

        templates.append(new)

        invalidateCache()
        save()
    }
    
    
    
    
    
    
    
    
}

extension EventTemplate {

    func toEvent() -> EventItem {

        EventItem(
            id: id,
            minutes: minutes,
            duration: duration,
            title: title,
            icon: icon,
            colorHex: colorHex,
            isSystemEvent: isSystemEvent
        )
    }
}

extension EventTemplate {

    func matches(date: Date) -> Bool {

        let weekday = Calendar.current.component(.weekday, from: date)

        switch recurrence {

        case .daily:
            return true

        case .weekdays:
            return weekday >= 2 && weekday <= 6

        case .specific(let days):
            return days.contains(weekday)

        case .once(let d):
            return Calendar.current.isDate(d, inSameDayAs: date)
        }
    }
}
