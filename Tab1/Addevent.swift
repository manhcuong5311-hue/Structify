
import SwiftUI

struct AddEventButton: View {
    
    var action: () -> Void
    
    var body: some View {
        
        Button(action: action) {
            
            HStack(spacing:6) {
                
                Image(systemName: "plus.circle.fill")
                
                Text("Add Event")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal,12)
            .padding(.vertical,6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }
}

struct CreateEventDetailSheet: View {

    // MARK: - Event Data

    @State private var title: String = ""

    @State private var icon: String = "@"
    @State private var color: Color = .blue

    @State private var date: Date = Date()

    @State private var startHour: Int = 20
    @State private var startMinute: Int = 0

    @State private var endHour: Int = 21
    @State private var endMinute: Int = 30

    @State private var duration: Double = 1.5

    
    @Environment(\.dismiss) private var dismiss
      
      let onCreate: (String,String,Date,Int) -> Void
      let suggestedStart: Int
      
      
      @State private var selectedDate = Date()
      @State private var startTime = Date()
      
      @State private var durationMinutes: Int = 60
      
      let presets = [30,60,90,120]
      
    @State private var showIconPicker = false
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
      init(
          suggestedStart: Int,
          onCreate: @escaping (String,String,Date,Int) -> Void
      ) {
          
          self.suggestedStart = suggestedStart
          self.onCreate = onCreate
          
          _startTime = State(
              initialValue:
                  TimelineEngine.dateFrom(
                      minutes: suggestedStart,
                      base: Date()
                  )
          )
      }
    
    
    
    // MARK: - Body

    var body: some View {

        NavigationStack {

            VStack(spacing: 22) {

                header

                datePickerSection

                timeSection

                durationSection

                continueButton

            }
            .padding(.horizontal)
            .navigationBarHidden(true)
        }
    }
}



extension CreateEventDetailSheet {

    var header: some View {

        HStack(alignment: .center, spacing: 16) {

            Button {
                showIconPicker = true
            } label: {

                ZStack {

                    Circle()
                        .fill(color.opacity(0.25))
                        .frame(width: 70, height: 70)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            TextField("Tên sự kiện", text: $title)
                .font(.system(size: 28, weight: .bold))
        }
        .padding(.top,10)
        .sheet(isPresented: $showIconPicker) {

            IconPicker(
                icon: $icon,
                color: $color
            )
        }
    }
}



extension CreateEventDetailSheet {

    var datePickerSection: some View {

        HStack {

            Image(systemName: "calendar")
                .foregroundStyle(.orange)

            Text(dateText)

            Spacer()

            DatePicker(
                "",
                selection: $date,
                in: Date()...,
                displayedComponents: [.date]
            )
            .labelsHidden()
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var dateText: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy"
        formatter.locale = Locale(identifier: "vi")

        return formatter.string(from: date)
    }
}



extension CreateEventDetailSheet {

    var timeSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Thời gian")
                .font(.title3.bold())

            HStack {

                Picker("", selection: $startHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)")
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)

                Picker("", selection: $startMinute) {
                    ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id:\.self) {
                        Text(String(format: "%02d",$0))
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)

                Image(systemName: "arrow.right")

                Picker("", selection: $endHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)")
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)

                Picker("", selection: $endMinute) {
                    ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id:\.self) {
                        Text(String(format: "%02d",$0))
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)

            }
            .frame(height: 140)
        }
    }
}



extension CreateEventDetailSheet {

    var durationSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Thời lượng")
                .font(.title3.bold())

            HStack {

                durationButton("1",1)

                durationButton("15",0.25)

                durationButton("30",0.5)

                durationButton("45",0.75)

                durationButton("1g",1)

                durationButton("1,5g",1.5)

            }
        }
    }

    func durationButton(_ label:String,_ value:Double) -> some View {

        Button {

            duration = value

        } label: {

            Text(label)
                .fontWeight(.semibold)
                .frame(maxWidth:.infinity)
                .padding(.vertical,12)
                .background(
                    duration == value ?
                    Color.orange :
                    Color.gray.opacity(0.2)
                )
                .foregroundStyle(
                    duration == value ? .white : .primary
                )
                .clipShape(Capsule())
        }
    }
}



extension CreateEventDetailSheet {

    var continueButton: some View {

        Button {

        } label: {

            Text("Tiếp tục")
                .font(.title3.bold())
                .frame(maxWidth:.infinity)
                .padding()
                .background(.orange)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding(.top,10)
    }
}
