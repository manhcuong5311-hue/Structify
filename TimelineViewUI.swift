import SwiftUI




struct TimelineView: View {

    var body: some View {

        ScrollView {

            VStack(spacing: 40) {

                TimelineEventRow(
                    time: "06:00",
                    title: "Rise and Shine",
                    icon: "alarm.fill",
                    color: .orange
                )

                AddEventButton()

                TimelineEventRow(
                    time: "23:30",
                    title: "Wind Down",
                    icon: "moon.fill",
                    color: .blue
                )

                Spacer(minLength: 200)
            }
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
