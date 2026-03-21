import Foundation

// MARK: - Stats Snapshot

struct StatsSnapshot {
    let todayCompletion: Double
    let totalEventsToday: Int
    let completedEventsToday: Int
    let weekCompletion: Double
    let previousWeekCompletion: Double
    let weekDelta: Double          // fractional change vs last week, e.g. +0.12 = +12%
    let monthCompletion: Double
    let currentStreak: Int
    let bestStreak: Int
    let consistencyScore: Double   // 0...1 — % of habit days above threshold in past 30 days
    let isStreakAtRisk: Bool       // streak > 1 but no habit progress today yet

    static var empty: StatsSnapshot {
        StatsSnapshot(
            todayCompletion: 0, totalEventsToday: 0, completedEventsToday: 0,
            weekCompletion: 0, previousWeekCompletion: 0, weekDelta: 0,
            monthCompletion: 0, currentStreak: 0, bestStreak: 0,
            consistencyScore: 0, isStreakAtRisk: false
        )
    }
}

// MARK: - StatsEngine

struct StatsEngine {

    // MARK: - Public API

    static func snapshot(store: TimelineStore, streakThreshold: Double) -> StatsSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let todayEvs = store.events(for: Date()).filter { !$0.isSystemEvent }
        let doneToday = todayEvs.filter { store.isCompleted(templateID: $0.id, date: Date()) }.count
        let todayRate = todayEvs.isEmpty ? 0.0 : Double(doneToday) / Double(todayEvs.count)

        let weekRate     = completionRate(store: store, endDate: today, dayCount: 7)
        let prevWeekEnd  = cal.date(byAdding: .day, value: -7, to: today) ?? today
        let prevWeekRate = completionRate(store: store, endDate: prevWeekEnd, dayCount: 7)
        let weekDelta    = prevWeekRate > 0 ? (weekRate - prevWeekRate) / prevWeekRate : 0

        let monthRate = completionRate(store: store, endDate: today, dayCount: 30)

        let streak      = currentStreak(store: store, threshold: streakThreshold)
        let best        = bestStreak(store: store, threshold: streakThreshold)
        let consistency = consistencyScore(store: store, threshold: streakThreshold, days: 30)

        let habitEventsToday = todayEvs.filter { $0.kind == .habit }
        let doneHabitsToday  = habitEventsToday.filter { store.isCompleted(templateID: $0.id, date: Date()) }.count
        let atRisk = streak > 1 && !habitEventsToday.isEmpty && doneHabitsToday == 0

        return StatsSnapshot(
            todayCompletion: todayRate,
            totalEventsToday: todayEvs.count,
            completedEventsToday: doneToday,
            weekCompletion: weekRate,
            previousWeekCompletion: prevWeekRate,
            weekDelta: weekDelta,
            monthCompletion: monthRate,
            currentStreak: streak,
            bestStreak: best,
            consistencyScore: consistency,
            isStreakAtRisk: atRisk
        )
    }

    // MARK: - Completion Rate

    /// Returns completion rate for `dayCount` days ending on (and including) `endDate`.
    static func completionRate(store: TimelineStore, endDate: Date, dayCount: Int) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let startDate = cal.date(byAdding: .day, value: -(dayCount - 1), to: endDate) else { return 0 }

        var total = 0, done = 0
        for d in 0..<dayCount {
            guard let date = cal.date(byAdding: .day, value: d, to: startDate) else { continue }
            if date > today { continue }
            let evs = store.events(for: date).filter { !$0.isSystemEvent }
            total += evs.count
            done  += evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
        }
        return total > 0 ? Double(done) / Double(total) : 0
    }

    // MARK: - Streak

    static func currentStreak(store: TimelineStore, threshold: Double) -> Int {
        let cal = Calendar.current
        var streak = 0
        var date   = cal.startOfDay(for: Date())

        for _ in 0..<365 {
            let evs = store.events(for: date).filter { !$0.isSystemEvent && $0.kind == .habit }
            guard !evs.isEmpty else { break }
            let done = evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
            guard Double(done) / Double(evs.count) >= threshold else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    static func bestStreak(store: TimelineStore, threshold: Double) -> Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sortedKeys = Set(store.completionLogs.map { $0.dateKey }).sorted()
        guard !sortedKeys.isEmpty else { return 0 }

        var best     = 0
        var current  = 0
        var prevDate: Date?

        for key in sortedKeys {
            let y = key / 10000, m = (key % 10000) / 100, d = key % 100
            guard let date = cal.date(from: DateComponents(year: y, month: m, day: d)),
                  date <= today else { continue }

            let evs = store.events(for: date).filter { !$0.isSystemEvent && $0.kind == .habit }
            guard !evs.isEmpty else { current = 0; prevDate = nil; continue }

            let done = evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
            if Double(done) / Double(evs.count) >= threshold {
                let consecutive = prevDate.map {
                    cal.dateComponents([.day], from: $0, to: date).day == 1
                } ?? false
                current = consecutive ? current + 1 : 1
                best = max(best, current)
            } else {
                current = 0
            }
            prevDate = date
        }
        return best
    }

    // MARK: - Consistency Score

    /// Fraction of habit-active days in the past `days` where threshold was met.
    static func consistencyScore(store: TimelineStore, threshold: Double, days: Int) -> Double {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        var valid = 0, consistent = 0

        for d in 0..<days {
            guard let date = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            let evs = store.events(for: date).filter { !$0.isSystemEvent && $0.kind == .habit }
            guard !evs.isEmpty else { continue }
            valid += 1
            let done = evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
            if Double(done) / Double(evs.count) >= threshold { consistent += 1 }
        }
        return valid > 0 ? Double(consistent) / Double(valid) : 0
    }
}
