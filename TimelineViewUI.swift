



import SwiftUI






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
    
    var body: some View {

        
        
        ScrollView {
            
           
            VStack(alignment: .leading) {
                


                ForEach(Array(events.enumerated()), id: \.element.id) { i, _ in

                    DraggableEventRow(
                        event: $events[i],
                        index: i,
                        events: $events,
                        isDragging: $isDragging,
                        onDragEnded: {

                            let event = events[i]

                            store.overrideEventTime(
                                templateID: event.id,
                                date: calendar.selectedDate,
                                minutes: event.minutes
                            )
                            
                            addButtonsIndex =
                            TimelineEngine.largestGapIndex(
                                events: events
                            )
                        },
                        onTapEvent: { event in
                            guard !event.isSystemEvent else { return }
                            activeSheet = .eventDetail(event)
                        }
                    )

                    if i < events.count - 1 {

                        let spacing = TimelineLayoutEngine.spacing(
                            current: events[i],
                            next: events[i + 1]
                        )
                    

                        VStack(spacing: 0) {

                            Spacer()
                                .frame(height: spacing / 2)

                            if addButtonsIndex == i {

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

                Spacer(minLength: 120)
            }
            .background(alignment: .leading) {

                TimelineLineView(
                    events: events,
                    isDragging: isDragging
                )
                .padding(.leading, 100)
            }
            .transaction { t in
                if isDragging { t.animation = nil }
                
            }
            .animation(nil, value: isDragging)
            .animation(
                .interactiveSpring(),
                value: events.map(\.minutes)
            )
            .padding(.horizontal)
            .padding(.top, 30)
        }

        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    scheme == .dark
                    ? Color(.systemBackground)
                    : Color(red: 0.992, green: 0.991, blue: 0.985)
                )
                .shadow(
                    color: scheme == .dark
                    ? .clear
                    : .black.opacity(0.05),
                    radius: 10
                )
        )
       
        
        .padding(.bottom, -20)
        .ignoresSafeArea(edges: .bottom)

        .onAppear {

            events = store.events(for: calendar.selectedDate)

            addButtonsIndex =
            TimelineEngine.largestGapIndex(
                events: events
            )
        }
        .onChange(of: calendar.selectedDate) { _, newDate in

            events = store.events(for: newDate)

            addButtonsIndex =
            TimelineEngine.largestGapIndex(events: events)
        }
        // MARK: Sheet

        .sheet(item: $activeSheet) { sheet in

            switch sheet {

            case .createItem:

                let suggested =
                TimelineEngine.suggestedStartMinutes(events: events)

                CreateEventDetailSheet(
                    suggestedStart: suggested,
                    onOpenHabit: {

                        activeSheet = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showHabitSheet = true
                        }
                    }
                ) { title, icon, date, duration in

                    let minutes = TimelineEngine.minutes(from: date)

                    store.addEvent(
                        title: title,
                        icon: icon,
                        minutes: minutes,
                        duration: duration
                    )

                    events = store.events(for: calendar.selectedDate)

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

                        events = store.events(for: calendar.selectedDate)

                        addButtonsIndex =
                            TimelineEngine.largestGapIndex(events: events)
                    },
                    secondaryButton: .cancel()
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

                    store.addEvent(
                        title: title,
                        icon: icon,
                        minutes: startMinutes,
                        duration: nil
                    )

                    events = store.events(for: calendar.selectedDate)

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

    @Binding var event: EventItem

    let index: Int
    
    @Binding var events: [EventItem]
    @Binding var isDragging: Bool

    var onDragEnded: () -> Void
    var onTapEvent: (EventItem) -> Void

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
    
    
    var body: some View {

        TimelineEventRow(
            time: event.time,
            endTime: event.endTime,
            title: event.title,
            icon: event.icon,
            color: event.color,
            kind: event.kind,
            isHolding: isHolding && !event.isSystemEvent,
            
            onTap: {
                if !event.isSystemEvent {
                    onTapEvent(event)
                }
            },
            

            onDragChanged: { value in


                isDragging = true
                dragOffsetY = value.translation.height

                let newMinutes = TimelineEngine.move(
                    event: event,
                    index: index,
                    events: events,
                    translation: value.translation.height
                )
                
                

                event.update(minutes: max(0, min(newMinutes, 1440)))
                
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
                
            },

            onDragEnded: {

                dragOffsetY = 0
                isDragging = false

                morningTriggered = false
                nightTriggered = false
                
                didSnapMorning = false
                didSnapNight = false

                onDragEnded()
            }
        )
        .frame(height: TimelineLayoutEngine.eventHeight(event))
        .offset(x: dragOffsetX, y: dragOffsetY)
        .scaleEffect(isHolding ? 1.05 : 1)
        .shadow(
            color: isHolding ? .black.opacity(0.25) : .clear,
            radius: 8
        )
        .animation(.interactiveSpring(response:0.22,dampingFraction:0.92), value: dragOffsetX)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in

                    guard !event.isSystemEvent else { return }

                    swapHaptic.prepare()

                    withAnimation(.spring()) {
                        isHolding = true
                    }

                    UIImpactFeedbackGenerator(style:.medium).impactOccurred()
                }
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    
                    // system events vẫn drag bình thường
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

                                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                                    let temp = events[index].minutes
                                    events[index].update(minutes: events[next].minutes)
                                    events[next].update(minutes: temp)

                                    events.swapAt(index, next)
                                }

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
                        
                        event.update(minutes: max(0, min(newMinutes, 1440)))
                    }
                }
                .onEnded { _ in
                    
                    dragOffsetX = 0
                    dragOffsetY = 0
                    isHolding = false
                    isReordering = false
                    isDragging = false
                    
                    lastSwapIndex = -1
                    
                    onDragEnded()
                }
        )
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
    
    var onTap: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    var body: some View {

        HStack(alignment: .center, spacing: 8) {

            VStack(alignment: .leading, spacing: 2) {

                Text(time)
                    .font(.system(size:15, weight:.semibold, design:.rounded))
                    .monospacedDigit()

                if let endTime {
                    Text(endTime)
                        .font(.system(size:12, weight:.medium, design:.rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.gray)
            .frame(width:70, alignment:.leading)

            // 👇 DRAG HANDLE
            ZStack {

                // base glow
                Circle()
                    .fill(color.opacity(0.18))

                // gradient layer
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.9),
                                color.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(6)

                // icon
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size:18, weight:.bold))
                        .foregroundStyle(.white)
                    
                    if isHolding {
                        Image(systemName:"arrow.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                            .offset(x:28)
                            .transition(.move(edge:.leading).combined(with:.opacity))
                    }
                }
                
                if kind == .habit {

                     Image(systemName: "repeat")
                         .font(.system(size:8, weight:.bold))
                         .padding(4)
                         .background(.ultraThinMaterial)
                         .clipShape(Circle())
                         .offset(x:14,y:14)
                 }
                
            }
            .frame(width:50,height:50)
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
            .offset(x: -4)
               

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.headline)

                HStack(spacing:6){

                    if kind == .habit {
                        Image(systemName:"repeat")
                        Text("Habit")
                    } else {
                        Text(time)
                    }
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onDragChanged?(value)
                    }
                    .onEnded { _ in
                        onDragEnded?()
                    }
            )

            Spacer()

            Circle()
                .stroke(color,lineWidth:3)
                .frame(width:28,height:28)
        }
    }
}
