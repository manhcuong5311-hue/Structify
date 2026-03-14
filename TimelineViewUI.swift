



import SwiftUI
import Combine

extension Notification.Name {
    static let cancelTimelineHold = Notification.Name("cancelTimelineHold")
}




struct TimelineView: View {

    @EnvironmentObject var store: TimelineStore

    @State private var addButtonsIndex: Int?
    @State private var isDragging = false

    @State private var activeSheet: AppSheet?
    @State private var showHabitSheet = false
    @State private var showEventSheet = false
    
    @State private var activeAlert: AppAlert?
    
    @State private var events: [EventItem] = []

    @EnvironmentObject var calendar: CalendarState
    
    @Environment(\.colorScheme) private var scheme
    
    @State private var pendingSystemChange: EventItem?
    @State private var pendingMinutes: Int = 0
    
    @State private var timer =
    Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var now = TimelineEngine.currentMinutes()
    
    @State private var showNowBlockAlert = false
    
    
    
    func isRecurring(_ event: EventItem) -> Bool {
        guard let t = store.templates.first(where: { $0.id == event.id }) else { return false }
        switch t.recurrence {
        case .once: return false
        default:    return true
        }
    }

    func recurringMessage(_ event: EventItem) -> String {
        guard let t = store.templates.first(where: { $0.id == event.id }) else { return "" }
        switch t.recurrence {
        case .daily:    return "This event repeats every day."
        case .weekdays: return "This event repeats Mon–Fri."
        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            return "Repeats on " + days.sorted().map { s[$0-1] }.joined(separator: ", ")
        case .once: return ""
        }
    }
    
    
    func isPastDate() -> Bool {

        let today = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: calendar.selectedDate)

