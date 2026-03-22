import SwiftUI

enum HabitRepeat: String, CaseIterable {
    case oneDay
    case week
    case month
    case everyday
}

extension HabitRepeat {
    var localized: String {
        switch self {
        case .oneDay:
            return String(localized: "habit_repeat_one_day")
        case .week:
            return String(localized: "habit_repeat_week")
        case .month:
            return String(localized: "habit_repeat_month")
        case .everyday:
            return String(localized: "habit_repeat_everyday")
        }
    }
}

enum HabitType: String, Codable {
    case binary
    case accumulative
}

struct CreateHabitDetailSheet: View {

    // MARK: - Data
    @State private var title: String = ""
    @State private var icon: String  = "checkmark.circle.fill"
    @State private var color: Color  = Color(red: 120/255, green: 156/255, blue: 123/255)
    @State private var date: Date    = Date()

    @State private var isCompleted   = false
    @State private var showIconPicker = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TimelineStore

    let onCreate: (String, String, String, Date, HabitType, Double?, String?, Int?, Double?, HabitRepeat) -> Void
    let onOpenEvent: (() -> Void)?

    // MARK: - Schedule
    @State private var repeatMode: HabitRepeat = .everyday
    @State private var habitTime: Date = Date()
    @State private var isAnytime = true

    // MARK: - Habit config
    @State private var habitType: HabitType = .binary
    @State private var targetValue: Double   = 10
    @State private var targetUnit: TargetUnit = .times
    @State private var incrementValue: Double = 1
    @State private var previewProgress: Double = 0

    enum TargetUnit: String, CaseIterable {
        case times, km, ml, l, min, pages, steps

        var localized: String {
            switch self {
            case .times: return String(localized: "unit_times")
            case .km: return String(localized: "unit_km")
            case .ml: return String(localized: "unit_ml")
            case .l: return String(localized: "unit_l")
            case .min: return String(localized: "unit_min")
            case .pages: return String(localized: "unit_pages")
            case .steps: return String(localized: "unit_steps")
            }
        }
    }

    // MARK: - Validation
    @State private var titleWarning: String?   = nil
    @State private var timeWarning: String?    = nil
    @State private var targetWarning: String?  = nil

    // MARK: - Suggested values
    let targetSuggestions: [Double] = [5, 10, 20, 30, 50, 100]
    let incrementSuggestions: [Double] = [1, 5, 10]

    // MARK: - Computed
    var currentMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var selectedMinutes: Int {
        Calendar.current.component(.hour, from: habitTime) * 60 +
        Calendar.current.component(.minute, from: habitTime)
    }

    var headerScheduleText: String {
        isAnytime ? dateRangeText : "\(timeText) • \(dateRangeText)"
    }

    // MARK: - Validation logic
    func validateTime() {
        guard !isAnytime else { timeWarning = nil; return }
        let mins = selectedMinutes

        if isToday && mins < currentMinutes {
            timeWarning = String(localized: "time_error_passed")
            return
        }

        if mins < store.wakeMinutes {
            timeWarning = String(localized: "time_error_before_wake")
            return
        }

        if mins >= store.sleepMinutes {
            timeWarning = String(localized: "time_error_after_sleep")
            return
        }

        if store.hasOverlap(minutes: mins, duration: 30, date: date) {
            timeWarning = String(localized: "time_error_overlap")
            return
        }

        timeWarning = nil
    }

    func validateTarget() {
        if habitType == .accumulative {

            if targetValue <= 0 {
                targetWarning = String(localized: "target_error_invalid")
                return
            }

            if incrementValue <= 0 {
                targetWarning = String(localized: "increment_error_invalid")
                return
            }

            if incrementValue > targetValue {
                targetWarning = String(localized: "increment_error_exceed")
                return
            }
        }

        targetWarning = nil
    }

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && timeWarning == nil
        && targetWarning == nil
        && !isPastDate   // 👈 thêm
    }
    
    
    var isPastDate: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: date)
        // Block cả .week và .oneDay nếu start date là quá khứ
        switch repeatMode {
        case .oneDay, .week, .month:
            return selected < today
        case .everyday:
            return false
        }
    }

    
    
    
    
    
    
    
    
    
    

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(isCompleted: isCompleted, color: color)

                VStack(spacing: 14) {
                    header
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .ignoresSafeArea(edges: .horizontal)

                    ScrollView {
                        VStack(spacing: 14) {
                            CardSection { datePickerSection }
                            CardSection { repeatSection }
                            CardSection { habitTimeSection }
                            CardSection { habitTypeSection }

                            if habitType == .accumulative {
                                CardSection { accumulativeTargetSection }
                                CardSection { incrementSection }
                            }

                            Spacer(minLength: 120)
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.top, -12)
                }
                .safeAreaInset(edge: .bottom) {
                    continueButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 20 : -20)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
        }
    }
}

