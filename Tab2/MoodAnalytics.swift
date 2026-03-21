import Foundation

// MARK: - Mood Analytics

struct MoodAnalytics {
    let averageScore: Double           // 0...1
    let trend: MoodTrend
    let dominantMood: MoodLevel?
    let correlationInsight: String?    // e.g. "You're more productive on good mood days"

    // MARK: - Init

    init(moodStore: MoodStore, store: TimelineStore) {
        let sorted = moodStore.entries.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(14))

        guard !recent.isEmpty else {
            averageScore       = 0.5
            trend              = .stable
            dominantMood       = nil
            correlationInsight = nil
            return
        }

        // Average score
        averageScore = recent.map { $0.level }.reduce(0, +) / Double(recent.count)

        // Trend — compare first half vs second half
        if recent.count >= 4 {
            let half       = recent.count / 2
            let firstAvg   = recent.prefix(half).map { $0.level }.reduce(0, +) / Double(half)
            let secondAvg  = recent.suffix(half).map { $0.level }.reduce(0, +) / Double(half)
            let delta      = secondAvg - firstAvg
            if delta > 0.08       { trend = .improving }
            else if delta < -0.08 { trend = .declining }
            else                  { trend = .stable    }
        } else {
            trend = .stable
        }

        // Dominant mood (most frequent in recent 14 days)
        let counts = Dictionary(grouping: recent, by: { $0.mood })
        dominantMood = counts.max { $0.value.count < $1.value.count }?.key

        // Correlation: good mood days vs low mood days — completion rate difference
        correlationInsight = Self.correlationInsight(moodEntries: recent, store: store)
    }

    // MARK: - Correlation

    private static func correlationInsight(moodEntries: [MoodEntry], store: TimelineStore) -> String? {
        guard moodEntries.count >= 5 else { return nil }

        var goodMoodRates: [Double] = []
        var lowMoodRates:  [Double] = []

        for entry in moodEntries {
            let evs = store.events(for: entry.date).filter { !$0.isSystemEvent }
            guard !evs.isEmpty else { continue }
            let done = evs.filter { store.isCompleted(templateID: $0.id, date: entry.date) }.count
            let rate = Double(done) / Double(evs.count)

            if entry.level >= 0.6      { goodMoodRates.append(rate) }
            else if entry.level < 0.4  { lowMoodRates.append(rate) }
        }

        guard !goodMoodRates.isEmpty, !lowMoodRates.isEmpty else { return nil }

        let avgGood = goodMoodRates.reduce(0, +) / Double(goodMoodRates.count)
        let avgLow  = lowMoodRates.reduce(0, +)  / Double(lowMoodRates.count)

        if avgGood - avgLow > 0.15 {
            return "You're more productive on good mood days 😊"
        } else if avgLow - avgGood > 0.15 {
            return "You push through even on tough days 💪"
        }
        return nil
    }
}
