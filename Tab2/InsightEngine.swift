import Foundation

// MARK: - Insight Type

enum InsightType {
    case positive   // green/teal — improving, strong momentum
    case warning    // amber/orange — streak at risk, decline
    case recovery   // soft purple — bounce-back, low mood support
    case identity   // gold — who you're becoming
    case neutral    // default blue-white
}

// MARK: - Insight

struct Insight {
    let title: String
    let subtitle: String?
    let type: InsightType
}

// MARK: - Insight Context

struct InsightContext {
    let streak: Int
    let bestStreak: Int
    let weekCompletion: Double
    let weekDelta: Double         // fractional: +0.15 = +15% better than last week
    let monthCompletion: Double
    let todayCompletion: Double
    let moodLevel: MoodLevel?
    let moodTrend: MoodTrend
    let consistencyScore: Double  // 0...1
    let hour: Int
}

// MARK: - InsightEngine

struct InsightEngine {

    static func generate(context: InsightContext) -> Insight {

        // Priority 1: Streak at risk (highest urgency)
        if context.streak > 1 && context.todayCompletion < 0.05 {
            return streakRiskInsight(streak: context.streak)
        }

        // Priority 2: Strong improvement vs last week
        if context.weekDelta > 0.15 && context.weekCompletion > 0.3 {
            return improvementInsight(delta: context.weekDelta, streak: context.streak)
        }

        // Priority 3: New best streak milestone
        if context.streak > 0 && context.streak == context.bestStreak && context.bestStreak >= 7 {
            return bestStreakInsight(streak: context.streak)
        }

        // Priority 4: Meaningful streak — identity reinforcement
        if context.streak >= 5 {
            return identityInsight(streak: context.streak)
        }

        // Priority 5: Declining + low completion — recovery framing
        if context.weekDelta < -0.15 && context.weekCompletion < 0.45 {
            return recoveryInsight()
        }

        // Priority 6: Mood-aware insight
        if let mood = context.moodLevel {
            if mood == .rough || mood == .low {
                return moodSupportInsight()
            }
            if (mood == .good || mood == .amazing) && context.weekCompletion > 0.55 {
                return moodProductivityInsight()
            }
        }

        // Priority 7: High consistency
        if context.consistencyScore > 0.75 {
            return consistencyInsight(score: context.consistencyScore)
        }

        // Fallback: time + completion based
        return timeInsight(hour: context.hour, completion: context.todayCompletion)
    }

    // MARK: - Generators

    private static func streakRiskInsight(streak: Int) -> Insight {
        Insight(
            title: "\(streak)-day streak at risk ⚠️",
            subtitle: "One habit is all it takes to keep it going.",
            type: .warning
        )
    }

    private static func improvementInsight(delta: Double, streak: Int) -> Insight {
        let pct = Int(delta * 100)
        if streak > 3 {
            return Insight(
                title: "Up \(pct)% this week 📈",
                subtitle: "Your rhythm is building on itself.",
                type: .positive
            )
        }
        return Insight(
            title: "You're moving in the right direction",
            subtitle: "Up \(pct)% compared to last week.",
            type: .positive
        )
    }

    private static func bestStreakInsight(streak: Int) -> Insight {
        Insight(
            title: "Your best streak ever — \(streak) days 🏆",
            subtitle: "This is what discipline actually looks like.",
            type: .identity
        )
    }

    private static func identityInsight(streak: Int) -> Insight {
        let titles = [
            "You've shown up \(streak) days in a row",
            "\(streak) days of not giving up",
            "Day \(streak). Still here."
        ]
        let subtitles = [
            "You're becoming someone who doesn't quit.",
            "Consistent people do exactly this.",
            "Small numbers add up to something real."
        ]
        let i = streak % titles.count
        return Insight(title: titles[i], subtitle: subtitles[i], type: .identity)
    }

    private static func recoveryInsight() -> Insight {
        let day = Calendar.current.component(.day, from: Date())
        let options: [(String, String)] = [
            ("It's okay to reset", "Every comeback starts with one day."),
            ("Quiet weeks happen", "What matters is what you do next."),
            ("You're still in it", "One day at a time is enough.")
        ]
        let pick = options[day % options.count]
        return Insight(title: pick.0, subtitle: pick.1, type: .recovery)
    }

    private static func moodSupportInsight() -> Insight {
        let day = Calendar.current.component(.day, from: Date())
        let options: [(String, String?)] = [
            ("Tough days are part of the process", "Be gentle with yourself today."),
            ("You don't have to be at full capacity", nil),
            ("It's okay to go slower today", "Small steps still count.")
        ]
        let pick = options[day % options.count]
        return Insight(title: pick.0, subtitle: pick.1, type: .recovery)
    }

    private static func moodProductivityInsight() -> Insight {
        Insight(
            title: "You perform well on days like this 😊",
            subtitle: "Good mood, good output — use it.",
            type: .positive
        )
    }

    private static func consistencyInsight(score: Double) -> Insight {
        let pct = Int(score * 100)
        return Insight(
            title: "\(pct)% consistent this month",
            subtitle: "Consistency is the only strategy that compounds.",
            type: .identity
        )
    }

    private static func timeInsight(hour: Int, completion: Double) -> Insight {
        switch hour {
        case 5..<9:
            return Insight(
                title: "Morning energy is your edge",
                subtitle: completion > 0.3 ? "You're already ahead." : "Use the quiet before the noise.",
                type: .positive
            )
        case 9..<12:
            if completion > 0.4 {
                return Insight(title: "Strong start this morning", subtitle: nil, type: .positive)
            }
            return Insight(title: "The morning window is open", subtitle: nil, type: .neutral)
        case 12..<15:
            let sub = completion > 0.4 ? "You're ahead of pace." : "Still time to build momentum."
            return Insight(title: "Midday check-in", subtitle: sub, type: completion > 0.4 ? .positive : .neutral)
        case 15..<19:
            return Insight(
                title: "Afternoon is often the most productive",
                subtitle: nil,
                type: .neutral
            )
        case 19..<24:
            if completion > 0.65 {
                return Insight(title: "Solid day ✓", subtitle: "You can close it out well.", type: .positive)
            }
            return Insight(title: "Wind down with intention", subtitle: nil, type: .neutral)
        default:
            return Insight(title: "Every day is a new page", subtitle: nil, type: .neutral)
        }
    }
}
