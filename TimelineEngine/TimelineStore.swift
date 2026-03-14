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
    
    var minutes: Int?
    var duration: Int?
}

class TimelineStore: ObservableObject {
    

    private let wakeKey = "user_wake_minutes"
    private let sleepKey = "user_sleep_minutes"
    private let key = "timeline_events"
    @Published var templates: [EventTemplate] = []

    @Published var overrides: [EventOverride] = []
 
    private var overrideIndex: [Int: [EventOverride]] = [:]
    private var cache: [Int: [EventItem]] = [:]
    
    
    
    
    @Published var completionLogs: [CompletionLog] = []
    private var completionIndex: [Int: [CompletionLog]] = [:]
    
    
    
    
    
    
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    func rebuildCompletionIndex() {
        completionIndex = Dictionary(grouping: completionLogs) { $0.dateKey }
    }
    
    init() {
        

        
        load()
        rebuildIndex()
        rebuildCompletionIndex()
        cleanupOverrides()
        cleanupCompletionLogs()
        
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
        
        if let data = UserDefaults.standard.data(forKey: "completionLogs"),
           let decoded = try? decoder.decode([CompletionLog].self, from: data) {

            completionLogs = decoded
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
        
        if let data = try? encoder.encode(completionLogs) {
            UserDefaults.standard.set(data, forKey: "completionLogs")
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
                minutes: -1,
                duration: nil
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

        var removeIDs: Set<UUID> = []

        for override in dayOverrides {

            if let minutes = override.minutes, minutes < 0 {
                removeIDs.insert(override.templateID)
                continue
            }

            if let index = events.firstIndex(where: { $0.id == override.templateID }) {

                if let minutes = override.minutes {
                    events[index].minutes = minutes
                }

                if let duration = override.duration {
                    events[index].duration = duration
                }
            }
        }

        if !removeIDs.isEmpty {
            events.removeAll { removeIDs.contains($0.id) }
        }
    }
    
    func key(for date: Date) -> Int {

        let c = Calendar.current.dateComponents([.year,.month,.day], from: date)

        guard let y = c.year,
              let m = c.month,
              let d = c.day else { return 0 }

        return y * 10000 + m * 100 + d
    }
    
  
    
    func moveEvent(templateID: UUID, date: Date, deltaMinutes: Int) {

        let events = events(for: date)

        guard let event = events.first(where: { $0.id == templateID }) else { return }

        let newMinutes = max(0, event.minutes + deltaMinutes)
        let snapped = (newMinutes / 5) * 5
        
        overrideEvent(
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
    
    func buildEventsFresh(date: Date) -> [EventItem] {

        var result: [EventItem] = []

        for template in templates where template.matches(date: date) {
            result.append(template.toEvent())
        }

        applyOverrides(&result, date: date)

        result.sort { $0.minutes < $1.minutes }

        return result
    }
    
    
    
    
    func overrideEvent(
        templateID: UUID,
        date: Date,
        minutes: Int? = nil,
        duration: Int? = nil,
        ignoreOverlap: Bool = false
    ) {

        let k = key(for: date)

        guard let template = templates.first(where: { $0.id == templateID }) else { return }

        var dayEvents = buildEventsFresh(date: date)
        let currentEvent = dayEvents.first { $0.id == templateID }

        var newMinutes = minutes ?? currentEvent?.minutes ?? template.minutes
        var newDuration = duration ?? currentEvent?.duration ?? template.duration

       
        // MARK: Prevent past time
        if Calendar.current.isDateInToday(date) && !template.isSystemEvent {
            let now = currentMinutesToday()
            newMinutes = max(newMinutes, now)
        }

        let wake = wakeMinutes
        let sleep = sleepMinutes
        let minDuration = 5
        let maxDuration = 720

        // MARK: Clamp start bounds
        newMinutes = max(newMinutes, wake)
        newMinutes = min(newMinutes, sleep - minDuration)

        // MARK: Duration normalize
        if var d = newDuration {

            d = max(minDuration, d)
            d = min(maxDuration, d)

            // midnight clamp
            if newMinutes + d > 1440 {
                d = 1440 - newMinutes
            }

            // sleep clamp
            if newMinutes + d > sleep {
                d = sleep - newMinutes
            }

            // prevent zero duration
            if d < minDuration {
                return
            }

            newDuration = d
        }

        // MARK: Prevent overlap

        if let idx = dayEvents.firstIndex(where: { $0.id == templateID }) {
            dayEvents[idx].minutes = newMinutes
            dayEvents[idx].duration = newDuration
        }

        if !ignoreOverlap, let d = newDuration {

            let newStart = newMinutes
            let newEnd = newMinutes + d

            for e in dayEvents where e.id != templateID {

                guard let ed = e.duration else { continue }

                let start = e.minutes
                let end = e.minutes + ed

                if newStart < end && start < newEnd {
                    return
                }
            }
        }

        // MARK: Remove redundant override

        if newMinutes == template.minutes &&
           newDuration == template.duration {

            overrides.removeAll {
                $0.templateID == templateID &&
                $0.dateKey == k
            }

            rebuildIndex()
            invalidateCache()
            save()
            return
        }

        // MARK: Apply override

        if let index = overrides.firstIndex(where: {
            $0.templateID == templateID &&
            $0.dateKey == k
        }) {

            overrides[index].minutes = newMinutes
            overrides[index].duration = newDuration

        } else {

            overrides.append(
                EventOverride(
                    templateID: templateID,
                    dateKey: k,
                    minutes: newMinutes,
                    duration: newDuration
                )
            )
        }

        rebuildIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }
    
    
    
    func toggleCompletion(templateID: UUID, date: Date) {
        
        if date > Date() && !Calendar.current.isDateInToday(date) {
               return
           }

        guard let event = events(for: date).first(where: {$0.id == templateID})
        else { return }
        
        if Calendar.current.isDateInToday(date) {

            if event.isEvent,
               let duration = event.duration {

                let now = currentMinutesToday()

                if now < event.minutes + duration {
                    return
                }
            }
        }


        let k = key(for: date)

        if let index = completionLogs.firstIndex(where: {
            $0.templateID == templateID && $0.dateKey == k
        }) {

            completionLogs[index].completed = !(completionLogs[index].completed ?? false)
            completionLogs[index].value = nil

        } else {

            completionLogs.append(
                CompletionLog(
                    templateID: templateID,
                    dateKey: k,
                    completed: true,
                    value: nil
                )
            )
        }

        rebuildCompletionIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }
    
    
    func isCompleted(templateID: UUID, date: Date) -> Bool {

        let k = key(for: date)

        return completionIndex[k]?.contains {
            $0.templateID == templateID && $0.completed == true
        } ?? false
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
    
    func updateAccumulation(
        templateID: UUID,
        date: Date,
        value: Double
    ) {

        let k = key(for: date)

        if let index = completionLogs.firstIndex(where: {
            $0.templateID == templateID && $0.dateKey == k
        }) {

            completionLogs[index].value = max(0, value)
            completionLogs[index].completed = nil

        } else {

            completionLogs.append(
                CompletionLog(
                    templateID: templateID,
                    dateKey: k,
                    completed: nil,
                    value: max(0, value)
                )
            )
        }

        rebuildCompletionIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }
    
    func accumulationValue(
        templateID: UUID,
        date: Date
    ) -> Double {

        let k = key(for: date)

        return completionIndex[k]?.first {
            $0.templateID == templateID
        }?.value ?? 0
    }
    
    func accumulationCompleted(
        templateID: UUID,
        date: Date
    ) -> Bool {

        guard let template = templates.first(where: {$0.id == templateID}),
              let target = template.targetValue
        else { return false }

        let value = accumulationValue(
            templateID: templateID,
            date: date
        )

        return value >= target
    }
    
    

    
    func deleteTemplate(_ id: UUID) {

        templates.removeAll { $0.id == id }

        completionLogs.removeAll { $0.templateID == id }

        rebuildCompletionIndex()
        invalidateCache()
        save()
    }
    
    
    func cleanupCompletionLogs() {

        let cutoff = key(
            for: Calendar.current.date(
                byAdding: .year,
                value: -1,
                to: Date()
            )!
        )

        completionLogs.removeAll {
            $0.dateKey < cutoff
        }

        rebuildCompletionIndex()
        invalidateCache()
        save()
    }
   
    func completionProgress(
        templateID: UUID,
        date: Date
    ) -> Double {

        guard let template = templates.first(where: {$0.id == templateID})
        else { return 0 }

        if template.kind == .event {
            return isCompleted(templateID: templateID, date: date) ? 1 : 0
        }

        if let target = template.targetValue, target > 0 {

            let value = accumulationValue(
                templateID: templateID,
                date: date
            )

            return min(value / target, 1)
        }

        return isCompleted(templateID: templateID, date: date) ? 1 : 0
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


struct CompletionLog: Codable {

    var templateID: UUID
    var dateKey: Int

    // binary habit / event
    var completed: Bool?

    // accumulative habit
    var value: Double?
}

extension EventItem {

    var isEvent: Bool {
        kind == .event
    }

    var isHabit: Bool {
        kind == .habit
    }
}
