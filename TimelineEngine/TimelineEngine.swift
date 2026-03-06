
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

        // clamp timeline
        newMinutes = max(minMinute, min(maxMinute, newMinutes))

        // clamp với event trước
        newMinutes = max(
            newMinutes,
            previousLimit(index: index, events: events)
        )

        // clamp với event sau
        if index < events.count - 1 {

            let eventEnd =
                newMinutes +
                (event.duration ?? 0)

            let nextLimit =
                nextLimit(index: index, events: events)

            if eventEnd > nextLimit {

                newMinutes =
                    nextLimit -
                    (event.duration ?? 0)
            }
        }

        // snap
        newMinutes =
            (newMinutes / snapStep) * snapStep

        return newMinutes
    }
}

extension TimelineEngine {

    static func spacing(
        current: EventItem,
        next: EventItem
    ) -> CGFloat {

        let currentEnd = endMinute(current)

        let diff = next.minutes - currentEnd

        return max(
            4,
            min(
                60,
                diff < 15
                ? CGFloat(diff) * 0.8
                : CGFloat(diff) * 0.25
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

        guard index < events.count - 1 else { return maxMinute }

        return events[index + 1].minutes - spacing
    }

}
