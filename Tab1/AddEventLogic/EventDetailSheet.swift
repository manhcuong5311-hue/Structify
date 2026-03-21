import SwiftUI

struct EventDetailSheet: View {

    let event: EventItem
    var onDelete: () -> Void
    var onEdit: (() -> Void)? = nil

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var showDeleteAlert = false
    @State private var showDeleteScopeAlert = false
    @State private var notesText: String = ""
    @State private var isEditingNotes = false
    @FocusState private var notesFocused: Bool
    @State private var editTitle: String = ""
    @State private var editIcon: String = ""
    @State private var editColor: Color = .blue
    @State private var showIconPicker = false
    @State private var isEditingTitle = false
    @FocusState private var titleFocused: Bool
    @State private var hasUnsavedEdits = false
    
    @State private var showScopeAlert = false
    @State private var pendingSave = false
    
    
    
    // MARK: - Computed
    
    var isRecurringEvent: Bool {
        guard let t = template else { return false }
        switch t.recurrence {
        case .once: return false
        default:    return true
        }
    }

    var recurrenceScopeMessage: String {
        guard let t = template else { return "" }

        switch t.recurrence {
        case .daily:
            return String(localized: "recurrence_scope_daily")

        case .weekdays:
            return String(localized: "recurrence_scope_weekdays")

        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            let names = days.sorted().map { s[$0 - 1] }.joined(separator: ", ")
            return String(localized: "recurrence_scope_specific \(names)")

        case .once:
            return ""

        case .dateRange(let start, let end):
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            let startStr = f.string(from: start)
            let endStr = f.string(from: end)

            return String(localized: "recurrence_scope_range \(startStr) \(endStr)")
        }
    }

    var template: EventTemplate? {
        store.templates.first { $0.id == event.id }
    }

    var recurrenceText: String {
        guard let t = template else {
            return String(localized: "dash_placeholder")
        }

        switch t.recurrence {
        case .daily:
            return String(localized: "recurrence_text_daily")

        case .weekdays:
            return String(localized: "recurrence_text_weekdays")

        case .specific(let days):
            let s = Calendar.current.shortWeekdaySymbols
            return days.sorted().map { s[$0 - 1] }.joined(separator: ", ")

        case .once(let d):
            let f = DateFormatter()
            f.dateFormat = "d MMM yyyy"
            return f.string(from: d)

        case .dateRange(let start, let end):
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            return String(
                localized: "recurrence_text_range \(f.string(from: start)) \(f.string(from: end))"
            )
        }
    }

    var recurrenceIcon: String {
        guard let t = template else {
            return "arrow.clockwise" // fallback hợp lý hơn "repeat"
        }

        switch t.recurrence {
        case .daily:
            return "arrow.clockwise"

        case .weekdays:
            return "calendar.badge.clock" // thay vì briefcase (logic thời gian rõ hơn)

        case .specific:
            return "calendar.badge.checkmark"

        case .once:
            return "calendar" // Apple style: single event = calendar

        case .dateRange:
            return "calendar.badge.clock"
        }
    }

    var isCompleted: Bool {
        store.isCompleted(templateID: event.id, date: calendar.selectedDate)
    }

    var durationText: String {
        guard let d = event.duration, d != 1440 else {
            return String(localized: "all_day")
        }

        let h = d / 60
        let m = d % 60

        if h > 0 && m > 0 {
            return String(localized: "duration_h_m \(h) \(m)")
        } else if h > 0 {
            return String(localized: "duration_h \(h)")
        } else {
            return String(localized: "duration_m \(m)")
        }
    }

