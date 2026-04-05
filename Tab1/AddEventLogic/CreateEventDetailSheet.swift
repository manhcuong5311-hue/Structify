import SwiftUI

// MARK: - AddEventButton (unchanged)

struct AddEventButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text(String(localized: "event.add"))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }
}

// MARK: - CreateEventDetailSheet

struct CreateEventDetailSheet: View {

    @EnvironmentObject var store: TimelineStore

    // MARK: State — Event Data
    @State private var title: String = ""
    @State private var icon: String = "calendar.badge.plus"
    @State private var color: Color = Color(red: 108/255, green: 74/255, blue: 47/255)
    @State private var date: Date = Date()
    @State private var duration: Double = 1.5

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool

    let onCreate: (String, String, Int, Int, String, Recurrence) -> Void
    var onOpenHabit: (() -> Void)?
    let suggestedStart: Int

    // MARK: State — UI
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    @State private var durationMinutes: Int = 60
    @State private var showIconPicker = false
    @State private var showHabitSheet = false

    // MARK: State — Time
    @State private var startMinutes: Int = 20 * 60
    @State private var endMinutes: Int = 21 * 60 + 30
    @State private var startHour: Int = 20
    @State private var startMinute: Int = 0

    // MARK: State — Duration
    @State private var durationHours: Int = 1
    @State private var durationMinutesOnly: Int = 30

    // MARK: State — Flags
    @State private var isCompleted = false
    @State private var isAllDay = false

    // MARK: State — Repeat
    enum RepeatRule: CaseIterable {
        case none, weekly, specificWeek
        var title: String {
            switch self {
            case .none:         return String(localized: "repeat.none")
            case .weekly:       return String(localized: "repeat.weekly")
            case .specificWeek: return String(localized: "repeat.specific_week")
            }
        }
    }
    @State private var repeatRule: RepeatRule = .none
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedWeekOffset: Int = 0
    @State private var selectedWeekDates: Set<Date> = []

    // MARK: State — Warnings
    @State private var timeWarning: TimeWarning? = nil
    @State private var durationWarning: DurationWarning? = nil
    @State private var titleWarning: String? = nil

    // MARK: State — Expand/Collapse rows
    @State private var timeRowExpanded = true
    @State private var durationRowExpanded = true

    enum TimeWarning {
        case past, overlap, pastSleep, beforeWake
        var message: String {
            switch self {
            case .past:       return String(localized: "warning.time.past")
            case .overlap:    return String(localized: "warning.time.overlap")
            case .pastSleep:  return String(localized: "warning.time.past_sleep")
            case .beforeWake: return String(localized: "warning.time.before_wake")
            }
        }
    }

    enum DurationWarning {
        case exceedsSleep, tooShort, noTimeLeft
        var message: String {
            switch self {
            case .exceedsSleep: return String(localized: "warning.duration.exceeds_sleep")
            case .tooShort:     return String(localized: "warning.duration.too_short")
            case .noTimeLeft:   return String(localized: "warning.duration.no_time_left")
            }
        }
    }

    // MARK: Computed
    var sleepMinutes: Int  { store.sleepMinutes }
    var wakeMinutes:  Int  { store.wakeMinutes  }
    var isToday: Bool      { Calendar.current.isDateInToday(date) }
    var isFormBlocked: Bool { durationWarning == .noTimeLeft || durationWarning == .tooShort }
    var isPastTime: Bool   { isToday && startMinutes < currentMinutes }

    var currentMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: Init
    init(
        suggestedStart: Int,
        initialDate: Date = Date(),
        onOpenHabit: (() -> Void)? = nil,
        onCreate: @escaping (String, String, Int, Int, String, Recurrence) -> Void
    ) {
        self.suggestedStart = suggestedStart
        self.onCreate       = onCreate
        self.onOpenHabit    = onOpenHabit

        let defaultDur = PreferencesStore().defaultDuration

        _date                = State(initialValue: initialDate)
        _startMinutes        = State(initialValue: suggestedStart)
        _endMinutes          = State(initialValue: suggestedStart + defaultDur)
        _startHour           = State(initialValue: suggestedStart / 60)
        _startMinute         = State(initialValue: suggestedStart % 60)
        _durationHours       = State(initialValue: defaultDur / 60)
        _durationMinutesOnly = State(initialValue: defaultDur % 60)
        _startTime           = State(initialValue: TimelineEngine.dateFrom(minutes: suggestedStart, base: Date()))
    }

