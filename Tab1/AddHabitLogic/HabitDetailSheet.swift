//
//  HabitDetailSheet.swift
//  Structify
//

import SwiftUI
import Combine

struct HabitDetailSheet: View {

    let event: EventItem
    var onDelete: () -> Void

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    // MARK: - Edit State
    @State private var editTitle: String = ""
    @State private var editIcon: String = ""
    @State private var editColor: Color = .green
    @State private var showIconPicker = false
    @State private var isEditingTitle = false
    @FocusState private var titleFocused: Bool

    // MARK: - Target / Increment Edit
    @State private var editTargetValue: Double = 1
    @State private var editMinutes: Int = 0
    @State private var editIncrement: Double = 1
    @State private var editUnit: String = "times"
    @State private var editCustomUnitText: String = ""
    @FocusState private var editCustomUnitFocused: Bool
    @State private var isEditingTarget = false
    @State private var targetWarning: String? = nil

    static let builtInUnitRawValues: Set<String> = {
        Set(CreateHabitDetailSheet.TargetUnit.allCases
            .filter { $0 != .custom }
            .map(\.rawValue))
    }()

    var editEffectiveUnitLabel: String {
        if editUnit == CreateHabitDetailSheet.TargetUnit.custom.rawValue {
            let trimmed = editCustomUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? String(localized: "unit_custom") : trimmed
        }
        return CreateHabitDetailSheet.TargetUnit(rawValue: editUnit)?.localized ?? editUnit
    }

