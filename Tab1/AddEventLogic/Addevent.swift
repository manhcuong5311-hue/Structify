
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
    
    
    @State private var startMinutes: Int = 20 * 60
    @State private var endMinutes: Int = 21 * 60 + 30
    
    @State private var durationHours: Int = 1
    @State private var durationMinutesOnly: Int = 30
    
    
    var timeRangeText: String {
        
        let sh = startMinutes / 60
        let sm = startMinutes % 60
        
        let eh = endMinutes / 60
        let em = endMinutes % 60
        
        let duration = endMinutes - startMinutes
        
        let dh = duration / 60
        let dm = duration % 60
        
        return String(
            format: "%02d:%02d–%02d:%02d (%d giờ, %d phút)",
            sh, sm, eh, em, dh, dm
        )
    }
    
    func updateEndTimeFromDuration() {
        
        let minutes = Int(duration * 60)
        
        endMinutes = startMinutes + minutes
    }
    
    func updateStartTime(_ newValue: Int) {
        
        startMinutes = newValue
        updateEndTimeFromDuration()
    }
    
    func updateDurationFromPicker() {
        
        duration = Double(durationHours) + Double(durationMinutesOnly) / 60
        
        updateEndTimeFromDuration()
    }
    
    
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
            
            ZStack {
                
                AmbientBackground()
                
                
            VStack(spacing: 14) {
                
                header
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 28,
                            style: .continuous
                        )
                    )
                    .padding(.horizontal, -24)
                
                CardSection {
                    datePickerSection
                }
                
                CardSection {
                    timeSection
                }
                
                CardSection {
                    durationSection
                }
                
                continueButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal,16)
            .edgesIgnoringSafeArea(.horizontal)
            .navigationBarHidden(true)
        }
    }
}
}



extension CreateEventDetailSheet {

    var header: some View {

        ZStack(alignment: .topLeading) {

            // background
            LinearGradient(
                colors: [
                    color.opacity(0.9),
                    color.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .horizontal)

            VStack(spacing: 20) {

                // close button
                HStack {
                    Button {
                        dismiss()
                    } label: {

                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.6))
                            .clipShape(Circle())
                    }

                    Spacer()
                }

                // main content
                HStack(spacing: 16) {

                    // icon preview
                    Button {
                        showIconPicker = true
                    } label: {

                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {

                        Text(timeRangeText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        TextField("Tên sự kiện", text: $title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 28, height: 28)
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showIconPicker) {

            IconPicker(
                icon: $icon,
                color: $color
            )
            .presentationBackground(Color.paper)
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
            .frame(height: 110)
        }
    }
}



extension CreateEventDetailSheet {

    var durationSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Thời lượng")
                .font(.title3.bold())

            HStack(spacing: 20) {

                // PRESET GRID
                VStack(spacing: 12) {

                    HStack(spacing: 10) {

                        durationPreset(15)
                        durationPreset(45)

                    }

                    HStack(spacing: 10) {

                        durationPreset(30)
                        durationPreset(60)

                    }

                }
                .frame(width: 150)

                // WHEEL PICKER
                HStack(spacing: 8) {

                    Picker("", selection: $durationHours) {

                        ForEach(0..<6) { hour in
                            Text("\(hour)h")
                        }

                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)

                    Picker("", selection: $durationMinutesOnly) {

                        ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id:\.self) {
                            Text("\($0)p")
                        }

                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)

                }
                .frame(height: 95)
                .onChange(of: durationHours) { _ in
                    updateDurationFromPicker()
                }
                .onChange(of: durationMinutesOnly) { _ in
                    updateDurationFromPicker()
                }

            }
        }
    }
    
    
    func durationPreset(_ minutes: Int) -> some View {

        let isActive =
            durationHours == minutes / 60 &&
            durationMinutesOnly == minutes % 60

        return Button {

            durationHours = minutes / 60
            durationMinutesOnly = minutes % 60
            updateDurationFromPicker()

        } label: {

            Text(labelForPreset(minutes))
                .font(.subheadline.weight(.semibold))
                .frame(width: 60)
                .padding(.vertical,10)
                .background(
                    isActive
                    ? Color.orange
                    : Color.gray.opacity(0.15)
                )
                .foregroundStyle(
                    isActive ? .white : .primary
                )
                .clipShape(Capsule())
        }
    }

    func labelForPreset(_ minutes: Int) -> String {

        if minutes >= 60 {

            let h = minutes / 60
            let m = minutes % 60

            if m == 0 {
                return "\(h)h"
            } else {
                return "\(h)h\(m)"
            }

        } else {

            return "\(minutes)p"

        }
    }
    
    func durationButton(_ label:String,_ value:Double) -> some View {

        Button {

            duration = value
            updateEndTimeFromDuration()

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


struct CardSection<Content: View>: View {

    let tint: Color
    let content: Content

    @State private var pressed = false

    init(
        tint: Color = .blue,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {

        content
            .padding(.horizontal,18)
            .padding(.vertical,16)

            .background(
                ZStack {

                    RoundedRectangle(cornerRadius:22)
                        .fill(.ultraThinMaterial)

                    // tint theo màu event
                    RoundedRectangle(cornerRadius:22)
                        .fill(tint.opacity(0.08))

                    RoundedRectangle(cornerRadius:22)
                        .stroke(
                            Color.white.opacity(0.18),
                            lineWidth:1
                        )
                }
            )

            .shadow(
                color:.black.opacity(0.18),
                radius:20,
                y:10
            )

            .scaleEffect(pressed ? 0.97 : 1)

            .animation(
                .spring(response:0.28),
                value: pressed
            )

            .simultaneousGesture(
                DragGesture(minimumDistance:0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

struct TimeSlider: View {

    let title: String
    @Binding var minutes: Int

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Text(title)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(timeString)
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(minutes) },
                    set: { minutes = Int($0) }
                ),
                in: 0...1439,
                step: 5
            )
        }
    }

    var timeString: String {

        let h = minutes / 60
        let m = minutes % 60

        return String(format: "%02d:%02d", h, m)
    }
}

struct AmbientBackground: View {

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(.blue.opacity(0.25))
                .blur(radius:120)
                .offset(x:-140,y:-220)

            Circle()
                .fill(.purple.opacity(0.25))
                .blur(radius:120)
                .offset(x:160,y:260)
        }
        .ignoresSafeArea()
    }
}
