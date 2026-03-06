import SwiftUI




struct TimelineView: View {

    @State var events: [EventItem] = [
        EventItem(time:"06:00", title:"Rise and Shine", icon:"alarm.fill", color:.orange),
        EventItem(time:"12:30", title:"Lunch", icon:"fork.knife", color:.green),
        EventItem(time:"23:30", title:"Wind Down", icon:"moon.fill", color:.blue)
    ]

    var body: some View {

    

        ScrollView {

            VStack(alignment: .leading) {

                ForEach($events.indices, id: \.self) { i in

                    DraggableEventRow(event: $events[i])

                    if i < events.count - 1 {

                        let diff =
                        events[i + 1].minutes - events[i].minutes

                        let spacing = min(max(CGFloat(diff) * 0.05, 16), 60)

                        Spacer()
                            .frame(height: spacing)
                    }
                }

                AddEventButton()

                Spacer(minLength: 120)
            }
            .animation(.spring(response: 0.35), value: events)
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

    @State private var dragOffset: CGFloat = 0

    var body: some View {

        TimelineEventRow(
            time: event.time,
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
                    newMinutes = max(0, min(1439, newMinutes))

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
    let title: String
    let icon: String
    let color: Color

    var body: some View {

        HStack(alignment: .center, spacing: 16) {

            Text(time)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .frame(width:60, alignment: .leading)

            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width:50,height:50)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(color)
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
