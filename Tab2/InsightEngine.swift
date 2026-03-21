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
            title: String(
                format: String(localized: "insight_streak_risk_title"),
                streak
            ),
            subtitle: String(
                localized: "insight_streak_risk_subtitle"
            ),
            type: .warning
        )
    }

    private static func improvementInsight(delta: Double, streak: Int) -> Insight {
        let pct = Int(delta * 100)

        if streak > 3 {
            return Insight(
                title: String(
                    format: String(localized: "insight_improvement_strong_title"),
                    pct
                ),
                subtitle: String(
                    localized: "insight_improvement_strong_subtitle"
                ),
                type: .positive
            )
        }

        return Insight(
            title: String(
                localized: "insight_improvement_normal_title"
            ),
            subtitle: String(
                format: String(localized: "insight_improvement_normal_subtitle"),
                pct
            ),
            type: .positive
        )
    }

    private static func bestStreakInsight(streak: Int) -> Insight {
        Insight(
            title: String(
                format: String(localized: "insight_best_streak_title"),
                streak
            ),
            subtitle: String(
                localized: "insight_best_streak_subtitle"
            ),
            type: .identity
        )
    }

    private static func identityInsight(streak: Int) -> Insight {
        let titles = [
            String(format: String(localized: "insight_identity_title_1"), streak),
            String(format: String(localized: "insight_identity_title_2"), streak),
            String(format: String(localized: "insight_identity_title_3"), streak)
        ]

        let subtitles = [
            String(localized: "insight_identity_subtitle_1"),
            String(localized: "insight_identity_subtitle_2"),
            String(localized: "insight_identity_subtitle_3")
        ]

        let i = streak % titles.count

        return Insight(
            title: titles[i],
            subtitle: subtitles[i],
            type: .identity
        )
    }

    private static func recoveryInsight() -> Insight {
        let day = Calendar.current.component(.day, from: Date())

        let titles = [
            String(localized: "insight_recovery_title_1"),
            String(localized: "insight_recovery_title_2"),
            String(localized: "insight_recovery_title_3")
        ]

        let subtitles = [
            String(localized: "insight_recovery_subtitle_1"),
            String(localized: "insight_recovery_subtitle_2"),
            String(localized: "insight_recovery_subtitle_3")
        ]

        let i = day % titles.count

        return Insight(
            title: titles[i],
            subtitle: subtitles[i],
            type: .recovery
        )
    }

    private static func moodSupportInsight() -> Insight {
        let day = Calendar.current.component(.day, from: Date())

        let titles = [
            String(localized: "insight_mood_support_title_1"),
            String(localized: "insight_mood_support_title_2"),
            String(localized: "insight_mood_support_title_3")
        ]

        let subtitles: [String?] = [
            String(localized: "insight_mood_support_subtitle_1"),
            nil,
            String(localized: "insight_mood_support_subtitle_3")
        ]

        let i = day % titles.count

        return Insight(
            title: titles[i],
            subtitle: subtitles[i],
            type: .recovery
        )
    }

    private static func moodProductivityInsight() -> Insight {
        Insight(
            title: String(localized: "insight_mood_productivity_title"),
            subtitle: String(localized: "insight_mood_productivity_subtitle"),
            type: .positive
        )
    }

    private static func consistencyInsight(score: Double) -> Insight {
        let pct = Int(score * 100)

        return Insight(
            title: String(
                format: String(localized: "insight_consistency_title"),
                pct
            ),
            subtitle: String(
                localized: "insight_consistency_subtitle"
            ),
            type: .identity
        )
    }

    private static func timeInsight(hour: Int, completion: Double) -> Insight {
        switch hour {

        case 5..<9:
            return Insight(
                title: String(localized: "insight_time_morning_early_title"),
                subtitle: completion > 0.3
                    ? String(localized: "insight_time_morning_early_subtitle_ahead")
                    : String(localized: "insight_time_morning_early_subtitle_focus"),
                type: .positive
            )

        case 9..<12:
            if completion > 0.4 {
                return Insight(
                    title: String(localized: "insight_time_morning_strong_title"),
                    subtitle: nil,
                    type: .positive
                )
            }
            return Insight(
                title: String(localized: "insight_time_morning_open_title"),
                subtitle: nil,
                type: .neutral
            )

        case 12..<15:
            let isAhead = completion > 0.4
            return Insight(
                title: String(localized: "insight_time_midday_title"),
                subtitle: isAhead
                    ? String(localized: "insight_time_midday_subtitle_ahead")
                    : String(localized: "insight_time_midday_subtitle_build"),
                type: isAhead ? .positive : .neutral
            )

        case 15..<19:
            return Insight(
                title: String(localized: "insight_time_afternoon_title"),
                subtitle: nil,
                type: .neutral
            )

        case 19..<24:
            if completion > 0.65 {
                return Insight(
                    title: String(localized: "insight_time_evening_good_title"),
                    subtitle: String(localized: "insight_time_evening_good_subtitle"),
                    type: .positive
                )
            }
            return Insight(
                title: String(localized: "insight_time_evening_winddown_title"),
                subtitle: nil,
                type: .neutral
            )

        default:
            return Insight(
                title: String(localized: "insight_time_default_title"),
                subtitle: nil,
                type: .neutral
            )
        }
    }
    
    
    
}
