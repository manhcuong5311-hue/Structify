



import SwiftUI

struct EventItem: Identifiable, Codable, Equatable {

    // ID phải là templateID
    let id: UUID
    
    var kind: EventKind

    var minutes: Int
    var duration: Int? = nil

    var title: String
    var icon: String
    var colorHex: String

    var isSystemEvent: Bool = false

    // MARK: Computed

    var time: String {
        TimelineEngine.formatTime(minutes)
    }

    var endTime: String? {
        guard let duration else { return nil }
        return TimelineEngine.formatTime(minutes + duration)
    }

    // MARK: Update

    mutating func update(minutes: Int) {
        self.minutes = minutes
    }

    // MARK: Color

    var color: Color {
        Color(hex: colorHex)
    }
}

enum EventKind: String, Codable {
    case event
    case habit
}
enum HabitCompletionType: String, Codable {
    case binary
    case accumulate
}





struct TimelineView: View {

    @EnvironmentObject var store: TimelineStore

    @State private var addButtonsIndex: Int?
    @State private var isDragging = false

    @State private var activeSheet: AppSheet?
    @State private var showHabitSheet = false
    
    
    @State private var activeAlert: AppAlert?
    
    @State private var events: [EventItem] = []

    @EnvironmentObject var calendar: CalendarState
    
    
    
    var body: some View {

        ScrollView {

            VStack(alignment: .leading) {

                ForEach(events.indices, id: \.self)  { i in

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
            .transaction { t in
                if isDragging { t.animation = nil }
            }
            .animation(
                .interactiveSpring(),
                value: events.map(\.minutes)
            )
            .padding(.horizontal)
            .padding(.top, 30)
        }

        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10)
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

                        events.removeAll { $0.id == event.id }

                    },
                    secondaryButton: .cancel()
                )
            }
        }
        
        .sheet(isPresented: $showHabitSheet) {

            CreateHabitDetailSheet { title, icon, date in

                let minutes = TimelineEngine.minutes(from: date)

                store.addEvent(
                    title: title,
                    icon: icon,
                    minutes: minutes,
                    duration: nil
                )

                events = store.events(for: calendar.selectedDate)

                addButtonsIndex =
                TimelineEngine.largestGapIndex(events: events)
            }
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

    @State private var dragOffset: CGFloat = 0

    var body: some View {

        TimelineEventRow(
            time: event.time,
            endTime: event.endTime,
            title: event.title,
            icon: event.icon,
            color: event.color,

            onTap: {
                if !event.isSystemEvent {
                    onTapEvent(event)
                }
            },
            

            onDragChanged: { value in


                isDragging = true
                dragOffset = value.translation.height

                let newMinutes = TimelineEngine.move(
                    event: event,
                    index: index,
                    events: events,
                    translation: value.translation.height
                )

                event.update(minutes: max(0, min(newMinutes, 1440)))
            },

            onDragEnded: {

                dragOffset = 0
                isDragging = false

                events.sort { $0.minutes < $1.minutes }

                onDragEnded()
            }
        )
        .frame(height: TimelineLayoutEngine.eventHeight(event))
        .offset(y: dragOffset)
        .animation(.spring(), value: dragOffset)
    }
}

struct TimelineEventRow: View {

    let time: String
    let endTime: String?
    let title: String
    let icon: String
    let color: Color
    var onTap: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    var body: some View {

        HStack(alignment: .center, spacing: 8) {

            VStack(alignment: .leading, spacing: 2) {

                Text(time)
                    .font(.subheadline)

                if let endTime {
                    Text(endTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.gray)
            .frame(width:60, alignment: .leading)

            // 👇 DRAG HANDLE
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width:50,height:50)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(color)
                )
                .offset(x: -4)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDragChanged?(value)
                        }
                        .onEnded { _ in
                            onDragEnded?()
                        }
                )

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.headline)

                HStack(spacing:6){
                    Image(systemName:"repeat")
                    Text(time)
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            Spacer()

            Circle()
                .stroke(color,lineWidth:3)
                .frame(width:28,height:28)
        }
    }
}
