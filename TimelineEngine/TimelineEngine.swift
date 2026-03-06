//
//  TimelineEvent.swift
//  Structify
//

import SwiftUI
import Combine

// MARK: - MODEL

struct TimelineEvent: Identifiable, Equatable {

    let id: UUID
    var title: String

    var start: Date
    var end: Date

    var color: String

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}







// MARK: - ENGINE

final class TimelineEngine: ObservableObject {

    @Published var events: [TimelineEvent] = []

    let calendar = Calendar.current

    // UI scale
    let pixelPerMinute: CGFloat = 1.2
    let snapMinutes: Int = 5

    let minMinute = 0
    let maxMinute = 1440

    // MARK: - Timeline Range

    func timelineStartMinute(startOfDay: Date) -> Int {
        max(minEventMinute(startOfDay: startOfDay) - 60, minMinute)
    }

    func timelineEndMinute(startOfDay: Date) -> Int {
        min(maxEventMinute(startOfDay: startOfDay) + 60, maxMinute)
    }

    func timelineHeight(startOfDay: Date) -> CGFloat {

        CGFloat(
            timelineEndMinute(startOfDay: startOfDay)
            -
            timelineStartMinute(startOfDay: startOfDay)
        ) * pixelPerMinute
    }

    // MARK: - Event Bounds

    func minEventMinute(startOfDay: Date) -> Int {

        guard let first = events.min(by: { $0.start < $1.start }) else {
            return 0
        }

        return calendar.dateComponents(
            [.minute],
            from: startOfDay,
            to: first.start
        ).minute ?? 0
    }

    func maxEventMinute(startOfDay: Date) -> Int {

        guard let last = events.max(by: { $0.end < $1.end }) else {
            return 1440
        }

        return calendar.dateComponents(
            [.minute],
            from: startOfDay,
            to: last.end
        ).minute ?? 1440
    }







    // MARK: - Layout

    func yPosition(
        for event: TimelineEvent,
        startOfDay: Date
    ) -> CGFloat {

        let minutes = calendar.dateComponents(
            [.minute],
            from: startOfDay,
            to: event.start
        ).minute ?? 0

        return CGFloat(
            minutes - timelineStartMinute(startOfDay: startOfDay)
        ) * pixelPerMinute
    }

    func height(for event: TimelineEvent) -> CGFloat {
        CGFloat(event.durationMinutes) * pixelPerMinute
    }







    // MARK: - Snap

    func snapMinutesValue(_ minutes: Int) -> Int {

        Int(
            (Double(minutes) / Double(snapMinutes)).rounded()
        ) * snapMinutes
    }







    // MARK: - Move Event

    func moveEvent(
        _ event: TimelineEvent,
        dragOffset: CGFloat,
        startOfDay: Date
    ) {

        guard let index = events.firstIndex(of: event) else { return }

        let minuteDelta = Int(dragOffset / pixelPerMinute)

        let snapped = snapMinutesValue(minuteDelta)

        var newStart = calendar.date(
            byAdding: .minute,
            value: snapped,
            to: event.start
        ) ?? event.start

        let minutesFromStart = calendar.dateComponents(
            [.minute],
            from: startOfDay,
            to: newStart
        ).minute ?? 0

        let clamped = min(max(minutesFromStart, minMinute), maxMinute)

        newStart = calendar.date(
            byAdding: .minute,
            value: clamped,
            to: startOfDay
        )!

        let newEnd = calendar.date(
            byAdding: .minute,
            value: event.durationMinutes,
            to: newStart
        )!

        events[index].start = newStart
        events[index].end = newEnd
    }







    // MARK: - Gap

    func gapMinutes(
        between first: TimelineEvent,
        and second: TimelineEvent
    ) -> Int {

        let minutes = calendar.dateComponents(
            [.minute],
            from: first.end,
            to: second.start
        ).minute ?? 0

        return max(minutes, 0)
    }
}







