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
        let end   = events[index + 1].minutes
        return now >= start && now <= end
    }
    
    func nowMinute() -> Int {

        let cal = Calendar.current
        let now = Date()

        return cal.component(.hour, from: now) * 60 +
               cal.component(.minute, from: now)
    }
    
    func nowY() -> CGFloat? {

        let now = nowMinute()

        for i in 0..<events.count-1 {

            let start = events[i].minutes
            let end   = events[i+1].minutes

            if now >= start && now <= end {

                let startY = yPosition(for: i)
                let endY   = yPosition(for: i+1)

                let progress =
                CGFloat(now - start) / CGFloat(max(end - start,1))

                return startY + (endY - startY) * progress
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

                ZStack(alignment: .topLeading) {

                    ForEach(rise..<window, id: \.self) { i in

                        let startY = yPosition(for: i)
                        let endY   = yPosition(for: i + 1)

                        let minutesGap =
                        events[i + 1].minutes - TimelineEngine.endMinute(events[i])

                        let segmentHeight = endY - startY

                        let pixelsPerMinute =
                        segmentHeight / CGFloat(max(minutesGap,1))

                        // GAP DYNAMIC
                        let dashLength =
                        max(4, pixelsPerMinute * 8)

                        let gapLength =
                        max(4, pixelsPerMinute * 5)

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: startY))
                            path.addLine(to: CGPoint(x: 0, y: endY))
                        }
                        .stroke(
                            isDragging
                            ? Color.blue.opacity(0.7)
                            : Color.gray.opacity(0.45),
                            style: StrokeStyle(
                                lineWidth: isDragging ? 4 : 3,
                                lineCap: .round,
                                dash: [dashLength, gapLength]
                            )
                        )
                        if isToday() && isPastOrCurrentSegment(i) {

                            let end = isCurrentSegment(i) ? (nowY() ?? endY) : endY
                            let sleepMinute = events[windowIndex()].minutes
                            let now = nowMinute()

                            let progressColor: Color =
                                now < sleepMinute
                                ? Color.orange.opacity(0.6)
                                : events[windowIndex()].color.opacity(0.7)

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: startY))
                                path.addLine(to: CGPoint(x: 0, y: end))
                            }
                            .stroke(
                                progressColor,
                                style: StrokeStyle(
                                    lineWidth: isDragging ? 4 : 3,
                                    lineCap: .round,
                                    dash: [dashLength, gapLength]
                                )
                            )
                        }
                        
                    }
                    
                    
                    
                    
                }
                .shadow(
                    color: isDragging
                    ? Color.blue.opacity(0.5)
                    : .clear,
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