    var editUnitForPersistence: String {
        if editUnit == CreateHabitDetailSheet.TargetUnit.custom.rawValue {
            return editCustomUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return editUnit
    }

    // MARK: - Notes
    @State private var notesText: String = ""
    @State private var isEditingNotes = false
    @FocusState private var notesFocused: Bool

    // MARK: - Alerts
    @State private var showDeleteAlert = false
    @State private var showScopeAlert = false
    @State private var showResetAlert = false

    // MARK: - Computed

    var template: EventTemplate? {
        store.templates.first { $0.id == event.id }
    }

    var isRecurring: Bool {
        guard let t = template else { return false }
        switch t.recurrence {
        case .once, .dateRange: return false
        default: return true
        }
    }

    var recurrenceScopeMessage: String {
        guard let t = template else { return "" }
        switch t.recurrence {
        case .daily:
            return String(localized: "habit_repeat_daily")
        case .weekdays:
            return String(localized: "habit_repeat_weekdays")
        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            let dayList = days.sorted().map { s[$0-1] }.joined(separator: ", ")
            return String.localizedStringWithFormat(
                NSLocalizedString("habit_repeat_specific %@", comment: ""),
                dayList
            )
        case .once:
            return ""
        case .dateRange(let start, let end):
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            return String.localizedStringWithFormat(
                NSLocalizedString("habit_repeat_range %@ %@", comment: ""),
                f.string(from: start),
                f.string(from: end)
            )
        }
    }

    var recurrenceText: String {
        guard let t = template else { return String(localized: "common_dash") }
        switch t.recurrence {
        case .daily:    return String(localized: "habit_every_day")
        case .weekdays: return String(localized: "habit_weekdays")
        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            return days.sorted().map { s[$0 - 1] }.joined(separator: ", ")
        case .once(let d):
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
            return f.string(from: d)
        case .dateRange(let start, let end):
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("d MMM")
            return String.localizedStringWithFormat(
                NSLocalizedString("habit_date_range %@ %@", comment: ""),
                f.string(from: start),
                f.string(from: end)
            )
        }
    }

    var habitType: HabitType { template?.habitType ?? .binary }
    var targetValue: Double { template?.targetValue ?? 1 }
    var incrementValue: Double { template?.increment ?? 1 }

    var currentProgress: Double {
        store.accumulationValue(templateID: event.id, date: calendar.selectedDate)
    }

    var progressFraction: CGFloat {
        guard habitType == .accumulative, targetValue > 0 else {
            return store.isCompleted(templateID: event.id, date: calendar.selectedDate) ? 1 : 0
        }
        return min(CGFloat(currentProgress / targetValue), 1)
    }

    var isCompleted: Bool {
        store.isCompleted(templateID: event.id, date: calendar.selectedDate)
    }

    var isPastDate: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: calendar.selectedDate)
        return selected < today
    }

    var isFutureDate: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let selected = Calendar.current.startOfDay(for: calendar.selectedDate)
        return selected > today
    }

    /// Consecutive completed days ending at the selected date.
    var streakCount: Int {
        var streak = 0
        let cal = Calendar.current
        var checkDate = calendar.selectedDate
        while true {
            if store.isCompleted(templateID: event.id, date: checkDate) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else { break }
        }
        return streak
    }

    /// Longest consecutive-completion run ever recorded for this habit.
    /// Scans the completion logs in date order; uses `isCompleted` so the
    /// accumulative case (value >= target) is judged the same way it is
    /// shown in the UI.
    var bestStreak: Int {
        let cal = Calendar.current
        let dayKeys = Set(
            store.completionLogs
                .filter { $0.templateID == event.id }
                .map(\.dateKey)
        )
        guard !dayKeys.isEmpty else { return 0 }

        // Convert to dates and sort
        let dates: [Date] = dayKeys.compactMap { k in
            var c = DateComponents()
            c.year = k / 10000
            c.month = (k / 100) % 100
            c.day = k % 100
            return cal.date(from: c)
        }.sorted()

        var best = 0, current = 0
        var prev: Date?
        for date in dates {
            guard store.isCompleted(templateID: event.id, date: date) else {
                current = 0
                prev = nil
                continue
            }
            if let p = prev,
               let nextOfPrev = cal.date(byAdding: .day, value: 1, to: p),
               cal.isDate(nextOfPrev, inSameDayAs: date) {
                current += 1
            } else {
                current = 1
            }
            if current > best { best = current }
            prev = date
        }
        return best
    }

    /// Count of completed days in the last 30 days (inclusive of today).
    var completionCount30d: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var count = 0
        for offset in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            if store.isCompleted(templateID: event.id, date: date) { count += 1 }
        }
        return count
    }

    /// Day-by-day status for the last 7 days (oldest first → today last).
    var last7DaysData: [(date: Date, fraction: CGFloat, completed: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [(date: Date, fraction: CGFloat, completed: Bool)] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let completed = store.isCompleted(templateID: event.id, date: date)
            let frac: CGFloat
            if habitType == .accumulative, targetValue > 0 {
                let v = store.accumulationValue(templateID: event.id, date: date)
                frac = min(CGFloat(v / targetValue), 1)
            } else {
                frac = completed ? 1 : 0
            }
            out.append((date, frac, completed))
        }
        return out
    }

    var nextOccurrenceText: String? {
        guard let t = template else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let selectedDay = cal.startOfDay(for: calendar.selectedDate)
        let base = max(today, selectedDay)
        guard var probe = cal.date(byAdding: .day, value: 1, to: base) else { return nil }
        for _ in 0..<366 {
            if t.matches(date: probe) {
                let f = DateFormatter()
                f.setLocalizedDateFormatFromTemplate("EEE d MMM")
                return f.string(from: probe)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: probe) else { return nil }
            probe = next
        }
        return nil
    }

    var startsFromText: String? {
        guard let s = template?.startDate else { return nil }
        let cal = Calendar.current
        if cal.startOfDay(for: s) <= cal.startOfDay(for: Date()) { return nil }
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return f.string(from: s)
    }

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    var pageBg: Color {
        scheme == .dark ? Color(.systemBackground) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection.padding(.top, 12)
                        quickStatsRow
                        progressOrWeekSection
                        checkInSection
                        infoSection
                        if habitType == .accumulative { targetEditSection }
                        notesSection
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(String(localized: "habit_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) { actionsMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_done")) { handleDone() }
                        .fontWeight(.semibold)
                        .foregroundStyle(editColor)
                }
            }
            .onAppear {
                editTitle       = event.title
                editIcon        = event.icon
                editColor       = event.color
                notesText       = template?.notes ?? ""
                editTargetValue = template?.targetValue ?? 1
                let storedUnit = template?.unit ?? "times"
                if Self.builtInUnitRawValues.contains(storedUnit) {
                    editUnit = storedUnit
                    editCustomUnitText = ""
                } else {
                    editUnit = CreateHabitDetailSheet.TargetUnit.custom.rawValue
                    editCustomUnitText = storedUnit
                }
                editIncrement   = template?.increment ?? 1
                editMinutes     = event.minutes
            }
            .sheet(isPresented: $showIconPicker) {
                IconPicker(icon: $editIcon, color: $editColor)
                    .presentationCornerRadius(28)
                    .adaptiveSheet()
            }
            .alert(
                String(localized: "habit_apply_changes_title"),
                isPresented: $showScopeAlert
            ) {
                Button(String(localized: "habit_apply_all_days")) {
                    saveEdits(scope: .allDays)
                }
                Button(String(localized: "habit_apply_only_today")) {
                    saveEdits(scope: .onlyToday)
                }
                Button(String(localized: "common_cancel"), role: .cancel) {}
            } message: {
                Text(recurrenceScopeMessage)
            }
            .alert(
                String(localized: "habit_delete_title"),
                isPresented: $showDeleteAlert
            ) {
                Button(String(localized: "habit_delete_forever"), role: .destructive) {
                    store.deleteTemplate(event.id)
                    onDelete()
                    dismiss()
                }
                Button(String(localized: "common_cancel"), role: .cancel) {}
            } message: {
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("habit_delete_message %@", comment: ""),
                        event.title
                    )
                )
            }
            .alert(
                String(localized: "habit_reset_title"),
                isPresented: $showResetAlert
            ) {
                Button(String(localized: "habit_reset_action"), role: .destructive) {
                    store.updateAccumulation(
                        templateID: event.id,
                        date: calendar.selectedDate,
                        value: 0
                    )
                    store.objectWillChange.send()
                }
                Button(String(localized: "common_cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "habit_reset_message"))
            }
        }
    }

    // MARK: - Done handler

    func handleDone() {
        let clean = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleChanged = clean != event.title && !clean.isEmpty
        let iconChanged  = editIcon != event.icon
        let colorChanged = editColor.toHex() != event.colorHex
        let hasChange    = titleChanged || iconChanged || colorChanged

        if hasChange && isRecurring {
            showScopeAlert = true
        } else {
            if hasChange { saveEdits(scope: .allDays) }
            else {
                store.updateNotes(templateID: event.id, notes: notesText)
                dismiss()
            }
        }
    }

    enum SaveScope { case allDays, onlyToday }

    func saveEdits(scope: SaveScope) {
        let clean = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        switch scope {
        case .allDays:
            store.updateEvent(templateID: event.id, title: clean, icon: editIcon, colorHex: editColor.toHex())
        case .onlyToday:
            store.overrideEventAppearance(templateID: event.id, date: calendar.selectedDate, title: clean, icon: editIcon, colorHex: editColor.toHex())
        }
        store.updateNotes(templateID: event.id, notes: notesText)
        dismiss()
    }

    // MARK: - Actions menu

    @ViewBuilder
    var actionsMenu: some View {
        Menu {
            if habitType == .accumulative && currentProgress > 0 && !isFutureDate {
                Button {
                    showResetAlert = true
                } label: {
                    Label(
                        String(localized: "menu.reset_progress"),
                        systemImage: "arrow.counterclockwise"
                    )
                }
                Divider()
            }
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label(
                    String(localized: "menu.delete_habit"),
                    systemImage: "trash"
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(editColor)
                .accessibilityLabel(Text(String(localized: "menu.actions")))
        }
    }

    // MARK: - Hero

    var statusText: String {
        if isFutureDate {
            return String(localized: "habit_status_upcoming")
        } else if isCompleted {
            return String(localized: "habit_status_completed")
        } else {
            return String(localized: "habit_status_not_done")
        }
    }

    var heroSection: some View {
        ZStack {
            RadialGradient(
                colors: [editColor.opacity(0.18), editColor.opacity(0.04)],
                center: .center, startRadius: 10, endRadius: 130
            )

            VStack(spacing: 16) {
                Button { showIconPicker = true } label: {
                    ZStack {
                        Circle().fill(editColor.opacity(0.12)).frame(width: 88, height: 88)
                        Circle()
                            .fill(LinearGradient(
                                colors: [editColor.opacity(0.22), editColor.opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 72, height: 72)
                        Image(systemName: editIcon)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(editColor)

                        // Single small repeat badge — signals "habit"
                        ZStack {
                            Circle().fill(Color(.systemBackground)).frame(width: 24, height: 24)
                            Image(systemName: "repeat")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(editColor)
                        }
                        .offset(x: 26, y: 26)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    if isEditingTitle {
                        TextField(String(localized: "habit_name_placeholder"), text: $editTitle)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .focused($titleFocused)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))
                            .padding(.horizontal, 32)
                            .submitLabel(.done)
                            .onSubmit { withAnimation { isEditingTitle = false } }
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                isEditingTitle = true
                                titleFocused = true
                            }
                        } label: {
                            Text(editTitle)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 13, weight: .semibold))
                        Text(statusText)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(isFutureDate ? .secondary : isCompleted ? Color.green : Color.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            isFutureDate ? Color.primary.opacity(0.06) :
                                isCompleted ? Color.green.opacity(0.1) : Color.primary.opacity(0.06)
                        )
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
                }
            }
            .padding(.vertical, 32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20)
        .shadow(color: editColor.opacity(scheme == .dark ? 0.12 : 0.08), radius: 16, y: 4)
    }

    // MARK: - Quick Stats

    var quickStatsRow: some View {
        HStack(spacing: 12) {
            statChip(
                value: "\(streakCount)",
                label: String(localized: "habit_stat_streak"),
                icon: "flame.fill"
            )

            if habitType == .accumulative {
                statChip(
                    value: "\(formatValue(currentProgress))/\(formatValue(targetValue))",
                    label: String(localized: "habit_stat_today"),
                    icon: "chart.bar.fill"
                )
            } else {
                statChip(
                    value: "\(Int(round(Double(completionCount30d) / 30.0 * 100)))%",
                    label: String(localized: "stat.completion_30d"),
                    icon: "percent"
                )
            }

            statChip(
                value: "\(bestStreak)",
                label: String(localized: "stat.best_streak"),
                icon: "crown.fill"
            )
        }
        .padding(.horizontal, 20)
    }

    func statChip(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(editColor)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(surface)
                .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 6, y: 2)
        )
    }

    // MARK: - Progress / Week overview

    @ViewBuilder
    var progressOrWeekSection: some View {
        if habitType == .accumulative {
            accumulativeProgressSection
        } else {
            weekOverviewSection
        }
    }

    var accumulativeProgressSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "habit_section_progress"))

            VStack(spacing: 16) {
                // Big progress bar + numeric
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08)).frame(height: 10)
                        Capsule()
                            .fill(isCompleted ? Color.green : editColor)
                            .frame(width: geo.size.width * progressFraction, height: 10)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressFraction)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 16)

                HStack {
                    Text("\(formatValue(currentProgress)) \(template?.unit ?? "")")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(editColor)
                    Spacer()
                    Text(
                        String.localizedStringWithFormat(
                            NSLocalizedString("habit_goal %@ %@", comment: ""),
                            formatValue(targetValue),
                            String(localized: "unit_\(template?.unit ?? "times")")
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                Divider().padding(.horizontal, 16)

                // 7-day mini bars
                weekBarsRow

                // 30-day completion rate
                thirtyDayFooter
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }

    var weekOverviewSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "section.last_7_days"))

            VStack(spacing: 14) {
                weekBarsRow
                thirtyDayFooter
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }

    /// 7-day mini bar row. Bar height encodes progress fraction (0–1).
    /// Empty days render as a low pill so the row never collapses.
    var weekBarsRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(last7DaysData.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            day.completed
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [editColor, editColor.opacity(0.7)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                : AnyShapeStyle(Color.primary.opacity(0.10))
                        )
                        .frame(
                            height: max(6, day.fraction * 40)
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: day.fraction)
                    Text(shortWeekday(day.date))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64, alignment: .bottom)
        .padding(.horizontal, 16)
    }

    var thirtyDayFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(
                String.localizedStringWithFormat(
                    NSLocalizedString("stat.last_30_days_format %lld", comment: ""),
                    completionCount30d
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(round(Double(completionCount30d) / 30.0 * 100)))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(editColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEE") // single letter
        return f.string(from: date)
    }

    // MARK: - Check-in Section

    var markButtonText: String {
        isCompleted
        ? String(localized: "habit_mark_not_done")
        : String(localized: "habit_mark_done")
    }

    var checkInSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "habit_section_checkin"))

            VStack(spacing: 12) {
                if isFutureDate {
                    Label(
                        String(localized: "habit_future_checkin_blocked"),
                        systemImage: "clock.badge.xmark"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                } else if habitType == .binary {
                    Button {
                        store.toggleCompletion(templateID: event.id, date: calendar.selectedDate)
                        store.objectWillChange.send()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isCompleted ? Color.green : editColor)
                            Text(markButtonText)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isCompleted ? Color.green : editColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isCompleted ? Color.green.opacity(0.1) : editColor.opacity(0.08))
                        )
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            if currentProgress > 0 {
                                let step = template?.increment ?? 1
                                store.updateAccumulation(
                                    templateID: event.id,
                                    date: calendar.selectedDate,
                                    value: max(0, currentProgress - step)
                                )
                                store.objectWillChange.send()
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(currentProgress > 0 ? editColor : Color.primary.opacity(0.2))
                        }
                        .disabled(currentProgress <= 0)

                        VStack(spacing: 2) {
                            Text(formatValue(currentProgress))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .animation(.spring(response: 0.3), value: currentProgress)
                            Text(template?.unit ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 60)

                        Button {
                            store.incrementAccumulation(
                                templateID: event.id,
                                date: calendar.selectedDate,
                                by: template?.increment ?? 1
                            )
                            store.objectWillChange.send()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(editColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Info Section

    var habitTypeText: String {
        switch habitType {
        case .accumulative: return String(localized: "habit_type_accumulative")
        case .binary:       return String(localized: "habit_type_binary")
        }
    }

    var targetDisplay: String {
        String.localizedStringWithFormat(
            NSLocalizedString("habit_target_value %@ %@", comment: ""),
            formatValue(targetValue),
            String(localized: "unit_\(template?.unit ?? "times")")
        )
    }

    var infoSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "habit_section_details"))

            VStack(spacing: 0) {
                infoRow(
                    icon: "repeat",
                    iconBg: editColor,
                    label: String(localized: "habit_stat_schedule"),
                    value: recurrenceText
                )

                rowDivider

                // Inline time editor — Apple-style row with trailing DatePicker
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange).frame(width: 30, height: 30)
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(String(localized: "habit_time"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                                comps.hour   = editMinutes / 60
                                comps.minute = editMinutes % 60
                                return cal.date(from: comps) ?? Date()
                            },
                            set: { newDate in
                                guard !isFutureDate && !isPastDate else { return }
                                let mins = Calendar.current.component(.hour, from: newDate) * 60
                                + Calendar.current.component(.minute, from: newDate)
                                editMinutes = mins
                                store.updateEventTimeFromToday(templateID: event.id, minutes: mins)
                            }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .disabled(isFutureDate || isPastDate)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)

                rowDivider

                infoRow(
                    icon: habitType == .accumulative ? "chart.bar.fill" : "checkmark.circle.fill",
                    iconBg: habitType == .accumulative ? .purple : .green,
                    label: String(localized: "habit_type_label"),
                    value: habitTypeText
                )

                if habitType == .accumulative {
                    rowDivider
                    infoRow(
                        icon: "target",
                        iconBg: .red,
                        label: String(localized: "habit_target_label"),
                        value: targetDisplay
                    )
                }

                if isRecurring, let next = nextOccurrenceText {
                    rowDivider
                    infoRow(
                        icon: "calendar.badge.clock",
                        iconBg: .indigo,
                        label: String(localized: "label.next_occurrence"),
                        value: next
                    )
                }

                if let starts = startsFromText {
                    rowDivider
                    infoRow(
                        icon: "flag.fill",
                        iconBg: .orange,
                        label: String(localized: "label.starts_from"),
                        value: starts
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Target Edit Section (accumulative only)

    var targetEditSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "habit_section_edit_target"))

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Text(String(localized: "habit_daily_goal"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            if editTargetValue > 1 {
                                editTargetValue -= 1
                                validateTarget()
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 36)
                        }
                        .disabled(editTargetValue <= 1)

                        TextField("", value: $editTargetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                            .onChange(of: editTargetValue) { validateTarget() }

                        Button {
                            editTargetValue += 1
                            validateTarget()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 36)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))

                    Picker("", selection: $editUnit) {
                        ForEach(CreateHabitDetailSheet.TargetUnit.allCases, id: \.rawValue) { u in
                            Text(u.localized).tag(u.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.subheadline.weight(.semibold))
                    .onChange(of: editUnit) {
                        if editUnit == CreateHabitDetailSheet.TargetUnit.custom.rawValue {
                            editCustomUnitFocused = true
                        }
                        validateTarget()
                    }
                }
                .padding(.horizontal, 16)

                if editUnit == CreateHabitDetailSheet.TargetUnit.custom.rawValue {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(editColor)
                        TextField(
                            String(localized: "unit_custom_placeholder"),
                            text: $editCustomUnitText
                        )
                        .focused($editCustomUnitFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .font(.subheadline.weight(.medium))
                        .onChange(of: editCustomUnitText) { validateTarget() }
                        .onSubmit { editCustomUnitFocused = false }

                        if !editCustomUnitText.isEmpty {
                            Button {
                                editCustomUnitText = ""
                                validateTarget()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(editCustomUnitFocused ? editColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let w = targetWarning {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(w).font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.85)))
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(String(localized: "habit_per_tap"))
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        let taps = editTargetValue > 0 ? Int(ceil(editTargetValue / max(editIncrement, 0.01))) : 0
                        Text(
                            String.localizedStringWithFormat(
                                NSLocalizedString("habit_taps_to_complete", comment: ""),
                                taps
                            )
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 8) {
                        ForEach([1.0, 5.0, 10.0], id: \.self) { preset in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    editIncrement = preset
                                    validateTarget()
                                }
                            } label: {
                                Text("+\(Int(preset))")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(
                                        editIncrement == preset
                                        ? editColor
                                        : Color.primary.opacity(0.07)
                                    )
                                    .foregroundStyle(editIncrement == preset ? .white : .primary)
                                    .clipShape(Capsule())
                                    .animation(.easeInOut(duration: 0.15), value: editIncrement)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        HStack(spacing: 0) {
                            Button {
                                if editIncrement > 1 {
                                    editIncrement = max(1, editIncrement - 1)
                                    validateTarget()
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .disabled(editIncrement <= 1)

                            TextField("", value: $editIncrement, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .onChange(of: editIncrement) { validateTarget() }

                            Button {
                                editIncrement += 1
                                validateTarget()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))

                        Text(String(localized: "habit_per_tap"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                Button {
                    guard targetWarning == nil else { return }
                    saveTargetEdits()
                } label: {
                    Text(String(localized: "habit_save_target"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(targetWarning == nil ? editColor : Color.gray.opacity(0.4))
                        )
                }
                .padding(.horizontal, 16)
                .disabled(targetWarning != nil)
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: targetWarning)
        }
    }

    func validateTarget() {
        if editTargetValue <= 0 {
            targetWarning = String(localized: "habit_error_target_gt_zero")
        } else if editIncrement <= 0 {
            targetWarning = String(localized: "habit_error_increment_gt_zero")
        } else if editIncrement > editTargetValue {
            targetWarning = String(localized: "habit_error_increment_exceeds_target")
        } else if editUnit == CreateHabitDetailSheet.TargetUnit.custom.rawValue &&
                    editCustomUnitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetWarning = String(localized: "unit_error_empty")
        } else {
            targetWarning = nil
        }
    }

    func saveTargetEdits() {
        guard let idx = store.templates.firstIndex(where: { $0.id == event.id }) else { return }
        store.templates[idx].targetValue = editTargetValue
        store.templates[idx].unit        = editUnitForPersistence
        store.templates[idx].increment   = editIncrement
        store.invalidateCache()
        store.save()
        store.objectWillChange.send()
        withAnimation { isEditingTarget = false }
    }

    // MARK: - Notes

    var notesSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "notes_title"))

            VStack(alignment: .leading, spacing: 0) {
                if isEditingNotes {
                    TextEditor(text: $notesText)
                        .focused($notesFocused)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 100)
                        .padding(14)
                        .overlay(alignment: .topLeading) {
                            if notesText.isEmpty {
                                Text(String(localized: "notes_add_placeholder"))
                                    .font(.body).foregroundStyle(.tertiary)
                                    .padding(.top, 22).padding(.leading, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    Divider().padding(.horizontal, 14)

                    Button {
                        store.updateNotes(templateID: event.id, notes: notesText)
                        withAnimation(.spring(response: 0.3)) {
                            isEditingNotes = false
                            notesFocused = false
                        }
                    } label: {
                        Text(String(localized: "done"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(editColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isEditingNotes = true
                            notesFocused = true
                        }
                    } label: {
                        HStack {
                            if notesText.isEmpty {
                                Text(String(localized: "notes_tap_to_add"))
                                    .font(.body).foregroundStyle(.tertiary)
                            } else {
                                Text(notesText).font(.body).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "pencil").font(.system(size: 12, weight: .medium)).foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .frame(minHeight: 52, alignment: .topLeading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isEditingNotes)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.bottom, 8)
    }

    var rowDivider: some View {
        Divider().padding(.leading, 56)
    }

    func infoRow(icon: String, iconBg: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBg).frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(label).font(.body).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
