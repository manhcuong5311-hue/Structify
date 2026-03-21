import Foundation

// MARK: - Time Period

enum TimePeriod: String, CaseIterable {
    case morning   = "Morning"    // 06–12
    case afternoon = "Afternoon"  // 12–17
    case evening   = "Evening"    // 17–22
}

// MARK: - Time Analytics

struct TimeAnalytics {
    let bestHour: Int?
    let productivityByPeriod: [TimePeriod: Double]

    // MARK: - Init

    init(store: TimelineStore) {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        var hourBuckets: [Int: (done: Int, total: Int)] = [:]

        // Scan last 30 days
        for d in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            let evs = store.events(for: date).filter { !$0.isSystemEvent }

            for ev in evs {
                let hour   = ev.minutes / 60
                let isDone = store.isCompleted(templateID: ev.id, date: date)
                var bucket = hourBuckets[hour] ?? (done: 0, total: 0)
                bucket.total += 1
                if isDone { bucket.done += 1 }
                hourBuckets[hour] = bucket
            }
        }

        // Best hour — only consider hours with ≥3 data points
        let ratedHours = hourBuckets
            .filter { $0.value.total >= 3 }
            .mapValues { Double($0.done) / Double($0.total) }

        bestHour = ratedHours.max { $0.value < $1.value }?.key

        // Group into time periods
        var periodBuckets: [TimePeriod: (done: Int, total: Int)] = [:]
        for (hour, counts) in hourBuckets {
            let period: TimePeriod
            switch hour {
            case 6..<12:  period = .morning
            case 12..<17: period = .afternoon
            case 17..<22: period = .evening
            default: continue
            }
            var b = periodBuckets[period] ?? (done: 0, total: 0)
            b.done  += counts.done
            b.total += counts.total
            periodBuckets[period] = b
        }

        productivityByPeriod = periodBuckets
            .filter { $0.value.total > 0 }
            .mapValues { Double($0.done) / Double($0.total) }
    }

    // MARK: - Derived

    /// Human-readable best hour, e.g. "9 AM"
    var bestHourDescription: String? {
        guard let hour = bestHour else { return nil }
        let cal = Calendar.current
        guard let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        return fmt.string(from: date)
    }

    var bestPeriod: TimePeriod? {
        productivityByPeriod.max { $0.value < $1.value }?.key
    }
}