    // MARK: — BODY (NEW LAYOUT)
    // Layout architecture:
    //   ZStack {
    //     fullAmbientLayer     ← color bleeds entire screen
    //     VStack {
    //       topNavigationBar   ← transparent ~56pt
    //       heroPoster         ← icon + title + time summary  (~180pt)
    //       frostedFormPanel   ← single rounded panel, scrollable rows
    //     }
    //     continueButton (safeAreaInset)
    //   }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                // ── Layer 1: Full-screen color wash ──────────────────────
                fullAmbientLayer

                // ── Layer 2: Content ─────────────────────────────────────
                VStack(spacing: 0) {
                    topNavigationBar
                    heroPoster
                    frostedFormPanel
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
        .onAppear {
            let weekday = Calendar.current.component(.weekday, from: date)
            if !isPastWeekday(weekday) { selectedWeekdays.insert(weekday) }
            validateAndClampTime()
            validateDuration()
        }
        .onChange(of: date) { _, newDate in
            let weekday = Calendar.current.component(.weekday, from: newDate)
            if repeatRule == .weekly { selectedWeekdays.insert(weekday) }
            validateAndClampTime()
            validateDuration()
        }
        .sheet(isPresented: $showIconPicker) {
            IconPicker(icon: $icon, color: $color)
                .presentationBackground(Color.paper)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .ifPad { $0.presentationSizing(.page) }
        }
        .sheet(isPresented: $showHabitSheet) {
            CreateHabitDetailSheet(
                onCreate: { title, icon, colorHex, _, type, target, unit, minutes, increment, _ in
                    store.addHabit(
                        title: title, icon: icon, colorHex: colorHex,
                        minutes: minutes ?? 540, habitType: type,
                        targetValue: target, unit: unit, increment: increment
                    )
                },
                onOpenEvent: {
                    showHabitSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onOpenHabit?() }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .ifPad { $0.presentationSizing(.page) }
        }
    }
}

// MARK: - Full Ambient Layer

extension CreateEventDetailSheet {

    /// Replaces the old 210pt colored header — the tint now bleeds the entire screen.
    var fullAmbientLayer: some View {
        ZStack {
            // Base tint — full screen
            LinearGradient(
                colors: [color.opacity(0.82), color.opacity(0.38), color.opacity(0.08)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.55)
            )
            .ignoresSafeArea()

            // Soft blobs
            Circle()
                .fill(color.opacity(0.35))
                .blur(radius: 90)
                .frame(width: 320, height: 320)
                .offset(x: -80, y: -180)

            Circle()
                .fill(color.opacity(0.20))
                .blur(radius: 120)
                .frame(width: 280, height: 280)
                .offset(x: 160, y: 80)

            if isCompleted {
                Color.white.opacity(0.06)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.4), value: isCompleted)
            }
        }
    }
}

// MARK: - Top Navigation Bar

extension CreateEventDetailSheet {

    /// Slim transparent top bar — no background, no colored block.
    var topNavigationBar: some View {
        HStack {
            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.18))
                    .clipShape(Circle())
            }

            Spacer()


            // Add Habit
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onOpenHabit?() }
            } label: {
                Text(String(localized: "habit.add"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56) // below status bar
        .padding(.bottom, 8)
    }
}

// MARK: - Hero Poster  (replaces old large header block)

extension CreateEventDetailSheet {