// MARK: - Header
extension CreateHabitDetailSheet {

    var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [color.opacity(0.95), color.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(Color.white.opacity(isCompleted ? 0.06 : 0).blendMode(.overlay))
            .scaleEffect(isCompleted ? 1.02 : 1)
            .brightness(isCompleted ? 0.04 : 0)
            .animation(.easeInOut(duration: 0.35), value: isCompleted)

            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onOpenEvent?() }
                    } label: {
                        Text(String(localized: "add_event"))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.white.opacity(0.6))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 16) {
                    Button { showIconPicker = true } label: {
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().fill(Color.white.opacity(0.18))
                            Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                            Image(systemName: icon)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if isAnytime {
                            Text(dateRangeText).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        } else {
                            Label(headerScheduleText, systemImage: "clock")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                        }

                        // Title field with validation highlight
                        TextField(String(localized: "habit_name_placeholder"), text: $title)

                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(titleWarning != nil ? Color.red.opacity(0.8) : Color.clear, lineWidth: 1.5)
                                    )
                            )
                            .onChange(of: title) {
                                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    titleWarning = nil
                                }
                            }
                    }

                    Spacer()

                    // Preview completion button
                    Button {
                        withAnimation(.spring()) {
                            if habitType == .binary {
                                isCompleted.toggle()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } else {
                                previewProgress += incrementValue
                                if previewProgress >= targetValue { isCompleted = true }
                            }
                        }
                    } label: {
                        ZStack {
                            if habitType == .binary {
                                Circle().fill(isCompleted ? Color.white.opacity(0.25) : Color.clear)
                                Circle().stroke(Color.white, lineWidth: 2)
                                AnimatedCheckmark(progress: isCompleted ? 1 : 0)
                            } else {
                                let p = min(previewProgress / max(targetValue, 1), 1)
                                Circle().stroke(Color.white.opacity(0.25), lineWidth: 3)
                                Circle().trim(from: 0, to: p)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(previewProgress))").font(.caption.bold()).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 30, height: 30)
                        .animation(.easeOut(duration: 0.25), value: previewProgress)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 50).padding(.bottom, 30)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPicker(icon: $icon, color: $color)
                .presentationBackground(Color.paper)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .ifPad { $0.presentationSizing(.page) }
        }
    }
}

// MARK: - Sections
extension CreateHabitDetailSheet {

    // Thêm warning vào datePickerSection, sau HStack:
    var datePickerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar").foregroundStyle(.primary)
                Text(dateText)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .labelsHidden()
                    .disabled(repeatMode != .oneDay)
                    .opacity(repeatMode == .oneDay ? 1 : 0.4)
            }
            .padding()
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 👈 thêm warning
            if isPastDate {
                warningBanner(
                    String(localized: "date_error_past_habit"),
                    color: .red
                )
            }

        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPastDate)
    }

    var repeatSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HabitRepeat.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring()) {
                            repeatMode = mode
                            updateDateForRepeatMode()
                        }
                    } label: {
                        Text(mode.localized)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(repeatMode == mode ? color : Color.gray.opacity(0.15))
                            .foregroundStyle(repeatMode == mode ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    var habitTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "time_of_day"))
                .font(.title3.bold())

            HStack {
                if !isAnytime {
                    DatePicker("", selection: $habitTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .onChange(of: habitTime) { validateTime() }
                }
                Spacer()
                Button {
                    withAnimation(.spring()) { isAnytime.toggle() }
                    if isAnytime { timeWarning = nil }
                    else { validateTime() }
                } label: {
                    Text(String(localized: "anytime"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(isAnytime ? color : Color.gray.opacity(0.15))
                        .foregroundStyle(isAnytime ? .white : .primary)
                        .clipShape(Capsule())
                }
            }

            // Warning banner
            if let w = timeWarning {
                warningBanner(w, color: .orange)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timeWarning)
    }

    var habitTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "habit_type"))
                .font(.title3.bold())
            HStack(spacing: 12) {
                habitTypeButton(.binary, icon: "checkmark.circle")
                habitTypeButton(.accumulative, icon: "chart.bar")
            }
        }
    }

    // MARK: Target section — với suggested chips
    var accumulativeTargetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "target"))
                .font(.title3.bold())
            // Suggested chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(targetSuggestions, id: \.self) { val in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                targetValue = val
                                validateTarget()
                            }
                        } label: {
                            Text("\(Int(val))")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(
                                    targetValue == val
                                    ? color
                                    : Color.gray.opacity(0.12)
                                )
                                .foregroundStyle(targetValue == val ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // Custom input row
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    Button {
                        if targetValue > 1 {
                            targetValue -= 1
                            validateTarget()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 36)
                    }
                    .disabled(targetValue <= 1)

                    TextField("", value: $targetValue, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .onChange(of: targetValue) { validateTarget() }

                    Button {
                        targetValue += 1
                        validateTarget()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 36)
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))

                Picker("", selection: $targetUnit) {
                    ForEach(TargetUnit.allCases, id: \.self) { unit in
                        Text(unit.localized).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            if let w = targetWarning {
                warningBanner(w, color: .purple)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: targetWarning)
    }

    // MARK: Increment section — với suggested chips
    var incrementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "per_tap"))
                    .font(.title3.bold())

                Spacer()

                let taps = targetValue > 0
                    ? Int(ceil(targetValue / max(incrementValue, 0.01)))
                    : 0

                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("tap_to_complete_format", comment: ""),
                        taps
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Suggested chips
            HStack(spacing: 8) {
                ForEach(incrementSuggestions, id: \.self) { val in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            incrementValue = val
                            validateTarget()
                        }
                    } label: {
                        Text("+\(Int(val))")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                incrementValue == val
                                ? color
                                : Color.gray.opacity(0.12)
                            )
                            .foregroundStyle(incrementValue == val ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }

            // Custom input
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    Button {
                        if incrementValue > 1 {
                            incrementValue -= 1
                            validateTarget()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 36)
                    }
                    .disabled(incrementValue <= 1)

                    TextField("", value: $incrementValue, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .onChange(of: incrementValue) { validateTarget() }

                    Button {
                        incrementValue += 1
                        validateTarget()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 36)
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))

                Text(targetUnit.localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
    }
}

