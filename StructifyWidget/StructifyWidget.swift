//
//  StructifyWidget.swift
//  StructifyWidget
//
//  Created by Sam Manh Cuong on 18/3/26.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct StructifyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("label_time")
            Text(entry.date, style: .time)

            Text("label_favorite_emoji")
            Text(entry.configuration.favoriteEmoji)
        }
    }
}

struct StructifyWidget: Widget {
    let kind: String = "StructifyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            StructifyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    StructifyWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley)
    SimpleEntry(date: .now, configuration: .starEyes)
}



import WidgetKit
import SwiftUI

// MARK: - Shared Data Model

struct WidgetEventItem: Codable {
    let id: String
    let title: String
    let icon: String
    let colorHex: String
    let minutes: Int
    let duration: Int?
    let isSystemEvent: Bool
    let kind: String

    var time: String { formatTime(minutes) }
    var endTime: String? {
        guard let d = duration else { return nil }
        return formatTime(minutes + d)
    }
    var color: Color { Color(hex: colorHex) }

    private func formatTime(_ m: Int) -> String {
        let h = (m / 60) % 24
        let min = m % 60
        return String(format: "%02d:%02d", h, min)
    }
}

// MARK: - Data Reader (Widget side)

struct WidgetDataReader {
    static let suiteName = "group.com.samcorp.structify"

    static func events(for date: Date) -> [WidgetEventItem] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let templateData = defaults.data(forKey: "templates"),
              let overrideData = defaults.data(forKey: "overrides") else { return [] }

        let decoder = JSONDecoder()
        guard let templates = try? decoder.decode([WidgetTemplate].self, from: templateData),
              let overrides = try? decoder.decode([WidgetOverride].self, from: overrideData) else { return [] }

        let cal = Calendar.current
        let dateKey = dateToKey(date)

        var result: [WidgetEventItem] = templates
            .filter { matches(template: $0, date: date, cal: cal) }
            .map { WidgetEventItem(
                id: $0.id,
                title: $0.title,
                icon: $0.icon,
                colorHex: $0.colorHex,
                minutes: $0.minutes,
                duration: $0.duration,
                isSystemEvent: $0.isSystemEvent,
                kind: $0.kind
            )}

        // Apply overrides
        let dayOverrides = overrides.filter { $0.dateKey == dateKey }
        for ov in dayOverrides {
            if let mins = ov.minutes, mins < 0 {
                result.removeAll { $0.id == ov.templateID }
                continue
            }
            if let idx = result.firstIndex(where: { $0.id == ov.templateID }) {
                let e = result[idx]
                result[idx] = WidgetEventItem(
                    id: e.id,
                    title: ov.title ?? e.title,
                    icon: ov.icon ?? e.icon,
                    colorHex: ov.colorHex ?? e.colorHex,
                    minutes: ov.minutes ?? e.minutes,
                    duration: ov.duration ?? e.duration,
                    isSystemEvent: e.isSystemEvent,
                    kind: e.kind
                )
            }
        }

