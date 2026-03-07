//
//  LayoutEnGine.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct TimelineLayoutEngine {
    
    static let pixelsPerMinute: CGFloat = 1
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

        // Event cực gần (<15 phút)
        if safeDiff < 15 {
            return max(
                CGFloat(safeDiff) * 0.35,
                1
            )
        }

        // Event gần (<60 phút)
        if safeDiff < 60 {
            return CGFloat(safeDiff) * 0.25
        }

        // Event xa
        return min(
            CGFloat(safeDiff) * 0.18,
            32
        )
    }
}
