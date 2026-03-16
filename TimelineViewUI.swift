



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
    @State private var suggestedMinutes: Int? = nil
    private var brand: Color { Color(hex: PreferencesStore().accentHex) }
    @State private var showPremiumSheet = false
    
    
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
        case .once:      return false
        case .dateRange: return false  // 👈 không hỏi scope vì chỉ là range cố định
        default:         return true
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
        case .dateRange(let start, let end):
            let f = DateFormatter(); f.dateFormat = "d MMM"
            return "Repeats \(f.string(from: start)) – \(f.string(from: end))."
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
    
    
    
    // Sửa func indicatorTouchesEvent — truyền visibleEvents:
    func indicatorTouchesEvent(_ index: Int) -> Bool {
        let visible = events.filter { $0.duration != 1440 }
        let now = self.now
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
            return "A quiet hour — worth filling"
        case 120..<180:
            return "Two hours with nowhere to be"
        case 180..<240:
            return "Three hours, no excuses"
        case 240..<360:
            return "A good chunk of the day"
        case 360..<480:
            return "Half a workday, unspoken for"
        case 480..<600:
            return "The better part of a morning"
        case 600..<720:
            return "Ten hours of open road"
        case 720..<840:
            return "Nearly half a day, untouched"
        case 840..<960:
            return "A generous stretch of nothing"
        case 960...:
            return "The whole day is yours"
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
                    let prefs = PreferencesStore()
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
                                            activeAlert = .systemEventChange(liveEvent, liveEvent.minutes)
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
                                            activeAlert = .recurringTimeChange(liveEvent, liveEvent.minutes)
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
                                        // Hỏi scope nếu có pending recurring resize
                                        if let e = pendingSystemChange, !e.isSystemEvent {
                                            activeAlert = .recurringDurationChange(e, pendingMinutes)
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
                                TimeNowIndicator(time: TimelineEngine.formatTime(now))
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
                let habitEnabled = PreferencesStore().habitReminders
                UserDefaults.standard.set(habitEnabled, forKey: "notif_habit_ontime")
                for template in store.templates where template.kind == .habit && !template.isSystemEvent {
                    if habitEnabled {
                        NotificationManager.shared.scheduleRecurring(template: template)
                    } else {
                        NotificationManager.shared.cancelAll(templateID: template.id)
                    }
                }
            }
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
                    let prefs = PreferencesStore()
                    let suggested: Int = {
                        if let pinned = suggestedMinutes { return pinned }
                        if prefs.autoSuggestSlot {
                            return store.suggestFreeSlot(
                                date: calendar.selectedDate,
                                duration: prefs.defaultDuration
                            )
                        }
                        // Auto-suggest tắt → dùng current time hoặc wake time
                        let now = TimelineEngine.currentMinutes()
                        let wake = store.wakeMinutes
                        return max(now, wake)
                    }()
                    
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
                        ReviewManager.recordEventCreated()
                    }
                    .adaptiveSheet()
                    .onDisappear {
                        suggestedMinutes = nil
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
                            guard !isPastDate() else { return }

                            store.overrideEvent(
                                templateID: event.id,
                                date: calendar.selectedDate,
                                minutes: minutes
                            )

                            // 👇 Reschedule chỉ ngày hôm nay
                            NotificationManager.shared.cancel(templateID: event.id, date: calendar.selectedDate)
                            if let template = store.templates.first(where: { $0.id == event.id }) {
                                NotificationManager.shared.schedule(
                                    templateID: event.id,
                                    title: template.title,
                                    icon: template.icon,
                                    minutes: minutes,
                                    date: calendar.selectedDate,
                                    isHabit: false
                                )
                            }

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
                    
                    onCreate: { title, icon, colorHex, date, type, target, unit, minutes, increment, repeatMode in
                        
                        let startMinutes = minutes ?? TimelineEngine.smartSlotMinutes(
                            events: events, duration: 0
                        )
                        
                        // Map HabitRepeat → Recurrence
                        let recurrence: Recurrence = {
                            let cal = Calendar.current
                            switch repeatMode {
                            case .everyday:
                                return .daily
                                
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
                
            }
            
            
            
            
            
            
        }
    }
    
    
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
            let id = event.id  // 👈 dùng event binding trực tiếp, không qua events[index]
            
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
                return "Habit"
            }
            switch t.recurrence {
            case .daily:     return "Everyday"
            case .weekdays:  return "Weekdays"
            case .specific(let days):
                let s = Calendar.current.shortWeekdaySymbols
                return days.sorted().map { s[$0-1] }.joined(separator: ", ")
            case .once:      return "1 Day"
            case .dateRange(let start, let end):
                let cal = Calendar.current
                let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
                if days <= 6  { return "1 Week" }   // 👈 sửa 7 → 6
                if days <= 31 { return "1 Month" }
                let f = DateFormatter(); f.dateFormat = "d MMM"
                return "\(f.string(from: start)) – \(f.string(from: end))"
            }
        }
        
        
        
        
        
        
        func isPastEvent() -> Bool {
            guard Calendar.current.isDateInToday(calendar.selectedDate) else {
                // Ngày khác → dùng isPastDate từ TimelineView
                return false
            }
            let now = TimelineEngine.currentMinutes()
            // Event đã kết thúc hoàn toàn
            if let duration = event.duration {
                return event.minutes + duration < now
            }
            // Habit không có duration → đã qua start time
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
                
                // TÌM trong commitSwap — thêm check isRunning:
                if isToday {
                    let endMin = e.minutes + (e.duration ?? 0)
                    if endMin < nowMin { continue }
                    if e.minutes < nowMin && e.duration == nil { continue }
                    // 👈 thêm: skip running events
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
        
        // Thêm helper — dùng chung cho cả 2 chiều swap:
        func isEventLocked(_ e: EventItem) -> Bool {
            guard !e.isSystemEvent else { return true }
            guard Calendar.current.isDateInToday(calendar.selectedDate) else { return false }
            let now = TimelineEngine.currentMinutes()
            if let d = e.duration {
                return e.minutes + d <= now   // past hoặc running đều lock
            }
            return e.minutes < now           // habit đã qua start
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
                    
                    // Habit: chỉ chặn nếu là past date (ngày khác), không chặn past time
                    if isHabit {
                        guard isToday || !isLocked else { return }
                    } else {
                        guard !isLocked else { return }
                    }
                    
                    let template = store.templates.first { $0.id == event.id }
                    
                    if template?.habitType == .accumulative {
                        guard !store.isCompleted(templateID: event.id, date: calendar.selectedDate) else { return } // 👈 khoá
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
                    
                    // Haptic: medium khi done, light khi increment
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
                    if dragOffsetX > 65 {
                        isReordering = true
                    }
                    
                    
                    
                    if abs(dragOffsetY) > 80 {
                        nearSwapTarget = true
                    } else {
                        nearSwapTarget = false
                    }
                    
                    
                    // TÌM toàn bộ khối if isReordering { ... } — THAY HOÀN TOÀN:
                    if isReordering {
                        
                        let swapThreshold: CGFloat = 75   // giảm từ 60 → dễ swap hơn
                        let resetThreshold: CGFloat = 20
                        let cooldown: TimeInterval = 0.15
                        let dragY = dragOffsetY
                        let now = Date()
                        
                        guard now.timeIntervalSince(lastSwapTime) > cooldown else { return }
                        
                        guard let liveIdx = events.firstIndex(where: { $0.id == event.id }) else { return }
                        
                        // SWAP XUỐNG
                        if dragY > swapThreshold && liveIdx < events.count - 1 {
                            let next = liveIdx + 1
                            let target = events[next]
                            
                            if !isEventLocked(target) && lastSwapIndex != next {
                                lastSwapIndex = next
                                lastSwapTime = now
                                
                                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                                    // Hoán đổi minutes
                                    let aMin = events[liveIdx].minutes
                                    let bMin = events[next].minutes
                                    
                                    // Đảm bảo minutes không trùng nhau sau swap
                                    let newA = min(aMin, bMin)
                                    let newB = max(aMin, bMin)
                                    
                                    events[liveIdx].update(minutes: newB)
                                    events[next].update(minutes: newA)
                                    
                                    // Re-sort để giữ visual order đúng
                                    events.sort { $0.minutes < $1.minutes }
                                }
                                
                                commitSwap()
                                swapHaptic.impactOccurred()
                                
                                // Reset để cho phép swap tiếp ngay
                                DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                                    lastSwapIndex = -1
                                }
                            }
                        }
                        
                        // SWAP LÊN
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
                        
                        // Reset khi gần trung tâm
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
        let isNowApproachingStart: Bool
        let nearSwapTarget: Bool
        let durationPreview: String?
        let startMinutes: Int
        let isCompleted: Bool
        let isSystemEvent: Bool
        var recurrenceLabel: String = "Daily habit"
        var progressFraction: CGFloat = 0        // 👈 thêm
        var incrementValue: Double = 1
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
            
            let brand = Color(hex: PreferencesStore().accentHex)
            
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
            guard isToday, let d = durationMinutes else { return false }
            let now = TimelineEngine.currentMinutes()
            let end = startMinutes + d
            // Ẩn end time trong 10 phút cuối
            return now >= end - 10 && now <= end + 2
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
            
            // Khi đang chạy → show còn bao lâu
            if isRunning() && isToday {
                let now = TimelineEngine.currentMinutes()
                let remaining = (startMinutes + durationMinutes) - now
                if remaining > 0 {
                    let h = remaining / 60
                    let m = remaining % 60
                    if h > 0 && m > 0 { return "\(h)h \(m)m left" }
                    else if h > 0 { return "\(h)h left" }
                    else { return "\(m)m left" }
                }
            }
            
            let h = durationMinutes / 60
            let m = durationMinutes % 60
            if h > 0 && m > 0 { return "\(h)h \(m)m" }
            else if h > 0 { return "\(h)h" }
            else { return "\(m)m" }
        }
        
        // TÌM và THAY TOÀN BỘ func isNowNearStartTime:
        private func isNowNearStartTime() -> Bool {
            guard isToday else { return false }
            if isNowApproachingStart { return true }   // pixel-based, đến gần 30pt thì ẩn
            guard let d = durationMinutes else { return false }
            let now = TimelineEngine.currentMinutes()
            return now >= startMinutes && now <= startMinutes + d  // đang trong event
        }
        
        
        
        
        
        
        
        
        
        var body: some View {
            
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            
            
            HStack(alignment: .center, spacing: isPad ? 8 : 4) {
                
                let ph = pillHeight(durationMinutes: durationMinutes)
                
                // 2. Đổi ZStack sang .topLeading
                ZStack(alignment: .topLeading) {
                    
                    // Start time — TOP
                    Text(time)
                        .font(.system(
                            size: isPad ? 15 : 13,
                            weight: .semibold,
                            design: .rounded
                        ))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .opacity(isNowNearStartTime() ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isNowNearStartTime())
                    
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
                .frame(width: isPad ? 85 : 70, height: ph, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
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
                    isToday: isToday,
                    progressFraction: progressFraction,
                    isAccumulative: kind == .habit && incrementValue > 0
                )
                .offset(x: -0.5)
                
                
                
                VStack(alignment: .leading, spacing: 2) {
                    
                    // Title + recurrence badge cùng hàng
                    HStack(alignment: .center, spacing: 6) {
                        Text(title)
                            .font(isPad ? .title3.weight(.semibold) : .headline)
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
                        
                        if kind == .habit {
                            Text(recurrenceLabel)
                                .font(.system(size: isPad ? 12 : 10, weight: .semibold))
                                .foregroundStyle(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(color.opacity(0.12)))
                                .fixedSize()
                                .opacity(isCompleted ? 0.45 : 1)
                        }
                    }
                    
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
                    
                    if isRunning() && hasDuration {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(color.opacity(0.6))
                                    .frame(width: geo.size.width * progress(), height: 3)
                                    .animation(.linear(duration: 30), value: progress())
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap?()
                }
                .gesture(
                    DragGesture().onChanged { _ in }
                )
                
                Spacer()
                
                FlyingIncrementButton(
                    color: color,
                    isCompleted: isCompleted,
                    isAccumulative: kind == .habit && incrementValue > 0,
                    incrementValue: incrementValue,
                    onTap: { onToggleComplete?() }
                )
                
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
    
    struct FlyingIncrementButton: View {
        let color: Color
        let isCompleted: Bool
        let isAccumulative: Bool
        let incrementValue: Double
        let onTap: () -> Void
        
        @State private var flyItems: [(id: UUID, offset: CGFloat, opacity: Double, scale: CGFloat)] = []
        
        func formatIncrement(_ v: Double) -> String {
            v.truncatingRemainder(dividingBy: 1) == 0 ? "+\(Int(v))" : String(format: "+%.1f", v)
        }
        
        let btnSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28
        
        var body: some View {
            ZStack {
                
                Button {
                    guard !(isAccumulative && isCompleted) else { return }
                    onTap()
                    guard isAccumulative && !isCompleted else { return }
                    let id = UUID()
                    flyItems.append((id: id, offset: 0, opacity: 1, scale: 1))
                    withAnimation(.easeOut(duration: 0.55)) {
                        if let i = flyItems.firstIndex(where: { $0.id == id }) {
                            flyItems[i].offset  = -36
                            flyItems[i].opacity = 0
                            flyItems[i].scale   = 1.3
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        flyItems.removeAll { $0.id == id }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? color.opacity(0.25) : Color.clear)
                            .frame(width: btnSize, height: btnSize)
                            .animation(.easeInOut(duration: 0.2), value: isCompleted)
                        Circle()
                            .stroke(color.opacity(0.8), lineWidth: 2)
                        AnimatedCheckmark(progress: isCompleted ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
                
                ForEach(flyItems, id: \.id) { item in
                    Text(formatIncrement(incrementValue))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .scaleEffect(item.scale)
                        .offset(y: item.offset)
                        .opacity(item.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: btnSize, height: btnSize)
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
        let progressFraction: CGFloat   // 0...1
        let isAccumulative: Bool
        
        @Environment(\.colorScheme) private var scheme
        
        // Chiều cao pill scale theo duration
        private var pillHeight: CGFloat {
            guard let d = durationMinutes else { return 50 }
            // 15 phút → 50pt, 60 phút → 80pt, 120 phút → 110pt, cap 130pt
            let h = 50 + CGFloat(d - 15) * (80.0 / 105.0)
            return min(max(h, 50), 130)
        }
        
        
        var brandRing: Color {
            let brand = Color(hex: PreferencesStore().accentHex)
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
        
        
        private var pillWidth: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 60 : 50
        }
        
        
        
        var body: some View {
            Group {
                if kind == .habit {
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
                        
                        // Progress ring cho accumulative
                        if isAccumulative {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                                .frame(width: 56, height: 56)
                            
                            Circle()
                                .trim(from: 0, to: progressFraction)
                                .stroke(
                                    isCompleted ? Color.green : Color.white,
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 56, height: 56)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progressFraction)
                        }
                    }
                    .frame(width: pillWidth, height: pillWidth)
                    
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


