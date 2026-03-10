
import Foundation

struct TimelineEngine {

    static let snapStep = 5
    static let minMinute = 0
    static let maxMinute = 1440
    static let spacing = 5

    static func move(
        event: EventItem,
        index: Int,
        events: [EventItem],
        translation: CGFloat
    ) -> Int {

        let minuteChange = Int(translation / 2)
        var newMinutes = event.minutes + minuteChange

        // 1️⃣ snap
        newMinutes = snap(newMinutes)

        // system event zones
        if event.title == "Rise and Shine" {

            // 00:00 → 12:00
            newMinutes = max(0, min(newMinutes, 720))

        }

        if event.title == "Wind Down" {

            // 12:00 → 24:00
            newMinutes = max(720, min(newMinutes, 1440))
        }

        // 3️⃣ clamp timeline
        let range = timelineRange(events: events)

        newMinutes = max(
            range.lowerBound,
            min(range.upperBound - (event.duration ?? 0), newMinutes)
        )

        // 4️⃣ clamp event trước
        let duration = event.duration ?? 0

        let prevLimit = event.title == "Wind Down"
            ? minMinute
            : previousLimit(index: index, events: events)

        let nextLimit = index < events.count - 1
            ? nextLimit(index: index, events: events)
            : maxMinute

        // nếu không còn khoảng trống → giữ nguyên
        if prevLimit > nextLimit - duration {
            return event.minutes
        }

        newMinutes = max(prevLimit, min(newMinutes, nextLimit - duration))

        return newMinutes
    }
    
    static func snap(_ minutes: Int) -> Int {

        (minutes / snapStep) * snapStep

    }
    
    static func clampDuration(
        start: Int,
        duration: Int
    ) -> Int {

        min(duration, maxMinute - start - spacing)
    }
    
    static func timelineRange(events: [EventItem]) -> ClosedRange<Int> {
        minMinute...maxMinute
    }
    
    
    static func minutes(from date: Date) -> Int {

        let comp = Calendar.current.dateComponents(
            [.hour,.minute],
            from: date
        )

        return (comp.hour ?? 0) * 60 + (comp.minute ?? 0)
    }
    
  
    
    static func dateFrom(minutes: Int, base: Date) -> Date {

        let calendar = Calendar.current

        let start = calendar.startOfDay(for: base)

        return start.addingTimeInterval(Double(minutes) * 60)
    }
    
    static func suggestedStartMinutes(events: [EventItem]) -> Int {

        guard events.count > 1 else { return 540 } // fallback 9:00

        var largestGap = 0
        var suggested = 540

        for i in 0..<(events.count - 1) {

            let current = events[i]
            let next = events[i + 1]

            let currentEnd = current.minutes + (current.duration ?? 0)

            let gap = next.minutes - currentEnd

            if gap > largestGap {

                largestGap = gap
                suggested = currentEnd + gap / 2
            }
        }

        return suggested
    }
    
     static func smartSlotMinutes(
        events: [EventItem],
        duration: Int = 0
    ) -> Int {

        let dayStart = minMinute
        let dayEnd = 1440

        let sorted = events.sorted { $0.minutes < $1.minutes }

        var bestStart = dayStart
        var largestGap = 0

        var previousEnd = dayStart

        for event in sorted {

            let gapStart = previousEnd
            let gapEnd = event.minutes

            let gap = gapEnd - gapStart

            if gap > largestGap {

                largestGap = gap

                let start: Int

                if gap < 60 {
                    start = gapStart + spacing
                } else if gap < 180 {
                    start = gapStart + gap / 2
                } else {
                    start = gapStart + gap / 3
                }

                bestStart = start
            }

            previousEnd = max(previousEnd, event.minutes + (event.duration ?? 0))
        }

        let finalGap = dayEnd - previousEnd

        if finalGap > largestGap {

            let start: Int

            if finalGap < 60 {
                start = previousEnd + spacing
            } else if finalGap < 180 {
                start = previousEnd + finalGap / 2
            } else {
                start = previousEnd + finalGap / 3
            }

            bestStart = start
        }

        // đảm bảo không vượt timeline
        bestStart = max(dayStart, min(bestStart, dayEnd - duration))

        return snap(bestStart)
    }
    
    
    
}

extension TimelineEngine {

    static func spacing(
        current: EventItem,
        next: EventItem
    ) -> CGFloat {

        let diff = next.minutes - endMinute(current)
        let safeDiff = max(diff, 0)

        var base: CGFloat = 40

        // boost spacing cho system events
        if current.isSystemEvent {
            base += 22
        }

        if next.isSystemEvent {
            base += 22
        }

        if safeDiff <= 5 {
            return base
        }

        if safeDiff <= 15 {
            return base + CGFloat(safeDiff) * 2
        }

        if safeDiff <= 60 {
            return base + CGFloat(safeDiff) * 0.7
        }

        return min(160, base + CGFloat(safeDiff) * 0.35)
    }
}

extension TimelineEngine {

    static func formatTime(_ minutes: Int) -> String {

        let normalized = minutes % 1440

        let h = normalized / 60
        let m = normalized % 60

        return String(format: "%02d:%02d", h, m)
    }

}

extension TimelineEngine {

    static func endMinute(_ event: EventItem) -> Int {

        event.minutes + (event.duration ?? 0)

    }

}

extension TimelineEngine {

    static func previousLimit(
        index: Int,
        events: [EventItem]
    ) -> Int {

        guard index > 0 else { return minMinute }

        let previous = events[index - 1]

        return endMinute(previous) + spacing
    }

    static func nextLimit(
        index: Int,
        events: [EventItem]
    ) -> Int {

        guard index < events.count - 1 else {
            return maxMinute - spacing
        }

        return events[index + 1].minutes - spacing
    }

}


extension TimelineEngine {

    static func largestGapIndex(
        events: [EventItem]
    ) -> Int? {

        guard events.count > 1 else { return nil }

        var largestGap = 0
        var index: Int?

        for i in 0..<(events.count - 1) {

            let gap =
                events[i + 1].minutes -
                endMinute(events[i])

            if gap > largestGap {
                largestGap = gap
                index = i
            }
        }

        return index
    }
    
    static func reorderIndex(
        currentIndex: Int,
        translation: CGFloat,
        events: [EventItem]
    ) -> Int {

        let step: CGFloat = 70

        let offset = Int((translation / step).rounded())

        let newIndex = max(
            0,
            min(events.count - 1, currentIndex + offset)
        )

        return newIndex
    }
    
    
    
    
    
    
    
    
    
}
