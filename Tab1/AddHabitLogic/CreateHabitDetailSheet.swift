import SwiftUI

enum HabitRepeat: String, CaseIterable {
    case oneDay, week, month, weekdays, everyday

    // Cases shown in the create-habit picker. `oneDay` is excluded because a
    // single-day "habit" is really an event — the Event flow handles that.
    static var habitCases: [HabitRepeat] {
        [.everyday, .weekdays, .week, .month]
    }
}

extension HabitRepeat {
    var localized: String {
        switch self {
        case .oneDay:    return String(localized: "habit_repeat_one_day")
        case .week:      return String(localized: "habit_repeat_week")
        case .month:     return String(localized: "habit_repeat_month")
        case .weekdays:  return String(localized: "habit_repeat_weekdays")
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
    @State private var icon: String  = "leaf.fill"
    @State private var color: Color  = Color(red: 120/255, green: 156/255, blue: 123/255)
    @State private var date: Date    = Date()
    @State private var isCompleted   = false
    @State private var showIconPicker = false

    /// Same role as in CreateEventDetailSheet — latches `true` whenever the user
    /// (or a template / a container hand-off) explicitly chose an icon. While
    /// `false`, the keyword auto-suggester swaps icon/color as the user types.
    @State private var iconWasManuallySet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TimelineStore
    @ObservedObject private var premium = PremiumStore.shared
    @FocusState private var isTitleFocused: Bool

    let onCreate: (String, String, String, Date, HabitType, Double?, String?, Int?, Double?, HabitRepeat) -> Void
    let onOpenEvent: (() -> Void)?
    let initialMinutes: Int?

    /// Fired whenever title/icon/color change. The parent (e.g. `CreateItemSheet`)
    /// uses this to keep its own copy in sync so it can re-inject the values when
    /// the user toggles Habit ↔ Event mid-flow. Standalone presentations pass nil.
    var onCommonFieldsChange: ((_ title: String, _ icon: String, _ colorHex: String) -> Void)?

    init(
        initialMinutes: Int? = nil,
        initialTitle: String = "",
        initialIcon: String? = nil,
        initialColorHex: String? = nil,
        onCreate: @escaping (String, String, String, Date, HabitType, Double?, String?, Int?, Double?, HabitRepeat) -> Void,
        onOpenEvent: (() -> Void)? = nil,
        onCommonFieldsChange: ((_ title: String, _ icon: String, _ colorHex: String) -> Void)? = nil
    ) {
        self.initialMinutes        = initialMinutes
        self.onCreate              = onCreate
        self.onOpenEvent           = onOpenEvent
        self.onCommonFieldsChange  = onCommonFieldsChange

        if let m = initialMinutes {
            let cal = Calendar.current
            let date = cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            _habitTime = State(initialValue: date)
            _isAnytime = State(initialValue: false)
        }

        // Restore preserved fields from the container.
        _title = State(initialValue: initialTitle)
        if let i = initialIcon { _icon = State(initialValue: i) }
        if let c = initialColorHex { _color = State(initialValue: Color(hex: c)) }
        _iconWasManuallySet = State(initialValue: initialIcon != nil)
    }

    // MARK: State — Schedule
    @State private var repeatMode: HabitRepeat = .everyday
    @State private var habitTime: Date = Date()
    @State private var isAnytime = true

    // MARK: State — Habit config
    @State private var habitType: HabitType    = .binary
    @State private var targetValue: Double     = 10
    @State private var targetUnit: TargetUnit  = .times
    @State private var customUnitText: String  = ""
    @FocusState private var customUnitFocused: Bool
    @State private var incrementValue: Double  = 1
    @State private var previewProgress: Double = 0

    enum TargetUnit: String, CaseIterable {
        case times, km, ml, l, min, pages, steps, custom
        var localized: String {
            switch self {
            case .times:  return String(localized: "unit_times")
            case .km:     return String(localized: "unit_km")
            case .ml:     return String(localized: "unit_ml")
            case .l:      return String(localized: "unit_l")
            case .min:    return String(localized: "unit_min")
            case .pages:  return String(localized: "unit_pages")
            case .steps:  return String(localized: "unit_steps")
            case .custom: return String(localized: "unit_custom")
            }
        }
    }

    /// Display label for unit anywhere outside the chip-picker — substitutes the user's
    /// typed string when `.custom` is selected, falls back to the "Custom" label until
    /// they type something.
    var effectiveUnitLabel: String {
        if targetUnit == .custom {
            let trimmed = customUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? String(localized: "unit_custom") : trimmed
        }
        return targetUnit.localized
    }

    /// Value persisted to the habit model — raw enum name for built-ins, typed string for custom.
    var unitForPersistence: String {
        targetUnit == .custom
            ? customUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
            : targetUnit.rawValue
    }

    // MARK: State — Validation
    @State private var titleWarning: String?  = nil
    @State private var timeWarning: String?   = nil
    @State private var targetWarning: String? = nil

    // MARK: State — Row expansion
    @State private var scheduleExpanded = true
    @State private var targetExpanded   = true

    // MARK: State — Templates
    @State private var selectedCategory: HabitCategory? = nil
    @State private var appliedTemplateID: UUID? = nil

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
        case .weekdays, .everyday:   return false
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
            if targetUnit == .custom &&
               customUnitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                targetWarning = String(localized: "unit_error_empty"); return
            }
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
                    templatesRow
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
        .onChange(of: title) { onCommonFieldsChange?(title, icon, color.toHex()) }
        .onChange(of: icon)  { onCommonFieldsChange?(title, icon, color.toHex()) }
        .onChange(of: color) { onCommonFieldsChange?(title, icon, color.toHex()) }
        .onAppear {
            // Catch seeded titles from mode-toggle: .onChange(of: title) skips
            // the initial value, so run the suggester once here for parity with
            // the event sheet.
            applyKeywordSuggestion()
        }
    }
}

