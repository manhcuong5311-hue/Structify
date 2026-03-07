



import SwiftUI

struct EventItem: Identifiable, Codable, Equatable {

    var id = UUID()

    var minutes: Int
    var duration: Int? = nil

    var title: String
    var icon: String

    var colorHex: String
    var isSystemEvent: Bool = false 
    // MARK: - Computed

    var time: String {
        TimelineEngine.formatTime(minutes)
    }

    var endTime: String? {
        guard let duration else { return nil }
        return TimelineEngine.formatTime(minutes + duration)
    }

    // MARK: - Helpers

   

    mutating func update(minutes: Int) {
        self.minutes = minutes
    }

    // Color convert

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




extension Color {

    init(hex: String) {

        let hex = hex.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: hex)

        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}





struct TimelineView: View {

    @StateObject private var store = TimelineStore()

    @State private var addButtonsIndex: Int?
    @State private var isDragging = false

    @State private var activeSheet: AppSheet?
    @State private var activeAlert: AppAlert?

    var body: some View {

        ScrollView {

            VStack(alignment: .leading) {

                ForEach($store.events.indices, id: \.self) { i in

                    DraggableEventRow(
                        event: $store.events[i],
                        index: i,
                        events: $store.events,
                        isDragging: $isDragging,
                        onDragEnded: {

                            addButtonsIndex =
                            TimelineEngine.largestGapIndex(
                                events: store.events
                            )
                        },
                        onTapEvent: { event in
                            guard !event.isSystemEvent else { return }
                            activeSheet = .eventDetail(event)
                        }
                    )

                    if i < store.events.count - 1 {

                        let spacing = TimelineLayoutEngine.spacing(
                            current: store.events[i],
                            next: store.events[i + 1]
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
                value: store.events.map(\.minutes)
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

            addButtonsIndex =
            TimelineEngine.largestGapIndex(
                events: store.events
            )
        }

        // MARK: Sheet

        .sheet(item: $activeSheet) { sheet in

            switch sheet {

            case .createItem:

                CreateItemSheet { kind, title, icon in
                    print(kind, title, icon)
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
                        
                        store.events.removeAll {
                            $0.id == event.id
                        }

                    },
                    secondaryButton: .cancel()
                )
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
                onTapEvent(event)
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

                event.update(minutes: newMinutes)
            },

            onDragEnded: {

              
                
                dragOffset = 0
                isDragging = false
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
