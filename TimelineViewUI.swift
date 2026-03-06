



import SwiftUI

struct EventItem: Identifiable, Codable, Equatable {

    var id = UUID()

    var minutes: Int
    var duration: Int? = nil

    var title: String
    var icon: String

    var colorHex: String

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
                        }
                    )

                    if i < store.events.count - 1 {

        

                        let spacing = TimelineLayoutEngine.spacing(
                            current: store.events[i],
                            next: store.events[i + 1]
                        )
                        
                        let gapMinutes =
                            store.events[i + 1].minutes -
                            TimelineEngine.endMinute(store.events[i])
                        
                        VStack(spacing: 0) {

                            Spacer()
                                .frame(height: spacing / 2)

                            if addButtonsIndex == i {

                                VStack(spacing: 8) {

                                    AddEventButton()
                                    AddHabitButton()

                                }
                                .transition(.opacity)
                                .animation(isDragging ? nil : .easeInOut(duration: 0.15), value: spacing)
                                .transaction { t in
                                    t.animation = nil
                                                        }
                            }

                            Spacer()
                                .frame(height: spacing / 2)
                        }
                    }
                }



                Spacer(minLength: 120)
            }
            .transaction { t in
                if isDragging {
                    t.animation = nil
                }
            }
            .animation(.interactiveSpring(), value: store.events.map(\.minutes))
            .padding(.horizontal)
            .padding(.top, 30)
        }
        
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
        .padding(.top, 10)
        .onAppear {
            addButtonsIndex =
                TimelineEngine.largestGapIndex(
                    events: store.events
                )
        }
        
    }
}

struct DraggableEventRow: View {

    @Binding var event: EventItem
      let index: Int
      @Binding var events: [EventItem]
    @Binding var isDragging: Bool
    var onDragEnded: () -> Void
      @State private var dragOffset: CGFloat = 0

    var body: some View {

        TimelineEventRow(
            time: event.time,
            endTime: event.endTime,
            title: event.title,
            icon: event.icon,
            color: event.color
        )
        .frame(
            height: TimelineLayoutEngine.eventHeight(event)
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in

                    isDragging = true
                    dragOffset = value.translation.height

                    let newMinutes = TimelineEngine.move(
                        event: event,
                        index: index,
                        events: events,
                        translation: value.translation.height
                    )

                    event.update(minutes: newMinutes)
                }
                .onEnded { _ in

                    dragOffset = 0
                    isDragging = false

                    onDragEnded()
                }
        )
        .animation(.spring(), value: dragOffset)
    }
}


struct TimelineEventRow: View {

    let time: String
    let endTime: String?   // 👈 thêm
    let title: String
    let icon: String
    let color: Color

    var body: some View {

        HStack(alignment: .center, spacing: 8) {

            // TIME COLUMN
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

            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width:50,height:50)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(color)
                )
                .offset(x: -4)

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

            Spacer()

            Circle()
                .stroke(color,lineWidth:3)
                .frame(width:28,height:28)
        }
    }
}



struct TabItem: View {

    let icon:String
    let title:String
    var active:Bool = false

    var body: some View {

        VStack(spacing:4){

            Image(systemName:icon)

            Text(title)
                .font(.caption)
        }
        .foregroundStyle(active ? Color.orange : Color.black)
        .frame(maxWidth:.infinity)
    }
}

