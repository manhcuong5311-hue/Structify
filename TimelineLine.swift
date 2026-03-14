import SwiftUI

struct TimelineLineView: View {

    let events: [EventItem]
    let isDragging: Bool
    let date: Date
    
    
    
    func isPastOrCurrentSegment(_ index: Int) -> Bool {

        let now = nowMinute()
        let start = events[index].minutes
        let sleep = events[windowIndex()].minutes

        return now >= start && start < sleep
    }
    
    func isCurrentSegment(_ index: Int) -> Bool {
        let now = nowMinute()
        let start = events[index].minutes
        let end   = events[index + 1].minutes  // giữ nguyên vì đây là segment gap
        return now > TimelineEngine.endMinute(events[index]) && now <= end
    }
    
    func nowMinute() -> Int {

        let cal = Calendar.current
        let now = Date()

        return cal.component(.hour, from: now) * 60 +
               cal.component(.minute, from: now)
    }
    
    func nowY() -> CGFloat? {
        let now = nowMinute()

        for i in 0..<events.count - 1 {
            let eventStart  = events[i].minutes
            let eventEnd    = TimelineEngine.endMinute(events[i])
            let nextStart   = events[i + 1].minutes

            let thisTopY    = yPosition(for: i) - TimelineLayoutEngine.eventHeight(events[i]) / 2
            let thisH       = TimelineLayoutEngine.eventHeight(events[i])
            let thisBottomY = thisTopY + thisH
            let nextTopY    = yPosition(for: i + 1) - TimelineLayoutEngine.eventHeight(events[i + 1]) / 2

            if now >= eventStart && now <= eventEnd {
                let progress = CGFloat(now - eventStart) / CGFloat(max(eventEnd - eventStart, 1))
                return thisTopY + thisH * progress
            }

            if now > eventEnd && now < nextStart {
                let progress = CGFloat(now - eventEnd) / CGFloat(max(nextStart - eventEnd, 1))
                return thisBottomY + (nextTopY - thisBottomY) * progress
            }
        }

        return nil
    }
    
    func isToday() -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    
    
    
    

    var body: some View {

        GeometryReader { geo in

            if events.count > 1 {

                let rise = riseIndex()
                let window = windowIndex()
                let indices = Array(rise..<window)

                ZStack(alignment: .topLeading) {

                    ForEach(indices, id: \.self) { i in

                        let startY = yPosition(for: i)
                        let endY   = yPosition(for: i + 1)

                        let minutesGap    = events[i + 1].minutes - TimelineEngine.endMinute(events[i])
                        let segmentHeight = endY - startY
                        let ppm           = segmentHeight / CGFloat(max(minutesGap, 1))
                        let dashLength    = max(4, ppm * 8)
                        let gapLength     = max(4, ppm * 5)
                        let style         = StrokeStyle(
                            lineWidth: isDragging ? 4 : 3,
                            lineCap: .round,
                            dash: [dashLength, gapLength]
                        )

                        // Đường base xám
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: startY))
                            path.addLine(to: CGPoint(x: 0, y: endY))
                        }
                        .stroke(
                            isDragging ? Color.blue.opacity(0.7) : Color.gray.opacity(0.45),
                            style: style
                        )

                        // Đường orange
                        if isToday() {
                            let now      = nowMinute()
                            let sleepMin = events[windowIndex()].minutes
                            let segStart = events[i].minutes
                            let segEnd   = events[i + 1].minutes

                            if now > segStart && segStart < sleepMin {

                                let paintTo: CGFloat = {
                                    if now >= segStart && now <= segEnd {
                                        return nowY() ?? endY
                                    } else if now > segEnd {
                                        return endY
                                    }
                                    return startY
                                }()

                                if paintTo > startY {
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: startY))
                                        path.addLine(to: CGPoint(x: 0, y: paintTo))
                                    }
                                    .stroke(
                                        now < sleepMin
                                            ? Color.orange.opacity(0.6)
                                            : events[windowIndex()].color.opacity(0.7),
                                        style: style
                                    )
                                }
                            }
                        }
                    }
                }
                .shadow(
                    color: isDragging ? Color.blue.opacity(0.5) : .clear,
                    radius: 6
                )
                .animation(.easeInOut(duration: 0.2), value: isDragging)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Rise / Window

    func riseIndex() -> Int {
        events.firstIndex { $0.systemType == .wake } ?? 0
    }

    func windowIndex() -> Int {
        events.firstIndex { $0.systemType == .sleep } ?? events.count - 1
    }

    // MARK: Y Position

    func yPosition(for index: Int) -> CGFloat {

        var y: CGFloat = 0

        for i in 0..<index {

            y += TimelineLayoutEngine.eventHeight(events[i])

            if i < events.count - 1 {

                y += TimelineLayoutEngine.spacing(
                    current: events[i],
                    next: events[i + 1]
                )
            }
        }

        return y + TimelineLayoutEngine.eventHeight(events[index]) / 2
    }
}
