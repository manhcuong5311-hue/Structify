import SwiftUI

struct TimelineLineView: View {

    let events: [EventItem]
    let isDragging: Bool
    let date: Date

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
        return y + TimelineLayoutEngine.eventHeight(events[index]) / 2
    }

    func dashStyle(gapMinutes: Int, segmentHeight: CGFloat) -> StrokeStyle {
        let lineWidth: CGFloat = isDragging ? 3.5 : 2.5
        let ratio = CGFloat(min(max(gapMinutes, 0), 300)) / 300.0
        let dashLen = 6 + ratio * 10
        let gapLen  = 4 + ratio * 8
        return StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [dashLen, gapLen])
    }

    var body: some View {
        GeometryReader { _ in
            if events.count > 1 {
                let rise    = riseIndex()
                let window  = windowIndex()
                let indices = Array(rise..<window)

                ZStack(alignment: .topLeading) {
                    ForEach(indices, id: \.self) { i in
                        let startY     = yPosition(for: i)
                        let endY       = yPosition(for: i + 1)
                        let gapMinutes = events[i + 1].minutes - TimelineEngine.endMinute(events[i])
                        let segH       = endY - startY
                        let style      = dashStyle(gapMinutes: gapMinutes, segmentHeight: segH)

                        // ── Base line ──
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

                        // ── Progress line — chỉ today ──
                        if isToday() {
                            let now      = nowMinute()
                            let sleepMin = events[windowIndex()].minutes
                            let segStart = events[i].minutes
                            let segEnd   = events[i + 1].minutes

                            if now > segStart && segStart < sleepMin {
                                // 👇 Dùng TimelineLayoutEngine.nowY thay vì nowY() cũ
                                let paintTo: CGFloat = {
                                    if now >= segStart && now <= segEnd {
                                        return TimelineLayoutEngine.nowY(events: events)
                                    } else if now > segEnd {
                                        return endY
                                    }
                                    return startY
                                }()

                                if paintTo > startY {
                                    let eveningStart = 18 * 60
                                    let sleepColor = events[windowIndex()].color
                                    let orangeColor = Color(red: 1.0, green: 0.58, blue: 0.25)

                                    let eveningY: CGFloat = {
                                        if eveningStart >= segStart && eveningStart <= segEnd {
                                            // 18h nằm trong segment này → nội suy Y
                                            let p = CGFloat(eveningStart - segStart) / CGFloat(max(segEnd - segStart, 1))
                                            return startY + (endY - startY) * p
                                        } else if eveningStart > segEnd {
                                            // Toàn bộ segment nằm TRƯỚC 18h → line cam kéo hết endY
                                            return endY
                                        } else {
                                            // Toàn bộ segment nằm SAU 18h → line sleep color từ startY
                                            return startY
                                        }
                                    }()

                                    // ── Đoạn CAM: startY → min(eveningY, paintTo) ──
                                    if now <= eveningStart || startY < eveningY {
                                        let camEnd = min(eveningY, paintTo)
                                        if camEnd > startY {
                                            Path { p in
                                                p.move(to:    CGPoint(x: 0, y: startY))
                                                p.addLine(to: CGPoint(x: 0, y: camEnd))
                                            }
                                            .stroke(
                                                LinearGradient(
                                                    colors: [orangeColor.opacity(0.4), orangeColor.opacity(0.9)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                style: StrokeStyle(lineWidth: isDragging ? 4 : 3, lineCap: .round, dash: style.dash)
                                            )
                                        }
                                    }

                                    // ── Đoạn SLEEP COLOR: eveningY → paintTo ──
                                    if now > eveningStart && eveningY < paintTo {
                                        let nightStart = max(startY, eveningY)
                                        Path { p in
                                            p.move(to:    CGPoint(x: 0, y: nightStart))
                                            p.addLine(to: CGPoint(x: 0, y: paintTo))
                                        }
                                        .stroke(
                                            LinearGradient(
                                                colors: [sleepColor.opacity(0.5), sleepColor.opacity(0.9)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            style: StrokeStyle(lineWidth: isDragging ? 4 : 3, lineCap: .round, dash: style.dash)
                                        )
                                    }

                                    // ── Dot tại now ──
                                    let dotColor = now >= eveningStart ? sleepColor : orangeColor
                                    Circle()
                                        .fill(dotColor)
                                        .frame(width: 7, height: 7)
                                        .offset(x: -3.5, y: paintTo + 6)
                                        .shadow(color: dotColor.opacity(0.6), radius: 4, y: 0)
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