    var dateText: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return f.string(from: calendar.selectedDate)
    }

    var timeText: String {
        guard event.duration != 1440 else {
            return String(localized: "all_day")
        }

        if let end = event.endTime {
            return String(localized: "time_range \(event.time) \(end)")
        }

        return event.time
    }

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    var pageBg: Color {
        scheme == .dark ? Color(.systemBackground) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection
                            .padding(.top, 12)

                        quickStatsRow

                        infoSection

                        notesSection

                        deleteSection
                    }
                    .padding(.bottom, 48)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(event.kind == .habit
                         ? String(localized: "kind_habit")
                         : String(localized: "kind_event"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "done")) {
                        let clean = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let titleChanged = clean != event.title
                        let iconChanged  = editIcon != event.icon
                        let colorChanged = editColor.toHex() != event.colorHex
                        let hasChange    = titleChanged || iconChanged || colorChanged

                        if hasChange && isRecurringEvent {
                            showScopeAlert = true  // hỏi user
                        } else {
                            if hasChange && !clean.isEmpty {
                                store.updateEvent(
                                    templateID: event.id,
                                    title: clean,
                                    icon: editIcon,
                                    colorHex: editColor.toHex()
                                )
                            }
                            saveNotes()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(editColor)
                }
            }
            .onAppear {
                notesText = template?.notes ?? ""
                editTitle = event.title
                editIcon  = event.icon
                editColor = event.color
            }
            .sheet(isPresented: $showIconPicker) {
                IconPicker(icon: $editIcon, color: $editColor)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(32)
                    .ifPad { $0.presentationSizing(.page) }
            }
            .onChange(of: showIconPicker) { _, isShowing in
                if !isShowing {
                    // Picker vừa đóng → đánh dấu có thay đổi
                    hasUnsavedEdits = true
                }
            }
            
            .alert(
                event.kind == .habit
                ? "delete_title_habit"
                : "delete_title_event",
                isPresented: $showDeleteAlert
            ) {
                Button("delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }

                Button("cancel", role: .cancel) {}
            } message: {
                Text("delete_message \(event.title)")
            }

            // Alert 2: recurring — hỏi scope
            .alert(
                String(
                    localized: event.kind == .habit
                    ? "delete_title_habit"
                    : "delete_title_event"
                ),
                isPresented: $showDeleteScopeAlert
            ) {
                Button(String(localized: "delete_only_today"), role: .destructive) {
                    onDelete()
                    dismiss()
                }

                Button(String(localized: "delete_all_scheduled"), role: .destructive) {
                    store.deleteTemplate(event.id)
                    dismiss()
                }

                Button(String(localized: "cancel"), role: .cancel) {}

            } message: {
                Text(
                    String(
                        localized: "delete_scope_message \(recurrenceScopeMessage)"
                    )
                )
            }
            
            .alert(String(localized: "apply_changes_title"), isPresented: $showScopeAlert) {

                Button(String(localized: "apply_all_days")) {
                    let clean = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    store.updateEvent(
                        templateID: event.id,
                        title: clean,
                        icon: editIcon,
                        colorHex: editColor.toHex()
                    )
                    saveNotes()
                    dismiss()
                }
                
                Button(String(localized: "apply_only_today")) {
                    let clean = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    store.overrideEventAppearance(
                        templateID: event.id,
                        date: calendar.selectedDate,
                        title: clean,
                        icon: editIcon,
                        colorHex: editColor.toHex()
                    )
                    saveNotes()
                    dismiss()
                }
                Button(String(localized: "cancel"), role: .cancel) {}
            } message: {
                Text(recurrenceScopeMessage)
            }
        }
    }

    // MARK: - Hero

    var heroSection: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [editColor.opacity(0.18), editColor.opacity(0.04)],
                    center: .center, startRadius: 10, endRadius: 120
                )
                VStack(spacing: 16) {

                    // Icon — tap để đổi
                    Button { showIconPicker = true } label: {
                        ZStack {
                            Circle()
                                .fill(editColor.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Circle()
                                .fill(LinearGradient(
                                    colors: [editColor.opacity(0.22), editColor.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 72, height: 72)
                            Image(systemName: editIcon)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(editColor)

                            // Edit badge nhỏ
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .offset(x: 26, y: 26)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: editColor)

                    VStack(spacing: 8) {
                        // Title — tap để edit
                        if isEditingTitle {
                            TextField(String(localized: "event_name_placeholder"), text: $editTitle)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .focused($titleFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.primary.opacity(0.08))
                                )
                                .padding(.horizontal, 32)
                                .submitLabel(.done)
                                .onSubmit {
                                    withAnimation { isEditingTitle = false }
                                    hasUnsavedEdits = true
                                }
                                .onChange(of: editTitle) { hasUnsavedEdits = true }
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

                        completionBadge
                    }
                }
                .padding(.vertical, 32)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 20)
            .shadow(color: editColor.opacity(scheme == .dark ? 0.12 : 0.08), radius: 16, y: 4)
        }
    }

    var completionBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 13, weight: .semibold))
            Text(isCompleted
                 ? String(localized: "status_completed")
                 : String(localized: "status_not_completed"))
        }
        .foregroundStyle(isCompleted ? Color.green : Color.secondary)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isCompleted
                    ? Color.green.opacity(0.1)
                    : Color.primary.opacity(0.06)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
    }

    // MARK: - Quick Stats Row

    var quickStatsRow: some View {
        HStack(spacing: 12) {

            statChip(
                value: event.time,
                label: String(localized: "stat_start"),
                icon: "clock.fill"
            )

            if event.duration != 1440 {
                statChip(
                    value: durationText,
                    label: String(localized: "stat_duration"),
                    icon: "timer"
                )
            }

            statChip(
                value: event.kind.localizedName,
                label: String(localized: "stat_type"),
                icon: event.kind.iconName
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

    // MARK: - Info Section

    var infoSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "section.details"))
            
            VStack(spacing: 0) {
                infoRow(
                    icon: "calendar",
                    iconBg: .blue,
                    label: String(localized: "label.date"),
                    value: dateText
                )
                
                rowDivider

                if event.duration != 1440 {
                    infoRow(
                        icon: "clock",
                        iconBg: editColor,
                        label: String(localized: "label.time"),
                        value: timeText,
                        valueColor: editColor
                    )
                    
                    rowDivider
                }

                infoRow(
                    icon: recurrenceIcon,
                    iconBg: .orange,
                    label: String(localized: "label.repeats"),
                    value: recurrenceText
                )
                
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 8, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    var rowDivider: some View {
        Divider()
            .padding(.leading, 56)
    }

    func infoRow(
        icon: String,
        iconBg: Color,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(spacing: 12) {
            // iOS-style colored icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(valueColor == .primary ? .secondary : valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Notes Section

    var notesSection: some View {
        VStack(spacing: 0) {
            sectionHeader(String(localized: "section.notes"))

            VStack(alignment: .leading, spacing: 0) {
                if isEditingNotes {
                    TextEditor(text: $notesText)
                        .focused($notesFocused)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 100)
                        .padding(14)
                        .overlay(alignment: .topLeading) {
                            if notesText.isEmpty {
                                Text(String(localized: "placeholder.add_notes"))

                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 22)
                                    .padding(.leading, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    Divider().padding(.horizontal, 14)

                    // Done editing button
                    Button {
                        saveNotes()
                        withAnimation(.spring(response: 0.3)) {
                            isEditingNotes = false
                            notesFocused = false
                        }
                    } label: {
                        Text(String(localized: "action.done"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(editColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
                                Text(String(localized: "placeholder.tap_to_add_notes"))
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(notesText)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
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

    func saveNotes() {
        store.updateNotes(templateID: event.id, notes: notesText)
    }

    // MARK: - Delete

    var deleteSection: some View {
        
        Button(role: .destructive) {
            if isRecurringEvent {
                showDeleteScopeAlert = true
            } else {
                showDeleteAlert = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("action.delete_item_format \(Text(event.kind.localizedKey))")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.red.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
    
    private var deleteTitle: String {
        let type = String(localized: event.kind == .habit ? "type.habit" : "type.event")
        
        return String(format: String(localized: "action.delete_item_format"), type)
    }
    
    
}

extension EventKind {

    var localizedName: String {
        switch self {
        case .habit:
            return String(localized: "kind_habit")
        case .event:
            return String(localized: "kind_event")
        }
    }

    var iconName: String {
        switch self {
        case .habit:
            return "repeat"
        case .event:
            return "calendar"
        }
    }
}

extension EventKind {
    
    var localizedKey: String {
        switch self {
        case .habit: return "type.habit"
        case .event: return "type.event"
        }
    }
}

enum L10n {
    static let habit: LocalizedStringResource = "type.habit"
    static let event: LocalizedStringResource = "type.event"
}