// MARK: - EVENT VIEW

struct TimelineEventView: View {

    let event: TimelineEvent
    let isLocked: Bool

    @ObservedObject var engine: TimelineEngine
    let startOfDay: Date

    @State private var dragOffset: CGFloat = 0

    var body: some View {

        RoundedRectangle(cornerRadius: 24)
            .fill(Color.blue.opacity(0.2))
            .overlay(
                Text(event.title)
                    .font(.headline)
                    .padding(),
                alignment: .topLeading
            )
            .frame(height: engine.height(for: event))
            .offset(
                y: engine.yPosition(
                    for: event,
                    startOfDay: startOfDay
                ) + dragOffset
            )
            .allowsHitTesting(!isLocked)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isLocked else { return }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in

                        guard !isLocked else { return }

                        engine.moveEvent(
                            event,
                            dragOffset: value.translation.height,
                            startOfDay: startOfDay
                        )

                        dragOffset = 0
                    }
            )
            .animation(.spring(), value: dragOffset)
    }
}







// MARK: - TIMELINE SPINE

struct TimelineSpine: View {

    var body: some View {

        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }
}







// MARK: - CONTAINER

struct TimelineContainer: View {

    @ObservedObject var engine: TimelineEngine
    let startOfDay: Date

    var body: some View {

        HStack(alignment: .top, spacing: 0) {

            TimeColumn(engine: engine, startOfDay: startOfDay)

            ZStack(alignment: .topLeading) {

                TimelineSpine()
                    .padding(.leading, 24)

                VStack(alignment: .leading, spacing: 0) {

                    ForEach(Array(engine.events.enumerated()), id: \.element.id) { index, event in

                        TimelineRow(
                            event: event,
                            engine: engine,
                            startOfDay: startOfDay
                        )

                        if index < engine.events.count - 1 {

                            let next = engine.events[index + 1]

                            let gap = engine.gapMinutes(
                                between: event,
                                and: next
                            )

                            if gap > 10 {

                                TimelineGapRow(
                                    gapMinutes: gap
                                )
                            }
                        }
                    }
                }
                .padding(.leading, 40)
            }
        }
    }
}

struct TimelineRow: View {

    let event: TimelineEvent
    let engine: TimelineEngine
    let startOfDay: Date

    var timeString: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.start)
    }

    var eventColor: Color {
        event.color == "orange" ? .orange : .blue
    }

    var body: some View {

        HStack(alignment: .top, spacing: 16) {

            Text(timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            ZStack {

                Circle()
                    .fill(eventColor.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: "alarm.fill")
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(event.title)
                    .font(.headline)

                Text(timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 28, height: 28)
        }
        .padding(.vertical, 12)
    }
}

struct TimelineGapRow: View {

    let gapMinutes: Int

    var body: some View {

        HStack(spacing: 16) {

            Text("")
                .frame(width: 60)

            Image(systemName: "clock")
                .foregroundStyle(.gray)

            Text("Nghỉ nhanh \(gapMinutes)ph để thêm sáng tạo.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 18)
    }
}



// MARK: - TIME COLUMN

struct TimeColumn: View {

    @ObservedObject var engine: TimelineEngine
    let startOfDay: Date

    var startHour: Int {
        engine.timelineStartMinute(startOfDay: startOfDay) / 60
    }

    var endHour: Int {
        engine.timelineEndMinute(startOfDay: startOfDay) / 60
    }

    var body: some View {

        ZStack(alignment: .topTrailing) {

            ForEach(startHour...endHour, id: \.self) { hour in

                Text(String(format: "%02d:00", hour))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(
                        y: CGFloat(
                            hour * 60
                            -
                            engine.timelineStartMinute(startOfDay: startOfDay)
                        ) * engine.pixelPerMinute
                    )
            }
        }
        .frame(width: 60)
        .frame(
            height: engine.timelineHeight(startOfDay: startOfDay),
            alignment: .top
        )
    }
}
