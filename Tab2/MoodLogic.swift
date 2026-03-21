//
//  MoodLogic.swift
//  Structify
//
//  Created by Sam Manh Cuong on 15/3/26.
//

import SwiftUI
import Combine

// MARK: - Mood Trend (shared with InsightEngine, MoodAnalytics)

enum MoodTrend {
    case improving, declining, stable
}

// MARK: - Mood Context

struct MoodContext {
    let level: MoodLevel
    let hour: Int
    let streak: Int
    let trend: MoodTrend
    let previousMood: MoodLevel?
}

// MARK: - MoodEntry Model
struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let level: Double  // 0...1
    let note: String

    var mood: MoodLevel {
        switch level {
        case 0..<0.2: return .rough
        case 0.2..<0.4: return .low
        case 0.4..<0.6: return .okay
        case 0.6..<0.8: return .good
        default:        return .amazing
        }
    }
}

enum MoodLevel: String, CaseIterable {
    case rough
    case low
    case okay
    case good
    case amazing

    // MARK: - Localized
    var title: String {
        switch self {
        case .rough:   return String(localized: "mood.rough")
        case .low:     return String(localized: "mood.low")
        case .okay:    return String(localized: "mood.okay")
        case .good:    return String(localized: "mood.good")
        case .amazing: return String(localized: "mood.amazing")
        }
    }

    // MARK: - Icon
    var icon: String {
        switch self {
        case .rough:   return "😞"
        case .low:     return "😔"
        case .okay:    return "😐"
        case .good:    return "😊"
        case .amazing: return "🤩"
        }
    }

    // MARK: - Color
    var color: Color {
        switch self {
        case .rough:   return Color(red:0.80,green:0.35,blue:0.40)
        case .low:     return Color(red:0.90,green:0.60,blue:0.30)
        case .okay:    return Color(red:1.0, green:0.80,blue:0.20)
        case .good:    return Color(red:0.35,green:0.80,blue:0.55)
        case .amazing: return Color(red:0.40,green:0.72,blue:1.0)
        }
    }
}


// MARK: - MoodStore
class MoodStore: ObservableObject {
    @Published var entries: [MoodEntry] = []  // 👈 khởi tạo trước

     init() {
         // load sau khi entries đã được khởi tạo
         if let d = UserDefaults.standard.data(forKey: "moodEntries_v1"),
            let decoded = try? JSONDecoder().decode([MoodEntry].self, from: d) {
             entries = decoded
         }
     }

    func log(level: Double, note: String) {
        entries.removeAll { Calendar.current.isDateInToday($0.date) }
        entries.append(MoodEntry(id: UUID(), date: Date(), level: level, note: note))
        save()
    }

    func entry(for date: Date) -> MoodEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func todayEntry() -> MoodEntry? { entry(for: Date()) }

    private func save() {
        if let d = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(d, forKey: "moodEntries_v1")
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: "moodEntries_v1"),
              let decoded = try? JSONDecoder().decode([MoodEntry].self, from: d)
        else { return }
        entries = decoded
    }
}

// MARK: - Petal Flower View
struct PetalFlower: View {
    let level: Double  // 0...1
    let color: Color

    var petalCount: Int { 8 }
    var petalSize: CGFloat { 40 + CGFloat(level) * 60 }  // 40→100

    var body: some View {
        ZStack {
            ForEach(0..<petalCount, id: \.self) { i in
                Ellipse()
                    .fill(color.opacity(0.18 + level * 0.12))
                    .frame(width: petalSize * 0.55, height: petalSize)
                    .offset(y: -petalSize * 0.38)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(petalCount))))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: level)
    }
}

