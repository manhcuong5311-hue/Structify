//
//  HabitDetailSheet.swift
//  Structify
//
//  Created by Sam Manh Cuong on 15/3/26.
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
    @State private var editIncrement: Double = 1
    @State private var editUnit: String = "times"
    @State private var isEditingTarget = false
    @State private var targetWarning: String? = nil

    // MARK: - Notes
    @State private var notesText: String = ""
    @State private var isEditingNotes = false
    @FocusState private var notesFocused: Bool

    // MARK: - Alerts
    @State private var showDeleteAlert = false
    @State private var showScopeAlert = false
    @State private var showResetAlert = false

    let targetUnits = ["times", "km", "ml", "L", "min", "pages", "steps"]

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
        case .daily:    return "This habit repeats every day."
        case .weekdays: return "This habit repeats Mon–Fri."
        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            return "Repeats on " + days.sorted().map { s[$0-1] }.joined(separator: ", ")
        case .once: return ""
        case .dateRange(let start, let end):
            let f = DateFormatter(); f.dateFormat = "d MMM"
            return "This repeats from \(f.string(from: start)) to \(f.string(from: end))."
        }
    }

    var recurrenceText: String {
        guard let t = template else { return "–" }
        switch t.recurrence {
        case .daily:         return "Every day"
        case .weekdays:      return "Mon – Fri"
        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            return days.sorted().map { s[$0-1] }.joined(separator: ", ")
        case .once(let d):
            let f = DateFormatter(); f.dateFormat = "d MMM yyyy"
            return f.string(from: d)
        case .dateRange(let start, let end):
            let f = DateFormatter(); f.dateFormat = "d MMM"
            return "\(f.string(from: start)) – \(f.string(from: end))"
        }
    }

    var habitType: HabitType {
        template?.habitType ?? .binary
    }

    var targetValue: Double {
        template?.targetValue ?? 1
    }

    var incrementValue: Double {
        template?.increment ?? 1
    }

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

    var streakCount: Int {
        // Đếm ngày liên tiếp hoàn thành
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

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    var pageBg: Color {
        scheme == .dark ? Color(.systemBackground) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }
    
    // Thêm vào MARK: - Helpers trong HabitDetailSheet:
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
                        if habitType == .accumulative { progressSection }
                        checkInSection
                        infoSection
                        if habitType == .accumulative { targetEditSection }
                        notesSection
                        dangerSection
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Habit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { handleDone() }
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
                editUnit        = template?.unit ?? "times"
                editIncrement   = template?.increment ?? 1   // 👈 thêm
            }
            .sheet(isPresented: $showIconPicker) {
                IconPicker(icon: $editIcon, color: $editColor)
                    .presentationCornerRadius(28)
            }
            // MARK: Scope alert (edit recurring)
            .alert("Apply changes to", isPresented: $showScopeAlert) {
                Button("All Days") { saveEdits(scope: .allDays) }
                Button("Only Today") { saveEdits(scope: .onlyToday) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(recurrenceScopeMessage)
            }
            // MARK: Delete alert
            .alert("Delete Habit", isPresented: $showDeleteAlert) {
                Button("Delete Forever", role: .destructive) {
                    store.deleteTemplate(event.id)
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\"\(event.title)\" and all its history will be permanently removed. This cannot be undone.")
            }
            // MARK: Reset progress alert
            .alert("Reset today's progress?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    store.updateAccumulation(templateID: event.id, date: calendar.selectedDate, value: 0)
                    store.objectWillChange.send()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your progress for today only.")
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

    // MARK: - Hero

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

                        // Repeat badge
                        ZStack {
                            Circle().fill(Color(.systemBackground)).frame(width: 24, height: 24)
                            Image(systemName: "repeat")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(editColor)
                        }
                        .offset(x: 26, y: 26)

                        // Edit badge
                        ZStack {
                            Circle().fill(Color(.systemBackground)).frame(width: 20, height: 20)
                            Image(systemName: "pencil")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .offset(x: -24, y: 28)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    if isEditingTitle {
                        TextField("Habit name", text: $editTitle)
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
                            HStack(spacing: 6) {
                                Text(editTitle)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 24)
                        }
                        .buttonStyle(.plain)
                    }

                    // Completion badge
                    HStack(spacing: 5) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isFutureDate ? "Upcoming" : isCompleted ? "Completed" : "Not yet done")
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
            statChip(value: "\(streakCount)🔥", label: "Streak", icon: "flame.fill")

            if habitType == .accumulative {
                statChip(
                    value: "\(formatValue(currentProgress))/\(formatValue(targetValue))",
                    label: "Today",
                    icon: "chart.bar.fill"
                )
            }

            statChip(
                value: recurrenceText,
                label: "Schedule",
                icon: "repeat"
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
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

    // MARK: - Progress Section (accumulative only)

    var progressSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Progress")

            VStack(spacing: 14) {
                // Progress bar
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

                    Text("Goal: \(formatValue(targetValue)) \(template?.unit ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                if currentProgress > 0 && !isFutureDate {
                    Button {
                        showResetAlert = true
                    } label: {
                        Label("Reset today", systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                }
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

    // MARK: - Check-in Section

    var checkInSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Check-in")

            VStack(spacing: 12) {
                if isFutureDate {
                    Label("Can't check in for future dates", systemImage: "clock.badge.xmark")
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
                            Text(isCompleted ? "Mark as not done" : "Mark as done")
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
                    // Accumulative: stepper + quick add
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

    var infoSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Details")

            VStack(spacing: 0) {
                infoRow(icon: "repeat", iconBg: editColor, label: "Schedule", value: recurrenceText)
                rowDivider
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange).frame(width: 30, height: 30)
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Time").font(.body).foregroundStyle(.primary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                                comps.hour   = event.minutes / 60
                                comps.minute = event.minutes % 60
                                return cal.date(from: comps) ?? Date()
                            },
                            set: { newDate in
                                guard !isFutureDate && !isPastDate else { return }
                                let mins = Calendar.current.component(.hour, from: newDate) * 60
                                             + Calendar.current.component(.minute, from: newDate)
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
                    label: "Type",
                    value: habitType == .accumulative ? "Accumulative" : "Binary"
                )
                if habitType == .accumulative {
                    rowDivider
                    infoRow(icon: "target", iconBg: .red, label: "Target", value: "\(formatValue(targetValue)) \(template?.unit ?? "")")
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
            sectionHeader("Edit Target")

            VStack(spacing: 16) {
                // Target stepper
                HStack(spacing: 12) {
                    Text("Daily goal")
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
                        ForEach(targetUnits, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)

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
                    // Header row
                    HStack {
                        Text("Per tap").font(.body).foregroundStyle(.primary)
                        Spacer()
                        let taps = editTargetValue > 0 ? Int(ceil(editTargetValue / max(editIncrement, 0.01))) : 0
                        Text("\(taps) tap\(taps == 1 ? "" : "s") to complete")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)

                    // Preset chips
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

                    // Custom input row
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

                        Text("per tap")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                // Save target button
                Button {
                    guard targetWarning == nil else { return }
                    saveTargetEdits()
                } label: {
                    Text("Save target")
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
            targetWarning = "Target must be greater than 0"
        } else if editIncrement <= 0 {
            targetWarning = "Per tap must be greater than 0"
        } else if editIncrement > editTargetValue {
            targetWarning = "Per tap can't exceed target"
        } else {
            targetWarning = nil
        }
    }

    func saveTargetEdits() {
        guard let idx = store.templates.firstIndex(where: { $0.id == event.id }) else { return }
        store.templates[idx].targetValue = editTargetValue
        store.templates[idx].unit        = editUnit
        store.templates[idx].increment   = editIncrement   // 👈 thêm
        store.invalidateCache()
        store.save()
        store.objectWillChange.send()
        withAnimation { isEditingTarget = false }
    }

    // MARK: - Notes

    var notesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Notes")

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
                                Text("Add notes...")
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
                        Text("Done")
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
                                Text("Tap to add notes…").font(.body).foregroundStyle(.tertiary)
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

    // MARK: - Danger Section

    var dangerSection: some View {
        VStack(spacing: 12) {
            // Reset all history
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 14, weight: .semibold))
                    Text("Reset today's progress").font(.body.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.orange.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.12), lineWidth: 1))
                )
            }
            .opacity(habitType == .accumulative && currentProgress > 0 && !isFutureDate ? 1 : 0)

            // Delete
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash").font(.system(size: 14, weight: .semibold))
                    Text("Delete Habit").font(.body.weight(.semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.12), lineWidth: 1))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
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
