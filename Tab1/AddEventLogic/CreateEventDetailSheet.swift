
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
    
    @State private var timeWarning: TimeWarning? = nil
    @State private var durationWarning: DurationWarning? = nil
    
    
    @State private var titleWarning: String? = nil

    var isFormBlocked: Bool {
        durationWarning == .noTimeLeft || durationWarning == .tooShort
    }
    
    
    enum TimeWarning: String {
        case past        = "⏰ This time has already passed"
        case overlap     = "⚡ Another event is already scheduled here"
        case pastSleep   = "🌙 Start time is past Night Reset"
        case beforeWake  = "🌅 Start time is before Morning Start"
    }

    enum DurationWarning: String {
        case exceedsSleep  = "🌙 Duration runs past Night Reset — will be trimmed"
        case tooShort      = "⚡ Minimum duration is 5 minutes"
        case noTimeLeft    = "🚫 No time left before Night Reset"
    }
    
    
    var sleepMinutes: Int { store.sleepMinutes }
    var wakeMinutes:  Int { store.wakeMinutes  }

    func isHourDimmed(_ hour: Int) -> Bool {
        let start = hour * 60
        let end   = hour * 60 + 59
        if isToday && end < currentMinutes { return true }  // giữ nguyên
        if start >= sleepMinutes           { return true }
        if start < wakeMinutes             { return true }
        return false
        // Bỏ điều kiện isToday ở 2 dòng cuối vì sleep/wake áp dụng cho mọi ngày
    }

    func isMinuteDimmed(_ minute: Int) -> Bool {
        let total = startHour * 60 + minute
        if isToday && total < currentMinutes { return true }  // chỉ today
        if total >= sleepMinutes             { return true }
        if total < wakeMinutes               { return true }
        return false
    }

    func validateAndClampTime() {
        guard !isAllDay else { timeWarning = nil; return }

        let total = startHour * 60 + startMinute

        // 1. Trước Morning Start
        if total < wakeMinutes {
            timeWarning = .beforeWake
            let clamped = ((wakeMinutes + 4) / 5) * 5
            startMinutes = clamped
            startHour   = clamped / 60
            startMinute = clamped % 60
            updateEndTimeFromDuration()
            return
        }

        // 2. Quá khứ — CHỈ check khi là today
        if isToday && total < currentMinutes {
            timeWarning = .past
            let clamped = ((currentMinutes + 4) / 5) * 5
            startMinutes = min(clamped, sleepMinutes - 5)
            startHour   = startMinutes / 60
            startMinute = startMinutes % 60
            updateEndTimeFromDuration()
            return
        }

        // 3. Qua sleep
        if total >= sleepMinutes {
            timeWarning = .pastSleep
            let clamped = ((sleepMinutes - 60 + 4) / 5) * 5
            startMinutes = max(wakeMinutes, clamped)
            startHour   = startMinutes / 60
            startMinute = startMinutes % 60
            updateEndTimeFromDuration()
            return
        }

        // 4. Overlap — check theo date đang chọn (đã đúng vì truyền date vào)
        if store.hasOverlap(minutes: total, duration: Int(duration * 60), date: date) {
            timeWarning = .overlap
            return
        }

        timeWarning = nil
    }

    func validateDuration() {
        guard !isAllDay else { durationWarning = nil; return }

        let d = Int(duration * 60)

        if d < 5 {
            durationWarning = .tooShort
            return
        }

        let remaining = sleepMinutes - startMinutes
        if remaining <= 0 {
            durationWarning = .noTimeLeft
            return
        }

        if startMinutes + d > sleepMinutes {
            durationWarning = .exceedsSleep
            return
        }

        durationWarning = nil
    }
    
    
    @ViewBuilder
    func warningBanner(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.85))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    
    
    var isPastTime: Bool {
        isToday && startMinutes < currentMinutes
    }
    
    func isPastWeekday(_ weekday: Int) -> Bool {

        if !isToday { return false }

        let today = Calendar.current.component(.weekday, from: Date())

        return weekday < today
    }
    
    
    
    var timeRangeText: String {

        if isAllDay {
            return "All Day"
        }

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
        initialDate: Date = Date(),
        onOpenHabit: (() -> Void)? = nil,
        onCreate: @escaping (String,String,Int,Int,String,Recurrence) -> Void
    ) {

        self.suggestedStart = suggestedStart
        self.onCreate = onCreate
        self.onOpenHabit = onOpenHabit

        _date = State(initialValue: initialDate) 
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

                            // TÌM TextField "Tên sự kiện", thêm overlay border đỏ khi empty + đã tap:
                            TextField("Event name", text: $title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    titleWarning != nil ? Color.red.opacity(0.8) : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                                .textInputAutocapitalization(.sentences)
                                .disableAutocorrection(true)
                                .onChange(of: title) { _ in
                                    if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        titleWarning = nil
                                    }
                                }

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
        .onAppear {
            let weekday = Calendar.current.component(.weekday, from: date)
            if !isPastWeekday(weekday) {
                selectedWeekdays.insert(weekday)
            }
            validateAndClampTime()
            validateDuration()
        }
        .onChange(of: date) { newDate in
            let weekday = Calendar.current.component(.weekday, from: newDate)
            if repeatRule == .weekly {
                selectedWeekdays.insert(weekday)
            }
            validateAndClampTime()
            validateDuration()
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
        VStack(alignment: .leading, spacing: 12) {

            // Header với remaining time hint
            HStack {
                Text("Start time")
                    .font(.title3.bold())

                Spacer()

                if !isAllDay {
                    let effectiveStart = isToday ? max(startMinutes, currentMinutes) : startMinutes
                    let remaining = sleepMinutes - effectiveStart
                    let total = sleepMinutes - wakeMinutes
                    let progress = max(0, min(1, CGFloat(remaining) / CGFloat(max(total, 1))))

                    HStack(spacing: 6) {
                        // Progress bar thời gian còn lại
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        progress > 0.3 ? Color.green.opacity(0.7) :
                                        progress > 0.1 ? Color.orange.opacity(0.7) :
                                        Color.red.opacity(0.7)
                                    )
                                    .frame(width: g.size.width * progress)
                            }
                        }
                        .frame(width: 60, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: startMinutes)

                        // Text thời gian còn lại
                        Text(remainingTimeText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(
                                remaining < 60 ? .red :
                                remaining < 180 ? .orange : .secondary
                            )
                            .monospacedDigit()
                    }
                }
            }


            HStack(alignment: .center, spacing: 12) {

                if !isAllDay {
                    HStack(spacing: 0) {

                        Picker("", selection: $startHour) {
                            ForEach(0..<24) { hour in
                                Text(String(format: "%02d", hour))
                                    .tag(hour)
                                    .foregroundStyle(
                                        isHourDimmed(hour)
                                        ? Color.gray.opacity(0.3)
                                        : Color.primary
                                    )
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 120)
                        .clipped()
                        .saturation(isHourDimmed(startHour) ? 0.2 : 1)
                        .opacity(isHourDimmed(startHour) ? 0.5 : 1)

                        Text(":")
                            .font(.title2.bold())
                            .padding(.horizontal, 4)

                        Picker("", selection: $startMinute) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                                Text(String(format: "%02d", minute))
                                    .tag(minute)
                                    .foregroundStyle(
                                        isMinuteDimmed(minute)
                                        ? Color.gray.opacity(0.3)
                                        : Color.primary
                                    )
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 120)
                        .clipped()
                        .saturation(isMinuteDimmed(startMinute) ? 0.2 : 1)
                        .opacity(isMinuteDimmed(startMinute) ? 0.5 : 1)
                    }
                    .onChange(of: startHour)   { _ in updateStartMinutes(); validateAndClampTime(); validateDuration() }
                    .onChange(of: startMinute) { _ in updateStartMinutes(); validateAndClampTime(); validateDuration() }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isAllDay.toggle()
                    }
                    if isAllDay {
                        startHour = 0; startMinute = 0
                        startMinutes = 0; endMinutes = 1440
                        durationHours = 24; durationMinutesOnly = 0
                        timeWarning = nil; durationWarning = nil
                    } else {
                        startHour = suggestedStart / 60
                        startMinute = suggestedStart % 60
                        startMinutes = suggestedStart
                        durationHours = 1; durationMinutesOnly = 30
                        updateEndTimeFromDuration()
                        validateAndClampTime()
                        validateDuration()
                    }
                } label: {
                    Text("All Day")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isAllDay ? Color.primary : Color.gray.opacity(0.15))
                        .foregroundStyle(isAllDay ? Color(.systemBackground) : .primary)
                        .clipShape(Capsule())
                }
            }

            if let w = timeWarning {
                warningBanner(w.rawValue, color: .orange)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timeWarning?.rawValue)
    }
    var remainingTimeText: String {
        // Future date: tính từ startMinutes đến sleep
        // Today: tính từ max(startMinutes, currentMinutes) đến sleep
        let effectiveStart = isToday ? max(startMinutes, currentMinutes) : startMinutes
        let remaining = sleepMinutes - effectiveStart
        if remaining <= 0 { return "No time left" }
        let h = remaining / 60
        let m = remaining % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m left" }
        if h > 0 { return "\(h)h left" }
        return "\(m)m left"
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
    
    var maxDurationText: String {
        let m = max(0, sleepMinutes - startMinutes)
        let h = m / 60
        let mins = m % 60
        if h > 0 && mins > 0 { return "\(h)h \(mins)m" }
        if h > 0 { return "\(h)h" }
        return "\(mins)m"
    }
    
    
    
    
}



