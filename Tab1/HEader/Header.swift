//
//  Header.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI
import Combine



class CalendarState: ObservableObject {

    @Published var selectedDate: Date = Date()

    private let calendar = Calendar.current
    
    
    
    var weekDates: [Date] {
        let prefs = PreferencesStore()
        var cal = calendar
        cal.firstWeekday = prefs.firstWeekday  // 1=Sun, 2=Mon
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap {
            cal.date(byAdding: .day, value: $0, to: startOfWeek)
        }
    }

    func nextWeek() {
        selectedDate =
        calendar.date(byAdding: .day, value: 7, to: selectedDate)!
    }

    func previousWeek() {
        selectedDate =
        calendar.date(byAdding: .day, value: -7, to: selectedDate)!
    }

    func select(_ date: Date) {
        selectedDate = date
    }

    var dateKey: String {

        staticFormatter.string(from: selectedDate)
    }

    private let staticFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    
}




// TÌM toàn bộ struct HeaderDateView, ĐỔI THÀNH:
struct HeaderDateView: View {

    @EnvironmentObject var calendar: CalendarState
    var brand: Color { Color(hex: PreferencesStore().accentHex) }
    @Environment(\.colorScheme) private var scheme
    @State private var showMonthPicker = false   // ← THÊM

    var body: some View {
        HStack {
            // Tap vào cả row date → mở picker
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMonthPicker = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text(calendar.selectedDate,
                         format: .dateTime.day())
                        .font(.system(size: 32, weight: .bold))

                    Text(calendar.selectedDate,
                         format: .dateTime.month(.abbreviated))
                        .font(.system(size: 32, weight: .bold))

                    Text(calendar.selectedDate,
                         format: .dateTime.year())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(brand)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(brand)
                        .rotationEffect(.degrees(showMonthPicker ? 90 : 0))
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.75),
                            value: showMonthPicker
                        )
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .background(
            (scheme == .dark ? Color.black : Color(.systemGray6))
                .ignoresSafeArea(edges: .top)
        )
        // Sheet mở picker
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerView(
                selectedDate: $calendar.selectedDate
            ) {
                showMonthPicker = false
            }
            .presentationDetents(
                UIDevice.current.userInterfaceIdiom == .pad
                    ? [.large]
                    : [.medium, .large]
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .ifPad { $0.presentationSizing(.form) }
        }
    }
}

struct WeekStripView: View {