        return result.filter { $0.duration != 1440 }.sorted { $0.minutes < $1.minutes }
    }

    static func nextEvent(after now: Date) -> WidgetEventItem? {
        let nowMins = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        return events(for: now)
            .filter { !$0.isSystemEvent }
            .first { $0.minutes + ($0.duration ?? 0) >= nowMins }
    }

    static func wakeMinutes() -> Int {
        UserDefaults(suiteName: suiteName)?.integer(forKey: "user_wake_minutes") ?? 360
    }
    static func sleepMinutes() -> Int {
        let v = UserDefaults(suiteName: suiteName)?.integer(forKey: "user_sleep_minutes") ?? 1410
        return v == 0 ? 1410 : v
    }

    private static func dateToKey(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    private static func matches(template: WidgetTemplate, date: Date, cal: Calendar) -> Bool {
        if let start = template.startDate,
           cal.startOfDay(for: date) < cal.startOfDay(for: start) { return false }
        let weekday = cal.component(.weekday, from: date)
        switch template.recurrence {
        case "daily": return true
        case "weekdays": return weekday >= 2 && weekday <= 6
        case "specific":
            return template.days?.contains(weekday) ?? false
        case "once":
            guard let d = template.onceDate else { return false }
            return cal.isDate(d, inSameDayAs: date)
        case "dateRange":
            guard let s = template.rangeStart, let e = template.rangeEnd else { return false }
            let check = cal.startOfDay(for: date)
            return check >= cal.startOfDay(for: s) && check <= cal.startOfDay(for: e)
        default: return true
        }
    }
    
    static func isCompleted(templateID: String, dateKey: Int) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "completionLogs") else { return false }

        // completionLogs dùng Codable trong app, widget dùng JSONSerialization cho đơn giản
        if let logs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return logs.contains {
                ($0["templateID"] as? String) == templateID &&
                ($0["dateKey"] as? Int) == dateKey &&
                ($0["completed"] as? Bool) == true
            }
        }

        // Fallback: dùng Codable decoder
        struct Log: Codable {
            let templateID: String  // sẽ fail vì app lưu UUID
            let dateKey: Int
            let completed: Bool?
        }
        return false
    }

    static func todayDateKey() -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
    
    static func isCompleted(templateID: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "completionLogs") else { return false }

        struct CompletionLog: Codable {
            let templateID: UUID
            let dateKey: Int
            let completed: Bool?
            let value: Double?
        }

        let dateKey = todayDateKey()
        guard let logs = try? JSONDecoder().decode([CompletionLog].self, from: data) else { return false }
        return logs.contains {
            $0.templateID.uuidString == templateID &&
            $0.dateKey == dateKey &&
            $0.completed == true
        }
    }
    
    
    
    
    
    
    
}

// Lightweight decodable structs cho widget
struct WidgetTemplate: Codable {
    let id: String
    let kind: String
    let minutes: Int
    let duration: Int?
    let title: String
    let icon: String
    let colorHex: String
    let recurrence: String
    let isSystemEvent: Bool
    let startDate: Date?
    let days: [Int]?
    let onceDate: Date?
    let rangeStart: Date?
    let rangeEnd: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, minutes, duration, title, icon, colorHex, isSystemEvent, startDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id).uuidString
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "event"
        minutes = try c.decode(Int.self, forKey: .minutes)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decode(String.self, forKey: .icon)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        isSystemEvent = try c.decodeIfPresent(Bool.self, forKey: .isSystemEvent) ?? false
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)

        // Decode recurrence manually
        struct RecWrapper: Codable {
            let recurrence: RecurrenceRaw
        }
        struct RecurrenceRaw: Codable {
            let type: String
            let days: [Int]?
            let date: Date?
            let endDate: Date?
        }
        let rc = try RecWrapper(from: decoder)
        recurrence = rc.recurrence.type
        days = rc.recurrence.days
        onceDate = rc.recurrence.type == "once" ? rc.recurrence.date : nil
        rangeStart = rc.recurrence.type == "dateRange" ? rc.recurrence.date : nil
        rangeEnd = rc.recurrence.date != nil ? rc.recurrence.endDate : nil
    }

    func encode(to encoder: Encoder) throws {}
}

struct WidgetOverride: Codable {
    let templateID: String
    let dateKey: Int
    let minutes: Int?
    let duration: Int?
    let title: String?
    let icon: String?
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case templateID, dateKey, minutes, duration, title, icon, colorHex
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templateID = try c.decode(UUID.self, forKey: .templateID).uuidString
        dateKey = try c.decode(Int.self, forKey: .dateKey)
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
    }
    func encode(to encoder: Encoder) throws {}
}

// MARK: - Timeline Entry

struct StructifyEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEventItem]
    let nextEvent: WidgetEventItem?
    let wakeMinutes: Int
    let sleepMinutes: Int
}

// MARK: - Provider

