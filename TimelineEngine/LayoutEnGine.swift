//
//  LayoutEnGine.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct TimelineLayoutEngine {
    
    static let pixelsPerMinute: CGFloat = 0.7
    static let minHeight: CGFloat = 44
    static let maxHeight: CGFloat = 90
    
    /// tính height của event theo duration
    static func eventHeight(_ event: EventItem) -> CGFloat {
        
        guard let duration = event.duration else {
            return minHeight
        }
        
        let rawHeight =
        CGFloat(duration) * pixelsPerMinute
        
        return min(
            max(rawHeight, minHeight),
            maxHeight
        )
    }
    
    /// khoảng cách giữa 2 event
    static func spacing(
        current: EventItem,
        next: EventItem
    ) -> CGFloat {

        let diff =
            next.minutes -
            TimelineEngine.endMinute(current)

        let safeDiff = max(diff, 0)

        var base: CGFloat = 16

        if current.isSystemEvent || next.isSystemEvent {
            base += 8
        }

        let normalized =
            min(CGFloat(safeDiff) / 120, 1)

        let curve =
            1 - pow(1 - normalized, 2)

        let dynamic =
            curve * 55

        let heightFactor =
            (eventHeight(current) +
             eventHeight(next)) * 0.1

        let result =
            base + dynamic + heightFactor

        return (result / 2).rounded() * 2
    }
    
    
}

extension TimelineLayoutEngine {

    static func wakeEvent(from events: [EventItem]) -> EventItem? {
        events.first { $0.systemType == .wake }
    }

    static func sleepEvent(from events: [EventItem]) -> EventItem? {
        events.first { $0.systemType == .sleep }
    }
}

extension TimelineLayoutEngine {

    static func timelineHeight(
        wake: Int,
        sleep: Int
    ) -> CGFloat {

        CGFloat(sleep - wake) * pixelsPerMinute
    }
}

extension TimelineLayoutEngine {

    static func yPosition(
        minutes: Int,
        wake: Int
    ) -> CGFloat {

        CGFloat(minutes - wake) * pixelsPerMinute
    }
}

extension TimelineLayoutEngine {

    static func eventY(
        event: EventItem,
        wake: Int
    ) -> CGFloat {

        yPosition(
            minutes: event.minutes,
            wake: wake
        )
    }
}

extension TimelineLayoutEngine {

    static func nowMinutes() -> Int {

        let c = Calendar.current
            .dateComponents([.hour,.minute], from: Date())

        return (c.hour ?? 0) * 60 +
               (c.minute ?? 0)
    }

    static func nowY(events: [EventItem]) -> CGFloat {

        guard events.count > 1 else { return 0 }

        let now = nowMinutes()

        var y: CGFloat = 0

        for i in 0..<events.count - 1 {

            let start = events[i]
            let end = events[i + 1]

            let startCenter =
                y + eventHeight(start) / 2

            let endCenter =
                startCenter
                + spacing(current: start, next: end)
                + eventHeight(end) / 2

            if now >= start.minutes && now <= end.minutes {

                let progress =
                    CGFloat(now - start.minutes) /
                    CGFloat(max(end.minutes - start.minutes, 1))

                return startCenter + (endCenter - startCenter) * progress
            }

            y += eventHeight(start)

            if i < events.count - 1 {
                y += spacing(current: start, next: end)
            }
        }

        return y
    }
}

extension TimelineLayoutEngine {

    static func clampedNowY(
        events: [EventItem]
    ) -> CGFloat {

        let y = nowY(events: events)

        let lastIndex = events.count - 1

        var total: CGFloat = 0

        for i in 0..<lastIndex {

            total += eventHeight(events[i])
            total += spacing(current: events[i], next: events[i + 1])
        }

        total += eventHeight(events[lastIndex])

        return min(max(y, 0), total)
    }
}
