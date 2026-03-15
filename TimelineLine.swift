import SwiftUI

struct TimelineLineView: View {

    let events: [EventItem]
    let isDragging: Bool
    let date: Date

    // MARK: - Helpers

    func nowMinute() -> Int {
        let c = Calendar.current
        return c.component(.hour, from: Date()) * 60 + c.component(.minute, from: Date())
    }

    func isToday() -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func riseIndex() -> Int {
        events.firstIndex { $0.systemType == .wake } ?? 0
    }

    func windowIndex() -> Int {
        events.firstIndex { $0.systemType == .sleep } ?? events.count - 1
    }

    func yPosition(for index: Int) -> CGFloat {
        var y: CGFloat = 0
        for i in 0..<index {
            let h = TimelineLayoutEngine.eventHeight(events[i])
            y += h
            if i < events.count - 1 {
                y += TimelineLayoutEngine.spacing(
                    current: events[i],
                    next: events[i + 1]
                )
            }
        }
        // Cộng thêm nửa chiều cao event hiện tại để lấy center
        return y + TimelineLayoutEngine.eventHeight(events[index]) / 2
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
                let p = CGFloat(now - eventStart) / CGFloat(max(eventEnd - eventStart, 1))
                return thisTopY + thisH * p
            }
            if now > eventEnd && now < nextStart {
                let p = CGFloat(now - eventEnd) / CGFloat(max(nextStart - eventEnd, 1))
                return thisBottomY + (nextTopY - thisBottomY) * p
            }
        }
        return nil
    }

    // MARK: - Dash style dựa trên gap time
    func dashStyle(gapMinutes: Int, segmentHeight: CGFloat) -> StrokeStyle {
        let lineWidth: CGFloat = isDragging ? 3.5 : 2.5  // đậm hơn

        let ratio = CGFloat(min(max(gapMinutes, 0), 300)) / 300.0

        // Gap lớn: dash=16, space=12 → thoáng rõ
        // Gap nhỏ: dash=6, space=4 → dày đặc
        let dashLen = 6 + ratio * 10   // 6...16
        let gapLen  = 4 + ratio * 8    // 4...12

        return StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            dash: [dashLen, gapLen]
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { _ in
            if events.count > 1 {
                let rise   = riseIndex()
                let window = windowIndex()
                let indices = Array(rise..<window)

                ZStack(alignment: .topLeading) {
                    ForEach(indices, id: \.self) { i in
                        let startY      = yPosition(for: i)
                        let endY        = yPosition(for: i + 1)
                        let gapMinutes  = events[i + 1].minutes - TimelineEngine.endMinute(events[i])
                        let segH        = endY - startY
                        let style       = dashStyle(gapMinutes: gapMinutes, segmentHeight: segH)

                        // ── Base line (gray mờ) ──
                        Path { p in
                            p.move(to:    CGPoint(x: 0, y: startY))
                            p.addLine(to: CGPoint(x: 0, y: endY))
                        }
                        .stroke(
                            isDragging
                                ? Color.blue.opacity(0.5)
                                : Color.primary.opacity(0.14),
                            style: style
                        )

                        // ── Progress line (orange) — chỉ today ──
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
                                    Path { p in
                                        p.move(to:    CGPoint(x: 0, y: startY))
                                        p.addLine(to: CGPoint(x: 0, y: paintTo))
                                    }
                                    .stroke(
                                        // Sau sleep → dùng màu sleep event, trước đó → orange ấm
                                        now < sleepMin
                                            ? Color(red: 1.0, green: 0.58, blue: 0.25).opacity(0.75)
                                            : events[windowIndex()].color.opacity(0.6),
                                        style: style
                                    )
                                }
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isDragging)
            }
        }
        .allowsHitTesting(false)
    }
}