struct StructifyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StructifyEntry {
        StructifyEntry(
            date: Date(),
            events: sampleEvents(),
            nextEvent: sampleEvents().first,
            wakeMinutes: 360,
            sleepMinutes: 1410
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StructifyEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StructifyEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> StructifyEntry {
        let now = Date()
        return StructifyEntry(
            date: now,
            events: WidgetDataReader.events(for: now),
            nextEvent: WidgetDataReader.nextEvent(after: now),
            wakeMinutes: WidgetDataReader.wakeMinutes(),
            sleepMinutes: WidgetDataReader.sleepMinutes()
        )
    }

    private func sampleEvents() -> [WidgetEventItem] {
        [
            WidgetEventItem(id: "1", title: "Deep Work", icon: "laptopcomputer", colorHex: "#007AFF", minutes: 540, duration: 90, isSystemEvent: false, kind: "event"),
            WidgetEventItem(id: "2", title: "Gym", icon: "dumbbell.fill", colorHex: "#FF6B6B", minutes: 720, duration: 60, isSystemEvent: false, kind: "habit"),
            WidgetEventItem(id: "3", title: "Read", icon: "book.fill", colorHex: "#34C759", minutes: 840, duration: nil, isSystemEvent: false, kind: "habit"),
        ]
    }
    
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Small Widget: Next Event

struct SmallWidgetView: View {
    let entry: StructifyEntry
    @Environment(\.colorScheme) var scheme

    private var nowMins: Int {
        Calendar.current.component(.hour, from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(scheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground))

            if let event = entry.nextEvent {
                let isRunning = event.minutes <= nowMins &&
                    nowMins <= event.minutes + (event.duration ?? 0)
                let isHabit = event.kind == "habit"
                let isCompleted = WidgetDataReader.isCompleted(templateID: event.id)

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        if isRunning {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                Text("widget_now")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                                    .tracking(1)
                            }
                        } else {
                            Text("widget_next")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                        }
                        Spacer()
                        Text(Date(), style: .time)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 10)

                    // Icon + tick button
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(event.color.opacity(isCompleted ? 0.25 : 0.15))
                                .frame(width: 44, height: 44)
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(event.color)
                            } else {
                                Image(systemName: validIcon(event.icon))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(event.color)
                            }
                        }

                        Spacer()

