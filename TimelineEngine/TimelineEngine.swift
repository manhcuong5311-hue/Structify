//
//  TimelineEvent.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI
import Foundation
import Combine

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



final class TimelineEngine: ObservableObject {

    @Published var events: [TimelineEvent] = []

    let calendar = Calendar.current

    // UI scale
    let pixelPerMinute: CGFloat = 1.2
    let snapMinutes: Int = 5
    
    let minMinute = 0
    let maxMinute = 1440
    
  
    
    
    func timelineHeight(startOfDay: Date) -> CGFloat {

        CGFloat(
            timelineEndMinute(startOfDay: startOfDay)
            -
            timelineStartMinute(startOfDay: startOfDay)
        ) * pixelPerMinute
    }
    
    func timelineStartMinute(startOfDay: Date) -> Int {
        max(minEventMinute(startOfDay: startOfDay) - 60, 0)
    }

    func timelineEndMinute(startOfDay: Date) -> Int {
        min(maxEventMinute(startOfDay: startOfDay) + 60, 1440)
    }
    
    
    
    func minEventMinute(startOfDay: Date) -> Int {

        guard let first = events.min(by: { $0.start < $1.start }) else { return 0 }

        return calendar.dateComponents(
            [.minute],
            from: startOfDay,
            to: first.start
        ).minute ?? 0
    }

    func maxEventMinute(startOfDay: Date) -> Int {

        guard let last = events.max(by: { $0.end < $1.end }) else { return 1440 }

        return calendar.dateComponents(
            [.minute],
            from: startOfDay,
            to: last.end
        ).minute ?? 1440
    }
    
    func timeString(from offset: CGFloat, startOfDay: Date) -> String {

        let minutes = Int(offset / pixelPerMinute)

        let date = calendar.date(
            byAdding: .minute,
            value: minutes,
            to: startOfDay
        )!

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        return formatter.string(from: date)
    }
    
    
    
    func snap(_ minutes: Int) -> Int {
          
          let step = Double(snapMinutes)
          
          return Int((Double(minutes) / step).rounded() * step)
      }

    // MARK: - Position

    func yPosition(for event: TimelineEvent, startOfDay: Date) -> CGFloat {

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
        Int((Double(minutes) / Double(snapMinutes)).rounded()) * snapMinutes
    }

    // MARK: - Update Event

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
                y: engine.yPosition(for: event, startOfDay: startOfDay) + dragOffset
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

struct TimelineSpine: View {

    var body: some View {

        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }
}

struct TimelineContainer: View {

    @ObservedObject var engine: TimelineEngine

    let startOfDay: Date

    var eventsLayer: some View {

        ZStack(alignment: .topLeading) {

            ForEach(Array(engine.events.enumerated()), id: \.element.id) { index, event in

                let event = engine.events[index]

                TimelineEventView(
                    event: event,
                    isLocked: index == 0 || index == engine.events.count - 1,
                    engine: engine,
                    startOfDay: startOfDay
                )
                .padding(.leading, 40)

                if index < engine.events.count - 1 {

                    let next = engine.events[index + 1]

                    let gap = engine.gapMinutes(
                        between: event,
                        and: next
                    )

                    if gap > 15 {

                        Text("Trống \(gap) phút")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 50)
                            .offset(
                                y: engine.yPosition(for: event, startOfDay: startOfDay)
                                + engine.height(for: event)
                                + 8
                            )
                    }
                }
            }
        }
    }
    
    
    var body: some View {

        HStack(alignment: .top, spacing: 0) {

            TimeColumn(
                engine: engine,
                startOfDay: startOfDay
            )
            ZStack(alignment: .topLeading) {

                TimelineSpine()
                    .padding(.leading, 20)

                eventsLayer
            }
        }
        .frame(height: engine.timelineHeight(startOfDay: startOfDay))
    }
}

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
                        y: CGFloat(hour * 60 - engine.timelineStartMinute(startOfDay: startOfDay))
                        * engine.pixelPerMinute
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