    /// Left-aligned icon + hint label | title field + tick — editorial style.
    var heroPoster: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Row 1: Icon (left) + Title + Tick ────────────────────────
            HStack(alignment: .center, spacing: 14) {

                // Icon column: circle + hint label below
                VStack(spacing: 5) {
                    Button { showIconPicker = true } label: {
                        ZStack {
                            Circle().fill(.white.opacity(0.18))
                            Circle().stroke(.white.opacity(0.28), lineWidth: 1)
                            Image(systemName: icon)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(icon == "calendar.badge.plus" ? 0.72 : 1)
                        }
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)

                    // Hint button — open picker
                    Button { showIconPicker = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil")
                                .font(.system(size: 8, weight: .bold))
                            Text(String(localized: "icon.change"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.68))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Title field
                TextField(
                    String(localized: "event.name.placeholder"),
                    text: $title,
                    axis: .vertical
                )
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .tint(.white)
                .strikethrough(isCompleted, color: .white.opacity(0.85))
                .animation(.easeInOut(duration: 0.25), value: isCompleted)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { isTitleFocused = false }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(titleWarning != nil ? 0.22 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    titleWarning != nil
                                        ? Color.red.opacity(0.75)
                                        : Color.white.opacity(0.18),
                                    lineWidth: 1
                                )
                        )
                )
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .onChange(of: title) {
                    if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        titleWarning = nil
                    }
                }
                // Done button trên keyboard toolbar
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(String(localized: "keyboard.done")) {
                            isTitleFocused = false
                        }
                        .fontWeight(.semibold)
                    }
                }

                // Tick button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isCompleted.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.white.opacity(0.28) : Color.clear)
                            .animation(.easeInOut(duration: 0.25), value: isCompleted)
                        Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                        AnimatedCheckmark(progress: isCompleted ? 1 : 0)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            // ── Row 2: Time pill + repeat chips ──────────────────────────
            HStack(spacing: 8) {
                Image(systemName: isAllDay ? "sun.max" : "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))

                Text(timeRangeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))

                if repeatRule == .weekly && !selectedWeekdays.isEmpty {
                    Rectangle()
                        .fill(.white.opacity(0.30))
                        .frame(width: 1, height: 12)
                    weekdayChips
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.14))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        // Tap ngoài TextField → ẩn keyboard
        .contentShape(Rectangle())
        .onTapGesture { isTitleFocused = false }
    }

    var weekdayChips: some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        return HStack(spacing: 4) {
            ForEach(selectedWeekdays.sorted(), id: \.self) { day in
                Text(symbols[day - 1])
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.22))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Frosted Form Panel  (replaces old CardSection stack)

extension CreateEventDetailSheet {