        return selected < today
    }
    
    func reloadTimeline() {
        // Disable animation khi reload hoàn toàn
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            events = store.events(for: calendar.selectedDate)
        }
        addButtonsIndex = bestGapIndex()
    }
   
    func bestGapIndex() -> Int? {
        guard events.count > 1 else { return nil }

        let nowMinutes = TimelineEngine.currentMinutes()
        let isToday = Calendar.current.isDateInToday(calendar.selectedDate)

        var largestGap = 0
        var index: Int? = nil

        for i in 0..<(events.count - 1) {
            let gapStart = TimelineEngine.endMinute(events[i])
            let gapEnd   = events[i + 1].minutes
            let gap      = gapEnd - gapStart

            // Nếu là today → chỉ xét gap bắt đầu sau now
            if isToday && gapStart < nowMinutes { continue }

            if gap > largestGap {
                largestGap = gap
                index = i
            }
        }

        return index
    }
    
    func nowTimeString() -> String {
        TimelineEngine.formatTime(now)
    }
    
    func eventCenterY(_ index: Int) -> CGFloat {

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
    
    func indicatorTouchesEvent(_ index: Int) -> Bool {

        let now = self.now

        guard let nearest = events.enumerated()
            .min(by: { abs($0.element.minutes - now) < abs($1.element.minutes - now) })
            else { return false }

        return nearest.offset == index &&
               abs(nearest.element.minutes - now) <= 5
    }
    
    // Thêm helper binding theo id
    func eventBinding(for id: UUID) -> Binding<EventItem>? {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return nil }
        return $events[index]
    }
    
    func gapMessage(for index: Int) -> String? {
        guard events.indices.contains(index),
              events.indices.contains(index + 1) else { return nil }

        let current = events[index]
        let next = events[index + 1]
        let gapMinutes = next.minutes - TimelineEngine.endMinute(current)

        switch gapMinutes {
        case ..<60:
            return nil
        case 60..<120:
            return "A little gap — sneak something in? 🌿"
        case 120..<240:
            return "2 hours of untapped potential ✦"
        case 240..<360:
            return "4 hours? That's a side project waiting to happen 🚀"
        case 360..<480:
            return "Half a workday just sitting there... 👀"
        case 480..<600:
            return "8 whole hours. No excuses now ⚡"
        case 600..<720:
            return "10 hours of pure possibility 🔥"
        case 720..<840:
            return "Half a day with zero plans. Bold move 🎲"
        case 840..<960:
            return "14 hours free. Are you even trying? 😂"
        case 960...:
            return "The entire day is a blank canvas 🌍"
        default:
            return nil
        }
    }
    
    
    
    
    
    
    
    var body: some View {

        
        
        ScrollView {

            VStack(alignment: .leading, spacing: 0) {

                let allDayEvents = events.filter { $0.duration == 1440 }

                // ALL DAY ROW
                if !allDayEvents.isEmpty {
                    AllDayEventsRow(events: allDayEvents) { event in
                        activeSheet = .eventDetail(event)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                // Spacer NẰM NGOÀI VStack có line — line không biết về khoảng này
                Spacer().frame(height: allDayEvents.isEmpty ? 30 : 8)

                // VStack này bắt đầu ĐÚNG tại Morning Start
                // → line.yPosition(for: 0) khớp chính xác với Morning Start
                let visibleEvents = events.filter { $0.duration != 1440 }

                VStack(alignment: .leading, spacing: 0) {

                    ForEach(visibleEvents) { event in

                        let eventID = event.id

                        if events.contains(where: { $0.id == eventID }),
                           let safeBinding = Binding<Any>.safe($events, id: eventID),
                           let index = events.firstIndex(where: { $0.id == eventID }) {

                            DraggableEventRow(
                                event: safeBinding,
                                index: index,
                                events: $events,
                                isDragging: $isDragging,
                                isNearNowIndicator: indicatorTouchesEvent(index),
                                isLocked: isPastDate(),
                                
                                
                                onDragEnded: {
                                    guard let liveIndex = events.firstIndex(where: { $0.id == eventID }),
                                          events.indices.contains(liveIndex) else { return }
                                    let liveEvent = events[liveIndex]

                                    if liveEvent.isSystemEvent {
                                        pendingSystemChange = liveEvent
                                        pendingMinutes = liveEvent.minutes
                                        activeAlert = .systemEventChange(liveEvent, liveEvent.minutes)
                                        return
                                    }

                                    // Lưu tất cả non-system positions (only today)
                                    for e in events where !e.isSystemEvent {
                                        if e.duration == 1440 { continue }
                                        store.overrideEvent(
                                            templateID: e.id,
                                            date: calendar.selectedDate,
                                            minutes: e.minutes,
                                            duration: e.duration,
                                            ignoreOverlap: true
                                        )
                                    }

                                    // Nếu event dragged là recurring → hỏi scope
                                    if isRecurring(liveEvent) {
                                        activeAlert = .recurringTimeChange(liveEvent, liveEvent.minutes)
                                    }

                                    addButtonsIndex = bestGapIndex()
                                },
                                
                                
                                onTapEvent: { tapped in
                                    guard !tapped.isSystemEvent, !isPastDate() else { return }
                                    activeSheet = .eventDetail(tapped)
                                },
                                
                                
                                onResizeCommit: { templateID, newDuration in
                                    guard !isPastDate() else { return }
                                    // Save only today trước
                                    store.overrideEvent(
                                        templateID: templateID,
                                        date: calendar.selectedDate,
                                        duration: newDuration,
                                        ignoreOverlap: true
                                    )
                                    // Nếu recurring → hỏi sau khi resize xong (onResizeComplete)
                                    if let e = events.first(where: { $0.id == templateID }), isRecurring(e) {
                                        // Lưu pending để hỏi khi resize final
                                        pendingSystemChange = e
                                        pendingMinutes = newDuration  // tái dụng state này để lưu duration
                                    }
                                },
                                onResizeComplete: {
                                    reloadTimeline()
                                    // Hỏi scope nếu có pending recurring resize
                                    if let e = pendingSystemChange, !e.isSystemEvent {
                                        activeAlert = .recurringDurationChange(e, pendingMinutes)
                                        pendingSystemChange = nil
                                    }
                                }
                                
                            )
                            .id(eventID)

                            if let currentIdx = events.firstIndex(where: { $0.id == eventID }),
                               events.indices.contains(currentIdx + 1) {

                                let spacing = TimelineLayoutEngine.spacing(
                                    current: events[currentIdx],
                                    next: events[currentIdx + 1]
                                )

                                VStack(spacing: 0) {
                                    Spacer().frame(height: spacing / 2)

                                    if addButtonsIndex == currentIdx && !isPastDate() {
                                        if let message = gapMessage(for: currentIdx) {
                                            Button {
                                                activeSheet = .createItem
                                            } label: {
                                                HStack(spacing: 7) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.orange.opacity(0.15))
                                                            .frame(width: 22, height: 22)
                                                        Image(systemName: "plus")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundStyle(Color.orange)
                                                    }
                                                    Text(message)
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(Color.primary.opacity(0.55))
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.orange.opacity(0.08))
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                                        )
                                                )
                                            }
                                            .padding(.leading, 108)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                                            .animation(.easeInOut(duration: 0.15), value: addButtonsIndex)
                                        }
                                    }

                                    Spacer().frame(height: spacing / 2)
                                }
                            }
                        }
                    }
                }
                .opacity(isPastDate() ? 0.65 : 1)
                .saturation(isPastDate() ? 0.6 : 1)
                .allowsHitTesting(!isPastDate())
                .background(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {

                        // Line không cần offset — tọa độ đã khớp Morning Start
                        TimelineLineView(
                            events: visibleEvents,
                            isDragging: isDragging,
                            date: calendar.selectedDate
                        )
                        .padding(.leading, 100)

                        if visibleEvents.count > 1 &&
                           Calendar.current.isDateInToday(calendar.selectedDate) &&
                           TimelineLayoutEngine.isNowInsideTimeline(events: visibleEvents) {
                            TimeNowIndicator(time: TimelineEngine.formatTime(now))
                                .frame(width: 70, alignment: .leading)
                                .offset(y: TimelineLayoutEngine.nowY(events: visibleEvents))
                                .id(visibleEvents.map { "\($0.id)\($0.duration ?? 0)\($0.minutes)" }.joined())
                                .opacity(TimelineLayoutEngine.isNowInsideTimeline(events: visibleEvents) ? 1 : 0)
                        }
                    }
                }
                .transaction { t in if isDragging { t.animation = nil } }
                .animation(nil, value: isDragging)
                .animation(
                    isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.85),
                    value: events.map(\.minutes)
                )
                .padding(.horizontal)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {

            NotificationCenter.default.post(
                name: .cancelTimelineHold,
                object: nil
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    scheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(red: 0.992, green: 0.991, blue: 0.985)
                )
                .shadow(
                    color: scheme == .dark
                    ? .black.opacity(0.25)
                    : .black.opacity(0.05),
                    radius: 12,
                    y: 4
                )
        )
       
        
        .padding(.bottom, -20)
        .ignoresSafeArea(edges: .bottom)
        .onReceive(timer) { _ in
            now = TimelineEngine.currentMinutes()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("timelineNowBlock"))
        ) { _ in
            showNowBlockAlert = true
        }
        .onAppear {
            reloadTimeline()
            addButtonsIndex = bestGapIndex()
        }
        .onChange(of: calendar.selectedDate) { _, newDate in
            // Không animate khi switch date
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                events = store.events(for: newDate)
                addButtonsIndex = bestGapIndex()
            }
        }
        // MARK: Sheet

        .sheet(item: $activeSheet) { sheet in

            switch sheet {

            case .createItem:

                let suggested =
                store.suggestFreeSlot(
                    date: calendar.selectedDate,
                    duration: 60
                )

                CreateEventDetailSheet(
                    suggestedStart: suggested,
                    initialDate: calendar.selectedDate,
                    onOpenHabit: {

                        activeSheet = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showHabitSheet = true
                        }
                    }
                ) { title, icon, minutes, duration, colorHex, recurrence in

                    store.addEvent(
                        title: title,
                        icon: icon,
                        minutes: minutes,
                        duration: duration,
                        colorHex: colorHex,
                        recurrence: recurrence
                    )

                    reloadTimeline()

                    addButtonsIndex = bestGapIndex()
                }
                .presentationSizing(.page)          // 👈 mở rộng modal trên iPad
                  .presentationDetents([
                      .fraction(0.85),                // 👈 cao ~85% màn hình
                      .large
                  ])
                  .presentationDragIndicator(.visible)
                  .presentationCornerRadius(32)
                
            
                // ĐỔI THÀNH — chỉ cần onDelete:
            case .eventDetail(let event):
                EventDetailSheet(
                    event: event,
                    onDelete: {
                        guard !event.isSystemEvent else { return }
                        store.deleteEvent(templateID: event.id, date: calendar.selectedDate)
                        reloadTimeline()
                        addButtonsIndex = bestGapIndex()
                    }
                )
                .environmentObject(calendar)
                .onDisappear {
                    reloadTimeline()   // 👈 reload sau khi sheet đóng để title/icon mới hiện lên
                }
               
            }
        }

        // MARK: Alert

        .alert(item: $activeAlert) { alert in

            switch alert {

            case .deleteEvent(let event):

                return Alert(
                    title: Text("Delete Event"),
                    message: Text("This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {

                        guard !event.isSystemEvent else { return }

                        store.deleteEvent(
                            templateID: event.id,
                            date: calendar.selectedDate
                        )

                        reloadTimeline()

                        addButtonsIndex = bestGapIndex()
                    },
                    secondaryButton: .cancel()
                )
                
            case .systemEventChange(let event, let minutes):

                return Alert(
                    title: Text("Change System Event"),
                    message: Text("Apply this change to all days or only today?"),

                    // Trong primaryButton "All Days":
                    primaryButton: .default(Text("All Days")) {

                        if event.systemType == .wake {
                            // Không cho set wake sau sleep
                            let newWake = min(minutes, store.sleepMinutes - 30)
                            store.updateSystemEvents(
                                wakeMinutes: newWake,
                                sleepMinutes: store.sleepMinutes
                            )
                        } else if event.systemType == .sleep {
                            // Không cho set sleep trước wake
                            let newSleep = max(minutes, store.wakeMinutes + 30)
                            store.updateSystemEvents(
                                wakeMinutes: store.wakeMinutes,
                                sleepMinutes: newSleep
                            )
                        }

                        // Xóa override của ngày hôm nay vì đã apply vào template
                        store.overrides.removeAll {
                            $0.templateID == event.id &&
                            $0.dateKey == store.key(for: calendar.selectedDate)
                        }

                        store.rebuildIndex()
                        store.invalidateCache()
                        store.save()
                        reloadTimeline()
                    },

                    // Trong secondaryButton "Only Today":
                    secondaryButton: .default(Text("Only Today")) {
                        // Chỉ cho đổi today trở đi, không cho đổi past
                        guard !isPastDate() else { return }

                        store.overrideEvent(
                            templateID: event.id,
                            date: calendar.selectedDate,
                            minutes: minutes
                        )
                        reloadTimeline()
                    }
                )
                
            case .recurringTimeChange(let event, let minutes):
                return Alert(
                    title: Text("Move event"),
                    message: Text(recurringMessage(event)),
                    primaryButton: .default(Text("All Days")) {
                        store.updateEventTime(templateID: event.id, minutes: minutes)
                        reloadTimeline()
                    },
                    secondaryButton: .default(Text("Only Today")) {
                        // Already saved as override, nothing to do
                        reloadTimeline()
                    }
                )

            case .recurringDurationChange(let event, let duration):
                return Alert(
                    title: Text("Change duration"),
                    message: Text(recurringMessage(event)),
                    primaryButton: .default(Text("All Days")) {
                        store.updateEventDuration(templateID: event.id, duration: duration)
                        reloadTimeline()
                    },
                    secondaryButton: .default(Text("Only Today")) {
                        reloadTimeline()
                    }
                )
                
            }
        }
        
        .sheet(isPresented: $showHabitSheet) {

            CreateHabitDetailSheet(

                onCreate: { title, icon, date, type, target, unit, minutes, increment in

                    let startMinutes =
                        minutes ??
                        TimelineEngine.smartSlotMinutes(
                            events: events,
                            duration: 0
                        )

                    store.addHabit(
                        title: title,
                        icon: icon,
                        minutes: startMinutes,
                        habitType: type,
                        targetValue: target,
                        unit: unit,
                        increment: increment
                    )

                    reloadTimeline()

                    addButtonsIndex = bestGapIndex()
                },

                onOpenEvent: {

                    showHabitSheet = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        activeSheet = .createItem
                    }
                }
            )
            .presentationSizing(.page)          // 👈 mở rộng modal trên iPad
              .presentationDetents([
                  .fraction(0.85),                // 👈 cao ~85% màn hình
                  .large
              ])
              .presentationDragIndicator(.visible)
              .presentationCornerRadius(32)
           
        }
        
        
        
        
        
        
    }
}


