import SwiftUI
import WidgetKit
import Combine

enum EventTitleKey: String {
    case morningStart = "event_morning_start"
    case nightReset = "event_night_reset"
}

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
    var increment: Double? = nil
    
    var isSystemEvent: Bool = false
    var systemType: SystemEventType? = nil
    var notes: String? = nil
    var startDate: Date? = nil
}



extension Recurrence {

    enum CodingKeys: String, CodingKey {
        case type
        case days
        case date
        case endDate
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
            
        case .dateRange(let start, let end):
            try container.encode("dateRange", forKey: .type)
            try container.encode(start, forKey: .date)
            try container.encode(end, forKey: CodingKeys.endDate)
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
            
        case "dateRange":                                              // 👈 thêm
            let start = try container.decode(Date.self, forKey: .date)
            let end   = try container.decode(Date.self, forKey: .endDate)
            self = .dateRange(start, end)

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
    case dateRange(Date, Date)  // 👈 thêm: từ ngày start đến end (inclusive)
}

struct EventOverride: Codable {
    var templateID: UUID
    var dateKey: Int
    var minutes: Int?
    var duration: Int?
    // Thêm mới:
    var title: String? = nil
    var icon: String? = nil
    var colorHex: String? = nil
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
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.samcorp.structify") ?? .standard
    
    
    
    
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    func rebuildCompletionIndex() {
        completionIndex = Dictionary(grouping: completionLogs) { $0.dateKey }
    }
    
    func cleanupCompletionLogs() {
        let cutoff = key(
            for: Calendar.current.date(
                byAdding: .year,
                value: -1,
                to: Date()
            )!
        )
        completionLogs.removeAll { $0.dateKey < cutoff }
        rebuildCompletionIndex()
        invalidateCache()
        save()
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
                    title: EventTitleKey.morningStart.rawValue,
                    icon: "sunrise.fill",
                    colorHex: "#F4A261",
                    recurrence: .daily,
                    isSystemEvent: true,
                    systemType: .wake
                ),

                EventTemplate(
                    minutes: sleepMinutes,
                    title: EventTitleKey.nightReset.rawValue,
                    icon: "moon.stars.fill",
                    colorHex: "#6C7AA6",
                    recurrence: .daily,
                    isSystemEvent: true,
                    systemType: .sleep
                )
            ]

