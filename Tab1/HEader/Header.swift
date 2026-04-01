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

//
//  WeekTimelineView.swift
//  Structify
//
//  Updated to match pill + circle timeline mockup
//

import SwiftUI
import Combine

// MARK: - WeekTimelineView

//
//  WeekTimelineView.swift
//  Structify
//
//  Updated: collision-avoidance layout — circles no longer overlap
//

import SwiftUI
import Combine

// MARK: - WeekTimelineView

struct WeekTimelineView: View {

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme

    private let iconSize: CGFloat = 32
    private var pillWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 70 : 50
    }
    private let lineWidth: CGFloat = 1.5

    private var wakeHour: Int { store.wakeMinutes / 60 }
    private var sleepHour: Int { (store.sleepMinutes + 59) / 60 }

    private var weekDates: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = PreferencesStore().firstWeekday
        let start = cal.dateInterval(of: .weekOfYear, for: calendar.selectedDate)?.start
            ?? calendar.selectedDate
        return (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: start)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let maxH = geo.size.height * 0.55
            let isIpad = UIDevice.current.userInterfaceIdiom == .pad
            let targetHourH: CGFloat = isIpad
                ? max((maxH - iconSize * 2 - 16) / CGFloat(max(sleepHour - wakeHour, 1)), 20)
                : min(
                    max((maxH - iconSize * 2 - 16) / CGFloat(max(sleepHour - wakeHour, 1)), 20),
                    40
                  )

            HStack(alignment: .top, spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    CompactDayColumn(
                        date: date,
                        wakeHour: wakeHour,
                        sleepHour: sleepHour,
                        hourHeight: targetHourH,
                        pillWidth: pillWidth,
                        lineWidth: lineWidth,
                        iconSize: iconSize
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, isIpad ? 48 : 4)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - PlacedEvent (layout result)

/// Kết quả sau khi chạy layout pass — Y đã điều chỉnh tránh overlap
private struct PlacedEvent {
    let event: EventItem
    /// Y tính từ top của timeline zone.
    /// Với circle: top-edge của circle frame.
    /// Với pill: top-edge của pill.
    let topY: CGFloat
    let isCircle: Bool
}

// MARK: - CompactDayColumn

struct CompactDayColumn: View {

    let date: Date
    let wakeHour: Int
    let sleepHour: Int
    let hourHeight: CGFloat
    let pillWidth: CGFloat
    let lineWidth: CGFloat
    let iconSize: CGFloat

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme

    /// Events có duration <= ngưỡng này → hình tròn; còn lại → pill
    private let circleThreshold = 35   // phút

    /// Khoảng trống tối thiểu giữa hai events sau khi layout
    private let minEventGap: CGFloat = 3

    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: calendar.selectedDate)
    }
    private var isToday: Bool  { Calendar.current.isDateInToday(date) }
    private var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }

    private var totalHours: Int        { max(sleepHour - wakeHour, 1) }
    private var timelineHeight: CGFloat { CGFloat(totalHours) * hourHeight }

    private var allEvents: [EventItem] { store.events(for: date).filter { $0.duration != 1440 } }
    private var wakeEvent:  EventItem? { allEvents.first { $0.systemType == .wake  } }
    private var sleepEvent: EventItem? { allEvents.first { $0.systemType == .sleep } }
    private var userEvents: [EventItem] { allEvents.filter { !$0.isSystemEvent } }

    private var nowMinutes: Int {
        Calendar.current.component(.hour,   from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    var brand: Color { Color(hex: PreferencesStore().accentHex) }

    // MARK: Helpers

    private func yInTimeline(minutes: Int) -> CGFloat {
        CGFloat(minutes - wakeHour * 60) / 60.0 * hourHeight
    }

    func safeIcon(_ name: String) -> String {
        guard !name.isEmpty, UIImage(systemName: name) != nil else { return "checkmark.circle.fill" }
        return name
    }

    // MARK: - Layout pass — tránh overlap

    /// Duyệt qua tất cả user events theo thứ tự thời gian.
    /// Mỗi event được gán topY sao cho không trùng với event trước.
    ///
    /// Quy tắc:
    /// - Circle: idealTop = centerY - iconSize/2. Nếu bị block bởi event trước → đẩy xuống.
    /// - Pill:   idealTop = yInTimeline(startMin).   Nếu bị block bởi circle/pill trước → đẩy xuống.
    private func computeLayout() -> [PlacedEvent] {
        let sorted = userEvents.sorted { $0.minutes < $1.minutes }
        var result: [PlacedEvent] = []

        // bottom-edge của event cuối đã được đặt
        var nextFreeY: CGFloat = -9999

        for event in sorted {
            let duration = event.duration ?? 60
            let startMin = max(event.minutes, wakeHour * 60)
            guard startMin < sleepHour * 60 else { continue }

            let isCircle = duration <= circleThreshold

            if isCircle {
                // ── Circle ──────────────────────────────────────────
                let idealCenterY = yInTimeline(minutes: startMin)
                let idealTop     = idealCenterY - iconSize / 2

                let adjustedTop  = max(idealTop, nextFreeY + minEventGap)
                let clampedTop   = min(adjustedTop, max(0, timelineHeight - iconSize))

                nextFreeY = clampedTop + iconSize
                result.append(PlacedEvent(event: event, topY: clampedTop, isCircle: true))

            } else {
                // ── Pill ─────────────────────────────────────────────
                let endMin  = min(event.minutes + duration, sleepHour * 60)
                let rawH    = max(CGFloat(endMin - startMin) / 60.0 * hourHeight, 30)
                let idealTop = yInTimeline(minutes: startMin)

                let adjustedTop = max(idealTop, nextFreeY + minEventGap)
                let clampedTop  = min(adjustedTop, max(0, timelineHeight - rawH))

                nextFreeY = clampedTop + rawH
                result.append(PlacedEvent(event: event, topY: clampedTop, isCircle: false))
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {

            // ── Wake icon ─────────────────────────────────────────────
            iconCircle(
                icon:  wakeEvent?.icon  ?? "sunrise.fill",
                color: wakeEvent?.color ?? .orange
            )

            // ── Timeline zone ─────────────────────────────────────────
            ZStack(alignment: .top) {

                // Đường dọc nền
                Capsule()
                    .fill(Color.primary.opacity(isSelected ? 0.18 : 0.07))
                    .frame(width: lineWidth)
                    .frame(maxWidth: .infinity)

                // Past-fill gradient (today only)
                if isToday {
                    let pastH = max(min(yInTimeline(minutes: nowMinutes), timelineHeight), 0)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [brand.opacity(0.55), brand.opacity(0.18)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: lineWidth, height: pastH)
                        .frame(maxWidth: .infinity, alignment: .top)
                }

                // ── Events — đã qua layout pass ──────────────────────
                let placements = computeLayout()
                ForEach(placements, id: \.event.id) { p in
                    if p.isCircle {
                        renderedCircle(p.event, topY: p.topY)
                    } else {
                        renderedPill(p.event, topY: p.topY)
                    }
                }

                // Now dot
                if isToday,
                   nowMinutes >= wakeHour * 60,
                   nowMinutes <= sleepHour * 60 {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 9,  height: 9)
                        Circle().fill(brand)      .frame(width: 6,  height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(y: yInTimeline(minutes: nowMinutes) - 4.5)
                    .shadow(color: brand.opacity(0.4), radius: 3)
                }
            }
            .frame(height: timelineHeight)

            // ── Sleep icon ────────────────────────────────────────────
            iconCircle(
                icon:  sleepEvent?.icon  ?? "moon.stars.fill",
                color: sleepEvent?.color ?? .indigo
            )
        }
        .frame(maxWidth: .infinity)
        .opacity(isPast ? 0.38 : 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                calendar.select(date)
            }
        }
    }

    // MARK: - Circle renderer

    @ViewBuilder
    private func renderedCircle(_ event: EventItem, topY: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(event.color)
                .shadow(color: event.color.opacity(0.28), radius: 4, y: 2)
            Image(systemName: safeIcon(event.icon))
                .font(.system(size: iconSize * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: iconSize, height: iconSize)
        .frame(maxWidth: .infinity)
        .offset(y: topY)   // topY = top-edge của frame (ZStack alignment: .top)
    }

    // MARK: - Pill renderer

    @ViewBuilder
    private func renderedPill(_ event: EventItem, topY: CGFloat) -> some View {
        let displayDuration = event.duration ?? 60
        let startMin = max(event.minutes, wakeHour * 60)
        let endMin   = min(event.minutes + displayDuration, sleepHour * 60)

        if endMin > startMin {
            let rawH      = CGFloat(endMin - startMin) / 60.0 * hourHeight
            let minH: CGFloat = 30
            let pillH     = max(rawH, minH)
            let safePillH = min(pillH, max(0, timelineHeight - topY))
            let w         = pillWidth * 0.85
            let isPad     = UIDevice.current.userInterfaceIdiom == .pad

            ZStack {
                RoundedRectangle(cornerRadius: min(w / 2, safePillH / 2), style: .continuous)
                    .fill(event.color)
                    .shadow(color: event.color.opacity(0.22), radius: 4, y: 2)

                Image(systemName: safeIcon(event.icon))
                    .font(.system(
                        size: safePillH > 48
                            ? (isPad ? 24 : 18)
                            : (isPad ? 18 : 13),
                        weight: .semibold
                    ))
                    .foregroundStyle(.white)
            }
            .frame(width: w, height: max(safePillH, minH))
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(y: topY)
        }
    }

    // MARK: - Wake / Sleep icon circle

    func iconCircle(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: color.opacity(0.30), radius: 4, y: 2)
            Image(systemName: icon)
                .font(.system(size: iconSize * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Column

struct WeekDayColumn: View {

    let date: Date
    let wakeHour: Int
    let sleepHour: Int
    let hourHeight: CGFloat
    let pillWidth: CGFloat
    let lineWidth: CGFloat

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme

    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: calendar.selectedDate)
    }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }

    private var totalHeight: CGFloat { CGFloat(sleepHour - wakeHour) * hourHeight }

    private var visibleEvents: [EventItem] {
        store.events(for: date).filter { $0.duration != 1440 && !$0.isSystemEvent }
    }

    private var wakeEvent: EventItem? {
        store.events(for: date).first { $0.systemType == .wake }
    }

    private var nowMinutes: Int {
        Calendar.current.component(.hour, from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    private var brand: Color { Color(hex: PreferencesStore().accentHex) }

    var body: some View {
        ZStack(alignment: .top) {

            // Background hour lines
            hourLines

            // Vertical timeline line
            timelineLine

            // Now indicator
            if isToday {
                nowDot
            }

            // Wake icon at top
            if let wake = wakeEvent {
                wakeIcon(wake)
            }

            // Events as pills
            ForEach(visibleEvents) { event in
                eventPill(event)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .opacity(isPast ? 0.45 : 1)
    }

    // MARK: Hour lines

    var hourLines: some View {
        ZStack(alignment: .top) {
            ForEach(wakeHour...sleepHour, id: \.self) { hour in
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 0.5)
                    .offset(y: y(for: hour * 60))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Vertical line

    var timelineLine: some View {
        ZStack(alignment: .top) {
            // Past portion — colored
            if isToday {
                let pastHeight = y(for: min(nowMinutes, sleepHour * 60))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [brand.opacity(0.6), brand.opacity(0.25)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: lineWidth)
                    .frame(height: max(pastHeight, 0))
                    .frame(maxWidth: .infinity)
            }

            // Full line — gray
            Rectangle()
                .fill(Color.primary.opacity(isSelected ? 0.2 : 0.1))
                .frame(width: lineWidth)
                .frame(height: totalHeight)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Now dot

    var nowDot: some View {
        let yPos = y(for: nowMinutes)
        return Circle()
            .fill(brand)
            .frame(width: 8, height: 8)
            .frame(maxWidth: .infinity)
            .offset(y: yPos - 4)
            .shadow(color: brand.opacity(0.4), radius: 4)
    }

    // MARK: Wake icon

    func wakeIcon(_ event: EventItem) -> some View {
        let size: CGFloat = 38
        return ZStack {
            Circle()
                .fill(event.color.opacity(scheme == .dark ? 0.25 : 0.15))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(event.color.opacity(0.4), lineWidth: 1.5)
                )

            Image(systemName: event.icon)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(event.color)
        }
        .frame(maxWidth: .infinity)
        .offset(y: y(for: wakeHour * 60) - size / 2)
        .shadow(color: event.color.opacity(0.15), radius: 6, y: 2)
    }

    // MARK: Event pill

    @ViewBuilder
    func eventPill(_ event: EventItem) -> some View {
        let startMin = max(event.minutes, wakeHour * 60)
        let endMin   = min(event.minutes + (event.duration ?? 30), sleepHour * 60)
        let height   = max(CGFloat(endMin - startMin) / 60.0 * hourHeight, 28)
        let yStart   = y(for: startMin)

        ZStack {
            RoundedRectangle(cornerRadius: pillWidth / 2, style: .continuous)
                .fill(event.color.opacity(scheme == .dark ? 0.3 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: pillWidth / 2, style: .continuous)
                        .stroke(event.color.opacity(0.35), lineWidth: 1)
                )

            Image(systemName: UIImage(systemName: event.icon) != nil ? event.icon : "checkmark.circle.fill")
                .font(.system(size: height > 50 ? 16 : 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(event.color)
                .frame(maxHeight: .infinity, alignment: height > 50 ? .center : .center)
        }
        .frame(width: pillWidth, height: height)
        .frame(maxWidth: .infinity)
        .offset(y: yStart)
        .shadow(color: event.color.opacity(0.15), radius: 4, y: 2)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                calendar.select(date)
            }
        }
    }

    func y(for minutes: Int) -> CGFloat {
        CGFloat(minutes - wakeHour * 60) / 60.0 * hourHeight
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
