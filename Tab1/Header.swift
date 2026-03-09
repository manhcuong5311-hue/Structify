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
                    .foregroundStyle(Color.brown) // nâu cafe
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold)) // to hơn
                .foregroundStyle(Color.brown) // nâu cafe

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

                    Text(date,
                         format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ZStack {

                        if isSelected {

                            Circle()
                                .fill(Color(red: 0.45, green: 0.30, blue: 0.18)) // nâu cafe
                                .matchedGeometryEffect(
                                    id: "DAY",
                                    in: dayAnim
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: .brown.opacity(0.3),
                                        radius: 6,
                                        y: 3)
                        }

                        Text(date,
                             format: .dateTime.day())
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                isSelected ? .white :
                                (isToday ? Color(red: 0.45, green: 0.30, blue: 0.18) : .primary)
                            )
                    }
                    .frame(width: 38, height: 38)
                    
                    
                    if isToday && !isSelected {

                        Circle()
                            .fill(.orange)
                            .frame(width: 4, height: 4)
                            .transition(.scale)
                    }
                }
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


