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

    // MARK: - Undo

    struct PendingUndo: Identifiable {
        enum Kind {
            /// Single-day "hide" override added by deleteEvent.
            case singleDayDelete(templateID: UUID, dateKey: Int, date: Date)
            /// Full template removal — snapshot what was deleted so we can restore.
            case templateDelete(template: EventTemplate, overrides: [EventOverride], logs: [CompletionLog])
        }
        let id = UUID()
        let kind: Kind
        let title: String
    }

    @Published var pendingUndo: PendingUndo?
    private var undoExpiryTimer: Timer?

    private func setPendingUndo(_ undo: PendingUndo) {
        pendingUndo = undo
        undoExpiryTimer?.invalidate()
        undoExpiryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.pendingUndo?.id == undo.id { self.pendingUndo = nil }
            }
        }
    }

    func clearPendingUndo() {
        pendingUndo = nil
        undoExpiryTimer?.invalidate()
    }

    func performUndo() {
        guard let undo = pendingUndo else { return }
        switch undo.kind {
        case .singleDayDelete(let templateID, let dateKey, let date):
            overrides.removeAll {
                $0.templateID == templateID && $0.dateKey == dateKey && $0.minutes == -1
            }
            rebuildIndex()
            invalidateCache()
            saveNow()
            // Re-schedule the day's notification if we can locate the template.
            if let t = templates.first(where: { $0.id == templateID }) {
                NotificationManager.shared.schedule(
                    templateID: t.id,
                    title: t.title,
                    icon: t.icon,
                    minutes: t.minutes,
                    date: date,
                    isHabit: t.kind == .habit
                )
            }
        case .templateDelete(let template, let savedOverrides, let savedLogs):
            templates.append(template)
            overrides.append(contentsOf: savedOverrides)
            completionLogs.append(contentsOf: savedLogs)
            rebuildIndex()
            rebuildCompletionIndex()
            invalidateCache()
            objectWillChange.send()
            saveNow()
        }
        clearPendingUndo()
    }
    
    
    
    
    
    func invalidateCache() {
        cache.removeAll()
    }
    
    func rebuildCompletionIndex() {
        completionIndex = Dictionary(grouping: completionLogs) { $0.dateKey }
    }
    
    func cleanupCompletionLogs() {
        guard let cutoffDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else { return }
        let cutoff = key(for: cutoffDate)
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

    private var saveWorkItem: DispatchWorkItem?
    private var widgetReloadWorkItem: DispatchWorkItem?

    /// Debounced save. Coalesces rapid mutations (live drag, "+" accumulation,
    /// completion toggles) into one disk write + one widget reload. Safe for
    /// data because `flushPendingSave()` runs when the app backgrounds, and
    /// critical paths (create/delete/undo) call `saveNow()` directly.
    func save() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.persist()
            self?.scheduleWidgetReload()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    /// Immediate, non-debounced save for high-stakes mutations where losing the
    /// write would be user-visible (create, delete, undo, restore, import).
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        persist()
        scheduleWidgetReload()
    }

    /// Flush any pending debounced save right now. Call when the app is about to
    /// background/terminate so nothing in the 0.4s window is lost.
    func flushPendingSave() {
        if saveWorkItem != nil {
            saveWorkItem?.cancel()
            saveWorkItem = nil
            persist()
        }
        flushWidgetReload()
    }

    private func persist() {
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
    }

    /// Widget timeline reloads are system rate-limited, so we debounce them out
    /// of the per-mutation hot path rather than firing on every save.
    private func scheduleWidgetReload() {
        widgetReloadWorkItem?.cancel()
        let item = DispatchWorkItem { WidgetCenter.shared.reloadAllTimelines() }
        widgetReloadWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    private func flushWidgetReload() {
        widgetReloadWorkItem?.cancel()
        widgetReloadWorkItem = nil
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

                // Compute the clamped values first WITHOUT mutating, so we can lock the
                // past (snapshot OLD values, still held in the template) before applying.
                var newMinutes  = templates[i].minutes
                var newDuration = templates[i].duration

                if newMinutes < wakeMinutes {
                    newMinutes = wakeMinutes + 5
                }

                let dur = newDuration ?? 0
                if newMinutes + dur > sleepMinutes {
                    let newStart = sleepMinutes - dur
                    if newStart >= wakeMinutes {
                        newMinutes = newStart
                    } else {
                        newMinutes = wakeMinutes + 5
                        if newDuration != nil {
                            newDuration = max(5, sleepMinutes - (wakeMinutes + 5))
                        }
                    }
                }

                let minutesChanged  = newMinutes  != templates[i].minutes
                let durationChanged = newDuration != templates[i].duration

                if minutesChanged || durationChanged {
                    var fields: Set<SnapshotField> = []
                    if minutesChanged  { fields.insert(.minutes) }
                    if durationChanged { fields.insert(.duration) }
                    // Snapshot reads the template's current (old) values, so call before mutating.
                    snapshotPastInstances(templateID: templates[i].id, fields: fields)
                    templates[i].minutes  = newMinutes
                    templates[i].duration = newDuration
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
        guard let cutoff = calendar.date(byAdding: .year, value: -1, to: Date()) else { return }
        let cutoffKey = key(for: cutoff)

        overrides.removeAll { $0.dateKey < cutoffKey }

        rebuildIndex()
        invalidateCache()

        save()
    }

    // MARK: - Past lock

    /// Fields a snapshot can capture. Used by `snapshotPastInstances` to freeze
    /// the current template values into per-day overrides for past dates before
    /// the template's canonical values are mutated.
    enum SnapshotField {
        case minutes, duration, title, icon, colorHex
    }

    /// Earliest date the user has actually interacted with this template
    /// (a completion log or a per-day override). Used to bound the past-lock
    /// snapshot for legacy templates that predate the always-set `startDate`.
    private func earliestActivityKey(templateID: UUID) -> Int? {
        var minKey: Int?
        for log in completionLogs where log.templateID == templateID {
            if minKey == nil || log.dateKey < minKey! { minKey = log.dateKey }
        }
        for ov in overrides where ov.templateID == templateID {
            if minKey == nil || ov.dateKey < minKey! { minKey = ov.dateKey }
        }
        return minKey
    }

    private func dateFromKey(_ k: Int) -> Date? {
        var c = DateComponents()
        c.year  = k / 10000
        c.month = (k / 100) % 100
        c.day   = k % 100
        return Calendar.current.date(from: c)
    }

    /// Walks backwards through past dates where this template matched and writes
    /// the current template values into per-day overrides. Call this BEFORE you
    /// mutate `templates[idx]` so past days keep their historical appearance.
    ///
    /// Lower bound:
    /// - `startDate` if present (every template created going forward has one).
    /// - Otherwise (legacy templates) the earliest date the user actually used,
    ///   capped at 365 days. If the user never touched it, we skip entirely —
    ///   there's no historical appearance to preserve, so no overrides are made.
    private func snapshotPastInstances(templateID: UUID, fields: Set<SnapshotField>) {
        guard !fields.isEmpty else { return }
        guard let template = templates.first(where: { $0.id == templateID }) else { return }
        guard !template.isSystemEvent else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let hardCap = cal.date(byAdding: .day, value: -365, to: today) ?? today

        let lowerBound: Date = {
            if let start = template.startDate {
                return max(cal.startOfDay(for: start), hardCap)
            }
            guard let earliestKey = earliestActivityKey(templateID: templateID),
                  let earliestDate = dateFromKey(earliestKey) else {
                return today  // no history → nothing to lock
            }
            return max(cal.startOfDay(for: earliestDate), hardCap)
        }()

        guard lowerBound < today else { return }

        var cursor = cal.date(byAdding: .day, value: -1, to: today) ?? today
        while cursor >= lowerBound {
            if template.matches(date: cursor) {
                let dKey = key(for: cursor)

                if let i = overrides.firstIndex(where: { $0.templateID == templateID && $0.dateKey == dKey }) {
                    // Existing override. Don't touch "deleted" markers; fill nil fields only
                    // so we never clobber a user's deliberate per-day customization.
                    if let m = overrides[i].minutes, m < 0 {
                        // Day was deleted — leave it deleted.
                    } else {
                        if fields.contains(.minutes)  && overrides[i].minutes  == nil { overrides[i].minutes  = template.minutes  }
                        if fields.contains(.duration) && overrides[i].duration == nil { overrides[i].duration = template.duration }
                        if fields.contains(.title)    && overrides[i].title    == nil { overrides[i].title    = template.title    }
                        if fields.contains(.icon)     && overrides[i].icon     == nil { overrides[i].icon     = template.icon     }
                        if fields.contains(.colorHex) && overrides[i].colorHex == nil { overrides[i].colorHex = template.colorHex }
                    }
                } else {
                    overrides.append(EventOverride(
                        templateID: templateID,
                        dateKey: dKey,
                        minutes:  fields.contains(.minutes)  ? template.minutes  : nil,
                        duration: fields.contains(.duration) ? template.duration : nil,
                        title:    fields.contains(.title)    ? template.title    : nil,
                        icon:     fields.contains(.icon)     ? template.icon     : nil,
                        colorHex: fields.contains(.colorHex) ? template.colorHex : nil
                    ))
                }
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
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

        let clampedMinutes = max(wakeMinutes, min(minutes, sleepMinutes - 5))
        let clampedDuration = clampDuration(duration, start: clampedMinutes)

        var new = EventTemplate(
            minutes: clampedMinutes,
            duration: clampedDuration,
            title: title,
            icon: icon,
            colorHex: colorHex,
            recurrence: recurrence
        )

        if case .specific = recurrence {
            new.startDate = Calendar.current.startOfDay(for: Date())
        }

        // Always stamp a creation boundary so the past-lock snapshot only ever
        // walks back to the day this template was created (never fabricates
        // overrides for days before it existed).
        if new.startDate == nil {
            new.startDate = Calendar.current.startOfDay(for: Date())
        }

        templates.append(new)

        invalidateCache()
        objectWillChange.send()
        saveNow()

        NotificationManager.shared.scheduleRecurring(template: new)
    }

    // Clamp duration so event never crosses sleep time or midnight.
    // Returns nil if no room left (caller should treat as invalid).
    // All-day events (duration == 1440) pass through unchanged.
    private func clampDuration(_ duration: Int?, start minutes: Int) -> Int? {
        guard let d = duration else { return nil }
        if d == 1440 { return 1440 }
        let cap = sleepMinutes - minutes
        guard cap >= 5 else { return nil }
        return max(5, min(d, cap))
    }
    
    func currentMinutesToday() -> Int {

        let c = Calendar.current.dateComponents([.hour,.minute], from: Date())

        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    
    
    /// Footprint a habit occupies on the timeline for overlap-detection purposes.
    /// Habits have `duration == nil` in storage; we treat them as a fixed slot so
    /// event creation can warn when colliding with a scheduled habit.
    static let habitOverlapFootprint: Int = 30

    /// `includeHabits` controls whether habits (duration == nil) count toward overlap.
    /// Pass `true` from event-creation flows so events warn when colliding with a
    /// scheduled habit; pass `false` from habit-creation flows so habits can stack
    /// on each other freely (the original product behavior).
    func hasOverlap(
        minutes: Int,
        duration: Int,
        date: Date,
        includeHabits: Bool = false
    ) -> Bool {
        let newStart = minutes
        let newEnd = minutes + duration

        let dayEvents = events(for: date)

        for e in dayEvents {
            let d: Int
            if let eventDur = e.duration {
                if eventDur == 1440 { continue }   // all-day events don't block
                d = eventDur
            } else if includeHabits && e.isHabit {
                d = Self.habitOverlapFootprint
            } else {
                continue
            }

            let start = e.minutes
            let end = e.minutes + d

            if newStart < end && start < newEnd {
                return true
            }
        }

        return false
    }


    /// `includeHabits: true` makes the slot finder skip over habits as well, so an
    /// anytime habit / event won't land on top of a scheduled habit on display.
    func suggestFreeSlot(
        date: Date,
        duration: Int,
        includeHabits: Bool = false
    ) -> Int {

        let dayEvents = events(for: date)
            .sorted { $0.minutes < $1.minutes }

        if dayEvents.isEmpty {
            return currentMinutesToday()
        }

        for i in 0..<dayEvents.count {

            let d: Int
            if let eventDur = dayEvents[i].duration {
                d = eventDur
            } else if includeHabits && dayEvents[i].isHabit {
                d = Self.habitOverlapFootprint
            } else {
                continue
            }

            let end = dayEvents[i].minutes + d

            let nextStart =
            i < dayEvents.count - 1
            ? dayEvents[i + 1].minutes
            : 1440

            if nextStart - end >= duration {
                return end
            }
        }

        let last = dayEvents.last!
        let lastDuration: Int = last.duration
            ?? (includeHabits && last.isHabit ? Self.habitOverlapFootprint : 0)
        return last.minutes + lastDuration
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
        snapshotPastInstances(templateID: templateID, fields: [.title, .icon, .colorHex])
        templates[idx].title = title
        templates[idx].icon = icon
        templates[idx].colorHex = colorHex
        rebuildIndex()
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
    
    
    // Update template time cho "All Days" (today + future)
    func updateEventTime(templateID: UUID, minutes: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        // Lock past: snapshot current template.minutes into per-day overrides so
        // historical days keep their old time when we mutate the template below.
        snapshotPastInstances(templateID: templateID, fields: [.minutes])

        templates[idx].minutes = minutes
        // Wipe minute overrides for today+ so the new template value applies forward.
        for i in overrides.indices {
            if overrides[i].templateID == templateID && overrides[i].dateKey >= todayKey {
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

    // Update template duration cho "All Days" (today + future)
    func updateEventDuration(templateID: UUID, duration: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        guard let clamped = clampDuration(duration, start: templates[idx].minutes) else { return }
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        snapshotPastInstances(templateID: templateID, fields: [.duration])

        templates[idx].duration = clamped
        // Wipe duration overrides for today+ so the new value applies forward.
        for i in overrides.indices {
            if overrides[i].templateID == templateID && overrides[i].dateKey >= todayKey {
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

        // Same creation-boundary stamp as addEvent — see note there.
        if new.startDate == nil {
            new.startDate = Calendar.current.startOfDay(for: Date())
        }

        templates.append(new)
        invalidateCache()
        objectWillChange.send()
        saveNow()

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
        let title = templates.first(where: { $0.id == templateID })?.title ?? ""

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
        saveNow()

        setPendingUndo(PendingUndo(
            kind: .singleDayDelete(templateID: templateID, dateKey: k, date: date),
            title: title
        ))
    }

    func deleteTemplate(_ id: UUID) {

        NotificationManager.shared.cancelAll(templateID: id)

        // Snapshot for undo BEFORE we remove anything.
        let snapshotTemplate = templates.first(where: { $0.id == id })
        let snapshotOverrides = overrides.filter { $0.templateID == id }
        let snapshotLogs = completionLogs.filter { $0.templateID == id }

        templates.removeAll { $0.id == id }
        overrides.removeAll { $0.templateID == id }      // 👈 xóa overrides
        completionLogs.removeAll { $0.templateID == id } // 👈 xóa completion logs
        rebuildIndex()
        rebuildCompletionIndex()
        invalidateCache()
        objectWillChange.send()
        saveNow()

        if let template = snapshotTemplate {
            setPendingUndo(PendingUndo(
                kind: .templateDelete(template: template, overrides: snapshotOverrides, logs: snapshotLogs),
                title: template.title
            ))
        }
    }

    // From-today variants cho recurring changes
    func updateEventTimeFromToday(templateID: UUID, minutes: Int) {
        guard let idx = templates.firstIndex(where: { $0.id == templateID }) else { return }
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        // Lock past before mutating the template's canonical minutes.
        snapshotPastInstances(templateID: templateID, fields: [.minutes])

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
        guard let clamped = clampDuration(duration, start: templates[idx].minutes) else { return }
        let todayKey = key(for: Calendar.current.startOfDay(for: Date()))

        snapshotPastInstances(templateID: templateID, fields: [.duration])

        for i in overrides.indices {
            if overrides[i].templateID == templateID && overrides[i].dateKey >= todayKey {
                overrides[i].duration = nil
            }
        }

        templates[idx].duration = clamped
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
        f.dateStyle = .short
        f.timeStyle = .none

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
