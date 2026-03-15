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

        let startOfWeek =
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startOfWeek)
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




struct HeaderDateView: View {

    @EnvironmentObject var calendar: CalendarState
    let brand = Color(red: 0.29, green: 0.44, blue: 0.65)
    
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {

        HStack {

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
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold)) // to hơn
                .foregroundStyle(brand)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .background(
                   (scheme == .dark
                    ? Color.black
                    : Color(.systemGray6))
                       .ignoresSafeArea(edges: .top)
               )
    }
}

struct WeekStripView: View {

    @EnvironmentObject var calendar: CalendarState
    @EnvironmentObject var store: TimelineStore
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.colorScheme) private var scheme

    @Namespace private var dayAnim
    let brand = Color(red: 0.29, green: 0.44, blue: 0.65)

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

        let startOfWeek = Calendar.current
            .dateInterval(of: .weekOfYear, for: baseDate)!.start

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

import SwiftUI

struct WeekTimelineView: View {

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme

    private let hourHeight: CGFloat = 52
    private let pillWidth: CGFloat = 38
    private let lineWidth: CGFloat = 1.5
    private let iconSize: CGFloat = 36

    private var wakeHour: Int { store.wakeMinutes / 60 }
    private var sleepHour: Int { (store.sleepMinutes + 59) / 60 }
    private var totalHours: Int { max(sleepHour - wakeHour, 1) }
    private var totalHeight: CGFloat { CGFloat(totalHours) * hourHeight + iconSize }

    private var weekDates: [Date] {
        let start = Calendar.current
            .dateInterval(of: .weekOfYear, for: calendar.selectedDate)?.start
            ?? calendar.selectedDate
        return (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: start)
        }
    }

    var body: some View {
        GeometryReader { geo in
            // Tính hourHeight để wake→sleep fit trong 30% màn hình
            let targetHeight = geo.size.height * 0.30
            let dynamicHourHeight = max(
                (targetHeight - iconSize * 2) / CGFloat(max(totalHours, 1)),
                20
            )

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(weekDates, id: \.self) { date in
                        CompactDayColumn(
                            date: date,
                            wakeHour: wakeHour,
                            sleepHour: sleepHour,
                            hourHeight: dynamicHourHeight,  // 👈 dynamic
                            pillWidth: pillWidth,
                            lineWidth: lineWidth,
                            iconSize: iconSize
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Compact Day Column

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

    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: calendar.selectedDate)
    }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }

    private var totalHeight: CGFloat { CGFloat(sleepHour - wakeHour) * hourHeight }

    private var allEvents: [EventItem] {
        store.events(for: date).filter { $0.duration != 1440 }
    }
    private var wakeEvent: EventItem? {
        allEvents.first { $0.systemType == .wake }
    }
    private var sleepEvent: EventItem? {
        allEvents.first { $0.systemType == .sleep }
    }
    private var userEvents: [EventItem] {
        allEvents.filter { !$0.isSystemEvent }
    }

    private var nowMinutes: Int {
        Calendar.current.component(.hour, from: Date()) * 60 +
        Calendar.current.component(.minute, from: Date())
    }

    private let brand = Color(red: 0.29, green: 0.44, blue: 0.65)

    var body: some View {
        ZStack(alignment: .top) {

            // Vertical line — full height
            verticalLine

            // Wake icon — top anchor
            if let wake = wakeEvent {
                solidIcon(
                    icon: wake.icon,
                    color: wake.color,
                    yOffset: 0
                )
            }

            // User event pills
            ForEach(userEvents) { event in
                eventPill(event)
            }

            // Sleep icon — bottom anchor
            if let sleep = sleepEvent {
                solidIcon(
                    icon: sleep.icon,
                    color: sleep.color,
                    yOffset: iconSize + totalHeight - iconSize / 2
                )
            }

            // Now dot on today
            if isToday {
                nowIndicator
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: iconSize + totalHeight + iconSize / 2)
        .opacity(isPast ? 0.4 : 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                calendar.select(date)
            }
        }
    }

    // MARK: Vertical line

    var verticalLine: some View {
        ZStack(alignment: .top) {
            // Base gray line
            Capsule()
                .fill(Color.primary.opacity(isSelected ? 0.18 : 0.08))
                .frame(width: lineWidth)
                .frame(height: iconSize + totalHeight + iconSize / 2)
                .frame(maxWidth: .infinity)

            // Colored past portion on today
            if isToday {
                let pastH = min(
                    CGFloat(nowMinutes - wakeHour * 60) / 60.0 * hourHeight + iconSize,
                    iconSize + totalHeight
                )
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [brand.opacity(0.5), brand.opacity(0.2)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: lineWidth)
                    .frame(height: max(pastH, 0))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Solid icon (no transparency)

    func solidIcon(icon: String, color: Color, yOffset: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: color.opacity(0.3), radius: 6, y: 3)

            Image(systemName: icon)
                .font(.system(size: iconSize * 0.42, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .offset(y: yOffset)
    }

    // MARK: Event pill

    @ViewBuilder
    func eventPill(_ event: EventItem) -> some View {
        let startMin = max(event.minutes, wakeHour * 60)
        let endMin   = min(event.minutes + (event.duration ?? 30), sleepHour * 60)

        if endMin > startMin {  // ✅ dùng if thay guard
            let pillH  = max(CGFloat(endMin - startMin) / 60.0 * hourHeight, 32)
            let yStart = iconSize + CGFloat(startMin - wakeHour * 60) / 60.0 * hourHeight

            ZStack {
                RoundedRectangle(cornerRadius: pillWidth / 2, style: .continuous)
                    .fill(event.color)
                    .shadow(color: event.color.opacity(0.25), radius: 4, y: 2)

                Image(systemName: event.icon)
                    .font(.system(size: pillH > 48 ? 15 : 11, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            }
            .frame(width: pillWidth, height: pillH)
            .frame(maxWidth: .infinity)
            .offset(y: yStart)
        }
    }

    // MARK: Now dot

    var nowIndicator: some View {
        let yPos = iconSize + CGFloat(nowMinutes - wakeHour * 60) / 60.0 * hourHeight

        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
            Circle()
                .fill(brand)
                .frame(width: 7, height: 7)
        }
        .frame(maxWidth: .infinity)
        .offset(y: yPos - 5)
        .shadow(color: brand.opacity(0.4), radius: 3)
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

    private let brand = Color(red: 0.29, green: 0.44, blue: 0.65)

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

            Image(systemName: event.icon)
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
               

            Image(systemName: icon)
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
