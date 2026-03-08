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

    var weekDates: [Date] {

        let calendar = Calendar.current
        let startOfWeek =
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)!.start

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startOfWeek)
        }
    }

    func nextWeek() {
        selectedDate =
        Calendar.current.date(byAdding: .day, value: 7, to: selectedDate)!
    }

    func previousWeek() {
        selectedDate =
        Calendar.current.date(byAdding: .day, value: -7, to: selectedDate)!
    }

    func select(_ date: Date) {
        selectedDate = date
    }
    
    var dateKey: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: selectedDate)
    }
    
    
    
    
    
    
    
    
    
    
}

struct HeaderDateView: View {

    @EnvironmentObject var calendar: CalendarState

    var body: some View {

        HStack(spacing: 6) {

            Text(calendar.selectedDate,
                 format: .dateTime.day().month(.wide))
                .font(.system(size: 32, weight: .bold))

            Text(calendar.selectedDate,
                 format: .dateTime.year())
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.orange)

            Image(systemName: "chevron.right")
                .foregroundStyle(.orange)
                .font(.system(size: 14, weight: .bold))

            Spacer()

            Button {
                calendar.selectedDate = Date()
            } label: {
                Image(systemName: "calendar")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct WeekStripView: View {

    @EnvironmentObject var calendar: CalendarState
    let calendarSys = Calendar.current

    var body: some View {

        HStack {

            ForEach(calendar.weekDates, id: \.self) { date in

                let isSelected = calendarSys.isDate(
                    date,
                    inSameDayAs: calendar.selectedDate
                )

                VStack(spacing: 6) {

                    Text(date,
                         format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(.gray)

                    ZStack {

                        if isSelected {

                            Circle()
                                .fill(.black)
                                .frame(width: 36, height: 36)

                            Text(date,
                                 format: .dateTime.day())
                                .foregroundStyle(.white)
                                .fontWeight(.bold)

                        } else {

                            Text(date,
                                 format: .dateTime.day())
                                .fontWeight(.semibold)
                        }
                    }
                }
                .frame(maxWidth: .infinity)   // ⭐ chia đều width
                .contentShape(Rectangle())   // tap full vùng
                .onTapGesture {
                    calendar.select(date)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }
}