    /// Single rounded frosted panel, rows separated by hairline dividers.
    var frostedFormPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                formPanelContent
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)

            Spacer(minLength: 120)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var formPanelContent: some View {
        // Date row
        dateFormRow
        panelDivider

        // Time row (expandable)
        timeFormRow
        if let w = timeWarning {
            warningBanner(w.message, color: .orange)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        panelDivider

        // Repeat row
        repeatFormRow
        panelDivider

        // Duration row (expandable)
        durationFormRow
        if let w = durationWarning {
            warningBanner(w.message, color: .purple)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
    }

    private var panelDivider: some View {
        Divider().padding(.horizontal, 18)
    }
}

// MARK: - Date Form Row

extension CreateEventDetailSheet {

    var dateFormRow: some View {
        HStack(spacing: 12) {
            formRowIcon("calendar", tint: .orange)

            VStack(alignment: .leading, spacing: 2) {
                formRowLabel(String(localized: "time.date"))
                Text(dateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            DatePicker(
                "",
                selection: $date,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .onChange(of: date) { _, newDate in selectedDate = newDate }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    var dateText: String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }
}

// MARK: - Time Form Row

extension CreateEventDetailSheet {

    var timeFormRow: some View {
        VStack(spacing: 0) {
            // Header row — always visible, tap to expand/collapse
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    timeRowExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    formRowIcon("clock", tint: .blue)

                    VStack(alignment: .leading, spacing: 2) {
                        formRowLabel(String(localized: "time.start"))
                        Text(isAllDay ? String(localized: "time.all_day") : String(format: "%02d:%02d", startHour, startMinute))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    remainingTimeBadge

                    allDayPill

                    Image(systemName: timeRowExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expanded pickers
            if timeRowExpanded && !isAllDay {
                HStack(spacing: 0) {
                    Picker("", selection: $startHour) {
                        ForEach(0..<24) { hour in
                            Text(String(format: "%02d", hour))
                                .tag(hour)
                                .foregroundStyle(isHourDimmed(hour) ? Color.gray.opacity(0.3) : Color.primary)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 88, height: 110)
                    .clipped()
                    .saturation(isHourDimmed(startHour) ? 0.2 : 1)
                    .opacity(isHourDimmed(startHour) ? 0.5 : 1)

                    Text(":")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)

                    Picker("", selection: $startMinute) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                            Text(String(format: "%02d", minute))
                                .tag(minute)
                                .foregroundStyle(isMinuteDimmed(minute) ? Color.gray.opacity(0.3) : Color.primary)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 88, height: 110)
                    .clipped()
                    .saturation(isMinuteDimmed(startMinute) ? 0.2 : 1)
                    .opacity(isMinuteDimmed(startMinute) ? 0.5 : 1)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .onChange(of: startHour)   { updateStartMinutes(); validateAndClampTime(); validateDuration() }
                .onChange(of: startMinute) { updateStartMinutes(); validateAndClampTime(); validateDuration() }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var remainingTimeBadge: some View {
        let effectiveStart = isToday ? max(startMinutes, currentMinutes) : startMinutes
        let remaining = sleepMinutes - effectiveStart
        let total     = sleepMinutes - wakeMinutes
        let ratio     = max(0.0, min(1.0, Double(remaining) / Double(max(total, 1))))
        let badgeColor: Color = remaining < 60 ? .red : remaining < 180 ? .orange : .green

        return HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 6, height: 6)
                .opacity(isAllDay ? 0 : 1)
            Text(isAllDay ? "" : remainingTimeText)
                .font(.caption.weight(.medium))
                .foregroundStyle(badgeColor)
                .monospacedDigit()
                .opacity(isAllDay ? 0 : 1)
        }
        .opacity(isAllDay ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: ratio)
    }

    private var allDayPill: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isAllDay.toggle() }
            applyAllDayToggle()
        } label: {
            Text(String(localized: "time.all_day"))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isAllDay ? Color.primary : Color.gray.opacity(0.12))
                .foregroundStyle(isAllDay ? Color(.systemBackground) : .secondary)
                .clipShape(Capsule())
        }
    }

    private func applyAllDayToggle() {
        if isAllDay {
            startHour = 0; startMinute = 0
            startMinutes = 0; endMinutes = 1440
            durationHours = 24; durationMinutesOnly = 0
            timeWarning = nil; durationWarning = nil
        } else {
            startHour   = suggestedStart / 60
            startMinute = suggestedStart % 60
            startMinutes = suggestedStart
            let d = PreferencesStore().defaultDuration
            durationHours = d / 60; durationMinutesOnly = d % 60
            updateEndTimeFromDuration()
            validateAndClampTime(); validateDuration()
        }
    }
}

// MARK: - Repeat Form Row

extension CreateEventDetailSheet {

    var repeatFormRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                formRowIcon("repeat", tint: .purple)
                formRowLabel(String(localized: "repeat.title"))
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Picker("", selection: $repeatRule) {
                ForEach(RepeatRule.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)

            if repeatRule == .weekly     { weekdayPickerRow.padding(.horizontal, 18) }
            if repeatRule == .specificWeek { weekPickerSection.padding(.horizontal, 18) }
        }
        .padding(.bottom, 14)
    }

    var weekdayPickerRow: some View {
        let calendar    = Calendar.current
        let symbols     = calendar.shortWeekdaySymbols
        let firstIdx    = calendar.firstWeekday - 1
        let orderedDays = Array(symbols[firstIdx...] + symbols[..<firstIdx])

        return HStack(spacing: 8) {
            ForEach(Array(orderedDays.enumerated()), id: \.offset) { index, symbol in
                let weekday    = ((index + firstIdx) % 7) + 1
                let isSelected = selectedWeekdays.contains(weekday)
                let isPast     = isPastWeekday(weekday)

                Button {
                    guard !isPast else { return }
                    if isSelected {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                } label: {
                    Text(symbol)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.purple.opacity(0.85) : Color.gray.opacity(0.10))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .opacity(isPast ? 0.35 : 1)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    var weekPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { offset in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedWeekOffset = offset; selectedWeekDates = []
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(weekHeaderLabel(offset: offset)).font(.caption.weight(.bold))
                                Text(weekDateRange(offset: offset)).font(.system(size: 9))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(selectedWeekOffset == offset ? Color.purple.opacity(0.85) : Color.gray.opacity(0.10))
                            .foregroundStyle(selectedWeekOffset == offset ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(datesOfWeek(offset: selectedWeekOffset), id: \.self) { d in
                    specificWeekDayChip(date: d)
                }
            }
        }
    }
}

// MARK: - Duration Form Row

extension CreateEventDetailSheet {

    var durationFormRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to expand/collapse
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    durationRowExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    formRowIcon("timer", tint: .green)

                    VStack(alignment: .leading, spacing: 2) {
                        formRowLabel(String(localized: "duration"))
                        Text(currentDurationLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    if !isAllDay && !isPastTime {
                        Text(String(localized: "max_duration_format \(maxDurationText)"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.gray.opacity(0.08)))
                    }

                    Image(systemName: durationRowExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expanded controls
            if durationRowExpanded {
                VStack(spacing: 14) {
                    // Preset chips — horizontal row
                    HStack(spacing: 10) {
                        ForEach([15, 30, 45, 60], id: \.self) { mins in
                            durationPreset(mins)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)

                    // Wheel pickers
                    HStack(spacing: 0) {
                        Picker("", selection: $durationHours) {
                            ForEach(0..<6) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 88, height: 100)

                        Picker("", selection: $durationMinutesOnly) {
                            ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) {
                                Text("\($0)m").tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 88, height: 100)

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .onChange(of: durationHours)       { updateDurationFromPicker(); validateDuration() }
                    .onChange(of: durationMinutesOnly) { updateDurationFromPicker(); validateDuration() }
                }
                .disabled(isAllDay || isPastTime)
                .opacity(isAllDay || isPastTime ? 0.38 : 1)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var currentDurationLabel: String {
        if isAllDay { return String(localized: "time.all_day") }
        let totalMins = durationHours * 60 + durationMinutesOnly
        if totalMins == 0 { return "—" }
        let h = totalMins / 60; let m = totalMins % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Continue Button

extension CreateEventDetailSheet {

    var continueButton: some View {
        VStack(spacing: 8) {
            continueHintText
            createButtonView
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: title.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFormBlocked)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var continueHintText: some View {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(String(localized: "enter_title_to_continue"))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).transition(.opacity)
        } else if (repeatRule == .weekly && selectedWeekdays.isEmpty) ||
                  (repeatRule == .specificWeek && selectedWeekDates.isEmpty) {
            Text(String(localized: "pick_at_least_one_day"))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).transition(.opacity)
        } else if isFormBlocked {
            Text(String(localized: "fix_issues_to_continue"))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).transition(.opacity)
        }
    }

    private var createButtonView: some View {
        let isBlocked = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     || isFormBlocked
                     || (repeatRule == .weekly       && selectedWeekdays.isEmpty)
                     || (repeatRule == .specificWeek && selectedWeekDates.isEmpty)

        return Button { handleCreateTap() } label: {
            Text(String(localized: "create_event"))
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(isBlocked ? Color.gray.opacity(0.35) : Color(.label))
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: isBlocked)
        }
    }

    private func handleCreateTap() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            withAnimation { titleWarning = String(localized: "warning_enter_title") }
            return
        }
        if repeatRule == .weekly && selectedWeekdays.isEmpty  { return }
        guard endMinutes > startMinutes                        else { return }
        if isToday && startMinutes < currentMinutes            { return }
        if isFormBlocked                                        { return }

        var dur = endMinutes - startMinutes
        if isAllDay { dur = 1440 }
        else if startMinutes + dur > sleepMinutes { dur = sleepMinutes - startMinutes }
        guard dur >= 5, endMinutes <= 1440 else { return }

        if repeatRule == .specificWeek {
            guard !selectedWeekDates.isEmpty else { return }
            for weekDate in selectedWeekDates.sorted() {
                guard !store.hasOverlap(minutes: startMinutes, duration: dur, date: weekDate) else { continue }
                onCreate(cleanTitle, icon, startMinutes, dur, color.toHex(), .once(weekDate))
            }
            dismiss(); return
        }

        guard !store.hasOverlap(minutes: startMinutes, duration: dur, date: date) else { return }
        onCreate(cleanTitle, icon, startMinutes, dur, color.toHex(), buildRecurrence())
        dismiss()
    }
}

// MARK: - Form Row Helpers

extension CreateEventDetailSheet {

    func formRowIcon(_ name: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.15))
                .frame(width: 34, height: 34)
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    func formRowLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    @ViewBuilder
    func warningBanner(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.88)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Time / Duration Logic  (all logic unchanged)

extension CreateEventDetailSheet {

    func isHourDimmed(_ hour: Int) -> Bool {
        let start = hour * 60; let end = hour * 60 + 59
        if isToday && end < currentMinutes { return true }
        if start >= sleepMinutes           { return true }
        if start < wakeMinutes             { return true }
        return false
    }

    func isMinuteDimmed(_ minute: Int) -> Bool {
        let total = startHour * 60 + minute
        if isToday && total < currentMinutes { return true }
        if total >= sleepMinutes             { return true }
        if total < wakeMinutes               { return true }
        return false
    }

    func validateAndClampTime() {
        guard !isAllDay else { timeWarning = nil; return }
        let total = startHour * 60 + startMinute
        if total < wakeMinutes {
            timeWarning = .beforeWake
            let c = ((wakeMinutes + 4) / 5) * 5
            startMinutes = c; startHour = c / 60; startMinute = c % 60
            updateEndTimeFromDuration(); return
        }
        if isToday && total < currentMinutes {
            timeWarning = .past
            let c = ((currentMinutes + 4) / 5) * 5
            startMinutes = min(c, sleepMinutes - 5)
            startHour = startMinutes / 60; startMinute = startMinutes % 60
            updateEndTimeFromDuration(); return
        }
        if total >= sleepMinutes {
            timeWarning = .pastSleep
            let c = ((sleepMinutes - 60 + 4) / 5) * 5
            startMinutes = max(wakeMinutes, c)
            startHour = startMinutes / 60; startMinute = startMinutes % 60
            updateEndTimeFromDuration(); return
        }
        if store.hasOverlap(minutes: total, duration: Int(duration * 60), date: date) {
            timeWarning = .overlap; return
        }
        timeWarning = nil
    }

    func validateDuration() {
        guard !isAllDay else { durationWarning = nil; return }
        let d = Int(duration * 60)
        if d < 5               { durationWarning = .tooShort; return }
        let rem = sleepMinutes - startMinutes
        if rem <= 0            { durationWarning = .noTimeLeft; return }
        if startMinutes + d > sleepMinutes { durationWarning = .exceedsSleep; return }
        durationWarning = nil
    }

    func updateStartMinutes() {
        startMinutes = startHour * 60 + startMinute
        updateEndTimeFromDuration()
    }

    func updateEndTimeFromDuration() {
        endMinutes = startMinutes + Int(duration * 60)
    }

    func updateStartTime(_ newValue: Int) {
        startMinutes = newValue; updateEndTimeFromDuration()
    }

    func updateDurationFromPicker() {
        duration = Double(durationHours) + Double(durationMinutesOnly) / 60
        updateEndTimeFromDuration()
    }

    func buildRecurrence() -> Recurrence {
        switch repeatRule {
        case .none:         return .once(date)
        case .weekly:       return .specific(Array(selectedWeekdays))
        case .specificWeek: return .once(date)
        }
    }

    var timeRangeText: String {
        if isAllDay { return String(localized: "time.all_day") }
        let sh = startMinutes / 60; let sm = startMinutes % 60
        let eh = endMinutes   / 60; let em = endMinutes   % 60
        let dur = endMinutes - startMinutes
        return String(format: "%02d:%02d–%02d:%02d (%dh %dm)", sh, sm, eh, em, dur / 60, dur % 60)
    }

    var remainingTimeText: String {
        let eff = isToday ? max(startMinutes, currentMinutes) : startMinutes
        let rem = sleepMinutes - eff
        if rem <= 0 { return String(localized: "time.no_time_left") }
        let h = rem / 60; let m = rem % 60
        if h > 0 && m > 0 { return String(format: String(localized: "time.remaining.full"), h, m) }
        if h > 0           { return String(format: String(localized: "time.remaining.hours"), h) }
        return String(format: String(localized: "time.remaining.minutes"), m)
    }

    var maxDurationText: String {
        let m = max(0, sleepMinutes - startMinutes)
        let h = m / 60; let mins = m % 60
        if h > 0 && mins > 0 { return "\(h)h \(mins)m" }
        if h > 0 { return "\(h)h" }
        return "\(mins)m"
    }

    var repeatSummaryText: String {
        if repeatRule == .none { return String(localized: "repeat.none") }
        let symbols = Calendar.current.shortWeekdaySymbols
        let names   = selectedWeekdays.sorted().map { symbols[$0 - 1] }
        return String(format: String(localized: "repeat.every"), names.joined(separator: ", "))
    }

    func isPastWeekday(_ weekday: Int) -> Bool {
        guard isToday else { return false }
        return weekday < Calendar.current.component(.weekday, from: Date())
    }

    func clampPastTime() {
        if isToday && startMinutes < currentMinutes {
            let snapped = ((currentMinutes + 4) / 5) * 5
            startMinutes = snapped; startHour = snapped / 60; startMinute = snapped % 60
        }
    }
}

// MARK: - Week Helpers

extension CreateEventDetailSheet {

    func weekStart(offset: Int) -> Date {
        let cal     = Calendar.current
        let today   = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return cal.date(byAdding: .weekOfYear, value: offset, to: thisMonday)!
    }

    func datesOfWeek(offset: Int) -> [Date] {
        let start = weekStart(offset: offset)
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    func weekHeaderLabel(offset: Int) -> String {
        switch offset {
        case 0:  return String(localized: "week_this")
        case 1:  return String(localized: "week_next")
        default: return String(localized: "week_in_format \(offset)")
        }
    }

    func weekDateRange(offset: Int) -> String {
        let dates = datesOfWeek(offset: offset)
        guard let first = dates.first, let last = dates.last else { return "" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return "\(f.string(from: first))–\(f.string(from: last))"
    }

    func isDatePast(_ d: Date) -> Bool {
        Calendar.current.startOfDay(for: d) < Calendar.current.startOfDay(for: Date())
    }

    @ViewBuilder
    func specificWeekDayChip(date: Date) -> some View {
        let cal        = Calendar.current
        let isPast     = isDatePast(date)
        let key        = cal.startOfDay(for: date)
        let isSelected = selectedWeekDates.contains(key)
        let dayLetter  = cal.veryShortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
        let dayNum     = cal.component(.day, from: date)
        
        Button {
            guard !isPast else { return }
            if isSelected {
                selectedWeekDates.remove(key)
            } else {
                selectedWeekDates.insert(key)
            }
        } label: {
            VStack(spacing: 3) {
                Text(dayLetter).font(.system(size: 10, weight: .bold))
                Text("\(dayNum)").font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.85) : (isPast ? Color.gray.opacity(0.06) : Color.gray.opacity(0.10)))
            .foregroundStyle(isSelected ? .white : (isPast ? Color.gray.opacity(0.35) : .primary))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isPast)
    }
}

// MARK: - Duration Preset

extension CreateEventDetailSheet {

    func durationPreset(_ minutes: Int) -> some View {
        let isActive = durationHours == minutes / 60 && durationMinutesOnly == minutes % 60
        return Button {
            durationHours = minutes / 60; durationMinutesOnly = minutes % 60
            updateDurationFromPicker()
        } label: {
            Text(labelForPreset(minutes))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? Color.green.opacity(0.85) : Color.gray.opacity(0.10))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    func labelForPreset(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}

// MARK: - Supporting Views (unchanged)

struct CardSection<Content: View>: View {
    let tint: Color
    let content: Content
    init(tint: Color = .blue, @ViewBuilder content: () -> Content) {
        self.tint = tint; self.content = content()
    }
    var body: some View {
        content
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 22).fill(tint.opacity(0.08))
                    RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
    }
}

struct TimeSlider: View {
    let title: String
    @Binding var minutes: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(timeString).font(.system(.headline, design: .rounded)).monospacedDigit()
            }
            Slider(
                value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }),
                in: 0...1439, step: 5
            )
        }
    }
    var timeString: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
}

struct AmbientBackground: View {
    var isCompleted: Bool
    var color: Color
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.28)).blur(radius: 120).offset(x: -140, y: -220)
            Circle().fill(color.opacity(0.18)).blur(radius: 140).offset(x: 160, y: 260)
            if isCompleted {
                Circle().fill(.white.opacity(0.12)).blur(radius: 160).scaleEffect(1.1)
                    .animation(.easeOut(duration: 0.4), value: isCompleted)
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
            .scaleEffect(progress).opacity(progress)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: progress)
    }
}
