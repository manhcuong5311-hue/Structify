import SwiftUI

enum HabitRepeat: String, CaseIterable {
    case oneDay, week, month, everyday
}

extension HabitRepeat {
    var localized: String {
        switch self {
        case .oneDay:    return String(localized: "habit_repeat_one_day")
        case .week:      return String(localized: "habit_repeat_week")
        case .month:     return String(localized: "habit_repeat_month")
        case .everyday:  return String(localized: "habit_repeat_everyday")
        }
    }
}

enum HabitType: String, Codable {
    case binary, accumulative
}

extension HabitType {
    var localized: String {
        switch self {
        case .binary:        return String(localized: "habit_type_binary")
        case .accumulative:  return String(localized: "habit_type_accumulative")
        }
    }
}

// MARK: - CreateHabitDetailSheet

struct CreateHabitDetailSheet: View {

    // MARK: State — Data
    @State private var title: String = ""
    @State private var icon: String  = "checkmark.circle.fill"
    @State private var color: Color  = Color(red: 120/255, green: 156/255, blue: 123/255)
    @State private var date: Date    = Date()
    @State private var isCompleted   = false
    @State private var showIconPicker = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TimelineStore
    @FocusState private var isTitleFocused: Bool

    let onCreate: (String, String, String, Date, HabitType, Double?, String?, Int?, Double?, HabitRepeat) -> Void
    let onOpenEvent: (() -> Void)?

    // MARK: State — Schedule
    @State private var repeatMode: HabitRepeat = .everyday
    @State private var habitTime: Date = Date()
    @State private var isAnytime = true

    // MARK: State — Habit config
    @State private var habitType: HabitType    = .binary
    @State private var targetValue: Double     = 10
    @State private var targetUnit: TargetUnit  = .times
    @State private var incrementValue: Double  = 1
    @State private var previewProgress: Double = 0

    enum TargetUnit: String, CaseIterable {
        case times, km, ml, l, min, pages, steps
        var localized: String {
            switch self {
            case .times: return String(localized: "unit_times")
            case .km:    return String(localized: "unit_km")
            case .ml:    return String(localized: "unit_ml")
            case .l:     return String(localized: "unit_l")
            case .min:   return String(localized: "unit_min")
            case .pages: return String(localized: "unit_pages")
            case .steps: return String(localized: "unit_steps")
            }
        }
    }

    // MARK: State — Validation
    @State private var titleWarning: String?  = nil
    @State private var timeWarning: String?   = nil
    @State private var targetWarning: String? = nil

    // MARK: State — Row expansion
    @State private var scheduleExpanded = true
    @State private var targetExpanded   = true

    let targetSuggestions: [Double]     = [5, 10, 20, 30, 50, 100]
    let incrementSuggestions: [Double]  = [1, 5, 10]

    // MARK: Computed
    var currentMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var selectedMinutes: Int {
        Calendar.current.component(.hour, from: habitTime) * 60 +
        Calendar.current.component(.minute, from: habitTime)
    }
    var headerScheduleText: String {
        isAnytime ? dateRangeText : "\(timeText) • \(dateRangeText)"
    }
    var isPastDate: Bool {
        let today    = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: date)
        switch repeatMode {
        case .oneDay, .week, .month: return selected < today
        case .everyday:              return false
        }
    }
    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && timeWarning == nil
        && targetWarning == nil
        && !isPastDate
    }

    // MARK: Validation
    func validateTime() {
        guard !isAnytime else { timeWarning = nil; return }
        let mins = selectedMinutes
        if isToday && mins < currentMinutes       { timeWarning = String(localized: "time_error_passed");      return }
        if mins < store.wakeMinutes               { timeWarning = String(localized: "time_error_before_wake"); return }
        if mins >= store.sleepMinutes             { timeWarning = String(localized: "time_error_after_sleep"); return }
        if store.hasOverlap(minutes: mins, duration: 30, date: date) {
            timeWarning = String(localized: "time_error_overlap"); return
        }
        timeWarning = nil
    }

    func validateTarget() {
        if habitType == .accumulative {
            if targetValue <= 0    { targetWarning = String(localized: "target_error_invalid");    return }
            if incrementValue <= 0 { targetWarning = String(localized: "increment_error_invalid"); return }
            if incrementValue > targetValue { targetWarning = String(localized: "increment_error_exceed"); return }
        }
        targetWarning = nil
    }

    // MARK: — BODY
    // Layout:
    //   ZStack {
    //     fullAmbientLayer          ← color wash full screen
    //     VStack {
    //       topBar                  ← xmark + add event
    //       heroPoster              ← icon(left) + title + progress/check + schedule pill
    //       frostedPanel            ← single panel, expandable rows
    //     }
    //     continueButton
    //   }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                fullAmbientLayer

                VStack(spacing: 0) {
                    topBar
                    heroPoster
                    frostedPanel
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                continueButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 20 : -20)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
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

