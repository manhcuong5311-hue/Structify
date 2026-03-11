import SwiftUI
import Combine

struct EventItem: Identifiable, Codable, Equatable {

    // ID phải là templateID
    let id: UUID
    
    var kind: EventKind

    var minutes: Int
    var duration: Int? = nil

    var title: String
    var icon: String
    var colorHex: String

    var isSystemEvent: Bool = false
    var systemType: SystemEventType? = nil
    
    var originalMinutes: Int? = nil
    // MARK: Computed

    var time: String {
        TimelineEngine.formatTime(minutes)
    }

    var endTime: String? {
        guard let duration else { return nil }
        return TimelineEngine.formatTime(minutes + duration)
    }

    // MARK: Update

    mutating func update(minutes: Int) {
        self.minutes = minutes
    }

    // MARK: Color

    var color: Color {
        Color(hex: colorHex)
    }
}

enum EventKind: String, Codable {
    case event
    case habit
}
enum HabitCompletionType: String, Codable {
    case binary
    case accumulate
}


struct EventTemplate: Identifiable, Codable {

    var id = UUID()
    
    var kind: EventKind = .event
    
    var minutes: Int
    var duration: Int?

    var title: String
    var icon: String
    var colorHex: String

    var recurrence: Recurrence
    
    var habitType: HabitType? = nil
       var targetValue: Double? = nil
       var unit: String? = nil
    
    
    var isSystemEvent: Bool = false
    var systemType: SystemEventType? = nil
}



extension Recurrence {

    enum CodingKeys: String, CodingKey {
        case type
        case days
        case date
    }
}

extension Recurrence: Codable {

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {

        case .daily:
            try container.encode("daily", forKey: .type)

        case .weekdays:
            try container.encode("weekdays", forKey: .type)

        case .specific(let days):
            try container.encode("specific", forKey: .type)
            try container.encode(days, forKey: .days)

        case .once(let date):
            try container.encode("once", forKey: .type)
            try container.encode(date, forKey: .date)
        }
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(String.self, forKey: .type)

        switch type {

        case "daily":
            self = .daily

        case "weekdays":
            self = .weekdays

        case "specific":
            let days = try container.decode([Int].self, forKey: .days)
            self = .specific(days)

        case "once":
            let date = try container.decode(Date.self, forKey: .date)
            self = .once(date)

        default:
            self = .daily
        }
    }
}

enum SystemEventType: String, Codable {
    case wake
    case sleep
}

enum Recurrence {

    case daily
    case weekdays
    case specific([Int])
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
    
    
    
    
    @Published var habitLogs: [HabitLog] = []
    private var habitIndex: [Int: [HabitLog]] = [:]
    
    
    
    
    
    
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    func rebuildHabitIndex() {
        habitIndex = Dictionary(grouping: habitLogs) { $0.dateKey }
    }
    
