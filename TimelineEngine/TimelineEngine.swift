
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

        let resistance = translation * 0.7
        let minuteChange = Int(resistance / 8)
        var newMinutes = event.minutes + minuteChange

        // snap
        if abs(minuteChange) > 2 {
            newMinutes = snap(newMinutes)
        }

        // system zones
        if event.systemType == .wake {
            newMinutes = max(0, min(newMinutes, 720))
        }

        if event.systemType == .sleep {
            newMinutes = max(720, min(newMinutes, 1440))
        }

        // timeline clamp
        let range = timelineRange(events: events)

        let duration = event.duration ?? 0

        // system events không bị clamp
        if !event.isSystemEvent {

            newMinutes = max(
                range.lowerBound,
                min(range.upperBound - duration, newMinutes)
            )
        }

        let prevLimit = event.systemType == .sleep
            ? minMinute
            : previousLimit(index: index, events: events)

        let nextLimit = index < events.count - 1
            ? nextLimit(index: index, events: events)
            : maxMinute

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

        let wake =
            events.first { $0.systemType == .wake }?.minutes ?? minMinute

        let sleep =
            events.first { $0.systemType == .sleep }?.minutes ?? maxMinute

        return wake...sleep
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
    
    static func autoPush(
        events: inout [EventItem],
        movedIndex: Int,
        minSpacing: Int = 5
    ) {

        guard movedIndex < events.count else { return }

        // push xuống
        for i in (movedIndex + 1)..<events.count {

            let prev = events[i - 1]
            let current = events[i]

            let required = prev.minutes + minSpacing

            if current.minutes < required {

                events[i].update(minutes: required)

            } else {
                break
            }
        }

        // push lên (trường hợp kéo lên)
        if movedIndex > 0 {

            for i in stride(from: movedIndex - 1, through: 0, by: -1) {

                let next = events[i + 1]
                let current = events[i]

                let required = next.minutes - minSpacing

                if current.minutes > required {

                    events[i].update(minutes: required)

                } else {
                    break
                }
            }
        }
    }
    
    
    static func currentMinutes() -> Int {

        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())

        let hour = c.hour ?? 0
        let minute = c.minute ?? 0

        return hour * 60 + minute
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

        // không cho vượt wake
        if previous.systemType == .wake {
            return previous.minutes + spacing
        }

        return endMinute(previous) + spacing
    }

    static func nextLimit(
        index: Int,
        events: [EventItem]
    ) -> Int {

        guard index < events.count - 1 else {
            return maxMinute - spacing
        }

        let next = events[index + 1]

        // không cho vượt sleep
        if next.systemType == .sleep {
            return next.minutes - spacing
        }

        return next.minutes - spacing
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