// MARK: - Templates Row

extension CreateHabitDetailSheet {

    var templatesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryPill(nil, label: String(localized: "habit_category_all"), icon: "sparkles")
                    ForEach(HabitCategory.allCases) { cat in
                        categoryPill(cat, label: cat.localized, icon: cat.icon)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Template cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitTemplateCatalog.filtered(by: selectedCategory)) { tpl in
                        templateCard(tpl)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func categoryPill(_ cat: HabitCategory?, label: String, icon: String) -> some View {
        let selected = selectedCategory == cat
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedCategory = cat
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(selected ? Color.white.opacity(0.28) : Color.white.opacity(0.10))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(selected ? 0.45 : 0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private func templateCard(_ tpl: HabitTemplate) -> some View {
        let isApplied = appliedTemplateID == tpl.id
        let tplColor = Color(hex: tpl.colorHex)
        Button {
            apply(template: tpl)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tplColor)
                        .frame(width: 44, height: 44)
                        .shadow(color: tplColor.opacity(0.45), radius: 6, y: 3)
                    Image(systemName: tpl.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(String(localized: String.LocalizationValue(tpl.titleKey)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 76)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isApplied ? tplColor : Color.primary.opacity(0.08),
                        lineWidth: isApplied ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressFeedbackButtonStyle(scale: 0.94))
        .accessibilityLabel(Text(String(localized: String.LocalizationValue(tpl.titleKey))))
        .accessibilityAddTraits(isApplied ? [.isSelected, .isButton] : .isButton)
    }

    // Pre-fills the form with a template's settings.
    // Every field is overwritten — picking a template is an explicit "use this
    // preset" gesture. target/unit/increment are always set (even for binary
    // templates) so flipping to accumulative afterwards shows habit-appropriate
    // defaults instead of stale values from a previous template.
    func apply(template tpl: HabitTemplate) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            title = String(localized: String.LocalizationValue(tpl.titleKey))
            titleWarning = nil
            icon = tpl.icon
            color = Color(hex: tpl.colorHex)
            habitType = tpl.type
            targetValue = tpl.target
            targetUnit = tpl.unit
            incrementValue = tpl.increment

            if let mins = tpl.suggestedMinutes {
                isAnytime = false
                let cal = Calendar.current
                habitTime = cal.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: Date()) ?? Date()
            } else {
                isAnytime = true
                timeWarning = nil
            }

            appliedTemplateID  = tpl.id
            iconWasManuallySet = true
            validateTarget()
            if !isAnytime { validateTime() }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Mirrors the event sheet helper — heuristic icon/color from the typed
    /// title, gated by `iconWasManuallySet` so deliberate picks survive.
    func applyKeywordSuggestion() {
        guard !iconWasManuallySet else { return }
        guard let match = KeywordIconMap.match(title) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            icon  = match.icon
            color = Color(hex: match.colorHex)
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

            // Add Event — toggle mode via parent CreateItemSheet; falls back to dismiss
            // only when this sheet is presented standalone (no container wired up).
            Button {
                if let onOpenEvent {
                    onOpenEvent()
                } else {
                    dismiss()
                }
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
                    Button { showIconPicker = true; iconWasManuallySet = true } label: {
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

                    Button { showIconPicker = true; iconWasManuallySet = true } label: {
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
                        applyKeywordSuggestion()
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
            panelDivider
        }

        // Preview summary
        previewRow
    }

    private var panelDivider: some View {
        Divider().padding(.horizontal, 18)
    }

    // Summary row that shows how the habit will appear on the timeline.
    @ViewBuilder
    var previewRow: some View {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = cleanTitle.isEmpty
            ? String(localized: "habit_preview_placeholder_title")
            : cleanTitle

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                rowIcon("eye.fill", tint: color)
                rowLabel(String(localized: "habit_preview_label"))
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 14)

            HStack(spacing: 12) {
                // Time column
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAnytime ? String(localized: "anytime") : timeText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(dateRangeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 76, alignment: .leading)

                // Mock event row
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(habitType == .accumulative
                            ? "\(Int(targetValue)) \(effectiveUnitLabel) • +\(Int(incrementValue))"
                            : String(localized: "habit_type_binary"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    // Mock completion ring
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.08))
                )
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
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
                    ForEach(HabitRepeat.habitCases, id: \.self) { mode in
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

            VStack(spacing: 8) {
                habitTypeChip(
                    .binary,
                    sfIcon: "checkmark.circle",
                    subtitle: String(localized: "habit_type_binary_desc")
                )
                habitTypeChip(
                    .accumulative,
                    sfIcon: "chart.bar",
                    subtitle: String(localized: "habit_type_accumulative_desc")
                )
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }

    func habitTypeChip(_ type: HabitType, sfIcon: String, subtitle: String = "") -> some View {
        let selected = habitType == type
        return Button {
            withAnimation(.spring()) { habitType = type; validateTarget() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: sfIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? .white : color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.localized)
                        .font(.subheadline.weight(.semibold))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? color : Color.gray.opacity(0.10))
            .foregroundStyle(selected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressFeedbackButtonStyle(scale: 0.98))
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
                        Text("\(Int(targetValue)) \(effectiveUnitLabel)")
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

                    // Stepper
                    HStack(spacing: 12) {
                        stepperControl(value: $targetValue, min: 1) { validateTarget() }
                        Spacer()
                    }
                    .padding(.horizontal, 18)

                    // Unit chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TargetUnit.allCases, id: \.self) { unit in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        targetUnit = unit
                                    }
                                    if unit == .custom { customUnitFocused = true }
                                    validateTarget()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 4) {
                                        if unit == .custom {
                                            Image(systemName: "pencil")
                                                .font(.caption2.weight(.bold))
                                        }
                                        Text(unit.localized)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(targetUnit == unit ? color : Color.gray.opacity(0.10))
                                    .foregroundStyle(targetUnit == unit ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(PressFeedbackButtonStyle(scale: 0.92))
                                .accessibilityAddTraits(targetUnit == unit ? [.isSelected, .isButton] : .isButton)
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    // Custom unit input — visible only when `.custom` chip is selected.
                    if targetUnit == .custom {
                        HStack(spacing: 10) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(color)
                            TextField(
                                String(localized: "unit_custom_placeholder"),
                                text: $customUnitText
                            )
                            .focused($customUnitFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .font(.subheadline.weight(.medium))
                            .onChange(of: customUnitText) { validateTarget() }
                            .onSubmit { customUnitFocused = false }

                            if !customUnitText.isEmpty {
                                Button {
                                    customUnitText = ""
                                    validateTarget()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(customUnitFocused ? color.opacity(0.55) : Color.clear, lineWidth: 1.5)
                        )
                        .padding(.horizontal, 18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
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
                    Text("+\(Int(incrementValue)) \(effectiveUnitLabel)")
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
                Text(effectiveUnitLabel)
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

    private var currentHabitCount: Int {
        store.templates.filter { !$0.isSystemEvent && $0.kind == .habit }.count
    }

    private var isAtFreeLimit: Bool {
        !premium.isPremium && currentHabitCount >= PremiumLimit.maxFreeHabits
    }

    var continueButton: some View {
        VStack(spacing: 8) {
            // Hint text
            Group {
                if isAtFreeLimit {
                    EmptyView()
                } else if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

            if isAtFreeLimit {
                PremiumLimitPill(
                    message: String(
                        format: String(localized: "premium_limit_habits %lld"),
                        PremiumLimit.maxFreeHabits
                    ),
                    onTap: {
                        NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                        dismiss()
                    }
                )
            } else {
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
                        habitType == .accumulative ? unitForPersistence : nil,
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
        case .weekdays:
            return String(localized: "date_weekdays")
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
