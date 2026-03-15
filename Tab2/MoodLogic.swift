//
//  MoodLogic.swift
//  Structify
//
//  Created by Sam Manh Cuong on 15/3/26.
//

import SwiftUI
import Combine

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
    case rough   = "Rough"
    case low     = "Low"
    case okay    = "Okay"
    case good    = "Good"
    case amazing = "Amazing"

    var icon: String {
        switch self {
        case .rough:   return "😞"
        case .low:     return "😔"
        case .okay:    return "😐"
        case .good:    return "😊"
        case .amazing: return "🤩"
        }
    }

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
                Text("Mood Tracker")
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
            Text(currentMood.rawValue)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: currentMood.rawValue)

            // Slider
            VStack(spacing: 8) {
                HStack {
                    Text("LOW")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("High")
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
                Text("Add a note")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    if note.isEmpty {
                        Text("How was your day?")
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
                Text("Submit")
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
    let weekdays = ["S","M","T","W","T","F","S"]

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
                            Text("Recent")
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
                                            Text(entry.mood.rawValue)
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
                    Button("Done") { dismiss() }
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

            Text(entry.mood.rawValue)
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
    @State private var showMoodSheet = false
    @State private var showMoodLog = false

    var todayEntry: MoodEntry? { moodStore.todayEntry() }
    
   

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mood")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(todayEntry == nil
                         ? "Set your feeling for the day"
                         : todayEntry!.mood.dailyMessage()
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    
                    Button {
                        showMoodSheet = true
                    } label: {
                        Text(todayEntry == nil ? "Add mood" : "Edit")
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
    var messages: [String] {
        switch self {
        case .rough:
            return [
                "Tough days don't last forever 🌧",
                "It's okay to not be okay right now",
                "Rest up — tomorrow is a fresh start",
                "You're stronger than this moment",
                "Every storm runs out of rain",
                "Give yourself permission to feel this",
                "One hard day doesn't define your journey",
                "You showed up today — that already counts",
                "Take it one breath at a time",
                "You're not alone in this",
                "The lowest points often precede the biggest growth",
                "Be gentle with yourself today",
                "This feeling is temporary, your strength is not",
                "Even on hard days, you're still moving forward",
                "Rest is productive too",
                "You've survived every hard day so far",
                "It's okay to slow down",
                "Your feelings are valid, all of them",
                "Tomorrow holds new possibilities",
                "You don't have to have it all together today",
                "Small steps still count as progress",
                "Breathe. You've got this.",
                "Hard days build the strongest people",
                "You matter more than you know",
                "This chapter is hard, but it's not the last",
                "Reach out to someone you trust today",
                "Healing isn't linear — and that's okay",
                "You are enough, even on your worst days",
                "The sun will rise again tomorrow",
                "One day at a time is perfectly fine"
            ]

        case .low:
            return [
                "A low day is still a day you showed up",
                "You're doing better than you think",
                "Energy ebbs and flows — this will pass",
                "Even quiet days have value",
                "Small wins still count today",
                "Take care of yourself first",
                "A little progress is still progress",
                "It's okay to have an off day",
                "Your worth isn't measured by your output",
                "Recharge — you've earned it",
                "Tomorrow you might surprise yourself",
                "Slow and steady still gets there",
                "You don't have to be at 100% every day",
                "Be kind to yourself right now",
                "Even a small step forward matters",
                "Low energy doesn't mean low value",
                "Rest today, rise tomorrow",
                "You're allowed to take it easy",
                "Some days are for recovery",
                "You're still in the game",
                "Check in with yourself — what do you need?",
                "Your best looks different every day",
                "Give yourself grace today",
                "You've handled tough days before",
                "A quiet day can be a healing day",
                "Don't compare today to your best day",
                "You're human — this is normal",
                "Nourish yourself today",
                "It's a low day, not a bad life",
                "You'll find your rhythm again soon"
            ]

        case .okay:
            return [
                "Steady and solid — keep it up 🌤",
                "Okay is a perfectly good place to be",
                "You're holding it together well",
                "Consistent effort compounds over time",
                "Middle ground is still ground worth standing on",
                "Not every day needs to be extraordinary",
                "You're building something meaningful",
                "Steady days create lasting progress",
                "Keep showing up like this",
                "An okay day is a foundation for a great one",
                "You're on track — trust the process",
                "Balance is a skill you're mastering",
                "Normal days are the backbone of big wins",
                "You're exactly where you need to be",
                "One more okay day stacks up to something great",
                "Consistency beats intensity every time",
                "You're doing the quiet work — it shows",
                "Grounded and moving — that's a win",
                "Not all heroes feel amazing every day",
                "You're reliable, and that's powerful",
                "Today's effort is tomorrow's momentum",
                "Steady is underrated",
                "You're more capable than you realize",
                "Keep your rhythm going",
                "Every okay day is a step toward great",
                "You showed up — that's half the battle",
                "Progress doesn't always feel dramatic",
                "The compound effect is working in your favor",
                "You're building a solid foundation",
                "Calm and consistent wins the race"
            ]

        case .good:
            return [
                "You're in a great flow today 😊",
                "Ride this energy — it's working",
                "Good days are worth celebrating",
                "You earned this feeling",
                "Keep building on this momentum",
                "This is what consistency looks like",
                "You're firing on all cylinders",
                "Today is proof you're on the right path",
                "Channel this energy into something big",
                "You're in your element right now",
                "Good vibes, good work — keep going",
                "This version of you is unstoppable",
                "You're making it look easy",
                "Great things are happening for you",
                "Your hard work is paying off",
                "Savor this — you created it",
                "You're exactly where you want to be",
                "Use this momentum wisely",
                "Success has a way of building on itself",
                "Today you're setting the pace",
                "You're the energy in the room today",
                "Own this day completely",
                "Good days like this don't happen by accident",
                "You're growing and it shows",
                "Keep this feeling as your reference point",
                "You're proving what's possible",
                "The best is still ahead of you",
                "You're on a roll — don't stop now",
                "This is the version of you to remember",
                "Enjoy every moment of this"
            ]

        case .amazing:
            return [
                "You're absolutely on fire today 🤩",
                "This is peak you — soak it in",
                "The world better watch out",
                "You're operating at a whole new level",
                "Days like this are what dreams are made of",
                "You didn't just show up — you dominated",
                "This energy? Bottled and stored forever",
                "You are the momentum",
                "Unstoppable. Undeniable. That's you.",
                "Everything you've worked for is showing up today",
                "You're writing your best chapter right now",
                "This is what winning feels like",
                "You are the highlight reel today",
                "Pure excellence — keep going",
                "You're inspiring everyone around you",
                "Future you will thank today you",
                "You turned up and turned it all the way on",
                "This is your natural state — remember it",
                "You're making the impossible look easy",
                "Legendary effort, legendary result",
                "You've tapped into something special",
                "The universe is clearly on your side today",
                "You're radiating greatness",
                "Today you set the standard",
                "You belong exactly where you are right now",
                "Nothing can stop you in this state",
                "You're proof that amazing is achievable",
                "This is the energy that changes everything",
                "You're not just doing well — you're thriving",
                "Keep being this version of yourself"
            ]
        }
    }

    func randomMessage() -> String {
        messages.randomElement() ?? messages[0]
    }
    
    func dailyMessage() -> String {
        let day = Calendar.current.component(.day, from: Date())
        return messages[day % messages.count]
    }
}