struct DraggableEventRow: View {
    
    @EnvironmentObject var store: TimelineStore
      @EnvironmentObject var calendar: CalendarState
    
    @Binding var event: EventItem

    let index: Int
    
    @Binding var events: [EventItem]
    @Binding var isDragging: Bool
    var isNearNowIndicator: Bool = false
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
        let id = event.id  // 👈 dùng event binding trực tiếp, không qua events[index]

        let completed = store.isCompleted(
            templateID: id,
            date: date
        )

        if completed != isCompleted {
            isCompleted = completed
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    func isCurrentEvent() -> Bool {

        let now = TimelineEngine.currentMinutes()

        let start = event.minutes
        let end = event.minutes + (event.duration ?? 0)

        return now >= start && now <= end
    }
    
   
    
    func commitSwap() {

        guard !isLocked else { return }

        for e in events {

            guard !e.isSystemEvent else { continue }

            store.overrideEvent(
                templateID: e.id,
                date: calendar.selectedDate,
                minutes: e.minutes,
                ignoreOverlap: true
            )
        }
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
    
    
    var body: some View {
        
        TimelineEventRow(
            time: event.time,
               endTime: event.endTime,
               title: event.title,
               icon: event.icon,
               color: event.color,
               kind: event.kind,
               isHolding: isHolding && !event.isSystemEvent,
               hasDuration: event.duration != nil,
               durationMinutes: event.duration,
               isNearNowIndicator: isNearNowIndicator,
               nearSwapTarget: nearSwapTarget,
               durationPreview: durationPreview,
               startMinutes: event.minutes,
               isCompleted: isCompleted,
               isSystemEvent: event.isSystemEvent,
             
            
            
            onToggleComplete: {
                
                guard !isLocked else { return }

                store.toggleCompletion(
                    templateID: event.id,
                    date: calendar.selectedDate
                )

                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isCompleted = store.isCompleted(
                        templateID: event.id,
                        date: calendar.selectedDate
                    )
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
                
                let clamped = min(max(newMinutes, 0), 1440)
                
                if clamped != event.minutes {
                    event.update(minutes: clamped)
                }
                
                
                let minutes = event.minutes
                let morningStart = 6 * 60
                let nightStart = 22 * 60
                let snapRange = 12
                
                // MORNING SNAP
                if abs(minutes - morningStart) < snapRange && !didSnapMorning {
                    event.update(minutes: morningStart)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    didSnapMorning = true
                }
                
                if abs(minutes - morningStart) > snapRange {
                    didSnapMorning = false
                }
                
                // NIGHT SNAP
                if abs(minutes - nightStart) < snapRange && !didSnapNight {
                    event.update(minutes: nightStart)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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

                // lưu duration gốc khi bắt đầu drag
                if resizeBaseDuration == nil {
                    resizeBaseDuration = duration
                }

                guard let base = resizeBaseDuration else { return }

                let minuteDelta = Int(translation / 12)

                let raw = base + minuteDelta

                // snap 5 phút
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
                onResizeComplete?()   // 👈 chỉ gọi reloadTimeline, không đụng minutes
            },
            
            isLocked: isLocked,
            isToday: Calendar.current.isDateInToday(calendar.selectedDate)
            
        )
        .opacity(isDragging && !isHolding ? 0.6 : 1)
        .frame(height: TimelineLayoutEngine.eventHeight(event))
        .fixedSize(horizontal: false, vertical: true)
        .offset(x: dragOffsetX, y: dragOffsetY)
        .shadow(
            color: isHolding ? .black.opacity(0.25) : .clear,
            radius: isHolding ? 14 : 0,
            y: isHolding ? 8 : 0
        )
        .scaleEffect(isHolding ? 1.03 : 1)
        .animation(.spring(response:0.28,dampingFraction:0.85), value:isHolding)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in
                    
                    guard !isLocked else { return }
                    
                    guard !isCurrentEvent() else { return }
                    
                    swapHaptic.prepare()
                    
                    withAnimation(.spring()) {
                        isHolding = true
                    }
                    
                    UIImpactFeedbackGenerator(style:.medium).impactOccurred()
                }
        )
        
        .gesture(
            isLocked
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
                    
                    // system event cũng phải hold mới drag
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
                    // các event khác phải hold trước
                    guard isHolding else { return }
                    
                    isDragging = true
                    
                    dragOffsetX = max(0, value.translation.width)
                    dragOffsetY = value.translation.height
                    
                    // khi kéo ngang đủ xa → bật reorder
                    if dragOffsetX > 40 {
                        isReordering = true
                    }
                    
                    let swapRange: CGFloat = 60
                    
                    if abs(dragOffsetY) > swapRange {
                        if !nearSwapTarget {
                            nearSwapTarget = true
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        }
                    } else {
                        nearSwapTarget = false
                    }
                    
                    if isReordering {
                        
                        let swapThreshold: CGFloat = 60
                        let resetThreshold: CGFloat = 25
                        let cooldown: TimeInterval = 0.12
                        let dragY = dragOffsetY
                        let now = Date()
                        
                        // không cho swap quá nhanh
                        guard now.timeIntervalSince(lastSwapTime) > cooldown else { return }
                        
                        // swap xuống
                        if dragY > swapThreshold,
                           let liveIdx = events.firstIndex(where: { $0.id == event.id }),
                           liveIdx < events.count - 1 {
                            let next = liveIdx + 1
                            if !events[next].isSystemEvent && lastSwapIndex != next {
                                lastSwapIndex = next
                                lastSwapTime = now
                                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.75)) {
                                    let temp = events[liveIdx].minutes
                                    events[liveIdx].update(minutes: events[next].minutes)
                                    events[next].update(minutes: temp)
                                    events = events
                                }
                                commitSwap()

                                lastSwapIndex = -1
                                swapHaptic.impactOccurred()
                            }
                        }
                        
                        // swap lên
                        if dragY < -swapThreshold,
                           let liveIdx = events.firstIndex(where: { $0.id == event.id }),
                           liveIdx > 0 {
                            let prev = liveIdx - 1
                            if !events[prev].isSystemEvent && lastSwapIndex != prev {
                                lastSwapIndex = prev
                                lastSwapTime = now
                                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                                    let temp = events[liveIdx].minutes
                                    events[liveIdx].update(minutes: events[prev].minutes)
                                    events[prev].update(minutes: temp)
                                    events.swapAt(liveIdx, prev)
                                }
                                commitSwap()
                                
                                lastSwapIndex = -1
                                swapHaptic.impactOccurred()
                            }
                        }
                        
                        // reset lock khi kéo gần lại trung tâm
                        if abs(dragY) < resetThreshold {
                            lastSwapIndex = -1
                        }
                    } else {
                        
                        let newMinutes = TimelineEngine.move(
                            event: event,
                            index: index,
                            events: events,
                            translation: value.translation.height
                        )
                        
                        let now = TimelineEngine.currentMinutes()

                        if event.minutes > now && newMinutes < now {

                            UINotificationFeedbackGenerator().notificationOccurred(.warning)

                            NotificationCenter.default.post(
                                name: Notification.Name("timelineNowBlock"),
                                object: nil
                            )

                            return
                        }

                        event.update(minutes: max(0, min(newMinutes, 1440)))
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
                    
                    event.update(minutes: min(max(newMinutes,0),1440))
                    
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













struct TimelineEventRow: View {

    let time: String
    let endTime: String?
    let title: String
    let icon: String
    let color: Color
    let kind: EventKind
    let isHolding: Bool
    let hasDuration: Bool
    let durationMinutes: Int?
    let isNearNowIndicator: Bool
    let nearSwapTarget: Bool
    let durationPreview: String?
    let startMinutes: Int
    let isCompleted: Bool
    let isSystemEvent: Bool
    var onToggleComplete: (() -> Void)?
    
    
    var onTap: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    var onIconHold: (() -> Void)? = nil
    var onResizeEnd: ((CGFloat) -> Void)?
    var onResizeFinal: ((CGFloat) -> Void)? = nil
    
    let isLocked: Bool
    let isToday: Bool
    
    
    
    
    @Environment(\.colorScheme) private var scheme
    
    var brandRing: Color {

        let brand = Color(red: 0.29, green: 0.44, blue: 0.65)

        if scheme == .dark {
            return brand.opacity(0.85)
        } else {
            return brand.opacity(0.65)
        }
    }
    
    
    
    private func pillHeight(durationMinutes: Int?) -> CGFloat {
        guard let d = durationMinutes else { return 50 }
        let h = 50 + CGFloat(d - 15) * (80.0 / 105.0)
        return min(max(h, 50), 130)
    }
    
    private func isNowNearEndTime() -> Bool {
        guard isToday, let d = durationMinutes else { return false }  // 👈 guard isToday
        let now = TimelineEngine.currentMinutes()
        let end = startMinutes + d
        return abs(now - end) <= 5
    }
    
    func isRunning() -> Bool {
        guard isToday, let durationMinutes else { return false }  // 👈 guard isToday
        let now = TimelineEngine.currentMinutes()
        return now >= startMinutes && now <= startMinutes + durationMinutes
    }
    
    
    func progress() -> CGFloat {

        guard let durationMinutes else { return 0 }

        let now = TimelineEngine.currentMinutes()

        let start = startMinutes
        let end = start + durationMinutes

        if now <= start { return 0 }
        if now >= end { return 1 }

        return CGFloat(now - start) / CGFloat(durationMinutes)
    }
    
    
    private var timeScale: CGFloat {

        guard let durationMinutes else { return 1 }

        let scale = 1 + CGFloat(durationMinutes) / 240
        return min(scale, 1.35) // cap để không giãn quá
    }
    
    private var timeSpacing: CGFloat {

        guard let durationMinutes else { return 2 }

        let spacing = CGFloat(durationMinutes) / 6
        return min(max(spacing, 2), 18) // clamp
    }
    
    private var durationText: String? {

        if let durationPreview {
            return durationPreview
        }

        guard let durationMinutes else { return nil }

        let h = durationMinutes / 60
        let m = durationMinutes % 60

        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }
    
    
    var body: some View {

        // 1. Đổi alignment HStack
        HStack(alignment: .top, spacing: 4) {

            let ph = pillHeight(durationMinutes: durationMinutes)

            // 2. Đổi ZStack sang .topLeading
            ZStack(alignment: .topLeading) {

                // Start time — TOP
                Text(time)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                // End time — BOTTOM
                if let endTime {
                    Text(endTime)
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, isHolding ? 6 : 0)
                        .padding(.vertical, isHolding ? 2 : 0)
                        .background(
                            Capsule()
                                .fill(isHolding ? Color.primary.opacity(0.08) : .clear)
                        )
                        .gesture(
                            isHolding && !isLocked ?
                            DragGesture()
                                .onChanged { value in onResizeEnd?(value.translation.height) }
                                .onEnded   { value in
                                    onResizeEnd?(value.translation.height)
                                    onResizeFinal?(value.translation.height)  // 👈 thêm dòng này
                                }
                            : nil
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .opacity(isNowNearEndTime() ? 0 : 1)          // 👈 thêm dòng này
                        .animation(.easeInOut(duration: 0.2), value: isNowNearEndTime())  // 👈 và dòng này
                }
            }
            // 3. Frame đặt ở ZStack, alignment .topLeading
            .frame(width: 70, height: ph, alignment: .topLeading)
            .opacity(isNearNowIndicator ? 0.1 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHolding)
           

            // 👇 DRAG HANDLE
            EventIconView(
                icon: icon,
                color: color,
                kind: kind,
                isHolding: isHolding,
                durationMinutes: durationMinutes,
                startMinutes: startMinutes,
                isCompleted: isCompleted,
                isSystemEvent: isSystemEvent,
                isToday: isToday
            )
            .offset(x: -0.5)
           
               

            VStack(alignment: .leading, spacing: 2) {

                Text(title)
                    .font(.headline)
                    .opacity(durationPreview != nil ? 0.7 : 1)
                    .opacity(isCompleted ? 0.45 : 1)
                    .overlay(
                        Rectangle()
                            .fill(Color.primary)
                            .frame(height: 1.5)
                            .scaleEffect(x: isCompleted ? 1 : 0, anchor: .leading)
                            .animation(.easeOut(duration: 0.25), value: isCompleted),
                        alignment: .center
                    )
                
                if kind == .event {
                    
                    HStack(spacing: 6) {
                        
                        Text(time)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        
                        if let durationText {

                            if durationPreview != nil {

                                Text(durationText)
                                    .font(.caption.bold())
                                    .monospacedDigit()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(color.opacity(0.18))
                                    )
                                    .foregroundStyle(color)
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(response:0.25,dampingFraction:0.8), value: durationPreview)

                            } else {

                                Text("• \(durationText)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if kind == .habit {
                    HStack(spacing:4){
                        Image(systemName:"repeat")
                        Text("Habit")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
           

            Spacer()

            // ✅ CHECK BUTTON
            Button {

                onToggleComplete?()

            } label: {

                ZStack {

                    Circle()
                        .fill(isCompleted ? color.opacity(0.25) : Color.clear)
                        .frame(width: 28, height: 28)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)

                    Circle()
                        .stroke(color.opacity(0.8), lineWidth: 2)

                    AnimatedCheckmark(progress: isCompleted ? 1 : 0)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)

            ReorderHintArrows(
                show: isHolding,
                trigger: nearSwapTarget
            )
            .frame(width: 24)
            .offset(x: -8)

    
              
            
        }
    }
}

struct TimeNowIndicator: View {

    let time: String

    var body: some View {

        HStack(spacing: 8) {

            // giờ bên trái
            Text(time)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            // dot đỏ
           

        }
    }
}

struct ReorderHintArrows: View {

    let show: Bool
    let trigger: Bool

    @State private var slide: CGFloat = 0

    var body: some View {

        VStack(spacing: 6) {

            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .opacity(show ? 1 : 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .offset(x: slide)
                .opacity(trigger ? 1 : 0.6)
                .animation(
                    trigger ?
                    .easeInOut(duration:0.6).repeatForever(autoreverses:true)
                    : .default,
                    value: trigger
                )
            

            Image(systemName: "arrow.down")
                .font(.system(size: 12, weight: .bold))
                .opacity(show ? 1 : 0)
        }
        .foregroundStyle(.secondary)
        .scaleEffect(show ? 1 : 0.6)
        .opacity(show ? 1 : 0)
        .onChange(of: trigger) { _, value in

            if value {

                withAnimation(
                    .easeInOut(duration: 0.35)
                    .repeatForever(autoreverses: true)
                ) {
                    slide = 12
                }

            } else {

                withAnimation(.easeOut(duration: 0.15)) {
                    slide = 0
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: show)
    }
}


// MARK: - EventIconView (thay thế ZStack icon cũ)

struct EventIconView: View {

    let icon: String
    let color: Color
    let kind: EventKind
    let isHolding: Bool
    let durationMinutes: Int?
    let startMinutes: Int
    let isCompleted: Bool
    let isSystemEvent: Bool
    let isToday: Bool
    
    
    @Environment(\.colorScheme) private var scheme

    // Chiều cao pill scale theo duration
    private var pillHeight: CGFloat {
        guard let d = durationMinutes else { return 50 }
        // 15 phút → 50pt, 60 phút → 80pt, 120 phút → 110pt, cap 130pt
        let h = 50 + CGFloat(d - 15) * (80.0 / 105.0)
        return min(max(h, 50), 130)
    }

    private var pillWidth: CGFloat { 50 }

    var brandRing: Color {
        let brand = Color(red: 0.29, green: 0.44, blue: 0.65)
        return scheme == .dark ? brand.opacity(0.85) : brand.opacity(0.65)
    }

    func isRunning() -> Bool {
        guard isToday, let d = durationMinutes else { return false }  // 👈 guard isToday
        let now = TimelineEngine.currentMinutes()
        return now >= startMinutes && now <= startMinutes + d
    }

    func progress() -> CGFloat {
        guard let d = durationMinutes else { return 0 }
        let now = TimelineEngine.currentMinutes()
        let start = startMinutes
        let end = start + d
        if now <= start { return 0 }
        if now >= end { return 1 }
        return CGFloat(now - start) / CGFloat(d)
    }

    var body: some View {
        Group {
            if kind == .habit {
                // ── HABIT: tròn như cũ ──
                ZStack {
                    Circle()
                        .fill(color)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    // badge repeat
                    Image(systemName: "repeat")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 14, y: 14)
                }
                .frame(width: 50, height: 50)

            } else {
                ZStack {
                    // Nền pill
                    RoundedRectangle(cornerRadius: pillWidth / 2)
                        .fill(
                            isSystemEvent
                            ? color
                            : (scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07))
                        )



                    // Stroke viền màu khi running
                    if isRunning() {
                        RoundedRectangle(cornerRadius: pillWidth / 2)
                            .stroke(
                                isSystemEvent ? Color.white.opacity(0.5) : color,  // bỏ .opacity(0.6)
                                lineWidth: 2.5                                       // tăng từ 2 → 2.5
                            )
                            .animation(.easeInOut, value: isRunning())
                    }

                    // Icon giữa pill
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSystemEvent ? .white : color)
                }
                .frame(width: pillWidth, height: pillHeight)
            }
        }
        // hold scale áp dụng cho cả 2
        .scaleEffect(isHolding ? 1.15 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHolding)
        .shadow(
            color: color.opacity(isHolding ? 0.3 : 0.15),
            radius: isHolding ? 12 : 4,
            y: isHolding ? 6 : 2
        )
        .background(
            // halo blur phía sau
            Group {
                if kind == .habit {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                } else {
                    RoundedRectangle(cornerRadius: pillWidth / 2 + 5)
                        .fill(.ultraThinMaterial)
                        .frame(width: pillWidth + 10, height: pillHeight + 10)
                }
            }
        )
        .overlay(
            Group {
                if kind == .habit {
                    Circle()
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: pillWidth / 2)
                        .stroke(Color.white.opacity(isHolding ? 0.25 : 0.12), lineWidth: 1)
                }
            }
        )
    }
}


extension Binding {
    static func safe<T: Identifiable>(
        _ array: Binding<[T]>,
        id: T.ID
    ) -> Binding<T>? {
        guard array.wrappedValue.contains(where: { $0.id == id }) else {
            return nil
        }
        return Binding<T>(
            get: {
                guard let found = array.wrappedValue.first(where: { $0.id == id }) else {
                    return array.wrappedValue[0]  // wake event luôn tồn tại
                }
                return found
            },
            set: {
                guard let idx = array.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
                array.wrappedValue[idx] = $0
            }
        )
    }
}
