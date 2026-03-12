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
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)!.start

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
    }
}

struct WeekStripView: View {

    @EnvironmentObject var calendar: CalendarState

    @State private var weekOffset: Int = 0

    private let calendarSys = Calendar.current

    @Namespace private var dayAnim
    
    @State private var pulse = false
    @EnvironmentObject var store: TimelineStore
    @Environment(\.horizontalSizeClass) private var hSize
    let brand = Color(red: 0.29, green: 0.44, blue: 0.65)
    
    
    var uiScale: CGFloat {
        hSize == .regular ? 1.35 : 1.0
    }
    
    var body: some View {

        TabView(selection: $weekOffset) {

            weekView(offset: -1)
                .tag(-1)

            weekView(offset: 0)
                .tag(0)

            weekView(offset: 1)
                .tag(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: weekOffset) { oldValue, newValue in

            if newValue == 1 {
                calendar.nextWeek()
                weekOffset = 0
            }

            if newValue == -1 {
                calendar.previousWeek()
                weekOffset = 0
            }
        }
    }
    
    
    func iconsForDate(_ date: Date) -> [String] {

        let events = store.events(for: date)

        let icons = events.map { $0.icon }

        if icons.isEmpty {
            return ["sunrise.fill", "sun.max.fill", "moon.stars.fill"]
        }

        return Array(icons.prefix(3))
    }
    
    func eventsForDate(_ date: Date) -> [EventItem] {
        store.events(for: date)
    }
    
    func iconRow(for date: Date) -> some View {

        let event = nextOrActiveEvent(for: date)

        let size: CGFloat = 22 * uiScale
        let sideSize: CGFloat = 17 * uiScale

        return HStack(spacing: -7 * uiScale) {

            // Nếu có event → chỉ hiện event
            if let event {

                let state = eventState(for: event)

                EventMiniIcon(
                    icon: event.icon,
                    color: Color(hex: event.colorHex),
                    size: size
                )
                .scaleEffect(state == .active ? 1.2 : 1.15)
                .shadow(
                    color: state == .active
                    ? Color(hex: event.colorHex).opacity(0.4)
                    : .clear,
                    radius: 6
                )
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                           value: state == .active)

            } else {

                // Không có event → hiện system icons

                EventMiniIcon(
                    icon: "sunrise.fill",
                    color: .orange.opacity(0.75),
                    size: sideSize
                )

                EventMiniIcon(
                    icon: "moon.stars.fill",
                    color: .indigo.opacity(0.75),
                    size: sideSize
                )
            }
        }
        .frame(height: size)
    }
    
    func eventState(for event: EventItem) -> EventState {

        let cal = Calendar.current
        let now = Date()

        let nowMinutes =
            cal.component(.hour, from: now) * 60 +
            cal.component(.minute, from: now)

        let start = event.minutes
        let end = event.minutes + (event.duration ?? 0)

        if nowMinutes >= start && nowMinutes <= end {
            return .active
        }

        if nowMinutes < start {
            return .upcoming
        }

        return .past
    }

    enum EventState {
        case past
        case active
        case upcoming
    }
    
    
    func nextOrActiveEvent(for date: Date) -> EventItem? {

        let events = eventsForDate(date)
            .filter { !$0.isSystemEvent }

        let cal = Calendar.current
        let now = Date()

        let nowMinutes =
            cal.component(.hour, from: now) * 60 +
            cal.component(.minute, from: now)

        return events
            .sorted { $0.minutes < $1.minutes }
            .first {
                $0.minutes + ($0.duration ?? 0) >= nowMinutes
            }
    }
    
    
    
    func nextEvent(for date: Date) -> EventItem? {

        let events = eventsForDate(date)
            .filter { !$0.isSystemEvent }

        let now = Date()
        let cal = Calendar.current

        let nowMinutes =
            cal.component(.hour, from: now) * 60 +
            cal.component(.minute, from: now)

        return events
            .filter { $0.minutes >= nowMinutes }
            .sorted { $0.minutes < $1.minutes }
            .first
    }
    
    
    private func weekView(offset: Int) -> some View {

        let baseDate =
        Calendar.current.date(byAdding: .day,
                              value: offset * 7,
                              to: calendar.selectedDate)!

        let startOfWeek =
        calendarSys.dateInterval(of: .weekOfYear, for: baseDate)!.start

        let dates = (0..<7).compactMap {
            calendarSys.date(byAdding: .day, value: $0, to: startOfWeek)
        }

        return HStack(spacing: 0) {

            ForEach(dates, id: \.self) { date in

                let isSelected =
                calendarSys.isDate(date,
                                   inSameDayAs: calendar.selectedDate)

                let isToday =
                calendarSys.isDateInToday(date)

                VStack(spacing: 6) {

                    Text(date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ZStack {

                        if isSelected {

                            Circle()
                                .fill(brand)
                                .matchedGeometryEffect(id: "DAY", in: dayAnim)
                                .frame(width: 38 * uiScale, height: 38 * uiScale)
                                .shadow(
                                    color: isToday
                                    ? .orange.opacity(0.25)
                                    : .brown.opacity(0.3),
                                    radius: isToday ? 10 : 6,
                                    y: 3
                                )
                        }

                        Text(date, format: .dateTime.day())
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                isSelected
                                ? .white
                                : (isToday
                                   ? Color(red: 0.45, green: 0.30, blue: 0.18)
                                   : .primary)
                            )
                    }
                    .frame(width: 38 * uiScale, height: 38 * uiScale)

                    iconRow(for: date)
                }
                .frame(width: 44 * uiScale, height: 90 * uiScale)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .scaleEffect(isSelected ? 1.1 : 1)
                .animation(.spring(response: 0.35,
                                   dampingFraction: 0.8),
                           value: isSelected)
                .onTapGesture {

                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred()

                    withAnimation(.spring(response: 0.35,
                                          dampingFraction: 0.8)) {

                        calendar.select(date)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 8)
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
