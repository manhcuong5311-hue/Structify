



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
        Self.format(minutes)
    }

    var endTime: String? {
        guard let duration else { return nil }
        return Self.format(minutes + duration)
    }

    // MARK: - Helpers

    static func format(_ minutes: Int) -> String {

        let h = minutes / 60
        let m = minutes % 60

        return String(format: "%02d:%02d", h, m)
    }

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

    var body: some View {

    

        ScrollView {

            VStack(alignment: .leading) {

                ForEach(Array(store.events.indices), id: \.self) { i in
                    
                    DraggableEventRow(
                        event: $store.events[i],
                        index: i,
                        events: $store.events
                    )

                    if i < store.events.count - 1 {

                        let diff = store.events[i + 1].minutes - store.events[i].minutes

                        let spacing = max(
                            4,
                            min(
                                60,
                                diff < 15
                                ? CGFloat(diff) * 0.8
                                : CGFloat(diff) * 0.25
                            )
                        )
                        
                        VStack(spacing: 0) {

                            Spacer()
                                .frame(height: spacing / 2)

                            AddEventButton()
                                .opacity(spacing > 40 ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: spacing)
                                .transaction { t in
                                    t.animation = nil
                                }

                            Spacer()
                                .frame(height: spacing / 2)
                        }
                    }
                }



                Spacer(minLength: 120)
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
    }
}

struct DraggableEventRow: View {

    @Binding var event: EventItem
      let index: Int
      @Binding var events: [EventItem]

      @State private var dragOffset: CGFloat = 0

    var body: some View {

        TimelineEventRow(
            time: event.time,
            endTime: event.endTime,
            title: event.title,
            icon: event.icon,
            color: event.color
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in

                    dragOffset = value.translation.height

                    let minuteChange = Int(value.translation.height / 2)
                    let snapStep = 5

                    var newMinutes = event.minutes + minuteChange

                    // timeline clamp
                    newMinutes = max(0, min(1439, newMinutes))

                    // tránh đè event trước
                    if index > 0 {
                        let previousLimit = events[index - 1].minutes + 5
                        newMinutes = max(newMinutes, previousLimit)
                    }

                    // tránh đè event sau
                    if index < events.count - 1 {
                        let nextLimit = events[index + 1].minutes - 5
                        newMinutes = min(newMinutes, nextLimit)
                    }

                    // snap 5 phút
                    newMinutes = (newMinutes / snapStep) * snapStep

                    event.update(minutes: newMinutes)
                }
                .onEnded { _ in
                    dragOffset = 0
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

struct AddEventButton: View {

    var body: some View {

        HStack {

            Spacer()

            HStack(spacing:8){

                Image(systemName:"plus.circle.fill")

                Text("Thêm việc")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal,18)
            .padding(.vertical,10)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )

            Spacer()
        }
    }
}

struct BottomBar: View {

    var body: some View {

        HStack {

            TabItem(icon:"tray",title:"Hộp thư")

            TabItem(icon:"list.bullet",title:"Lịch trình",active:true)

            TabItem(icon:"sparkles",title:"AI")

            TabItem(icon:"gearshape",title:"Cài đặt")

            Circle()
                .fill(Color.orange)
                .frame(width:56,height:56)
                .overlay(
                    Image(systemName:"plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                )
        }
        .padding(.horizontal)
        .padding(.top,12)
        .padding(.bottom,20)
        .background(.ultraThinMaterial)
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