extension CreateEventDetailSheet {

    var durationSection: some View {

        GeometryReader { geo in
            
            let isWide = geo.size.width > 500
            
            VStack(alignment: .leading, spacing: 16) {

                // Thay "Thời lượng" header thành:
                HStack {
                    Text("Duration")
                        .font(.title3.bold())

                    Spacer()

                    if !isAllDay && !isPastTime {
                        let maxMins = sleepMinutes - startMinutes
                        let currentDur = Int(duration * 60)
                        let isNearLimit = currentDur > maxMins - 30

                        Text("max \(maxDurationText)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isNearLimit ? .orange : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(isNearLimit ? Color.orange.opacity(0.12) : Color.gray.opacity(0.1))
                            )
                            .animation(.easeInOut(duration: 0.2), value: isNearLimit)
                    }
                }

             

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
                    .onChange(of: durationHours)      { _ in updateDurationFromPicker(); validateDuration() }
                    .onChange(of: durationMinutesOnly) { _ in updateDurationFromPicker(); validateDuration() }
                }
                
                .disabled(isAllDay || isPastTime)
                .opacity(isAllDay || isPastTime ? 0.4 : 1)
                if let w = durationWarning {
                    warningBanner(w.rawValue, color: .purple)
                }
            }
        }
        .frame(height: durationWarning != nil ? 180 : 140)
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
        VStack(spacing: 8) {

            // Hint text phía trên nút khi có vấn đề
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("✏️ Enter a title to continue")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if repeatRule == .weekly && selectedWeekdays.isEmpty {
                Text("📅 Pick at least one day")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if isFormBlocked {
                Text("Fix the issues above to continue")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            Button {
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

                // Show title warning instead of silent fail
                if cleanTitle.isEmpty {
                    withAnimation { titleWarning = "✏️ Please enter a title" }
                    return
                }

                if repeatRule == .weekly && selectedWeekdays.isEmpty { return }
                guard endMinutes > startMinutes else { return }
                if isToday && startMinutes < currentMinutes { return }
                if isFormBlocked { return }

                var duration = endMinutes - startMinutes
                if isAllDay {
                    duration = 1440
                } else if startMinutes + duration > sleepMinutes {
                    duration = sleepMinutes - startMinutes
                }

                guard duration >= 5 else { return }
                guard endMinutes <= 1440 else { return }
                guard !store.hasOverlap(minutes: startMinutes, duration: duration, date: date) else { return }

                onCreate(cleanTitle, icon, startMinutes, duration, color.toHex(), buildRecurrence())
                dismiss()

            } label: {
                let isBlocked = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             || isFormBlocked
                             || (repeatRule == .weekly && selectedWeekdays.isEmpty)

                Text("Create event")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isBlocked ? Color.gray.opacity(0.4) : Color(.label))
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: isBlocked)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: title.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFormBlocked)
        .padding(.top, 10)
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