// MARK: - Mood Sheet
struct MoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var moodStore: MoodStore

    @State private var sliderValue: Double = 0.5
    @State private var note: String = ""
    @State private var lastHapticStep: Int = -1

    var currentMood: MoodLevel {
        switch sliderValue {
        case 0..<0.2: return .rough
        case 0.2..<0.4: return .low
        case 0.4..<0.6: return .okay
        case 0.6..<0.8: return .good
        default:        return .amazing
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(String(localized: "mood_tracker.title"))
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Petal + icon
            ZStack {
                PetalFlower(level: sliderValue, color: currentMood.color)
                    .frame(width: 200, height: 200)

                ZStack {
                    Circle()
                        .fill(currentMood.color.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Text(currentMood.icon)
                           .font(.system(size: 44))
                }
            }
            .frame(height: 200)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentMood.color)

            // Mood label
            Text(currentMood.title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: currentMood.rawValue)

            // Slider
            VStack(spacing: 8) {
                HStack {
                    Text(String(localized: "mood.level.low"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(localized: "mood.level.high"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $sliderValue, in: 0...1, step: 0.01)
                    .tint(currentMood.color)
                    .onChange(of: sliderValue) { _, newVal in
                        let step = Int(newVal * 20)
                        guard step != lastHapticStep else { return }
                        lastHapticStep = step
                        // Haptic mạnh hơn khi mood cao hơn
                        let style: UIImpactFeedbackGenerator.FeedbackStyle = {
                            switch newVal {
                            case 0..<0.3: return .light
                            case 0.3..<0.6: return .medium
                            case 0.6..<0.85: return .heavy
                            default:
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                return .heavy
                            }
                        }()
                        UIImpactFeedbackGenerator(style: style).impactOccurred()
                    }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Note
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "mood.add_note"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    if note.isEmpty {
                        Text(String(localized: "mood.prompt.day"))
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.placeholderText))
                            .padding(14)
                    }

                    TextEditor(text: $note)
                        .font(.system(size: 15))
                        .frame(height: 100)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                }
                .frame(height: 100)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Submit
            Button {
                moodStore.log(level: sliderValue, note: note)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } label: {
                Text(String(localized: "common.submit"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Pre-fill với entry hôm nay nếu có
            if let today = moodStore.todayEntry() {
                sliderValue = today.level
                note = today.note
            }
        }
    }
}

// MARK: - Mood Log Calendar View
struct MoodLogView: View {
    @ObservedObject var moodStore: MoodStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: MoodEntry? = nil

    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    let weekdays = Calendar.current.shortStandaloneWeekdaySymbols

    var calendarDays: [Date?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let monthStart = cal.date(from: cal.dateComponents([.year,.month], from: today)) else { return [] }
        let weekday = cal.component(.weekday, from: monthStart) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for d in 0..<daysInMonth {
            days.append(cal.date(byAdding: .day, value: d, to: monthStart))
        }
        return days
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Weekday headers
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Calendar days
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                            if let date {
                                let entry = moodStore.entry(for: date)
                                let isToday = Calendar.current.isDateInToday(date)
                                let day = Calendar.current.component(.day, from: date)

                                Button {
                                    if let e = entry { selectedEntry = e }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(entry != nil
                                                  ? entry!.mood.color.opacity(0.25)
                                                  : Color(.systemGray6))
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        isToday ? Color.primary.opacity(0.5) : Color.clear,
                                                        lineWidth: 1.5
                                                    )
                                            )

                                        if let entry {
                                            Text(entry.mood.icon)
                                                .font(.system(size: 22))
                                                .foregroundStyle(entry.mood.color)
                                        } else {
                                            Text("\(day)")
                                                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                                                .foregroundStyle(isToday ? .primary : .secondary)
                                        }
                                    }
                                    .frame(height: 44)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }

                    // Recent entries list
                    if !moodStore.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "common.recent"))
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 4)

                            ForEach(moodStore.entries.sorted { $0.date > $1.date }.prefix(7)) { entry in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(entry.mood.color.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Text(entry.mood.icon)
                                            .font(.system(size: 22))
                                            .foregroundStyle(entry.mood.color)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(entry.mood.title)
                                                .font(.system(size: 15, weight: .semibold))
                                            Spacer()
                                            Text(entry.date, style: .date)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        if !entry.note.isEmpty {
                                            Text(entry.note)
                                                .font(.system(size: 13))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            MoodDetailView(entry: entry)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Mood Detail View (khi tap ngày)
struct MoodDetailView: View {
    let entry: MoodEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            ZStack {
                PetalFlower(level: entry.level, color: entry.mood.color)
                    .frame(width: 160, height: 160)

                ZStack {
                    Circle()
                        .fill(entry.mood.color.opacity(0.2))
                        .frame(width: 70, height: 70)
                    Text(entry.mood.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(entry.mood.color)
                }
            }
            .frame(height: 160)

            Text(entry.mood.title)
                .font(.system(size: 28, weight: .bold))

            Text(entry.date, style: .date)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Mood Card (dùng trong StatsView)
struct MoodLogCard: View {
    @ObservedObject var moodStore: MoodStore
    var moodContext: MoodContext? = nil

    @State private var showMoodSheet = false
    @State private var showMoodLog = false

    var todayEntry: MoodEntry? { moodStore.todayEntry() }

    var messageText: String {
        guard let entry = todayEntry else { return String(localized: "mood.empty.prompt") }
        if let ctx = moodContext { return entry.mood.contextualMessage(context: ctx) }
        return entry.mood.dailyMessage()
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "mood.title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(messageText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    
                    Button {
                        showMoodSheet = true
                    } label: {
                        Text(
                            todayEntry == nil
                            ? String(localized: "mood.action.add")
                            : String(localized: "mood.action.edit")
                        )
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red:0.45,green:0.78,blue:1.0))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Circle indicator — tap để mở log
                Button {
                    if todayEntry != nil {
                        showMoodLog = true
                    } else {
                        showMoodSheet = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 52, height: 52)

                        if let entry = todayEntry {
                            Circle()
                                .fill(entry.mood.color.opacity(0.25))
                                .frame(width: 52, height: 52)
                            Text(entry.mood.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(entry.mood.color)
                        } else {
                            Image(systemName: "sun.min.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodSheet(moodStore: moodStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showMoodLog) {
            MoodLogView(moodStore: moodStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

extension MoodLevel {

    // MARK: - Context-Aware Message (primary API)

    func contextualMessage(context: MoodContext) -> String {
        let day  = Calendar.current.component(.day, from: Date())
        let hour = context.hour
        let isMorning   = hour >= 5  && hour < 12
        let isEvening   = hour >= 18 && hour < 24
        let hasStreak   = context.streak >= 3
        let improving   = context.trend == .improving
        let declining   = context.trend == .declining
        let cameFromLow = context.previousMood == .rough || context.previousMood == .low

        switch self {

        case .rough:
            
            let validation = [
                "mood.rough.validation.1",
                "mood.rough.validation.2",
                "mood.rough.validation.3",
                "mood.rough.validation.4"
            ].map { String(localized: $0) }
            
            let grounding = [
                "mood.rough.grounding.1",
                "mood.rough.grounding.2",
                "mood.rough.grounding.3",
                "mood.rough.grounding.4"
            ].map { String(localized: $0) }
            
            let streakSafe = [
                "mood.rough.streak_safe.1",
                "mood.rough.streak_safe.2",
                "mood.rough.streak_safe.3"
            ].map { String(localized: $0) }
            
            if hasStreak { return streakSafe[day % streakSafe.count] }
            if isMorning  { return grounding[day % grounding.count] }
            return validation[day % validation.count]

        case .low:
            
            let validation = [
                "mood.low.validation.1",
                "mood.low.validation.2",
                "mood.low.validation.3",
                "mood.low.validation.4"
            ].map { String(localized: $0) }

            let gentle = [
                "mood.low.gentle.1",
                "mood.low.gentle.2",
                "mood.low.gentle.3",
                "mood.low.gentle.4"
            ].map { String(localized: $0) }

            let recovery = [
                "mood.low.recovery.1",
                "mood.low.recovery.2",
                "mood.low.recovery.3"
            ].map { String(localized: $0) }
            
            if declining    { return recovery[day % recovery.count] }
            if isEvening    { return validation[day % validation.count] }
            return gentle[day % gentle.count]

        case .okay:
            
            let steady = [
                "mood.okay.steady.1",
                "mood.okay.steady.2",
                "mood.okay.steady.3",
                "mood.okay.steady.4"
            ].map { String(localized: $0) }

            let momentum = [
                "mood.okay.momentum.1",
                "mood.okay.momentum.2",
                "mood.okay.momentum.3",
                "mood.okay.momentum.4"
            ].map { String(localized: $0) }

            let improving_ = [
                "mood.okay.improving.1",
                "mood.okay.improving.2",
                "mood.okay.improving.3"
            ].map { String(localized: $0) }
            
            if improving { return improving_[day % improving_.count] }
            if hasStreak { return momentum[day % momentum.count] }
            return steady[day % steady.count]

        case .good:
            
            let affirmation = [
                "mood.good.affirmation.1",
                "mood.good.affirmation.2",
                "mood.good.affirmation.3",
                "mood.good.affirmation.4"
            ].map { String(localized: $0) }

            let identity = [
                "mood.good.identity.1",
                "mood.good.identity.2",
                "mood.good.identity.3",
                "mood.good.identity.4"
            ].map { String(localized: $0) }

            let timeAware: [String] = isMorning ? [
                "mood.good.time.morning.1",
                "mood.good.time.morning.2"
            ].map { String(localized: $0) }
            : isEvening ? [
                "mood.good.time.evening.1",
                "mood.good.time.evening.2"
            ].map { String(localized: $0) }
            : [
                "mood.good.time.neutral.1",
                "mood.good.time.neutral.2"
            ].map { String(localized: $0) }
            
            if cameFromLow { return affirmation[day % affirmation.count] }
            if improving   { return identity[day % identity.count] }
            return timeAware[day % timeAware.count]

        case .amazing:
            
            let celebration = [
                "mood.amazing.celebration.1",
                "mood.amazing.celebration.2",
                "mood.amazing.celebration.3",
                "mood.amazing.celebration.4"
            ].map { String(localized: $0) }

            let identity = [
                "mood.amazing.identity.1",
                "mood.amazing.identity.2",
                "mood.amazing.identity.3",
                "mood.amazing.identity.4"
            ].map { String(localized: $0) }

            let timeAware: [String] = isMorning ? [
                "mood.amazing.time.morning.1",
                "mood.amazing.time.morning.2"
            ].map { String(localized: $0) }
            : isEvening ? [
                "mood.amazing.time.evening.1",
                "mood.amazing.time.evening.2"
            ].map { String(localized: $0) }
            : [
                "mood.amazing.time.neutral.1",
                "mood.amazing.time.neutral.2"
            ].map { String(localized: $0) }
            
            
            if improving { return identity[day % identity.count] }
            return day % 2 == 0
                ? celebration[day % celebration.count]
                : timeAware[day % timeAware.count]
        }
    }

    // MARK: - Fallback (deterministic, day-based)

    var messages: [String] {
        switch self {
        case .rough:
            return [
                String(localized: "mood.rough.1"),
                String(localized: "mood.rough.2"),
                String(localized: "mood.rough.3"),
                String(localized: "mood.rough.4"),
                String(localized: "mood.rough.5"),
                String(localized: "mood.rough.6"),
                String(localized: "mood.rough.7"),
                String(localized: "mood.rough.8"),
                String(localized: "mood.rough.9"),
                String(localized: "mood.rough.10")
            ]
        case .low:
            return [
                String(localized: "mood.low.1"),
                String(localized: "mood.low.2"),
                String(localized: "mood.low.3"),
                String(localized: "mood.low.4"),
                String(localized: "mood.low.5"),
                String(localized: "mood.low.6"),
                String(localized: "mood.low.7"),
                String(localized: "mood.low.8"),
                String(localized: "mood.low.9"),
                String(localized: "mood.low.10")
            ]
            
        case .okay:
            return [
                String(localized: "mood.okay.1"),
                String(localized: "mood.okay.2"),
                String(localized: "mood.okay.3"),
                String(localized: "mood.okay.4"),
                String(localized: "mood.okay.5"),
                String(localized: "mood.okay.6"),
                String(localized: "mood.okay.7"),
                String(localized: "mood.okay.8"),
                String(localized: "mood.okay.9"),
                String(localized: "mood.okay.10")
            ]
            
        case .good:
            return [
                String(localized: "mood.good.1"),
                String(localized: "mood.good.2"),
                String(localized: "mood.good.3"),
                String(localized: "mood.good.4"),
                String(localized: "mood.good.5"),
                String(localized: "mood.good.6"),
                String(localized: "mood.good.7"),
                String(localized: "mood.good.8"),
                String(localized: "mood.good.9"),
                String(localized: "mood.good.10")
            ]

        case .amazing:
            return [
                String(localized: "mood.amazing.1"),
                String(localized: "mood.amazing.2"),
                String(localized: "mood.amazing.3"),
                String(localized: "mood.amazing.4"),
                String(localized: "mood.amazing.5"),
                String(localized: "mood.amazing.6"),
                String(localized: "mood.amazing.7"),
                String(localized: "mood.amazing.8"),
                String(localized: "mood.amazing.9"),
                String(localized: "mood.amazing.10")
            ]
            
        }
    }

    func dailyMessage() -> String {
        let day = Calendar.current.component(.day, from: Date())
        return messages[day % messages.count]
    }
}
