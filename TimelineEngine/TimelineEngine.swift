
import Foundation

struct TimelineEngine {

    static let snapStep = 5
    static let minMinute = 0
    static let maxMinute = 1439
    static let spacing = 5

    static func move(
        event: EventItem,
        index: Int,
        events: [EventItem],
        translation: CGFloat
    ) -> Int {

        let minuteChange = Int(translation / 2)

        var newMinutes = event.minutes + minuteChange

        // 1️⃣ snap trước
        newMinutes = snap(newMinutes)

        // 2️⃣ clamp timeline
        newMinutes = max(minMinute, min(maxMinute, newMinutes))

        // 3️⃣ clamp event trước
        let previousLimit = previousLimit(
            index: index,
            events: events
        )

        newMinutes = max(newMinutes, previousLimit)

        // 4️⃣ clamp event sau
        if index < events.count - 1 {

            let nextLimit = nextLimit(
                index: index,
                events: events
            )

            let duration = event.duration ?? 0

            if newMinutes + duration > nextLimit {
                newMinutes = nextLimit - duration
            }
        }

        return newMinutes
    }
    
    static func snap(_ minutes: Int) -> Int {

        (minutes / snapStep) * snapStep

    }
    
    static func clampDuration(
        start: Int,
        duration: Int
    ) -> Int {

        min(duration, maxMinute - start)

    }
    
    
    
    
}

extension TimelineEngine {

    static func spacing(
        current: EventItem,
        next: EventItem
    ) -> CGFloat {

        let diff =
            next.minutes - endMinute(current)

        let safeDiff = max(diff, 0)

        return max(
            4,
            min(
                60,
                safeDiff < 15
                ? CGFloat(safeDiff) * 0.8
                : CGFloat(safeDiff) * 0.25
            )
        )
    }
}

extension TimelineEngine {

    static func formatTime(_ minutes: Int) -> String {

        let h = minutes / 60
        let m = minutes % 60

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
            return maxMinute
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
}