// MARK: - Continue button
extension CreateHabitDetailSheet {

    var continueButton: some View {
        VStack(spacing: 8) {
            // Hint text
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(String(localized: "hint_enter_title"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if timeWarning != nil {
                Text(String(localized: "hint_fix_time"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if targetWarning != nil {
                Text(String(localized: "hint_fix_target"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if isPastDate {
                Text(String(localized: "date_error_create_past"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red.opacity(0.8))
                    .transition(.opacity)
            }

            Button {
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !cleanTitle.isEmpty else {
                    withAnimation {
                        titleWarning = String(localized: "error_enter_title")
                    }
                    return
                }
                guard timeWarning == nil, targetWarning == nil else { return }
                
                guard !isPastDate else { return }

                let minutes = isAnytime ? nil : selectedMinutes

                onCreate(
                    cleanTitle, icon, color.toHex(), date, habitType,   // 👈 thêm color.toHex()
                    habitType == .accumulative ? targetValue : nil,
                    habitType == .accumulative ? targetUnit.rawValue : nil,
                    minutes,
                    habitType == .accumulative ? incrementValue : nil,
                    repeatMode
                )
                dismiss()

            } label: {
                Text(String(localized: "create_habit"))
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color(.label) : Color.gray.opacity(0.4))
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: isFormValid)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: title.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timeWarning)
        .padding(.top, 10)
    }
}

// MARK: - Helpers
extension CreateHabitDetailSheet {

    @ViewBuilder
    func warningBanner(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.85)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    func habitTypeButton(_ type: HabitType, icon: String) -> some View {
        let selected = habitType == type
        return Button {
            withAnimation(.spring()) { habitType = type; validateTarget() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(type.localized)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? color : Color.gray.opacity(0.15))
            .foregroundStyle(selected ? .white : .primary)
            .clipShape(Capsule())
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var timeText: String {
        Self.timeFormatter.string(from: habitTime)
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E, d MMM yyyy"
        f.locale = .current
        return f
    }()

    var dateText: String {
        Self.fullDateFormatter.string(from: date)
    }
    var dateRangeText: String {
        let cal = Calendar.current

        switch repeatMode {
        case .oneDay:
            return cal.isDateInToday(date)
            ? String(localized: "date_today")
            : formattedDate(date)

        case .everyday:
            return String(localized: "date_every_day")

        case .week:
            guard let end = cal.date(byAdding: .day, value: 6, to: date) else { return "" }
            return "\(shortDate(date)) – \(shortDate(end))"

        case .month:
            guard let end = cal.date(byAdding: .day, value: 29, to: date) else { return "" }
            return "\(shortDate(date)) – \(shortDate(end))"
        }
    }

    private static let formattedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E, d MMM"
        f.locale = .current
        return f
    }()

    func formattedDate(_ d: Date) -> String {
        Self.formattedDateFormatter.string(from: d)
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = .current
        return f
    }()

    func shortDate(_ d: Date) -> String {
        Self.shortDateFormatter.string(from: d)
    }

   
    func updateDateForRepeatMode() {
        let today = Calendar.current.startOfDay(for: Date())
        switch repeatMode {
        case .oneDay: break
        default: date = today   
        }
    }
}


extension HabitType {
    var localized: String {
        switch self {
        case .binary:
            return String(localized: "habit_type_binary")
        case .accumulative:
            return String(localized: "habit_type_accumulative")
        }
    }
}
