
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
    
    @EnvironmentObject var store: TimelineStore
    // MARK: - Event Data
    
    @State private var title: String = ""
    
    @State private var icon: String = "calendar.badge.plus"
    @State private var color: Color = Color(
        red: 108/255,
        green: 74/255,
        blue: 47/255
    )
    
    @State private var date: Date = Date()
    
  
    
    @State private var duration: Double = 1.5
    
    
    @Environment(\.dismiss) private var dismiss
    
    let onCreate: (String,String,Int,Int,String,Recurrence) -> Void
    var onOpenHabit: (() -> Void)?
    let suggestedStart: Int
    
    
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    
    @State private var durationMinutes: Int = 60
    
    let presets = [30,60,90,120]
    
    @State private var showIconPicker = false
    @State private var showHabitSheet = false
    
    @State private var startMinutes: Int = 20 * 60
    @State private var endMinutes: Int = 21 * 60 + 30
    
    @State private var durationHours: Int = 1
    @State private var durationMinutesOnly: Int = 30
    
    @State private var startHour: Int = 20
    @State private var startMinute: Int = 0
    
    @State private var isCompleted = false
    
    @State private var isAllDay = false
    
    enum RepeatRule: String, CaseIterable {
        case none = "None"
        case weekly = "Week"
    }

    @State private var repeatRule: RepeatRule = .none

    @State private var selectedWeekdays: Set<Int> = []
    
    
    
    
    
    
    var isPastTime: Bool {
        isToday && startMinutes < currentMinutes
    }
    
    func isPastWeekday(_ weekday: Int) -> Bool {

        if !isToday { return false }

        let today = Calendar.current.component(.weekday, from: Date())

        return weekday < today
    }
    
    
    
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
    
    func updateStartMinutes() {
        
        startMinutes = startHour * 60 + startMinute
        updateEndTimeFromDuration()
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
    
    func buildRecurrence() -> Recurrence {

        switch repeatRule {

        case .none:
            return .once(date)

        case .weekly:
            return .specific(Array(selectedWeekdays))
        }
    }
    
    
    
    
    
    init(
        suggestedStart: Int,
        onOpenHabit: (() -> Void)? = nil,
        onCreate: @escaping (String,String,Int,Int,String,Recurrence) -> Void
    ) {

        self.suggestedStart = suggestedStart
        self.onCreate = onCreate
        self.onOpenHabit = onOpenHabit

        _startMinutes = State(initialValue: suggestedStart)
        _endMinutes = State(initialValue: suggestedStart + 90)

        _startHour = State(initialValue: suggestedStart / 60)
        _startMinute = State(initialValue: suggestedStart % 60)

        _startTime = State(
            initialValue:
                TimelineEngine.dateFrom(
                    minutes: suggestedStart,
                    base: Date()
                )
        )
    }
    
    var repeatSummaryText: String {

        if repeatRule == .none {
            return "Does not repeat"
        }

        let symbols = Calendar.current.shortWeekdaySymbols

        let sorted = selectedWeekdays.sorted()

        let names = sorted.map { symbols[$0 - 1] }

        return "Every " + names.joined(separator: ", ")
    }
    
    var weekdayChips: some View {

        let symbols = Calendar.current.shortWeekdaySymbols

        return HStack(spacing:6) {

            ForEach(selectedWeekdays.sorted(), id:\.self) { day in

                Text(symbols[day-1])
                    .font(.caption.bold())
                    .padding(.horizontal,8)
                    .padding(.vertical,4)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
            }
        }
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var currentMinutes: Int {

        let c = Calendar.current.dateComponents([.hour,.minute], from: Date())

        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    // MARK: - Body
    
    var body: some View {

        NavigationStack {

            ZStack {

                AmbientBackground(
                    isCompleted: isCompleted,
                    color: color
                )

               

                VStack(spacing: 14) {

                    header
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)   // 👈 thêm dòng này
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 28,
                                style: .continuous
                            )
                        )
                        .ignoresSafeArea(edges: .horizontal)

                    ScrollView {

                        VStack(spacing: 14) {

                            CardSection { datePickerSection }
                            CardSection { timeSection }
                            CardSection { repeatSection }
                            CardSection { durationSection }

                            Spacer(minLength: 120)

                        }
                        .padding(.horizontal,16)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.top, -12)
                }
                
                .safeAreaInset(edge: .bottom) {

                    continueButton
                        .padding(.horizontal,20)
                        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 20 : -20)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
                
                
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
                    color.opacity(0.95),
                    color.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Color.white
                    .opacity(isCompleted ? 0.06 : 0)
                    .blendMode(.overlay)
                    .animation(.easeOut(duration: 0.25), value: isCompleted)
            )
            .scaleEffect(isCompleted ? 1.02 : 1)
            .brightness(isCompleted ? 0.04 : 0)
            .animation(.easeInOut(duration: 0.35), value: isCompleted)
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

                    Button {

                        dismiss()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onOpenHabit?()
                        }

                    } label: {

                        Text("Add Habit")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal,14)
                            .padding(.vertical,8)
                            .background(Color.white.opacity(0.6))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }

                // main content
                HStack(spacing: 16) {

                    // icon preview
                    Button {
                        showIconPicker = true
                    } label: {

                        ZStack {

                            Circle()
                                .fill(.ultraThinMaterial)

                            Circle()
                                .fill(Color.white.opacity(0.18))

                            Circle()
                                .stroke(
                                    Color.white.opacity(0.35),
                                    lineWidth: 1
                                )

                            Image(systemName: icon)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(icon == "calendar.badge.plus" ? 0.9 : 1)
                        }
                        .frame(width: 72, height: 72)
                        .shadow(
                            color: .black.opacity(0.25),
                            radius: 8,
                            y: 4
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        

                        Text(timeRangeText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if repeatRule == .weekly {
                              weekdayChips
                          }

                        ZStack(alignment: .leading) {

                            TextField("Tên sự kiện", text: $title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical,8)
                                .padding(.horizontal,12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.18))
                                )
                                .textInputAutocapitalization(.sentences)
                                .disableAutocorrection(true)

                            GeometryReader { geo in

                                Rectangle()
                                    .fill(Color.white)
                                    .frame(height: 2)
                                    .scaleEffect(x: isCompleted ? 1 : 0, anchor: .leading)
                                    .animation(.easeOut(duration: 0.35), value: isCompleted)
                                    .offset(y: geo.size.height / 2)
                            }
                        }
                    }

                    Spacer()

                    Button {

                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isCompleted.toggle()
                        }

                    } label: {

                        ZStack {

                            Circle()
                                .fill(isCompleted ? Color.white.opacity(0.25) : Color.clear)
                                .frame(width: 30, height: 30)
                                .animation(.easeInOut(duration: 0.25), value: isCompleted)

                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)

                            AnimatedCheckmark(progress: isCompleted ? 1 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 30)
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 30)
        }
        .onChange(of: date) { newDate in

            let weekday = Calendar.current.component(.weekday, from: newDate)

            if repeatRule == .weekly {
                selectedWeekdays.insert(weekday)
            }
        }
        .onAppear {

            let weekday = Calendar.current.component(.weekday, from: date)

            if !isPastWeekday(weekday) {
                selectedWeekdays.insert(weekday)
            }
        }
        .sheet(isPresented: $showIconPicker) {

            IconPicker(
                icon: $icon,
                color: $color
            )
            .presentationBackground(Color.paper)
        }
        .sheet(isPresented: $showHabitSheet) {

            CreateHabitDetailSheet(

                onCreate: { title, icon, date, type, target, unit, minutes, increment in

                    store.addHabit(
                        title: title,
                        icon: icon,
                        minutes: minutes ?? 540,
                        habitType: type,
                        targetValue: target,
                        unit: unit,
                        increment: increment
                    )
                },

                onOpenEvent: {

                    showHabitSheet = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onOpenHabit?()
                    }
                }
            )
        }
    }
}



