import Foundation

// MARK: - Trend Direction

enum TrendDirection {
    case up, down, stable
}

// MARK: - Prediction Engine

struct PredictionEngine {
    let projectedMonthCompletion: Double  // 0...1
    let trend: TrendDirection
    let onTrackMessage: String
    let trendIcon: String

    // MARK: - Init

    init(weekCompletion: Double, previousWeekCompletion: Double, monthSoFarCompletion: Double) {
        let delta = weekCompletion - previousWeekCompletion

        if delta > 0.05       { trend = .up   }
        else if delta < -0.05 { trend = .down }
        else                  { trend = .stable }

        // Project based on week momentum
        let projected: Double
        switch trend {
        case .up:     projected = min(1.0, weekCompletion * 1.05)
        case .down:   projected = max(0.0, weekCompletion * 0.95)
        case .stable: projected = weekCompletion
        }

        // Blend projection with actual month-to-date
        let cal          = Calendar.current
        let dayOfMonth   = cal.component(.day, from: Date())
        let daysInMonth  = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        let monthWeight  = Double(dayOfMonth) / Double(daysInMonth)

        projectedMonthCompletion = monthSoFarCompletion * monthWeight + projected * (1.0 - monthWeight)

        let pct = Int(projectedMonthCompletion * 100)
        switch trend {
        case .up:
            onTrackMessage = "On track for ~\(pct)% this month"
            trendIcon      = "chart.line.uptrend.xyaxis"
        case .down:
            onTrackMessage = "Projected ~\(pct)% this month"
            trendIcon      = "chart.line.downtrend.xyaxis"
        case .stable:
            onTrackMessage = "On track for ~\(pct)% this month"
            trendIcon      = "chart.xyaxis.line"
        }
    }
}