            save()
        }
        
        NotificationManager.shared.scheduleSystemEvents(
             wakeMinutes: wakeMinutes,
             sleepMinutes: sleepMinutes
         )
        
    }
    
    var wakeMinutes: Int {
        sharedDefaults.object(forKey: wakeKey) as? Int ?? 360
    }

    var sleepMinutes: Int {
        sharedDefaults.object(forKey: sleepKey) as? Int ?? 1410
    }
    
    // MARK: Load
    
    func load() {
        let decoder = JSONDecoder()
        if let data = sharedDefaults.data(forKey: "templates"),
           let decoded = try? decoder.decode([EventTemplate].self, from: data) {
            templates = decoded
        }
        if let data = sharedDefaults.data(forKey: "overrides"),
           let decoded = try? decoder.decode([EventOverride].self, from: data) {
            overrides = decoded
        }
        if let data = sharedDefaults.data(forKey: "completionLogs"),
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
            sharedDefaults.set(templateData, forKey: "templates")
        }
        if let overrideData = try? encoder.encode(overrides) {
            sharedDefaults.set(overrideData, forKey: "overrides")
        }
        if let data = try? encoder.encode(completionLogs) {
            sharedDefaults.set(data, forKey: "completionLogs")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    
   
    
    
    // MARK: Add Event
    
  
    
    func updateSystemEvents(wakeMinutes: Int, sleepMinutes: Int) {
        sharedDefaults.set(wakeMinutes, forKey: wakeKey)
        sharedDefaults.set(sleepMinutes, forKey: sleepKey)

        for i in templates.indices {
            if templates[i].systemType == .wake {
                templates[i].minutes = wakeMinutes
            }
            if templates[i].systemType == .sleep {
                templates[i].minutes = sleepMinutes
            }
        }

        // Clamp tất cả events từ today về sau vào trong window mới
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        for i in templates.indices {
            guard !templates[i].isSystemEvent else { continue }

            // Chỉ xử lý events từ today trở đi
            // Với daily/weekdays recurrence → clamp minutes
            // Với once → chỉ clamp nếu date >= today

            var needsClamp = false

            switch templates[i].recurrence {
            case .daily, .weekdays, .specific:
                needsClamp = true
            case .once(let d):
                let dKey = key(for: d)
                needsClamp = dKey >= todayKey
            case .dateRange(let start, _):       // 👈 thêm
                let dKey = key(for: start)
                needsClamp = dKey >= todayKey
            }

            if needsClamp {
                
                if templates[i].duration == 1440 { continue }
                // Clamp start sau wake
                if templates[i].minutes < wakeMinutes {
                    templates[i].minutes = wakeMinutes + 5
                }

                // Clamp start trước sleep
                let dur = templates[i].duration ?? 0
                if templates[i].minutes + dur > sleepMinutes {
                    // Đẩy start lùi để fit
                    let newStart = sleepMinutes - dur
                    if newStart >= wakeMinutes {
                        templates[i].minutes = newStart
                    } else {
                        // Không fit → đặt sau wake, trim duration
                        templates[i].minutes = wakeMinutes + 5
                        if let _ = templates[i].duration {
                            templates[i].duration = max(5, sleepMinutes - (wakeMinutes + 5))
                        }
                    }
                }
            }
        }

        // Clamp overrides từ today trở đi
        for i in overrides.indices {
            guard overrides[i].dateKey >= todayKey else { continue }

            if var mins = overrides[i].minutes {
                mins = max(mins, wakeMinutes + 5)
                let dur = overrides[i].duration ?? 0
                if mins + dur > sleepMinutes {
                    mins = max(wakeMinutes + 5, sleepMinutes - dur)
                }
                overrides[i].minutes = mins
            }
        }

        save()
        rebuildIndex()
        invalidateCache()
        
        NotificationManager.shared.cancelSystemEvents()
          NotificationManager.shared.scheduleSystemEvents(
              wakeMinutes: wakeMinutes,
              sleepMinutes: sleepMinutes
          )
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
                
                if let title = override.title {
                    events[index].title = title
                }
                if let icon = override.icon {
                    events[index].icon = icon
                }
                if let colorHex = override.colorHex {
                    events[index].colorHex = colorHex
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
        
        let currentEventCount = templates.filter {
               !$0.isSystemEvent && $0.kind == .event
           }.count
           guard PremiumStore.shared.canAddEvent(currentCount: currentEventCount) else {
               NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
               return
           }

        // Chỉ chặn quá khứ nếu là event hôm nay
        if case .once(let date) = recurrence {

            if Calendar.current.isDateInToday(date) &&
               minutes < currentMinutesToday() {
                return
            }
        }

        var new = EventTemplate(
            minutes: minutes,
            duration: duration,
            title: title,
            icon: icon,
            colorHex: colorHex,
            recurrence: recurrence
        )

        if case .specific = recurrence {
            new.startDate = Calendar.current.startOfDay(for: Date())
        }

        templates.append(new)

        invalidateCache()
        save()
        
        NotificationManager.shared.scheduleRecurring(template: new)
    }
    
    func currentMinutesToday() -> Int {

        let c = Calendar.current.dateComponents([.hour,.minute], from: Date())

        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    
    
    // TÌM hàm hasOverlap, sửa vòng for:
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
            
            // Bỏ qua all-day events
            if d == 1440 { continue }

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

            // Reject hoàn toàn nếu event đã qua hoặc đang chạy
            let currentMins = currentEvent?.minutes ?? template.minutes
            let currentDur  = currentEvent?.duration ?? template.duration

            let isPast: Bool = {
                if let d = currentDur { return currentMins + d < now }
                return currentMins < now
            }()
            let isRunning: Bool = {
                guard let d = currentDur else { return false }
                return currentMins <= now && currentMins + d >= now
            }()

            if isPast || isRunning { return }   // 👈 khoá cứng hoàn toàn
        }

        let wake = wakeMinutes
        let sleep = sleepMinutes
        let minDuration = 5
        let maxDuration = 720

     
        // MARK: Clamp start bounds
        if !template.isSystemEvent {
            newMinutes = max(newMinutes, wake)
            newMinutes = min(newMinutes, sleep - minDuration)
        } else {
            if template.systemType == .wake {
                newMinutes = max(0, min(newMinutes, sleep - 30))
            } else if template.systemType == .sleep {
                newMinutes = max(wake + 30, min(newMinutes, 1440))
            }
        }
      
        // MARK: Duration normalize
        if var d = newDuration {
            // All-day events không clamp
            if d == 1440 {
                newDuration = 1440
            } else {
                d = max(minDuration, d)
                d = min(maxDuration, d)

                if newMinutes + d > 1440 {
                    d = 1440 - newMinutes
                }
                if newMinutes + d > sleep {
                    d = sleep - newMinutes
                }
                if d < minDuration { return }

                newDuration = d
            }
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
            
            NotificationManager.shared.cancel(templateID: templateID, date: date)
            if let template = templates.first(where: { $0.id == templateID }) {
                NotificationManager.shared.schedule(
                    templateID: templateID,
                    title: template.title,
                    icon: template.icon,
                    minutes: newMinutes,
                    date: date,
                    isHabit: template.kind == .habit
                )
            }
            
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
    
    
    
   
    
  
    
    
    func updateNotes(templateID: UUID, notes: String) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        templates[idx].notes = notes.isEmpty ? nil : notes
        invalidateCache()
        save()
    }
    
    func updateEvent(templateID: UUID, title: String, icon: String, colorHex: String) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        templates[idx].title = title
        templates[idx].icon = icon
        templates[idx].colorHex = colorHex
        invalidateCache()
        save()
        objectWillChange.send()
    }
    
    func overrideEventAppearance(
        templateID: UUID,
        date: Date,
        title: String,
        icon: String,
        colorHex: String
    ) {
        let k = key(for: date)

        if let index = overrides.firstIndex(where: {
            $0.templateID == templateID && $0.dateKey == k
        }) {
            overrides[index].title    = title
            overrides[index].icon     = icon
            overrides[index].colorHex = colorHex
        } else {
            overrides.append(EventOverride(
                templateID: templateID,
                dateKey: k,
                title: title,
                icon: icon,
                colorHex: colorHex
            ))
        }

        rebuildIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }
    
    
    // Update template time cho "All Days"
    func updateEventTime(templateID: UUID, minutes: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        templates[idx].minutes = minutes
        // Xóa override minutes cho tất cả ngày (giữ lại duration/appearance overrides)
        for i in overrides.indices {
            if overrides[i].templateID == templateID {
                overrides[i].minutes = nil
            }
        }
        rebuildIndex()
        invalidateCache()
        objectWillChange.send()
        save()
        
        if let template = templates.first(where: { $0.id == templateID }) {
              NotificationManager.shared.scheduleRecurring(template: template)
          }
    }

    // Update template duration cho "All Days"
    func updateEventDuration(templateID: UUID, duration: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        templates[idx].duration = duration
        // Xóa override duration cho tất cả ngày
        for i in overrides.indices {
            if overrides[i].templateID == templateID {
                overrides[i].duration = nil
            }
        }
        rebuildIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
//HABIT logic
    
    // MARK: - Habit Functions (Production-grade)

    func addHabit(
        title: String,
        icon: String,
        colorHex: String = "#34C759",
        minutes: Int,
        habitType: HabitType,
        targetValue: Double?,
        unit: String?,
        increment: Double?,
        recurrence: Recurrence = .daily
    ) {
        
        let currentHabitCount = templates.filter {
              !$0.isSystemEvent && $0.kind == .habit
          }.count
          guard PremiumStore.shared.canAddHabit(currentCount: currentHabitCount) else {
              NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
              return
          }
        
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        if case .once(let date) = recurrence {
            let today = Calendar.current.startOfDay(for: Date())
            let target = Calendar.current.startOfDay(for: date)
            if target < today { return }
        }
        
        // Clamp minutes vào trong wake/sleep window
        let clampedMinutes = max(wakeMinutes, min(minutes, sleepMinutes - 1))

        var new = EventTemplate(
            kind: .habit,
            minutes: clampedMinutes,
            duration: nil,
            title: cleanTitle,
            icon: icon.isEmpty ? "checkmark.circle.fill" : icon,
            colorHex: colorHex.isEmpty ? "#34C759" : colorHex,
            recurrence: recurrence,
            habitType: habitType,
            targetValue: habitType == .accumulative ? max(0.01, targetValue ?? 1) : nil,
            unit: habitType == .accumulative ? unit : nil
        )
        new.increment = habitType == .accumulative ? max(0.01, increment ?? 1) : nil 

        if case .dateRange(let start, _) = recurrence {
            new.startDate = start
        }
        if case .specific = recurrence {
            new.startDate = Calendar.current.startOfDay(for: Date())
        }
        
        if case .daily = recurrence {
            new.startDate = Calendar.current.startOfDay(for: Date())
        }
        
        templates.append(new)
        invalidateCache()
        save()
        
        NotificationManager.shared.scheduleRecurring(template: new)
    }

    func toggleCompletion(templateID: UUID, date: Date) {
        // Không cho complete future dates (trừ today)
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfTarget = Calendar.current.startOfDay(for: date)
        guard startOfTarget <= startOfToday else { return }

        guard let template = templates.first(where: { $0.id == templateID }) else { return }
        guard let event = events(for: date).first(where: { $0.id == templateID }) else { return }

        // Event chưa kết thúc → không cho complete
        if Calendar.current.isDateInToday(date) && template.kind == .event {
            if let duration = event.duration {
                let now = currentMinutesToday()
                if now < event.minutes + duration { return }
            }
        }

        // Accumulative habit → dùng updateAccumulation thay vì toggle
        // toggleCompletion chỉ dành cho binary
        if template.kind == .habit && template.habitType == .accumulative { return }

        let k = key(for: date)

        if let index = completionLogs.firstIndex(where: {
            $0.templateID == templateID && $0.dateKey == k
        }) {
            completionLogs[index].completed = !(completionLogs[index].completed ?? false)
            completionLogs[index].value = nil
        } else {
            completionLogs.append(CompletionLog(
                templateID: templateID,
                dateKey: k,
                completed: true,
                value: nil
            ))
        }

        rebuildCompletionIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }

    func updateAccumulation(
        templateID: UUID,
        date: Date,
        value: Double
    ) {
        // Không cho update future dates
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfTarget = Calendar.current.startOfDay(for: date)
        guard startOfTarget <= startOfToday else { return }

        guard let template = templates.first(where: { $0.id == templateID }),
              template.habitType == .accumulative else { return }

        // Clamp value: 0 → targetValue (không vượt quá target)
        let maxValue = template.targetValue ?? Double.greatestFiniteMagnitude
        let clamped = max(0, min(value, maxValue))

        let k = key(for: date)

        if let index = completionLogs.firstIndex(where: {
            $0.templateID == templateID && $0.dateKey == k
        }) {
            completionLogs[index].value = clamped
            completionLogs[index].completed = nil
        } else {
            completionLogs.append(CompletionLog(
                templateID: templateID,
                dateKey: k,
                completed: nil,
                value: clamped
            ))
        }

        rebuildCompletionIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }

    // Increment accumulation (dùng cho nút +)
    func incrementAccumulation(
        templateID: UUID,
        date: Date,
        by increment: Double
    ) {
        guard increment > 0 else { return }
        let current = accumulationValue(templateID: templateID, date: date)
        updateAccumulation(templateID: templateID, date: date, value: current + increment)
    }

    func accumulationValue(templateID: UUID, date: Date) -> Double {
        let k = key(for: date)
        return completionIndex[k]?.first {
            $0.templateID == templateID
        }?.value ?? 0
    }

    func accumulationCompleted(templateID: UUID, date: Date) -> Bool {
        guard let template = templates.first(where: { $0.id == templateID }),
              let target = template.targetValue,
              target > 0 else { return false }
        return accumulationValue(templateID: templateID, date: date) >= target
    }

    func isCompleted(templateID: UUID, date: Date) -> Bool {
        guard let template = templates.first(where: { $0.id == templateID }) else { return false }

        // Accumulative → check target reached
        if template.kind == .habit && template.habitType == .accumulative {
            return accumulationCompleted(templateID: templateID, date: date)
        }

        // Binary habit / event
        let k = key(for: date)
        return completionIndex[k]?.contains {
            $0.templateID == templateID && $0.completed == true
        } ?? false
    }

    // Xóa habit/event đúng cách — xóa cả overrides và completion logs
    func deleteEvent(templateID: UUID, date: Date) {
        
        NotificationManager.shared.cancel(templateID: templateID, date: date)
        
        let k = key(for: date)

        overrides.removeAll {
            $0.templateID == templateID && $0.dateKey == k
        }

        overrides.append(EventOverride(
            templateID: templateID,
            dateKey: k,
            minutes: -1,
            duration: nil
        ))

        rebuildIndex()
        invalidateCache()
        save()
    }

    func deleteTemplate(_ id: UUID) {
        
        NotificationManager.shared.cancelAll(templateID: id)
        
        templates.removeAll { $0.id == id }
        overrides.removeAll { $0.templateID == id }      // 👈 xóa overrides
        completionLogs.removeAll { $0.templateID == id } // 👈 xóa completion logs
        rebuildIndex()
        rebuildCompletionIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }

    // From-today variants cho recurring changes
    func updateEventTimeFromToday(templateID: UUID, minutes: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        for i in overrides.indices {
            if overrides[i].templateID == templateID && overrides[i].dateKey >= todayKey {
                overrides[i].minutes = nil
            }
        }

        templates[idx].minutes = minutes
        rebuildIndex()
        invalidateCache()
        objectWillChange.send()
        save()

        // 👇 thêm reschedule
        NotificationManager.shared.scheduleRecurring(template: templates[idx])
    }

    func updateEventDurationFromToday(templateID: UUID, duration: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        for i in overrides.indices {
            if overrides[i].templateID == templateID && overrides[i].dateKey >= todayKey {
                overrides[i].duration = nil
            }
        }

        templates[idx].duration = duration
        rebuildIndex()
        invalidateCache()
        objectWillChange.send()
        save()
    }

    func completionProgress(templateID: UUID, date: Date) -> Double {
        guard let template = templates.first(where: { $0.id == templateID }) else { return 0 }

        if template.kind == .habit && template.habitType == .accumulative {
            guard let target = template.targetValue, target > 0 else { return 0 }
            return min(accumulationValue(templateID: templateID, date: date) / target, 1)
        }

        return isCompleted(templateID: templateID, date: date) ? 1 : 0
    }
    
    // Thêm vào TimelineStore (cuối file):
    func exportCSV() -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        
        var rows = ["Date,Title,Type,Start,Duration,Completed"]
        
        for dayOffset in stride(from: -90, through: 0, by: 1) {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dayEvents = events(for: date).filter { !$0.isSystemEvent && $0.duration != 1440 }
            
            for event in dayEvents {
                let completed = isCompleted(templateID: event.id, date: date) ? "Yes" : "No"
                let dur = event.duration.map { "\($0)" } ?? ""
                let row = "\(f.string(from: date)),\"\(event.title)\",\(event.kind.rawValue),\(event.time),\(dur),\(completed)"
                rows.append(row)
            }
        }
        return rows.joined(separator: "\n")
    }
    
    
   
    
    // Thêm vào TimelineStore:
    func resetAllData() {
        templates.removeAll { !$0.isSystemEvent }
        overrides.removeAll()
        completionLogs.removeAll()
        rebuildIndex()
        rebuildCompletionIndex()
        invalidateCache()
        save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // Thêm vào TimelineStore:
    func exportBackup() -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        var dict: [String: Data] = [:]
        
        if let t = try? encoder.encode(templates) { dict["templates"] = t }
        if let o = try? encoder.encode(overrides) { dict["overrides"] = o }
        if let c = try? encoder.encode(completionLogs) { dict["completionLogs"] = c }
        
        // Wake/sleep riêng vì là Int
        let meta = BackupMeta(
            wakeMinutes: wakeMinutes,
            sleepMinutes: sleepMinutes,
            exportedAt: Date()
        )
        if let m = try? encoder.encode(meta) { dict["meta"] = m }
        
        guard let finalData = try? JSONEncoder().encode(dict) else { return nil }
        
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let fileName = "structify_backup_\(f.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try finalData.write(to: url)
            return url
        } catch {
            print("Backup error: \(error)")
            return nil
        }
    }

    func restoreBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let dict = try JSONDecoder().decode([String: Data].self, from: data)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let t = dict["templates"],
           let decoded = try? decoder.decode([EventTemplate].self, from: t) {
            templates = decoded
        }
        if let o = dict["overrides"],
           let decoded = try? decoder.decode([EventOverride].self, from: o) {
            overrides = decoded
        }
        if let c = dict["completionLogs"],
           let decoded = try? decoder.decode([CompletionLog].self, from: c) {
            completionLogs = decoded
        }
        if let m = dict["meta"],
           let meta = try? decoder.decode(BackupMeta.self, from: m) {
            sharedDefaults.set(meta.wakeMinutes, forKey: "user_wake_minutes")
            sharedDefaults.set(meta.sleepMinutes, forKey: "user_sleep_minutes")
        }
        
        rebuildIndex()
        rebuildCompletionIndex()
        invalidateCache()
        save()
        objectWillChange.send()
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
        let cal = Calendar.current

        // 👈 Thêm check startDate trước tất cả các case
        if let start = startDate,
           cal.startOfDay(for: date) < cal.startOfDay(for: start) {
            return false
        }

        let weekday = cal.component(.weekday, from: date)
        switch recurrence {
        case .daily:                return true
        case .weekdays:             return weekday >= 2 && weekday <= 6
        case .specific(let days):   return days.contains(weekday)
        case .once(let d):          return cal.isDate(d, inSameDayAs: date)
        case .dateRange(let start, let end):
            let startDay = cal.startOfDay(for: start)
            let endDay   = cal.startOfDay(for: end)
            let checkDay = cal.startOfDay(for: date)
            return checkDay >= startDay && checkDay <= endDay
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

// Thêm struct này bên ngoài TimelineStore (cuối file TimelineStore):
struct BackupMeta: Codable {
    var wakeMinutes: Int
    var sleepMinutes: Int
    var exportedAt: Date
}