    @EnvironmentObject var calendar: CalendarState
    @EnvironmentObject var store: TimelineStore
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.colorScheme) private var scheme

    @Namespace private var dayAnim
    var brand: Color { Color(hex: PreferencesStore().accentHex) }

    // MARK: Drag state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    private let swipeThreshold: CGFloat = 60

    var uiScale: CGFloat {
        hSize == .regular ? 1.35 : 1.0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // tuần trước (bên trái)
                weekView(offsetWeeks: -1)
                    .offset(x: -geo.size.width + dragOffset)

                // tuần hiện tại
                weekView(offsetWeeks: 0)
                    .offset(x: dragOffset)

                // tuần sau (bên phải)
                weekView(offsetWeeks: 1)
                    .offset(x: geo.size.width + dragOffset)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        // chỉ nhận horizontal drag
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false

                        let velocity = value.predictedEndTranslation.width
                        let shouldSwipe = abs(dragOffset) > swipeThreshold || abs(velocity) > 300

                        if shouldSwipe {
                            if dragOffset < 0 {
                                // swipe left → next week
                                withAnimation(.easeOut(duration: 0.25)) {
                                    dragOffset = -geo.size.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    calendar.nextWeek()
                                    dragOffset = 0
                                }
                            } else {
                                // swipe right → previous week
                                withAnimation(.easeOut(duration: 0.25)) {
                                    dragOffset = geo.size.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    calendar.previousWeek()
                                    dragOffset = 0
                                }
                            }
                        } else {
                            // snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .background(
            (scheme == .dark ? Color.black : Color(.systemGray6))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Week View

    private func weekView(offsetWeeks: Int) -> some View {

        let baseDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: offsetWeeks,
            to: calendar.selectedDate
        )!

        var cal = Calendar.current
        cal.firstWeekday = PreferencesStore().firstWeekday
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: baseDate)!.start

        let dates = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: startOfWeek)
        }

        return HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                dayCell(date: date)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Day Cell

    private func dayCell(date: Date) -> some View {

        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: calendar.selectedDate)
        let isToday = cal.isDateInToday(date)

        return VStack(spacing: 6) {

            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)

            ZStack {
                if isToday {
                    Circle()
                        .stroke(brand, lineWidth: 1.8)
                        .opacity(0.9)
                        .frame(width: 42 * uiScale, height: 42 * uiScale)
                }

                if isSelected {
                    Circle()
                        .fill(brand)
                        .matchedGeometryEffect(id: "DAY", in: dayAnim)
                        .frame(width: 38 * uiScale, height: 38 * uiScale)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }

                Text(date, format: .dateTime.day())
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        isSelected ? .white : (isToday ? brand : .primary)
                    )
            }
            .frame(width: 38 * uiScale, height: 38 * uiScale)

            iconRow(for: date)
        }
        .frame(width: 44 * uiScale, height: 90 * uiScale)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.1 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                calendar.select(date)
            }
        }
    }

    // MARK: Icon Row (giữ nguyên logic cũ)

    func iconRow(for date: Date) -> some View {
        let event = nextOrActiveEvent(for: date)
        let size: CGFloat = 22 * uiScale
        let sideSize: CGFloat = 17 * uiScale

        return HStack(spacing: -7 * uiScale) {
            if let event {
                let state = eventState(for: event)
                EventMiniIcon(icon: event.icon, color: Color(hex: event.colorHex), size: size)
                    .scaleEffect(state == .active ? 1.2 : 1.15)
                    .shadow(
                        color: state == .active ? Color(hex: event.colorHex).opacity(0.4) : .clear,
                        radius: 6
                    )
            } else {
                EventMiniIcon(icon: "sunrise.fill", color: .orange.opacity(0.75), size: sideSize)
                EventMiniIcon(icon: "moon.stars.fill", color: .indigo.opacity(0.75), size: sideSize)
            }
        }
        .frame(height: size)
    }

    // MARK: Helpers (giữ nguyên)

    func eventState(for event: EventItem) -> EventState {
        let cal = Calendar.current
        let now = Date()
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let start = event.minutes
        let end = event.minutes + (event.duration ?? 0)
        if nowMinutes >= start && nowMinutes <= end { return .active }
        if nowMinutes < start { return .upcoming }
        return .past
    }

    enum EventState { case past, active, upcoming }

    func nextOrActiveEvent(for date: Date) -> EventItem? {
        let events = store.events(for: date).filter { !$0.isSystemEvent }
        let cal = Calendar.current
        let now = Date()
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return events.sorted { $0.minutes < $1.minutes }.first {
            $0.minutes + ($0.duration ?? 0) >= nowMinutes
        }
    }
}

// MARK: - Compact Week Timeline Strip

import SwiftUI
import Combine

// MARK: - WeekStripPeriod

private enum WeekStripPeriod: Int, CaseIterable {
    case morning    // 0..<720   (before 12:00)
    case afternoon  // 720..<1080 (12:00–18:00)
    case night      // 1080..<1440 (after 18:00)

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .night:     return "moon.fill"
        }
    }

    var label: String {
        switch self {
        case .morning:   return String(localized: "Morning")
        case .afternoon: return String(localized: "Noon")
        case .night:     return String(localized: "Night")
        }
    }

    var color: Color {
        switch self {
        case .morning:   return .orange
        case .afternoon: return .yellow
        case .night:     return .indigo
        }
    }

    func contains(minutes: Int) -> Bool {
        switch self {
        case .morning:   return minutes < 720
        case .afternoon: return minutes >= 720 && minutes < 1080
        case .night:     return minutes >= 1080
        }
    }
}

// MARK: - WeekTimelineView

struct WeekTimelineView: View {

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var hSize

    private let badgeSize: CGFloat = 26
    private let badgeGap: CGFloat = 3
    private let maxStripHeight: CGFloat = 260

    private var brand: Color { Color(hex: PreferencesStore().accentHex) }

