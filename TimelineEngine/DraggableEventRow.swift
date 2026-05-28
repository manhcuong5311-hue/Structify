import SwiftUI

struct DraggableEventRow: View {

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @State private var visibleEventsBinding: [EventItem] = []
    @Binding var event: EventItem

    let index: Int

    @Binding var events: [EventItem]
    @Binding var isDragging: Bool
    var isNearNowIndicator: Bool = false
    var isNowApproachingStart: Bool = false
    let isLocked: Bool
    var onDragEnded: () -> Void
    var onTapEvent: (EventItem) -> Void
    var onResizeCommit: ((UUID, Int) -> Void)?
    var onResizeComplete: (() -> Void)? = nil


    @State private var dragOffsetY: CGFloat = 0
    @State private var dragOffsetX: CGFloat = 0
    @State private var isHolding = false
    @State private var isReordering = false
    @State private var lastSwapIndex: Int = -1
    @State private var lastSwapTime: Date = .distantPast
    private let swapHaptic = UIImpactFeedbackGenerator(style: .rigid)

    @State private var morningTriggered = false
    @State private var nightTriggered = false

    @State private var didSnapMorning = false
    @State private var didSnapNight = false
    @State private var lastHapticMinute: Int = -1
    @State private var nearSwapTarget = false

    @State private var isResizingStart = false
    @State private var isResizingEnd = false

    @State private var durationPreview: String? = nil
    @State private var resizeBaseDuration: Int?

    @State private var isCompleted = false

    func syncCompletion() {

        let date = calendar.selectedDate
        let id = event.id

        let completed = store.isCompleted(
            templateID: id,
            date: date
        )

        if completed != isCompleted {
            isCompleted = completed
        }
    }


    func recurrenceLabel(for event: EventItem) -> String {
        guard let t = store.templates.first(where: { $0.id == event.id }) else {
            return String(localized: "recurrence_habit")
        }

        switch t.recurrence {
        case .daily:
            return String(localized: "recurrence_daily")

        case .weekdays:
            return String(localized: "recurrence_weekdays")

        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            return days.sorted().map { s[$0-1] }.joined(separator: ", ")

        case .once:
            return String(localized: "recurrence_once")

        case .dateRange(let start, let end):
            let cal = Calendar.current
            let days = cal.dateComponents([.day], from: start, to: end).day ?? 0

            if days <= 6 {
                return String(localized: "recurrence_week")
            }

            if days <= 31 {
                return String(localized: "recurrence_month")
            }

            let f = DateFormatter()
            f.dateFormat = "d MMM"

            return String(
                localized: "recurrence_range \(f.string(from: start))–\(f.string(from: end))"
            )
        }
    }


    func isPastEvent() -> Bool {
        guard Calendar.current.isDateInToday(calendar.selectedDate) else {
            return false
        }
        let now = TimelineEngine.currentMinutes()
        if let duration = event.duration {
            return event.minutes + duration < now
        }
        return event.minutes < now
    }


    func isCurrentEvent() -> Bool {
        let now = TimelineEngine.currentMinutes()
        let start = event.minutes
        let end = event.minutes + (event.duration ?? 0)
        return now >= start && now <= end
    }


    func commitSwap() {
        guard !isLocked else { return }
        let nowMin = TimelineEngine.currentMinutes()
        let isToday = Calendar.current.isDateInToday(calendar.selectedDate)

        for e in events {
            guard !e.isSystemEvent else { continue }

            if isToday {
                let endMin = e.minutes + (e.duration ?? 0)
                if endMin < nowMin { continue }
                if e.minutes < nowMin && e.duration == nil { continue }
                if let d = e.duration, e.minutes <= nowMin && e.minutes + d >= nowMin { continue }
            }

            store.overrideEvent(
                templateID: e.id,
                date: calendar.selectedDate,
                minutes: e.minutes,
                ignoreOverlap: true
            )
        }
    }