extension CreateEventDetailSheet {

    var datePickerSection: some View {

        HStack {

            Image(systemName: "calendar")
                .foregroundStyle(.primary)

            Text(dateText)

            Spacer()

            DatePicker(
                "",
                selection: $date,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .onChange(of: date) { newDate in
                
                selectedDate = newDate
            }
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
    
    func clampPastTime() {

        if isToday && startMinutes < currentMinutes {

            let snapped = ((currentMinutes + 4) / 5) * 5

            startMinutes = snapped

            startHour = snapped / 60
            startMinute = snapped % 60
        }
    }

    var timeSection: some View {
        
        

        VStack(alignment: .leading, spacing: 16) {

            Text("Thời gian bắt đầu")
                .font(.title3.bold())

            HStack(alignment: .center, spacing: 12) {

                if !isAllDay {

                    HStack {

                        Picker("", selection: $startHour) {

                            ForEach(0..<24) { hour in

                                let minutes = hour * 60

                                Text(String(format: "%02d", hour))
                                    .tag(hour)
                                    .foregroundStyle(
                                        isToday && minutes < currentMinutes
                                        ? Color.gray.opacity(0.35)
                                        : Color.primary
                                    )
                            }

                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height:120)
                        .clipped()

                        Text(":")
                            .font(.title2.bold())

                        Picker("", selection: $startMinute) {

                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id:\.self) { minute in

                                let total = startHour * 60 + minute

                                Text(String(format: "%02d", minute))
                                    .tag(minute)
                                    .foregroundStyle(
                                        isToday && total < currentMinutes
                                        ? Color.gray.opacity(0.35)
                                        : Color.primary
                                    )
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height:120)
                        .clipped()
                    }
                    .onChange(of: startHour) { _ in
                        updateStartMinutes()
                        clampPastTime()
                    }

                    .onChange(of: startMinute) { _ in
                        updateStartMinutes()
                        clampPastTime()
                    }
                }

                Spacer()

                Button {

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isAllDay.toggle()
                    }
                    
                    if isAllDay {
                           startHour = 0
                           startMinute = 0
                           startMinutes = 0
                       }

                } label: {

                    Text("All Day")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal,14)
                        .padding(.vertical,8)
                        .background(
                            isAllDay
                            ? Color.primary
                            : Color.gray.opacity(0.15)
                        )
                        .foregroundStyle(
                            isAllDay ? Color(.systemBackground) : .primary
                        )
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    var repeatSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Repeat")
                .font(.title3.bold())

            Picker("", selection: $repeatRule) {

                ForEach(RepeatRule.allCases, id:\.self) {
                    Text($0.rawValue).tag($0)
                }

            }
            .pickerStyle(.segmented)

            if repeatRule == .weekly {

                weekdayPicker
            }
        }
    }
    
    var weekdayPicker: some View {

        let days = [
            (1,"S"),
            (2,"M"),
            (3,"T"),
            (4,"W"),
            (5,"T"),
            (6,"F"),
            (7,"S")
        ]

        return HStack(spacing:10) {

            ForEach(days, id:\.0) { day in

                let isSelected = selectedWeekdays.contains(day.0)
                let isPast = isPastWeekday(day.0)

                Button {

                    if isPast { return }

                    if isSelected {
                        selectedWeekdays.remove(day.0)
                    } else {
                        selectedWeekdays.insert(day.0)
                    }

                } label: {

                    Text(day.1)
                        .font(.subheadline.bold())
                        .frame(width:36,height:36)
                        .background(
                            isSelected
                            ? Color.orange
                            : Color.gray.opacity(0.15)
                        )
                        .opacity(isPast ? 0.35 : 1)
                        .foregroundStyle(
                            isSelected ? .white : .primary
                        )
                        .clipShape(Circle())
                }
            }
        }
    }
    
    
    
    
    
    
}



extension CreateEventDetailSheet {

    var durationSection: some View {

        GeometryReader { geo in
            
            let isWide = geo.size.width > 500
            
            VStack(alignment: .leading, spacing: 16) {

                Text("Thời lượng")
                    .font(.title3.bold())

                HStack(spacing: isWide ? 40 : 20) {

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
                    .frame(width: isWide ? 220 : 150)

                    Spacer(minLength: isWide ? 40 : 10)

                    // WHEEL PICKER
                    HStack(spacing: 10) {

                        Picker("", selection: $durationHours) {

                            ForEach(0..<6) { hour in
                                Text("\(hour)h")
                                    .tag(hour)
                            }

                        }
                        .pickerStyle(.wheel)
                        .frame(width: isWide ? 110 : 70)

                        Picker("", selection: $durationMinutesOnly) {

                            ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id:\.self) {
                                Text("\($0)p")
                                    .tag($0)
                            }

                        }
                        .pickerStyle(.wheel)
                        .frame(width: isWide ? 110 : 70)

                    }
                    .frame(height: isWide ? 120 : 95)
                    .onChange(of: durationHours) { _ in
                        updateDurationFromPicker()
                    }
                    .onChange(of: durationMinutesOnly) { _ in
                        updateDurationFromPicker()
                    }
                }
                .disabled(isAllDay || isPastTime)
                .opacity(isAllDay || isPastTime ? 0.4 : 1)
            }
        }
        .frame(height: 140)
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

            let cleanTitle =
            title.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanTitle.isEmpty else { return }

            if repeatRule == .weekly && selectedWeekdays.isEmpty {
                return
            }

            guard endMinutes > startMinutes else {
                return
            }

            if isToday && startMinutes < currentMinutes {
                return
            }

            var duration = endMinutes - startMinutes

            if isAllDay {
                duration = 1440
            }

            guard endMinutes <= 1440 else { return }

            guard !store.hasOverlap(
                minutes: startMinutes,
                duration: duration,
                date: date
            ) else { return }

            let recurrence = buildRecurrence()

            onCreate(
                cleanTitle,
                icon,
                startMinutes,
                duration,
                color.toHex(),
                recurrence
            )

            dismiss()

        } label: {

            Text("Create event")
                .font(.title3.bold())
                .frame(maxWidth:.infinity)
                .padding()
                .background(Color(.label))
                .shadow(
                    color: .black.opacity(0.25),
                    radius: 20,
                    y: 10
                )
                .foregroundStyle(Color(.systemBackground))
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


            .allowsHitTesting(true)
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
    
    var isCompleted: Bool
    var color: Color
    
    var body: some View {

        ZStack {

            Circle()
                .fill(color.opacity(0.28))
                .blur(radius:120)
                .offset(x:-140,y:-220)

            Circle()
                .fill(color.opacity(0.18))
                .blur(radius:140)
                .offset(x:160,y:260)

            if isCompleted {
                Circle()
                    .fill(.white.opacity(0.12))
                    .blur(radius:160)
                    .scaleEffect(1.1)
                    .animation(.easeOut(duration:0.4), value:isCompleted)
            }
        }
        .ignoresSafeArea()
    }
}

struct AnimatedCheckmark: View {

    var progress: CGFloat

    var body: some View {

        Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .scaleEffect(progress)
            .opacity(progress)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: progress)
    }
}