// MARK: - Ambient Layer

extension CreateHabitDetailSheet {

    var fullAmbientLayer: some View {
        ZStack {
            LinearGradient(
                colors: [color.opacity(0.80), color.opacity(0.35), color.opacity(0.06)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.52)
            )
            .ignoresSafeArea()

            Circle()
                .fill(color.opacity(0.32))
                .blur(radius: 88)
                .frame(width: 300, height: 300)
                .offset(x: -90, y: -170)

            Circle()
                .fill(color.opacity(0.18))
                .blur(radius: 110)
                .frame(width: 260, height: 260)
                .offset(x: 150, y: 70)

            if isCompleted {
                Color.white.opacity(0.05).ignoresSafeArea()
                    .animation(.easeOut(duration: 0.4), value: isCompleted)
            }
        }
    }
}

// MARK: - Top Bar

extension CreateHabitDetailSheet {

    var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.18))
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
                    .background(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }
}

// MARK: - Hero Poster

extension CreateHabitDetailSheet {

    var heroPoster: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Row: icon column | title | preview button
            HStack(alignment: .center, spacing: 14) {

                // Icon + hint
                VStack(spacing: 5) {
                    Button { showIconPicker = true } label: {
                        ZStack {
                            Circle().fill(.white.opacity(0.18))
                            Circle().stroke(.white.opacity(0.28), lineWidth: 1)
                            Image(systemName: icon)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button { showIconPicker = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil").font(.system(size: 8, weight: .bold))
                            Text(String(localized: "icon.change")).font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.68))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Title field
                TextField(String(localized: "habit_name_placeholder"), text: $title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { isTitleFocused = false }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(titleWarning != nil ? 0.22 : 0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        titleWarning != nil ? Color.red.opacity(0.75) : Color.white.opacity(0.18),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(true)
                    .onChange(of: title) {
                        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { titleWarning = nil }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: "keyboard.done")) { isTitleFocused = false }
                                .fontWeight(.semibold)
                        }
                    }

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
                            Circle().stroke(Color.white, lineWidth: 1.5)
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
                    .frame(width: 36, height: 36)
                    .animation(.easeOut(duration: 0.25), value: previewProgress)
                }
                .buttonStyle(.plain)
            }

            // Schedule pill
            HStack(spacing: 8) {
                Image(systemName: isAnytime ? "calendar" : "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                Text(headerScheduleText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.white.opacity(0.14))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .contentShape(Rectangle())
        .onTapGesture { isTitleFocused = false }
    }
}

// MARK: - Frosted Panel

extension CreateHabitDetailSheet {

    var frostedPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                panelContent
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)