    func isEventLocked(_ e: EventItem) -> Bool {
        guard !e.isSystemEvent else { return true }
        guard Calendar.current.isDateInToday(calendar.selectedDate) else { return false }
        let now = TimelineEngine.currentMinutes()
        if let d = e.duration {
            return e.minutes + d <= now
        }
        return e.minutes < now
    }


    func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60

        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }

    // Apply magnetic snaps: neighbor end-time + hourly marks.
    // Returns adjusted minutes; caller writes back to event.
    private func applyMagneticSnap(_ minutes: Int) -> Int {
        var result = minutes
        let pullRadius = 8     // magnet activation radius (min)
        let neighborGap = 5    // preferred gap after prev event (min)

        // 1. Snap to previous event's end + gap
        let prevCandidates = events
            .filter { $0.id != event.id && !$0.isSystemEvent }
            .sorted { $0.minutes < $1.minutes }
        if let prev = prevCandidates.last(where: {
            ($0.minutes + ($0.duration ?? 0)) <= minutes + pullRadius
        }) {
            let target = prev.minutes + (prev.duration ?? 0) + neighborGap
            if abs(result - target) < pullRadius {
                result = target
            }
        }

        // 2. Hourly soft snap (every :00) within ±5 min
        let hourMins = (result / 60) * 60
        let distDown = result - hourMins
        let distUp = 60 - distDown
        if distDown < 5 {
            result = hourMins
        } else if distUp < 5 {
            result = hourMins + 60
        }

        return result
    }

    // Tick haptic per 15-min boundary crossing.
    private func tickHapticIfNeeded(minutes: Int) {
        let step = minutes / 15
        if step != lastHapticMinute {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            lastHapticMinute = step
        }
    }


    var body: some View {

        TimelineEventRow(
            time: event.time,
            endTime: event.endTime,
            title: event.title.localized,
            icon: event.icon,
            color: event.color,
            kind: event.kind,
            isHolding: isHolding && !event.isSystemEvent,
            hasDuration: event.duration != nil,
            durationMinutes: event.duration,
            isNearNowIndicator: isNearNowIndicator,
            isNowApproachingStart: isNowApproachingStart,
            nearSwapTarget: nearSwapTarget,
            durationPreview: durationPreview,
            startMinutes: event.minutes,
            isCompleted: isCompleted,
            isSystemEvent: event.isSystemEvent,
            recurrenceLabel: recurrenceLabel(for: event),

            progressFraction: {
                let t = store.templates.first { $0.id == event.id }
                guard t?.habitType == .accumulative,
                      let target = t?.targetValue, target > 0 else { return 0 }
                let val = store.accumulationValue(templateID: event.id, date: calendar.selectedDate)
                return CGFloat(min(val / target, 1))
            }(),
            incrementValue: store.templates.first { $0.id == event.id }?.increment ?? 1,

            onToggleComplete: {
                let isHabit = event.kind == .habit
                let isToday = Calendar.current.isDateInToday(calendar.selectedDate)

                if isHabit {
                    guard isToday || !isLocked else { return }
                } else {
                    guard !isLocked else { return }
                }

                let template = store.templates.first { $0.id == event.id }

                if template?.habitType == .accumulative {
                    guard !store.isCompleted(templateID: event.id, date: calendar.selectedDate) else { return }
                    let increment = store.templates.first { $0.id == event.id }?.increment ?? 1.0
                    store.incrementAccumulation(
                        templateID: event.id,
                        date: calendar.selectedDate,
                        by: increment
                    )
                } else {
                    store.toggleCompletion(
                        templateID: event.id,
                        date: calendar.selectedDate
                    )
                }

                let nowCompleted = store.isCompleted(templateID: event.id, date: calendar.selectedDate)

                if nowCompleted {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else if template?.habitType == .accumulative {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isCompleted = nowCompleted
                }
            },

            onTap: {
                if !event.isSystemEvent {
                    onTapEvent(event)
                }
            }, onDragChanged: { value in


                isDragging = true
                dragOffsetY = value.translation.height

                let newMinutes = TimelineEngine.move(
                    event: event,
                    index: index,
                    events: events,
                    translation: value.translation.height
                )

                let raw = min(max(newMinutes, 0), 1440)
                let snapped = applyMagneticSnap(raw)

                if snapped != event.minutes {
                    event.update(minutes: snapped)
                    tickHapticIfNeeded(minutes: snapped)
                }


                let minutes = event.minutes
                let morningStart = 6 * 60
                let nightStart = 22 * 60
                let snapRange = 12

                if abs(minutes - morningStart) < snapRange && !didSnapMorning {
                    event.update(minutes: morningStart)
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    didSnapMorning = true
                }

                if abs(minutes - morningStart) > snapRange {
                    didSnapMorning = false
                }

                if abs(minutes - nightStart) < snapRange && !didSnapNight {
                    event.update(minutes: nightStart)
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    didSnapNight = true
                }

                if abs(minutes - nightStart) > snapRange {
                    didSnapNight = false
                }

            }, onDragEnded: {

                dragOffsetY = 0
                isDragging = false

                morningTriggered = false
                nightTriggered = false

                didSnapMorning = false
                didSnapNight = false

                durationPreview = nil

                onDragEnded()
            },onResizeEnd: { translation in

                guard let duration = event.duration else { return }

                if resizeBaseDuration == nil {
                    resizeBaseDuration = duration
                }

                guard let base = resizeBaseDuration else { return }

                let minuteDelta = Int(translation / 12)

                let raw = base + minuteDelta

                let snapped = max(5, (raw / 5) * 5)

                let step = snapped / 5
                if step != lastHapticMinute {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    lastHapticMinute = step
                }

                event.duration = snapped
                durationPreview = formatDuration(snapped)

                onResizeCommit?(event.id, snapped)
            },

            onResizeFinal: { _ in
                durationPreview = nil
                resizeBaseDuration = nil
                lastHapticMinute = -1
                isDragging = false
                isHolding = false
                onResizeComplete?()
            },

            isLocked: isLocked,
            isToday: Calendar.current.isDateInToday(calendar.selectedDate)

        )
        .opacity(isDragging && !isHolding ? 0.5 : 1)
        .frame(height: TimelineLayoutEngine.eventHeight(event))
        .fixedSize(horizontal: false, vertical: true)
        .offset(x: dragOffsetX, y: dragOffsetY)
        .shadow(
            color: .black.opacity(isHolding ? 0.28 : 0),
            radius: isHolding ? 18 : 0,
            y: isHolding ? 10 : 0
        )
        .scaleEffect(isHolding ? 1.05 : 1)
        .zIndex(isHolding ? 100 : 0)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isHolding)
        .sensoryFeedback(.impact(weight: .medium), trigger: isHolding)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in

                    guard !isLocked else { return }

                    guard !isCurrentEvent() else { return }

                    guard !isPastEvent() else { return }

                    swapHaptic.prepare()

                    withAnimation(.spring()) {
                        isHolding = true
                    }

                    UIImpactFeedbackGenerator(style:.medium).impactOccurred()
                }
        )

        .gesture(
            (isLocked || isPastEvent())
            ? nil
            : (event.isSystemEvent && !isHolding
               ? nil
               : DragGesture())

            .onChanged { value in

                if event.isSystemEvent && !isHolding {
                    return
                }

                if event.originalMinutes == nil {
                    event.originalMinutes = event.minutes
                }

                if event.isSystemEvent {


                    isDragging = true

                    let newMinutes = TimelineEngine.move(
                        event: event,
                        index: index,
                        events: events,
                        translation: value.translation.height
                    )

                    let clamped = max(0, min(newMinutes, 1440))
                    event.update(minutes: clamped)

                    if let liveIdx = events.firstIndex(where: { $0.id == event.id }) {
                        TimelineEngine.autoPush(
                            events: &events,
                            movedIndex: liveIdx
                        )
                    }

                    let step = clamped / 5

                    if step != lastHapticMinute {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        lastHapticMinute = step
                    }

                    return
                }
                guard isHolding else { return }

                isDragging = true

                dragOffsetX = max(0, value.translation.width)
                dragOffsetY = value.translation.height

                // Reorder mode entered when user drags right past threshold.
                // Until then, vertical drag just adjusts time (with neighbor clamping).
                if dragOffsetX > 65 {
                    isReordering = true
                }

                if abs(dragOffsetY) > 80 {
                    nearSwapTarget = true
                } else {
                    nearSwapTarget = false
                }


                if isReordering {

                    let swapThreshold: CGFloat = 75
                    let resetThreshold: CGFloat = 20
                    let cooldown: TimeInterval = 0.15
                    let dragY = dragOffsetY
                    let now = Date()

                    guard now.timeIntervalSince(lastSwapTime) > cooldown else { return }

                    guard let liveIdx = events.firstIndex(where: { $0.id == event.id }) else { return }

                    if dragY > swapThreshold && liveIdx < events.count - 1 {
                        let next = liveIdx + 1
                        let target = events[next]

                        if !isEventLocked(target) && lastSwapIndex != next {
                            lastSwapIndex = next
                            lastSwapTime = now

                            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                                let aMin = events[liveIdx].minutes
                                let bMin = events[next].minutes

                                let newA = min(aMin, bMin)
                                let newB = max(aMin, bMin)

                                events[liveIdx].update(minutes: newB)
                                events[next].update(minutes: newA)

                                events.sort { $0.minutes < $1.minutes }
                            }

                            commitSwap()
                            swapHaptic.impactOccurred()

                            DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                                lastSwapIndex = -1
                            }
                        }
                    }

                    if dragY < -swapThreshold && liveIdx > 0 {
                        let prev = liveIdx - 1
                        let target = events[prev]

                        if !isEventLocked(target) && lastSwapIndex != prev {
                            lastSwapIndex = prev
                            lastSwapTime = now

                            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                                let aMin = events[prev].minutes
                                let bMin = events[liveIdx].minutes

                                let newA = min(aMin, bMin)
                                let newB = max(aMin, bMin)

                                events[prev].update(minutes: newB)
                                events[liveIdx].update(minutes: newA)

                                events.sort { $0.minutes < $1.minutes }
                            }

                            commitSwap()
                            swapHaptic.impactOccurred()

                            DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                                lastSwapIndex = -1
                            }
                        }
                    }

                    if abs(dragY) < resetThreshold {
                        lastSwapIndex = -1
                    }
                } else {

                    let rawMinutes = TimelineEngine.move(
                        event: event,
                        index: index,
                        events: events,
                        translation: value.translation.height
                    )

                    let now = TimelineEngine.currentMinutes()

                    if event.minutes > now && rawMinutes < now {

                        UINotificationFeedbackGenerator().notificationOccurred(.warning)

                        NotificationCenter.default.post(
                            name: Notification.Name("timelineNowBlock"),
                            object: nil
                        )

                        return
                    }

                    let snapped = applyMagneticSnap(max(0, min(rawMinutes, 1440)))
                    if snapped != event.minutes {
                        event.update(minutes: snapped)
                        tickHapticIfNeeded(minutes: snapped)
                    }
                }
            }
                .onEnded { value in

                    event.originalMinutes = nil

                    let predicted = value.predictedEndTranslation.height

                    let newMinutes = TimelineEngine.move(
                        event: event,
                        index: index,
                        events: events,
                        translation: predicted
                    )

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        event.update(minutes: min(max(newMinutes,0),1440))
                    }

                    dragOffsetX = 0
                    dragOffsetY = 0
                    isHolding = false
                    isReordering = false
                    isDragging = false
                    lastSwapIndex = -1
                    resizeBaseDuration = nil
                    lastHapticMinute = -1



                    onDragEnded()
                }
        )
        .onAppear {
            syncCompletion()
        }


        .onChange(of: calendar.selectedDate) { _, _ in
            DispatchQueue.main.async {
                syncCompletion()
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .cancelTimelineHold)) { _ in

            if isHolding {

                withAnimation(.spring(response:0.25,dampingFraction:0.85)) {
                    isHolding = false
                    isReordering = false
                    dragOffsetX = 0
                    dragOffsetY = 0
                }
            }
        }

    }

}
