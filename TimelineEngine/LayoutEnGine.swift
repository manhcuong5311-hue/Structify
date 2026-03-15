//
//  LayoutEnGine.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct TimelineLayoutEngine {
    
    static let pixelsPerMinute: CGFloat = 0.7
    static let minHeight: CGFloat = 50
    static let maxHeight: CGFloat = 80
    
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

        let diff = next.minutes - TimelineEngine.endMinute(current)
        let safeDiff = max(diff, 0)

        var base: CGFloat = 20  // 👈 tăng từ 16 → 28

        if current.isSystemEvent || next.isSystemEvent {
            base += 8
        }

        // 👈 thêm: bù cho phần pill tràn ra ngoài eventHeight
        let currentPillOverflow = max(0, pillOverflow(current) - eventHeight(current))
        let nextPillOverflow    = max(0, pillOverflow(next))
        base += currentPillOverflow * 0.5 + nextPillOverflow * 0.3

        let normalized = min(CGFloat(safeDiff) / 120, 1)
        let curve      = 1 - pow(1 - normalized, 2)
        let dynamic    = curve * 55

        let heightFactor = (eventHeight(current) + eventHeight(next)) * 0.1

        let result = base + dynamic + heightFactor

        return (result / 2).rounded() * 2
    }

    // 👈 thêm helper tính chiều cao pill thực tế
    private static func pillOverflow(_ event: EventItem) -> CGFloat {
        guard let d = event.duration else { return 50 }
        let h = 50 + CGFloat(d - 15) * (80.0 / 105.0)
        return min(max(h, 50), 130)
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

        // tính y từng event giống hệt TimelineLineView.yPosition
        func topY(for index: Int) -> CGFloat {
            var y: CGFloat = 0
            for i in 0..<index {
                y += eventHeight(events[i])
                if i < events.count - 1 {
                    y += spacing(  // phải là TimelineLayoutEngine.spacing
                        current: events[i],
                        next: events[i + 1]
                    )
                }
            }
            return y
        }

        for i in 0..<events.count - 1 {
            let eventStart  = events[i].minutes
            let eventEnd    = TimelineEngine.endMinute(events[i])
            let nextStart   = events[i + 1].minutes

            let thisTopY    = topY(for: i)
            let thisH       = eventHeight(events[i])
            let thisBottomY = thisTopY + thisH
            let nextTopY    = topY(for: i + 1)

            // Now trong event
            if now >= eventStart && now <= eventEnd {
                let progress = CGFloat(now - eventStart) / CGFloat(max(eventEnd - eventStart, 1))
                return thisTopY + thisH * progress
            }

            // Now trong gap
            if now > eventEnd && now < nextStart {
                let progress = CGFloat(now - eventEnd) / CGFloat(max(nextStart - eventEnd, 1))
                return thisBottomY + (nextTopY - thisBottomY) * progress
            }
        }

        return topY(for: events.count - 1)
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

extension TimelineLayoutEngine {

    static func isNowInsideTimeline(
        events: [EventItem]
    ) -> Bool {

        guard
            let wake = events.first(where: { $0.systemType == .wake }),
            let sleep = events.first(where: { $0.systemType == .sleep })
        else { return false }

        let now = TimelineEngine.currentMinutes()

        return now >= wake.minutes && now <= sleep.minutes
    }
}
