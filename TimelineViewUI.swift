



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
    
    @StateObject private var ticker = TimelineTicker()
    
    @State private var showNowBlockAlert = false
    @State private var suggestedMinutes: Int? = nil
    // Reactive accent — subscribes to UserDefaults so the timeline tint updates
    // immediately when the user changes the accent in Settings.
    @AppStorage("pref_accent_hex") private var accentHex: String = "#4A70A6"
    private var brand: Color { Color(hex: accentHex) }
    @State private var showPremiumSheet = false
    @State private var showRecurringDragDialog = false
    @State private var pendingRecurringDrag: (EventItem, Int)?
    @State private var showSystemEventDialog = false
    // Thêm vào đầu TimelineView cùng với các state khác
    @State private var showRecurringResizeDialog = false
    @State private var pendingRecurringResize: (EventItem, Int)?
    
    func isNowApproachingStart(of eventID: UUID, in visible: [EventItem]) -> Bool {
        guard Calendar.current.isDateInToday(calendar.selectedDate) else { return false }
        let now = TimelineEngine.currentMinutes()
        
        guard let idx = visible.firstIndex(where: { $0.id == eventID }),
              idx > 0 else { return false }
        
        let event    = visible[idx]
        let prevEvent = visible[idx - 1]
        
        guard now < event.minutes else { return false } // đã qua start
        
        let prevEnd     = TimelineEngine.endMinute(prevEvent)
        let gapMinutes  = event.minutes - prevEnd
        guard gapMinutes > 0 else { return false }
        
        // Chiều cao pixel của gap này
        let spacingPx   = TimelineLayoutEngine.spacing(current: prevEvent, next: event)
        
        // Quy đổi 30pt → minutes tương đương trong gap này
        let minutesPerPx    = CGFloat(gapMinutes) / spacingPx
        let thresholdMin    = Int(30 * minutesPerPx)
        
        return (event.minutes - now) <= max(thresholdMin, 3)
    }
    
    
    
    
    
    
    
    
    
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
        case .daily:
            return String(localized: "event_repeat_daily")

        case .weekdays:
            return String(localized: "event_repeat_weekdays")

        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            let daysText = days.sorted().map { s[$0-1] }.joined(separator: ", ")
            return String(
                localized: "event_repeat_specific \(daysText)"
            )

        case .once:
            return ""

        case .dateRange(let start, let end):
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            return String(
                localized: "event_repeat_range \(f.string(from: start)) \(f.string(from: end))"
            )
        }
    }
    
    
    func isPastDate() -> Bool {

        let today = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: calendar.selectedDate)

        return selected < today
    }

    /// True when the user has not created any habits or events yet (only system wake/sleep exist).
    var isTimelineEmpty: Bool {
        store.templates.allSatisfy { $0.isSystemEvent }
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
    
    // Sửa bestGapIndex() — dùng visibleEvents:
    func bestGapIndex() -> Int? {
        let visible = events.filter { $0.duration != 1440 }
        guard visible.count > 1 else { return nil }
        let nowMinutes = TimelineEngine.currentMinutes()
        let isToday = Calendar.current.isDateInToday(calendar.selectedDate)
        var largestGap = 0
        var index: Int? = nil
        for i in 0..<(visible.count - 1) {
            let gapStart = TimelineEngine.endMinute(visible[i])
            let gapEnd   = visible[i + 1].minutes
            let gap      = gapEnd - gapStart
            if isToday && gapStart < nowMinutes { continue }
            if gap > largestGap {
                largestGap = gap
                index = i
            }
        }
        return index
    }
    
    func nowTimeString() -> String {
        TimelineEngine.formatTime(ticker.now)
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
    
    
    
    // Sửa func indicatorTouchesEvent — truyền visibleEvents:
    func indicatorTouchesEvent(_ index: Int) -> Bool {
        let visible = events.filter { $0.duration != 1440 }
        let now = ticker.now
        guard let nearest = visible.enumerated()
            .min(by: { abs($0.element.minutes - now) < abs($1.element.minutes - now) })
        else { return false }
        return nearest.offset == index && abs(nearest.element.minutes - now) <= 5
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
            return String(localized: "gap_1h")
        case 120..<180:
            return String(localized: "gap_2h")
        case 180..<240:
            return String(localized: "gap_3h")
        case 240..<360:
            return String(localized: "gap_chunk")
        case 360..<480:
            return String(localized: "gap_half_workday")
        case 480..<600:
            return String(localized: "gap_morning")
        case 600..<720:
            return String(localized: "gap_long_block")
        case 720..<840:
            return String(localized: "gap_half_day")
        case 840..<960:
            return String(localized: "gap_long_free")
        case 960...:
            return String(localized: "gap_full_day")
        default:
            return nil
        }
    }
    
    
    
    
    
    
    
    
    
    
    var body: some View {
        
        GeometryReader { geo in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let maxWidth: CGFloat = isPad ? min(geo.size.width * 0.85, 900) : .infinity
            
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
                    let prefs = PreferencesStore.shared
                    let visibleEvents = events.filter { event in
                        guard event.duration != 1440 else { return false }
                        if prefs.hideCompleted && !event.isSystemEvent {
                            return !store.isCompleted(templateID: event.id, date: calendar.selectedDate)
                        }
                        return true
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        
                        ForEach(visibleEvents) { event in
                            
                            let eventID = event.id
                            
                            if events.contains(where: { $0.id == eventID }),
                               let safeBinding = Binding<Any>.safe($events, id: eventID),
                               let index = visibleEvents.firstIndex(where: { $0.id == eventID }) {
                                
                                let approaching = isNowApproachingStart(of: eventID, in: visibleEvents)
                                
                                
                                DraggableEventRow(
                                    event: safeBinding,
                                    index: index,
                                    events: Binding(
                                        get: { events.filter { $0.duration != 1440 } },
                                        set: { newVisible in
                                            for item in newVisible {
                                                if let i = events.firstIndex(where: { $0.id == item.id }) {
                                                    events[i] = item
                                                }
                                            }
                                            events.sort { $0.minutes < $1.minutes } // 👈 thêm dòng này
                                        }
                                    ),
                                    isDragging: $isDragging,
                                    isNearNowIndicator: indicatorTouchesEvent(index),
                                    isNowApproachingStart: approaching,
                                    isLocked: isPastDate(),
                                    
                                    
                                    onDragEnded: {
                                        guard let liveIndex = events.firstIndex(where: { $0.id == eventID }),
                                              events.indices.contains(liveIndex) else { return }
                                        let liveEvent = events[liveIndex]
                                        
                                        if liveEvent.isSystemEvent {
                                            pendingSystemChange = liveEvent
                                            pendingMinutes = liveEvent.minutes
                                            showSystemEventDialog = true  // thay activeAlert = .systemEventChange
                                            return
                                        }
                                        
                                        // Lưu tất cả non-system positions (only today)
                                        let nowMin = TimelineEngine.currentMinutes()
                                        let isToday = Calendar.current.isDateInToday(calendar.selectedDate)
                                        
                                        for e in events where !e.isSystemEvent {
                                            if e.duration == 1440 { continue }
                                            
                                            // TÌM trong onDragEnded của TimelineView — thêm check tương tự:
                                            if isToday {
                                                let endMin = e.minutes + (e.duration ?? 0)
                                                if endMin < nowMin { continue }
                                                if e.minutes < nowMin && e.duration == nil { continue }
                                                // 👈 thêm:
                                                if let d = e.duration, e.minutes <= nowMin && e.minutes + d >= nowMin { continue }
                                            }
                                            
                                            
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
                                            pendingRecurringDrag = (liveEvent, liveEvent.minutes)
                                            showRecurringDragDialog = true  // thay activeAlert = .recurringTimeChange
                                        }
                                        
                                        addButtonsIndex = bestGapIndex()
                                    },
                                    
                                    
                                    onTapEvent: { tapped in
                                        guard !tapped.isSystemEvent, !isPastDate() else { return }
                                        if tapped.kind == .habit {
                                            activeSheet = .habitDetail(tapped)
                                        } else {
                                            activeSheet = .eventDetail(tapped)
                                        }
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
                                        if let e = pendingSystemChange, !e.isSystemEvent {
                                            pendingRecurringResize = (e, pendingMinutes)
                                            showRecurringResizeDialog = true
                                            pendingSystemChange = nil
                                        }
                                    }
                                    
                                )
                                .id(eventID)
                                
                                if let currentIdx = visibleEvents.firstIndex(where: { $0.id == eventID }),
                                   visibleEvents.indices.contains(currentIdx + 1) {
                                    let spacing = TimelineLayoutEngine.spacing(
                                        current: visibleEvents[currentIdx],
                                        next: visibleEvents[currentIdx + 1]
                                    )
                                    
                                    ZStack(alignment: .leading) {
                                        // Spacer giữ đúng height — line tính dựa vào đây
                                        Color.clear.frame(height: spacing)
                                        
                                        // Button float bên trên, không ảnh hưởng layout
                                        if addButtonsIndex == currentIdx && !isPastDate() {
                                            if let message = gapMessage(for: currentIdx) {
                                                Button {
                                                    // Tính giờ bắt đầu của gap này
                                                    let gapStart = TimelineEngine.endMinute(visibleEvents[currentIdx])
                                                    let gapEnd   = visibleEvents[currentIdx + 1].minutes
                                                    // Đặt suggested vào đầu gap, hoặc now nếu now nằm trong gap
                                                    let nowMin   = TimelineEngine.currentMinutes()
                                                    if Calendar.current.isDateInToday(calendar.selectedDate) && nowMin > gapStart && nowMin < gapEnd {
                                                        suggestedMinutes = nowMin
                                                    } else {
                                                        suggestedMinutes = gapStart
                                                    }
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
                                                .padding(.leading, UIDevice.current.userInterfaceIdiom == .pad ? 128 : 108)
                                                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                                                .animation(.easeInOut(duration: 0.15), value: addButtonsIndex)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .opacity(isPastDate() ? 0.65 : 1)
                    .saturation(isPastDate() ? 0.6 : 1)
                    .allowsHitTesting(!isPastDate())
                    .overlay(alignment: .top) {
                        if isTimelineEmpty && !isPastDate() {
                            TimelineEmptyState(
                                onAddEvent: {
                                    suggestedMinutes = TimelineEngine.smartSlotMinutes(events: events, duration: 60)
                                    activeSheet = .createItem
                                },
                                onAddHabit: {
                                    showHabitSheet = true
                                }
                            )
                            .padding(.top, 80)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .background(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            
                            // Line không cần offset — tọa độ đã khớp Morning Start
                            TimelineLineView(
                                events: visibleEvents,
                                isDragging: isDragging,
                                date: calendar.selectedDate
                            )
                            .padding(.leading, UIDevice.current.userInterfaceIdiom == .pad ? 118 : 100)
                            
                            if visibleEvents.count > 1 &&
                                Calendar.current.isDateInToday(calendar.selectedDate) &&
                                TimelineLayoutEngine.isNowInsideTimeline(events: visibleEvents) {
                                TimeNowIndicator(time: TimelineEngine.formatTime(ticker.now))
                                    .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 85 : 70, alignment: .leading)
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
                .padding(.bottom, 400)
            }
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isPad ? 24 : 0)
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
        
            .onReceive(NotificationCenter.default.publisher(for: .preferencesDidChange)) { _ in
                TimelineLayoutEngine.updateDensity()
                reloadTimeline()
                // Reschedule habits khi habitReminders thay đổi
                let habitEnabled = PreferencesStore.shared.habitReminders
                UserDefaults.standard.set(habitEnabled, forKey: "notif_habit_ontime")
                for template in store.templates where template.kind == .habit && !template.isSystemEvent {
                    if habitEnabled {
                        NotificationManager.shared.scheduleRecurring(template: template)
                    } else {
                        NotificationManager.shared.cancelAll(templateID: template.id)
                    }
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .showPremiumPaywall)) { _ in
                showPremiumSheet = true
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
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
                    let prefs = PreferencesStore.shared
                    let suggested: Int = {
                        if let pinned = suggestedMinutes { return pinned }
                        if prefs.autoSuggestSlot {
                            return store.suggestFreeSlot(
                                date: calendar.selectedDate,
                                duration: prefs.defaultDuration,
                                includeHabits: true
                            )
                        }
                        let now = TimelineEngine.currentMinutes()
                        let wake = store.wakeMinutes
                        return max(now, wake)
                    }()

                    CreateItemSheet(
                        suggestedMinutes: suggested,
                        initialDate: calendar.selectedDate
                    )
                    .environmentObject(store)
                    .adaptiveSheet()
                    .onDisappear {
                        suggestedMinutes = nil
                        reloadTimeline()
                        addButtonsIndex = bestGapIndex()
                        ReviewManager.recordEventCreated()
                    }
                    
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
                    
                case .habitDetail(let event):
                    HabitDetailSheet(
                        event: event,
                        onDelete: {
                            store.deleteTemplate(event.id)
                            reloadTimeline()
                            addButtonsIndex = bestGapIndex()
                        }
                    )
                    .environmentObject(store)
                    .environmentObject(calendar)
                    .onDisappear {
                        reloadTimeline()
                    }
                    
                    
                    
                }
            }
            
            // MARK: Alert
            
            .alert(item: $activeAlert) { alert in
                
                switch alert {
                    
                case .deleteEvent(let event):
                    
                    return Alert(
                        title: Text(String(localized: "delete_event_title")),
                        message: Text(String(localized: "delete_event_message")),
                        primaryButton: .destructive(Text(String(localized: "delete_event_confirm"))) {
                            
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
                    
            
                }
            }
            .confirmationDialog(String(localized: "move_event_title"),
                                isPresented: $showRecurringDragDialog, titleVisibility: .visible) {
                Button(String(localized: "move_event_all_days")) {
                    if let (event, minutes) = pendingRecurringDrag {
                        store.updateEventTime(templateID: event.id, minutes: minutes)
                    }
                    reloadTimeline()
                    pendingRecurringDrag = nil
                }
                Button(String(localized: "move_event_today_only")) {
                    reloadTimeline()
                    pendingRecurringDrag = nil
                }
                Button(String(localized: "cancel"), role: .cancel) {
                    // tap ngoài cũng vào đây → revert
                    if let (event, _) = pendingRecurringDrag {
                        store.overrides.removeAll {
                            $0.templateID == event.id &&
                            $0.dateKey == store.key(for: calendar.selectedDate)
                        }
                        store.save()
                    }
                    reloadTimeline()
                    pendingRecurringDrag = nil
                }
            } message: {
                if let (event, _) = pendingRecurringDrag {
                    Text(recurringMessage(event))
                }
            }

            .confirmationDialog(
                String(localized: "system_event_change_title"),
                                
                            isPresented: $showSystemEventDialog, titleVisibility: .visible) {
                Button(String(localized: "move_event_all_days")) {
                    guard let event = pendingSystemChange else { return }
                    if event.systemType == .wake {
                        store.updateSystemEvents(wakeMinutes: min(pendingMinutes, store.sleepMinutes - 30), sleepMinutes: store.sleepMinutes)
                    } else if event.systemType == .sleep {
                        store.updateSystemEvents(wakeMinutes: store.wakeMinutes, sleepMinutes: max(pendingMinutes, store.wakeMinutes + 30))
                    }
                    store.overrides.removeAll {
                        $0.templateID == event.id &&
                        $0.dateKey == store.key(for: calendar.selectedDate)
                    }
                    store.rebuildIndex(); store.invalidateCache(); store.save()
                    reloadTimeline()
                    pendingSystemChange = nil
                }
                Button(String(localized: "apply_only_today")) {
                    guard let event = pendingSystemChange, !isPastDate() else { return }
                    store.overrideEvent(templateID: event.id, date: calendar.selectedDate, minutes: pendingMinutes)
                    NotificationManager.shared.cancel(templateID: event.id, date: calendar.selectedDate)
                    if let template = store.templates.first(where: { $0.id == event.id }) {
                        NotificationManager.shared.schedule(templateID: event.id, title: template.title, icon: template.icon, minutes: pendingMinutes, date: calendar.selectedDate, isHabit: false)
                    }
                    reloadTimeline()
                    pendingSystemChange = nil
                }
                Button(String(localized: "cancel"), role: .cancel) {
                    // tap ngoài cũng vào đây → revert
                    if let event = pendingSystemChange {
                        store.overrides.removeAll {
                            $0.templateID == event.id &&
                            $0.dateKey == store.key(for: calendar.selectedDate)
                        }
                        store.save()
                    }
                    reloadTimeline()
                    pendingSystemChange = nil
                }
            } message: {
                Text(String(localized: "recurring_change_scope_message"))
            }
            .confirmationDialog(
                String(localized: "change_duration_title"),
                                
                                isPresented: $showRecurringResizeDialog, titleVisibility: .visible) {
            Button(String(localized: "apply_all_days")) {
                    if let (event, duration) = pendingRecurringResize {
                        store.updateEventDuration(templateID: event.id, duration: duration)
                    }
                    reloadTimeline()
                    pendingRecurringResize = nil
                }
            Button(String(localized: "apply_only_today")) {
                    reloadTimeline()
                    pendingRecurringResize = nil
                }
            Button(String(localized: "cancel"), role: .cancel) {
                    if let (event, _) = pendingRecurringResize {
                        store.overrides.removeAll {
                            $0.templateID == event.id &&
                            $0.dateKey == store.key(for: calendar.selectedDate)
                        }
                        store.save()
                    }
                    reloadTimeline()
                    pendingRecurringResize = nil
                }
            } message: {
                if let (event, _) = pendingRecurringResize {
                    Text(recurringMessage(event))
                }
            }
            
            .sheet(isPresented: $showHabitSheet) {
                
                CreateHabitDetailSheet(
                    
                    onCreate: { title, icon, colorHex, date, type, target, unit, minutes, increment, repeatMode in
                        
                        let startMinutes = minutes ?? TimelineEngine.smartSlotMinutes(
                            events: events,
                            duration: 0,
                            habitFootprint: TimelineStore.habitOverlapFootprint
                        )
                        
                        // Map HabitRepeat → Recurrence
                        let recurrence: Recurrence = {
                            let cal = Calendar.current
                            switch repeatMode {
                            case .everyday:
                                return .daily

                            case .weekdays:
                                return .weekdays

                            case .oneDay:
                                return .once(date)

                            case .week:
                                let start = cal.startOfDay(for: date)
                                let end   = cal.startOfDay(for: cal.date(byAdding: .day, value: 6, to: start) ?? start)
                                return .dateRange(start, end)   // 7 ngày từ hôm nay

                            case .month:
                                let start = cal.startOfDay(for: date)
                                let end   = cal.startOfDay(for: cal.date(byAdding: .day, value: 29, to: start) ?? start)
                                return .dateRange(start, end)   // 30 ngày từ hôm nay
                            }
                        }()
                        
                        store.addHabit(
                            title: title,
                            icon: icon,
                            colorHex: colorHex,
                            minutes: startMinutes,
                            habitType: type,
                            targetValue: target,
                            unit: unit,
                            increment: increment,
                            recurrence: recurrence   // 👈 truyền recurrence đúng
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
                .environmentObject(store)
                .adaptiveSheet()
                .onDisappear {
                    reloadTimeline()        // ← thêm dòng này
                }
            }
            .overlay(alignment: .bottom) {
                if let undo = store.pendingUndo {
                    UndoToast(
                        title: undo.title,
                        onUndo: {
                            store.performUndo()
                            reloadTimeline()
                            addButtonsIndex = bestGapIndex()
                        },
                        onDismiss: {
                            store.clearPendingUndo()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.pendingUndo?.id)
        }
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
                    if let found = array.wrappedValue.first(where: { $0.id == id }) {
                        return found
                    }
                    // Element was removed between guard and get (concurrent mutation).
                    // Return any current element; SwiftUI will re-render and the safe()
                    // outer guard will then return nil, dropping the row.
                    if let any = array.wrappedValue.first { return any }
                    fatalError("Binding.safe: array emptied during read for id \(id)")
                },
                set: {
                    guard let idx = array.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
                    array.wrappedValue[idx] = $0
                }
            )
        }
    }
    
    extension View {
        func adaptiveSheet() -> some View {
            self
                .presentationDetents(
                    UIDevice.current.userInterfaceIdiom == .pad
                    ? [.large]
                    : [.fraction(0.85), .large]
                )
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .ifPad { $0.presentationSizing(.page) }
        }
    }
    
    extension View {
        @ViewBuilder
        func ifPad<Content: View>(_ transform: (Self) -> Content) -> some View {
            if UIDevice.current.userInterfaceIdiom == .pad {
                transform(self)
            } else {
                self
            }
        }
    }




extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