            Spacer(minLength: 120)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var panelContent: some View {
        // Date + repeat row
        dateRepeatRow
        panelDivider

        // Schedule row (expandable)
        scheduleRow
        if let w = timeWarning {
            warningInPanel(w, tint: .orange)
        }
        if isPastDate {
            warningInPanel(String(localized: "date_error_past_habit"), tint: .red)
        }
        panelDivider

        // Habit type row
        habitTypeRow
        panelDivider

        // Target row (expandable, only accumulative)
        if habitType == .accumulative {
            targetRow
            if let w = targetWarning {
                warningInPanel(w, tint: .purple)
            }
            panelDivider
            incrementRow
        }
    }

    private var panelDivider: some View {
        Divider().padding(.horizontal, 18)
    }

    @ViewBuilder
    private func warningInPanel(_ text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.88)))
        .padding(.horizontal, 16).padding(.bottom, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Date + Repeat Row

extension CreateHabitDetailSheet {

    var dateRepeatRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                rowIcon("calendar", tint: .orange)
                rowLabel(String(localized: "date_and_repeat"))
                Spacer()
                // Date picker (visible only for oneDay)
                if repeatMode == .oneDay {
                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            // Repeat chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                                .background(repeatMode == mode ? color : Color.gray.opacity(0.12))
                                .foregroundStyle(repeatMode == mode ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: repeatMode)
    }
}

// MARK: - Schedule Row (time of day, expandable)

extension CreateHabitDetailSheet {

    var scheduleRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    scheduleExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    rowIcon("clock", tint: .blue)

                    VStack(alignment: .leading, spacing: 2) {
                        rowLabel(String(localized: "time_of_day"))
                        Text(isAnytime ? String(localized: "anytime") : timeText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    // Anytime toggle pill
                    Button {
                        withAnimation(.spring()) { isAnytime.toggle() }
                        if isAnytime { timeWarning = nil } else { validateTime() }
                    } label: {
                        Text(String(localized: "anytime"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(isAnytime ? Color.primary : Color.gray.opacity(0.12))
                            .foregroundStyle(isAnytime ? Color(.systemBackground) : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: scheduleExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if scheduleExpanded && !isAnytime {
                HStack {
                    DatePicker("", selection: $habitTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .onChange(of: habitTime) { validateTime() }
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timeWarning)
    }
}

// MARK: - Habit Type Row

extension CreateHabitDetailSheet {

    var habitTypeRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                rowIcon(habitType == .binary ? "checkmark.circle" : "chart.bar", tint: color)
                rowLabel(String(localized: "habit_type"))
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 14)

            HStack(spacing: 10) {
                habitTypeChip(.binary,       sfIcon: "checkmark.circle")
                habitTypeChip(.accumulative, sfIcon: "chart.bar")
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }

    func habitTypeChip(_ type: HabitType, sfIcon: String) -> some View {
        let selected = habitType == type
        return Button {
            withAnimation(.spring()) { habitType = type; validateTarget() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sfIcon)
                Text(type.localized)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(selected ? color : Color.gray.opacity(0.10))
            .foregroundStyle(selected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Target Row (accumulative, expandable)

extension CreateHabitDetailSheet {

    var targetRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    targetExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    rowIcon("target", tint: .red)

                    VStack(alignment: .leading, spacing: 2) {
                        rowLabel(String(localized: "target"))
                        Text("\(Int(targetValue)) \(targetUnit.localized)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: targetExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if targetExpanded {
                VStack(spacing: 14) {
                    // Suggestion chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(targetSuggestions, id: \.self) { val in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        targetValue = val; validateTarget()
                                    }
                                } label: {
                                    Text("\(Int(val))")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(targetValue == val ? color : Color.gray.opacity(0.10))
                                        .foregroundStyle(targetValue == val ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    // Stepper + unit picker
                    HStack(spacing: 12) {
                        stepperControl(value: $targetValue, min: 1) { validateTarget() }

                        Picker("", selection: $targetUnit) {
                            ForEach(TargetUnit.allCases, id: \.self) {
                                Text($0.localized).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.subheadline.weight(.semibold))

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: targetWarning)
    }
}

// MARK: - Increment Row

extension CreateHabitDetailSheet {

    var incrementRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                rowIcon("plus.circle", tint: .green)

                VStack(alignment: .leading, spacing: 2) {
                    rowLabel(String(localized: "per_tap"))
                    Text("+\(Int(incrementValue)) \(targetUnit.localized)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                let taps = targetValue > 0 ? Int(ceil(targetValue / max(incrementValue, 0.01))) : 0
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("tap_to_complete_format", comment: ""),
                        taps
                    )
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.gray.opacity(0.08)))
            }
            .padding(.horizontal, 18).padding(.top, 14)

            // Suggestion chips
            HStack(spacing: 8) {
                ForEach(incrementSuggestions, id: \.self) { val in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            incrementValue = val; validateTarget()
                        }
                    } label: {
                        Text("+\(Int(val))")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(incrementValue == val ? color : Color.gray.opacity(0.10))
                            .foregroundStyle(incrementValue == val ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)

            // Stepper
            HStack(spacing: 12) {
                stepperControl(value: $incrementValue, min: 1) { validateTarget() }
                Text(targetUnit.localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Continue Button

extension CreateHabitDetailSheet {

    var continueButton: some View {
        VStack(spacing: 8) {
            // Hint text
            Group {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(String(localized: "hint_enter_title"))
                } else if timeWarning != nil {
                    Text(String(localized: "hint_fix_time"))
                } else if targetWarning != nil {
                    Text(String(localized: "hint_fix_target"))
                } else if isPastDate {
                    Text(String(localized: "date_error_create_past"))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .transition(.opacity)

            Button {
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanTitle.isEmpty else {
                    withAnimation { titleWarning = String(localized: "error_enter_title") }
                    return
                }
                guard timeWarning == nil, targetWarning == nil, !isPastDate else { return }

                let minutes = isAnytime ? nil : selectedMinutes
                onCreate(
                    cleanTitle, icon, color.toHex(), date, habitType,
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
                    .background(isFormValid ? Color(.label) : Color.gray.opacity(0.35))
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

// MARK: - Row Helpers

extension CreateHabitDetailSheet {

    func rowIcon(_ name: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 34, height: 34)
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    /// Reusable +/- stepper with inline text field.
    func stepperControl(value: Binding<Double>, min: Double, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button {
                if value.wrappedValue > min { value.wrappedValue -= 1; onChange() }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 36)
            }
            .disabled(value.wrappedValue <= min)

            TextField("", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(width: 60)
                .onChange(of: value.wrappedValue) { onChange() }

            Button {
                value.wrappedValue += 1; onChange()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 36)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.10)))
    }

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

    // Kept for backward compatibility
    func habitTypeButton(_ type: HabitType, icon: String) -> some View {
        habitTypeChip(type, sfIcon: icon)
    }
}

// MARK: - Date / Time Helpers (all logic unchanged)

extension CreateHabitDetailSheet {

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    var timeText: String { Self.timeFormatter.string(from: habitTime) }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "E, d MMM yyyy"; f.locale = .current; return f
    }()
    var dateText: String { Self.fullDateFormatter.string(from: date) }

    var dateRangeText: String {
        let cal = Calendar.current
        switch repeatMode {
        case .oneDay:
            return cal.isDateInToday(date) ? String(localized: "date_today") : formattedDate(date)
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
        let f = DateFormatter(); f.dateFormat = "E, d MMM"; f.locale = .current; return f
    }()
    func formattedDate(_ d: Date) -> String { Self.formattedDateFormatter.string(from: d) }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = .current; return f
    }()
    func shortDate(_ d: Date) -> String { Self.shortDateFormatter.string(from: d) }

    func updateDateForRepeatMode() {
        let today = Calendar.current.startOfDay(for: Date())
        switch repeatMode {
        case .oneDay: break
        default: date = today
        }
    }
}