    init() {
        

        
        load()
        rebuildIndex()
        rebuildHabitIndex()
        cleanupOverrides()
        cleanupHabitLogs()
        
        if templates.isEmpty {

            templates = [

                EventTemplate(
                    minutes: wakeMinutes,
                    title: "Morning Start",
                    icon: "sunrise.fill",
                    colorHex: "#F4A261",
                    recurrence: .daily,
                    isSystemEvent: true,
                    systemType: .wake
                ),

                EventTemplate(
                    minutes: sleepMinutes,
                    title: "Night Reset",
                    icon: "moon.stars.fill",
                    colorHex: "#6C7AA6",
                    recurrence: .daily,
                    isSystemEvent: true,
                    systemType: .sleep
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
        
        if let data = UserDefaults.standard.data(forKey: "habitLogs"),
           let decoded = try? decoder.decode([HabitLog].self, from: data) {

            habitLogs = decoded
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
        
        if let habitData = try? encoder.encode(habitLogs) {
            UserDefaults.standard.set(habitData, forKey: "habitLogs")
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

            if templates[i].systemType == .wake {
                templates[i].minutes = wakeMinutes
            }

            if templates[i].systemType == .sleep {
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
            minutes: snapped
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
        duration: Int?,
        colorHex: String,
        recurrence: Recurrence
    ) {

        // Chỉ chặn quá khứ nếu là event hôm nay
        if case .once(let date) = recurrence {

            if Calendar.current.isDateInToday(date) &&
               minutes < currentMinutesToday() {
                return
            }
        }

        let new = EventTemplate(
            minutes: minutes,
            duration: duration,
            title: title,
            icon: icon,
            colorHex: colorHex,
            recurrence: recurrence
        )

        templates.append(new)

        invalidateCache()
        save()
    }
    
    func currentMinutesToday() -> Int {

        let c = Calendar.current.dateComponents([.hour,.minute], from: Date())

        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    
    
    func hasOverlap(
        minutes: Int,
        duration: Int,
        date: Date
    ) -> Bool {

        let newStart = minutes
        let newEnd = minutes + duration

        let dayEvents = events(for: date)

        for e in dayEvents {

            guard let d = e.duration else { continue }

            let start = e.minutes
            let end = e.minutes + d

            if newStart < end && start < newEnd {
                return true
            }
        }

        return false
    }
    
    
    func suggestFreeSlot(
        date: Date,
        duration: Int
    ) -> Int {

        let dayEvents = events(for: date)
            .sorted { $0.minutes < $1.minutes }

        if dayEvents.isEmpty {
            return currentMinutesToday()
        }

        for i in 0..<dayEvents.count {

            guard let d = dayEvents[i].duration else { continue }

            let end = dayEvents[i].minutes + d

            let nextStart =
            i < dayEvents.count - 1
            ? dayEvents[i + 1].minutes
            : 1440

            if nextStart - end >= duration {
                return end
            }
        }

        return dayEvents.last!.minutes + (dayEvents.last!.duration ?? 0)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
//HABIT logic
    
    func addHabit(
        title: String,
        icon: String,
        minutes: Int,
        habitType: HabitType,
        targetValue: Double?,
        unit: String?,
        increment: Double?
    ) {

        let new = EventTemplate(
            kind: .habit,
            minutes: minutes,
            duration: nil,
            title: title,
            icon: icon,
            colorHex: "#34C759",
            recurrence: .daily,
            habitType: habitType,
            targetValue: targetValue,
            unit: unit
        )

        templates.append(new)

        invalidateCache()
        save()
    }
    
    func toggleHabit(templateID: UUID, date: Date) {
        
        guard let template = templates.first(where: {$0.id == templateID}),
                 template.matches(date: date)
           else { return }

        let k = key(for: date)

        if let index = habitLogs.firstIndex(where: {
            $0.templateID == templateID && $0.dateKey == k
        }) {

            habitLogs[index].completed.toggle()

        } else {

            habitLogs.append(
                HabitLog(
                    templateID: templateID,
                    dateKey: k,
                    completed: true
                )
            )
        }

        rebuildHabitIndex()
        invalidateCache()
        save()
    }
    
    func habitCompleted(templateID: UUID, date: Date) -> Bool {

        let k = key(for: date)

        return habitIndex[k]?.contains {
            $0.templateID == templateID && $0.completed
        } ?? false
    }
    
    func deleteTemplate(_ id: UUID) {

        templates.removeAll { $0.id == id }

        habitLogs.removeAll { $0.templateID == id }

        rebuildHabitIndex()
        invalidateCache()
        save()
    }
    
    func cleanupHabitLogs() {

        let cutoff = key(for: Calendar.current.date(byAdding: .year, value: -1, to: Date())!)

        habitLogs.removeAll {
            $0.dateKey < cutoff
        }

        rebuildHabitIndex()
        save()
    }
    
   
    
    
    
    
}

extension EventTemplate {

    func toEvent() -> EventItem {

        EventItem(
            id: id,
            kind: kind,
            minutes: minutes,
            duration: duration,
            title: title,
            icon: icon,
            colorHex: colorHex,
            isSystemEvent: isSystemEvent,
            systemType: systemType
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


struct HabitLog: Codable {

    var templateID: UUID
    var dateKey: Int
    var completed: Bool
}

extension EventItem {

    var isEvent: Bool {
        kind == .event
    }

    var isHabit: Bool {
        kind == .habit
    }
}
