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

        // spacing tối thiểu cho icon lớn
        var base: CGFloat = 20

        // nếu là system event → thêm khoảng cách
        if current.isSystemEvent || next.isSystemEvent {
            base += 12
        }

        if safeDiff <= 5 {
            return base
        }

        if safeDiff <= 15 {
            return base + CGFloat(safeDiff) * 1.2
        }

        if safeDiff <= 60 {
            return base + CGFloat(safeDiff) * 0.45
        }

        return min(
            base + CGFloat(safeDiff) * 0.25,
            100
        )
    }
    
    
}
