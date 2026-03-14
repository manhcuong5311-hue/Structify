



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
    
    
    
    func isPastDate() -> Bool {

        let today = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: calendar.selectedDate)

        return selected < today
    }
    
    func reloadTimeline() {
        events = store.events(for: calendar.selectedDate)
        addButtonsIndex = TimelineEngine.largestGapIndex(events: events)
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
    
    
    
    
    
    var body: some View {

        
        
        ScrollView {
            
           
            VStack(alignment: .leading) {
                
                
                
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    if events.indices.contains(index) {
                        
                        DraggableEventRow(
                            event: $events[index],
                            index: index,
                            events: $events,
                            isDragging: $isDragging,
                            isNearNowIndicator: indicatorTouchesEvent(index),
                            isLocked: isPastDate(),
                            
                            onDragEnded: {
                                
                                guard events.indices.contains(index) else { return }
                                
                                let event = events[index]
                                
                                if event.isSystemEvent {
                                    
                                    pendingSystemChange = event
                                    pendingMinutes = event.minutes
                                    
                                    activeAlert = .systemEventChange(event, event.minutes)
                                    
                                    return
                                }
                                
                                for e in events {
                                    
                                    if !e.isSystemEvent {
                                        
                                        store.overrideEvent(
                                            templateID: e.id,
                                            date: calendar.selectedDate,
                                            minutes: e.minutes
                                        )
                                    }
                                }
                                
                                addButtonsIndex =
                                TimelineEngine.largestGapIndex(events: events)
                            },
                            onTapEvent: { event in
                                
                                guard !event.isSystemEvent else { return }
                                guard !isPastDate() else { return }
                                
                                activeSheet = .eventDetail(event)
                            },
                            onResizeCommit: { templateID, newDuration in
                                
                                guard !isPastDate() else { return }
                                
                                store.overrideEvent(
                                    templateID: templateID,
                                    date: calendar.selectedDate,
                                    duration: newDuration
                                )
                                
                                reloadTimeline()
                            }
                        )
                        .id(events[index].id)
                        
                        if events.indices.contains(index),
                           events.indices.contains(index + 1) {
                            
                            let spacing = TimelineLayoutEngine.spacing(
                                current: events[index],
                                next: events[index + 1]
                            )
                            
                            VStack(spacing: 0) {
                                
                                Spacer()
                                    .frame(height: spacing / 2)
                                
                                if addButtonsIndex == index && !isPastDate() {
                                    
                                    AddItemButton {
                                        activeSheet = .createItem
                                    }
                                    .frame(maxWidth: .infinity)
                                    .transition(.opacity)
                                    .animation(
                                        isDragging ? nil :
                                                .easeInOut(duration: 0.15),
                                        value: spacing
                                    )
                                }
                                
                                Spacer()
                                    .frame(height: spacing / 2)
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

                    TimelineLineView(
                        events: events,
                        isDragging: isDragging,
                        date: calendar.selectedDate
                    )
                    .padding(.leading, 100)

                    if events.count > 1 &&
                       Calendar.current.isDateInToday(calendar.selectedDate) &&
                       TimelineLayoutEngine.isNowInsideTimeline(events: events) {

                        TimeNowIndicator(
                            time: TimelineEngine.formatTime(now)
                        )
                        .frame(width: 70, alignment: .leading)
                        .offset(y: TimelineLayoutEngine.nowY(events: events))
                        .opacity(
                            TimelineLayoutEngine.isNowInsideTimeline(events: events)
                            ? 1 : 0
                        )
                        .animation(.easeOut(duration: 0.2), value: events)
                    }
                }
            }
            .transaction { t in
                if isDragging { t.animation = nil }
                
            }
            .animation(nil, value: isDragging)
            .animation(
                isDragging ? nil : .interactiveSpring(),
                value: events.map(\.minutes)
            )
            .padding(.horizontal)
            .padding(.top, 30)
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

            addButtonsIndex =
            TimelineEngine.largestGapIndex(
                events: events
            )
        }
        .onChange(of: calendar.selectedDate) { _, newDate in

            withAnimation(.easeOut(duration: 0.15)) {

                events = store.events(for: newDate)

                addButtonsIndex =
                    TimelineEngine.largestGapIndex(events: events)
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

                    addButtonsIndex =
                    TimelineEngine.largestGapIndex(events: events)
                }
                .presentationSizing(.page)          // 👈 mở rộng modal trên iPad
                  .presentationDetents([
                      .fraction(0.85),                // 👈 cao ~85% màn hình
                      .large
                  ])
                  .presentationDragIndicator(.visible)
                  .presentationCornerRadius(32)
                
            case .eventDetail(let event):

                EventDetailSheet(
                    event: event,
                    onDelete: {
                        activeAlert = .deleteEvent(event)
                    }
                )
               
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

                        addButtonsIndex =
                            TimelineEngine.largestGapIndex(events: events)
                    },
                    secondaryButton: .cancel()
                )
                
            case .systemEventChange(let event, let minutes):

                return Alert(
                    title: Text("Change System Event"),
                    message: Text("Apply this change to all days or only today?"),

                    primaryButton: .default(Text("All Days")) {

                        if event.systemType == .wake {

                            store.updateSystemEvents(
                                wakeMinutes: minutes,
                                sleepMinutes: store.sleepMinutes
                            )

                           
                            let k = store.key(for: calendar.selectedDate)

                            if let index = store.overrides.firstIndex(where: {
                                $0.templateID == event.id &&
                                $0.dateKey == k
                            }) {
                                store.overrides[index].minutes = nil
                            }

                            store.rebuildIndex()
                            store.invalidateCache()
                            store.save()

                            reloadTimeline()

                        } else if event.systemType == .sleep {

                            store.updateSystemEvents(
                                wakeMinutes: store.wakeMinutes,
                                sleepMinutes: minutes
                            )

                            store.overrides.removeAll {
                                $0.templateID == event.id &&
                                $0.dateKey == store.key(for: calendar.selectedDate)
                            }

                            store.rebuildIndex()
                            store.invalidateCache()
                            store.save()

                            reloadTimeline()
                        }

                        reloadTimeline()
                    },

                    secondaryButton: .default(Text("Only Today")) {

                        store.overrideEvent(
                            templateID: event.id,
                            date: calendar.selectedDate,
                            minutes: minutes
                        )

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

                    addButtonsIndex =
                    TimelineEngine.largestGapIndex(events: events)
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

        guard events.indices.contains(index) else { return }

        let id = events[index].id

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
            
            isLocked: isLocked
            
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
                        
                        TimelineEngine.autoPush(
                            events: &events,
                            movedIndex: index
                        )
                        
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
                        if dragY > swapThreshold, index < events.count - 1 {
                            
                            let next = index + 1
                            
                            if !events[next].isSystemEvent && lastSwapIndex != next {
                                
                                lastSwapIndex = next
                                lastSwapTime = now
                                
                                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.75)) {

                                    let temp = events[index].minutes
                                    events[index].update(minutes: events[next].minutes)
                                    events[next].update(minutes: temp)

                                    events = events
                                }
                                commitSwap()

                                lastSwapIndex = -1
                                swapHaptic.impactOccurred()
                            }
                        }
                        
                        // swap lên
                        if dragY < -swapThreshold, index > 0 {
                            
                            let prev = index - 1
                            
                            if !events[prev].isSystemEvent && lastSwapIndex != prev {
                                
                                lastSwapIndex = prev
                                lastSwapTime = now
                                
                                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                                    let temp = events[index].minutes
                                    events[index].update(minutes: events[prev].minutes)
                                    events[prev].update(minutes: temp)
                                    
                                    events.swapAt(index, prev)
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
    var onToggleComplete: (() -> Void)?
    
    
    var onTap: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    var onIconHold: (() -> Void)? = nil
    var onResizeEnd: ((CGFloat) -> Void)?
    
    let isLocked: Bool
    
    
    
    
    
    @Environment(\.colorScheme) private var scheme
    
    var brandRing: Color {

        let brand = Color(red: 0.29, green: 0.44, blue: 0.65)

        if scheme == .dark {
            return brand.opacity(0.85)
        } else {
            return brand.opacity(0.65)
        }
    }
    
    
    
    
    
    func isRunning() -> Bool {

        guard let durationMinutes else { return false }

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

        HStack(alignment: .center, spacing: 4) {

            VStack(spacing: isHolding ? 6 : 0) {

                Text(time)
                    .scaleEffect(isHolding ? 1.05 : 1)
                    .offset(y: isHolding ? -4 : 0)

                if let endTime {

                    Spacer()
                        .frame(height: timeSpacing)

                    Text(endTime)
                        .scaleEffect(isHolding ? 1.05 : 1)
                        .offset(y: isHolding ? 4 : 0)
                        .padding(.horizontal, isHolding ? 6 : 0)
                        .padding(.vertical, isHolding ? 2 : 0)
                        .background(
                            Capsule()
                                .fill(isHolding ? Color.primary.opacity(0.08) : .clear)
                        )
                        .gesture(
                            isHolding && !isLocked ?
                            DragGesture()
                                .onChanged { value in
                                    onResizeEnd?(value.translation.height)
                                }
                                .onEnded { value in
                                    onResizeEnd?(value.translation.height)
                                }
                            : nil
                        )
                }
            }
            .animation(.spring(response:0.25,dampingFraction:0.8), value:isHolding)
            .opacity(isNearNowIndicator ? 0.1 : 1)
            .frame(width:70, alignment:.leading)
           

            // 👇 DRAG HANDLE
            ZStack {

                Circle()
                    .fill(color)
                
                if isRunning() {

                      Circle()
                          .trim(from: 0, to: progress())
                          .stroke(
                            brandRing,
                              style: StrokeStyle(
                                  lineWidth: 4,
                                  lineCap: .round
                              )
                          )
                          .rotationEffect(.degrees(-90))
                          .animation(.linear(duration: 0.5), value: progress())
                  }

                Image(systemName: icon)
                    .font(.system(size:18, weight:.semibold))
                    .foregroundStyle(.white)

                if kind == .habit {
                    Image(systemName: "repeat")
                        .font(.system(size:7, weight:.bold))
                        .foregroundStyle(.white)
                        .offset(x:14,y:14)
                }

            }
            .frame(width:50,height:50)
            .scaleEffect(isHolding ? 1.15 : 1)   // 👈 scale ở đây
            .animation(.spring(response:0.25,dampingFraction:0.8), value:isHolding)
            .offset(x:-0.5)
            .shadow(
                color: isHolding ? .black.opacity(0.25) : .clear,
                radius: isHolding ? 12 : 0,
                y: isHolding ? 6 : 0
            )
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width:60,height:60)
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.05), lineWidth:1)
            )
            .shadow(color: color.opacity(0.35), radius:6, y:3)
           
               

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