    private var weekDates: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = PreferencesStore().firstWeekday
        let start = cal.dateInterval(of: .weekOfYear, for: calendar.selectedDate)?.start
            ?? calendar.selectedDate
        return (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: start)
        }
    }

    // MARK: - Data

    private var weekEventsMap: [Date: [EventItem]] {
        var map: [Date: [EventItem]] = [:]
        for date in weekDates {
            map[date] = store.events(for: date)
                .filter { !$0.isSystemEvent && $0.duration != 1440 }
                .sorted { $0.minutes < $1.minutes }
        }
        return map
    }

    private var hasAnyEvents: Bool {
        weekEventsMap.values.contains { !$0.isEmpty }
    }

    private var activePeriods: [WeekStripPeriod] {
        let allEvents = weekEventsMap.values.flatMap { $0 }
        return WeekStripPeriod.allCases.filter { period in
            allEvents.contains { period.contains(minutes: $0.minutes) }
        }
    }

    private func events(for date: Date, period: WeekStripPeriod) -> [EventItem] {
        (weekEventsMap[date] ?? []).filter { period.contains(minutes: $0.minutes) }
    }

    private func maxBadgeCount(for period: WeekStripPeriod) -> Int {
        var maxCount = 0
        for date in weekDates {
            maxCount = max(maxCount, events(for: date, period: period).count)
        }
        return max(maxCount, 1)
    }

    private func nowMinutes() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: - Body

    var body: some View {
        if !hasAnyEvents {
            EmptyView()
        } else {
            let periods = activePeriods
            // header row height + event rows per period + spacing
            let totalHeight = periods.reduce(CGFloat(0)) { acc, period in
                let rows = CGFloat(maxBadgeCount(for: period))
                let headerH: CGFloat = 24
                let eventsH = rows * badgeSize + max(rows - 1, 0) * badgeGap
                return acc + headerH + 2 + eventsH
            } + CGFloat(max(periods.count - 1, 0)) * 8

            Group {
                if totalHeight > maxStripHeight {
                    ScrollView(.vertical, showsIndicators: false) {
                        stripContent(periods: periods)
                    }
                    .frame(maxHeight: maxStripHeight)
                } else {
                    stripContent(periods: periods)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Strip content

    @ViewBuilder
    private func stripContent(periods: [WeekStripPeriod]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(periods, id: \WeekStripPeriod.rawValue) { period in
                periodSection(period: period)
            }
        }
    }

    // MARK: - Period section: header label row + event grid rows

    @ViewBuilder
    private func periodSection(period: WeekStripPeriod) -> some View {
        let rowCount = maxBadgeCount(for: period)
        let now = nowMinutes()
        let isNowPeriod = period.contains(minutes: now)

        VStack(alignment: .leading, spacing: 2) {
            // ── Period header: icon + label ──
            HStack(spacing: 5) {
                Image(systemName: period.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(period.color)

                Text(period.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(period.color)
            }
            .padding(.leading, 2)
            .padding(.vertical, 3)
            .frame(height: 24)

            // ── Event grid rows ──
            // Each row: 7 columns aligned with day cells
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                        let dayEvents = events(for: date, period: period)
                        let isPast = Calendar.current.startOfDay(for: date) <
                            Calendar.current.startOfDay(for: Date())
                        let isDayToday = Calendar.current.isDateInToday(date)

                        ZStack {
                            if rowIndex < dayEvents.count {
                                badgeView(event: dayEvents[rowIndex])
                            }

                            // Now dot on first row of today's column
                            if isDayToday && isNowPeriod && rowIndex == 0 {
                                Circle()
                                    .fill(brand)
                                    .frame(width: 5, height: 5)
                                    .shadow(color: brand.opacity(0.5), radius: 2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                                           alignment: .topTrailing)
                                    .padding(.trailing, 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: badgeSize)
                        .opacity(isPast ? 0.35 : 1)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                calendar.select(date)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Badge view

    @ViewBuilder
    private func badgeView(event: EventItem) -> some View {
        let color = event.color

        ZStack {
            Circle()
                .fill(color.opacity(scheme == .dark ? 0.25 : 0.15))
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 1.2)
                )

            Image(systemName: safeIcon(event.icon))
                .font(.system(size: badgeSize * 0.4, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: badgeSize, height: badgeSize)
        .shadow(color: color.opacity(0.18), radius: 2, y: 1)
    }

    // MARK: - Helpers

    private func safeIcon(_ name: String) -> String {
        guard !name.isEmpty, UIImage(systemName: name) != nil else { return "checkmark.circle.fill" }
        return name
    }
}


struct EventMiniIcon: View {

    let icon: String
    let color: Color
    var size: CGFloat

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        ZStack {

            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
               

            Image(systemName: UIImage(systemName: icon) != nil ? icon : "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(color)   // 👈 không opacity
        }
        .frame(width: size, height: size)
    }

    private var backgroundColor: Color {
        scheme == .dark
        ? color.opacity(0.25)
        : color.opacity(0.12)
    }

    private var borderColor: Color {
        scheme == .dark
        ? .black.opacity(0.35)
        : .white.opacity(0.9)
    }
}