                        // Tick button chỉ cho habit
                        if isHabit {
                            Button(intent: ToggleHabitIntent(templateID: event.id)) {
                                ZStack {
                                    Circle()
                                        .stroke(event.color.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 28, height: 28)
                                    if isCompleted {
                                        Circle()
                                            .fill(event.color)
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)

                    // Title
                    Text(event.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                        .strikethrough(isCompleted)
                        .padding(.bottom, 2)

                    // Time + running progress
                    if isRunning, let dur = event.duration {
                        let progress = Double(nowMins - event.minutes) / Double(dur)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(event.color)
                                let remaining = (event.minutes + dur) - nowMins
                                Text(String.localizedStringWithFormat(
                                    NSLocalizedString("widget_minutes_left", comment: ""),
                                    remaining
                                ))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(event.color)
                            }
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(event.color.opacity(0.15))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(event.color)
                                        .frame(width: geo.size.width * min(progress, 1), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(event.color)
                            Text(event.time)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(event.color)
                            if let dur = event.duration {
                                Text("· \(dur >= 60 ? "\(dur/60)h\(dur%60>0 ? " \(dur%60)m" : "")" : "\(dur)m")")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(14)
            } else {
                // No events
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.indigo.opacity(0.7))
                    Text("widget_all_clear")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("widget_no_more_events_today")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

// MARK: - Medium Widget: Mini Timeline

struct MediumWidgetView: View {
    let entry: StructifyEntry
    @Environment(\.colorScheme) var scheme

    private var userEvents: [WidgetEventItem] {
        entry.events.filter { !$0.isSystemEvent }
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(scheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground))

            HStack(spacing: 0) {
                // Left: Timeline visual
                timelineColumn
                    .frame(width: 60)

                Divider()
                    .padding(.vertical, 12)

                // Right: Event list
                eventList
                    .padding(.leading, 12)
            }
            .padding(.vertical, 12)
            .padding(.leading, 14)
            .padding(.trailing, 12)
        }
    }

    var timelineColumn: some View {
        VStack(spacing: 0) {
            // Date
            VStack(spacing: 2) {
                Text(Date(), format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(Date(), format: .dateTime.day())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 8)

            // Mini timeline bar
            GeometryReader { geo in
                let h = geo.size.height
                let wake = entry.wakeMinutes
                let sleep = entry.sleepMinutes
                let range = CGFloat(sleep - wake)
                let nowMins = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
                let nowY = CGFloat(nowMins - wake) / range * h

                ZStack(alignment: .top) {
                    // Background track
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 3)
                        .frame(maxWidth: .infinity)

                    // Past fill
                    Capsule()
                        .fill(LinearGradient(colors: [.blue.opacity(0.5), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: max(min(nowY, h), 0))
                        .frame(maxWidth: .infinity, alignment: .top)

                    // Event dots
                    ForEach(userEvents.prefix(5), id: \.id) { event in
                        let y = CGFloat(event.minutes - wake) / range * h
                        Circle()
                            .fill(event.color)
                            .frame(width: 7, height: 7)
                            .shadow(color: event.color.opacity(0.4), radius: 3)
                            .frame(maxWidth: .infinity)
                            .offset(y: max(0, min(y - 3.5, h - 7)))
                    }

                    // Now dot
                    ZStack {
                        Circle().fill(.white).frame(width: 10, height: 10)
                        Circle().fill(.blue).frame(width: 7, height: 7)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(y: max(0, min(nowY - 5, h - 10)))
                    .shadow(color: .blue.opacity(0.4), radius: 4)
                }
            }
        }
    }

    var eventList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("widget_today")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.2)
                .padding(.bottom, 6)

            if userEvents.isEmpty {
                Text("widget_no_events")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(userEvents.prefix(4), id: \.id) { event in
                        eventRow(event)
                    }
                    if userEvents.count > 4 {
                        Text(String.localizedStringWithFormat(
                            NSLocalizedString("widget_more_count", comment: ""),
                            userEvents.count - 4
                        ))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func eventRow(_ event: WidgetEventItem) -> some View {
        let nowMins = Calendar.current.component(.hour, from: Date()) * 60 +
            Calendar.current.component(.minute, from: Date())
        let isPast = event.minutes + (event.duration ?? 0) < nowMins
        let isCurrent = event.minutes <= nowMins &&
            nowMins <= event.minutes + (event.duration ?? 0)
        let isHabit = event.kind == "habit"
        let isCompleted = WidgetDataReader.isCompleted(templateID: event.id)

        return HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrent ? event.color : event.color.opacity(isPast ? 0.3 : 0.6))
                .frame(width: 3, height: 28)

            Image(systemName: validIcon(event.icon))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(event.color.opacity(isPast ? 0.5 : 1))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: isCurrent ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .lineLimit(1)
                    .strikethrough(isCompleted, color: .secondary)
                Text(event.time)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCurrent && !isHabit {
                // Running indicator
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text("widget_now")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
            } else if isHabit {
                // Tick button
                Button(intent: ToggleHabitIntent(templateID: event.id)) {
                    ZStack {
                        Circle()
                            .stroke(event.color.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if isCompleted {
                            Circle().fill(event.color).frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isPast && !isHabit ? 0.6 : 1)
    }
}

// MARK: - Large Widget: Full Day

struct LargeWidgetView: View {
    let entry: StructifyEntry
    @Environment(\.colorScheme) var scheme

    private var userEvents: [WidgetEventItem] {
        entry.events.filter { !$0.isSystemEvent }
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(scheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground))

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Date(), format: .dateTime.weekday(.wide))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(Date(), format: .dateTime.day().month(.abbreviated))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    // Progress ring
                    progressRing
                }
                .padding(.bottom, 12)

                Divider()
                    .padding(.bottom, 10)

                // Event list
                if userEvents.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green.opacity(0.6))
                        Text("widget_free_day")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(userEvents.prefix(7), id: \.id) { event in
                            largeEventRow(event)
                        }
                        if userEvents.count > 7 {
                            HStack {
                                Spacer()
                                Text(String.localizedStringWithFormat(
                                    NSLocalizedString("widget_more_events_count", comment: ""),
                                    userEvents.count - 7
                                ))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
        }
    }

    var progressRing: some View {
        let nowMins = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
        let wake = entry.wakeMinutes
        let sleep = entry.sleepMinutes
        let progress = min(max(Double(nowMins - wake) / Double(sleep - wake), 0), 1)

        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    func largeEventRow(_ event: WidgetEventItem) -> some View {
        let nowMins = Calendar.current.component(.hour, from: Date()) * 60 +
            Calendar.current.component(.minute, from: Date())
        let isPast = event.minutes + (event.duration ?? 0) < nowMins
        let isCurrent = event.minutes <= nowMins &&
            nowMins <= event.minutes + (event.duration ?? 0)
        let isHabit = event.kind == "habit"
        let isCompleted = WidgetDataReader.isCompleted(templateID: event.id)

        return HStack(spacing: 10) {
            // Icon pill
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.color.opacity(isPast ? 0.08 : (isCompleted ? 0.25 : 0.15)))
                    .frame(width: 34, height: 34)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(event.color)
                } else {
                    Image(systemName: validIcon(event.icon))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(event.color.opacity(isPast ? 0.5 : 1))
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: isCurrent ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isPast || isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                    .strikethrough(isCompleted, color: .secondary)

                HStack(spacing: 4) {
                    // Running indicator
                    if isCurrent {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                    }
                    Text(event.time)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(isCurrent ? .green : .secondary)
                    if let dur = event.duration {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        // Nếu đang chạy hiện "Xm left"
                        if isCurrent {
                            let remaining = (event.minutes + dur) - nowMins
                            Text(String.localizedStringWithFormat(
                                NSLocalizedString("widget_minutes_left", comment: ""),
                                remaining
                            ))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.green)
                        } else {
                            Text(dur >= 60
                                 ? "\(dur/60)h\(dur%60>0 ? " \(dur%60)m" : "")"
                                 : "\(dur)m")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Status / Action
            if isHabit {
                // Tick button cho habit
                Button(intent: ToggleHabitIntent(templateID: event.id)) {
                    ZStack {
                        Circle()
                            .stroke(event.color.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                        if isCompleted {
                            Circle()
                                .fill(event.color)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else if isCurrent {
                Text("widget_now")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.green))
            } else if isPast {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(isPast && !isHabit ? 0.7 : 1)
    }
}

// MARK: - Helper

func validIcon(_ name: String) -> String {
    guard !name.isEmpty, UIImage(systemName: name) != nil else {
        return "circle.fill"
    }
    return name
}

// MARK: - Widget Definitions

struct NextEventWidget: Widget {
    let kind = "NextEventWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StructifyProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget_next_event_title")
        .description("widget_next_event_desc")

        .supportedFamilies([.systemSmall])
    }
}

struct TimelineWidget: Widget {
    let kind = "TimelineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StructifyProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget_today_timeline_title")
        .description("widget_today_timeline_desc")

        .supportedFamilies([.systemMedium])
    }
}

struct FullDayWidget: Widget {
    let kind = "FullDayWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StructifyProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget_full_day_title")
        .description("widget_full_day_desc")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Widget Bundle

// MARK: - Lock Screen Widgets

// MARK: Inline — 1 dòng nhỏ trên lock screen
struct InlineLockScreenView: View {
    let entry: StructifyEntry

    private var nowMins: Int {
        Calendar.current.component(.hour, from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    var body: some View {
        if let event = entry.nextEvent {
            let isRunning = event.minutes <= nowMins &&
                nowMins <= event.minutes + (event.duration ?? 0)
            Label {
                if isRunning, let dur = event.duration {
                    let remaining = (event.minutes + dur) - nowMins
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("widget_event_remaining", comment: ""),
                        event.title,
                        remaining
                    ))
                } else {
                    Text("\(event.title) \(event.time)")
                }
            } icon: {
                Image(systemName: validIcon(event.icon))
            }
        } else {
            Label("widget_all_clear", systemImage: "moon.stars.fill")
        }
    }
}

// MARK: Circular — icon tròn nhỏ
struct CircularLockScreenView: View {
    let entry: StructifyEntry

    private var nowMins: Int {
        Calendar.current.component(.hour, from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    var body: some View {
        if let event = entry.nextEvent {
            let isRunning = event.minutes <= nowMins &&
                nowMins <= event.minutes + (event.duration ?? 0)
            let isHabit = event.kind == "habit"
            let isCompleted = WidgetDataReader.isCompleted(templateID: event.id)

            ZStack {
                // Progress ring nếu đang chạy
                if isRunning, let dur = event.duration {
                    let progress = Double(nowMins - event.minutes) / Double(dur)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()
                } else {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2))
                        .opacity(0.3)
                }

                if isHabit && isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .widgetAccentable()
                } else {
                    Image(systemName: validIcon(event.icon))
                        .font(.system(size: 16, weight: .semibold))
                        .widgetAccentable()
                }
            }
        } else {
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2))
                    .opacity(0.3)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .widgetAccentable()
            }
        }
    }
}

// MARK: Rectangular — view đẹp chính
struct RectangularLockScreenView: View {
    let entry: StructifyEntry

    private var nowMins: Int {
        Calendar.current.component(.hour, from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    private var upcomingEvents: [WidgetEventItem] {
        entry.events
            .filter { !$0.isSystemEvent }
            .filter { $0.minutes + ($0.duration ?? 0) >= nowMins }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if upcomingEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 12))
                        .widgetAccentable()
                    Text("widget_no_more_events_today")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .opacity(0.7)
            } else {
                ForEach(upcomingEvents, id: \.id) { event in
                    lockScreenRow(event)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func lockScreenRow(_ event: WidgetEventItem) -> some View {
        let isRunning = event.minutes <= nowMins &&
            nowMins <= event.minutes + (event.duration ?? 0)
        let isHabit = event.kind == "habit"
        let isCompleted = WidgetDataReader.isCompleted(templateID: event.id)

        return HStack(spacing: 5) {
            // Icon
            Image(systemName: isCompleted ? "checkmark.circle.fill" : validIcon(event.icon))
                .font(.system(size: 11, weight: .semibold))
                .widgetAccentable()
                .frame(width: 14)

            // Title
            Text(event.title)
                .font(.system(size: 12, weight: isRunning ? .bold : .medium, design: .rounded))
                .lineLimit(1)
                .strikethrough(isCompleted)

            Spacer(minLength: 0)

            // Status
            if isRunning, let dur = event.duration {
                let remaining = (event.minutes + dur) - nowMins
                Text("\(remaining)m")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .widgetAccentable()
            } else {
                Text(event.time)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.7)
            }

            // Tick cho habit — dùng Button + AppIntent
            if isHabit {
                Button(intent: ToggleHabitIntent(templateID: event.id)) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .widgetAccentable()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Lock Screen Widget Definitions

struct LockScreenInlineWidget: Widget {
    let kind = "LockScreenInlineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StructifyProvider()) { entry in
            InlineLockScreenView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget_next_event_title")
        .description("widget_next_event_desc_short")
        .supportedFamilies([.accessoryInline])
    }
}

struct LockScreenCircularWidget: Widget {
    let kind = "LockScreenCircularWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StructifyProvider()) { entry in
            CircularLockScreenView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget_event_icon_title")
        .description("widget_event_icon_desc")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockScreenRectangularWidget: Widget {
    let kind = "LockScreenRectangularWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StructifyProvider()) { entry in
            RectangularLockScreenView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget_today_schedule_title")
        .description("widget_today_schedule_desc")
        .supportedFamilies([.accessoryRectangular])
    }
}
