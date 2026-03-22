//
//  LifetimeDetailView.swift
//  Structify
//
//  Created by Sam Manh Cuong on 15/3/26.
//

import SwiftUI
import Combine

struct LifetimeDetailView: View {

    @EnvironmentObject var store: TimelineStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed stats
    var allDates: [Date] {
        // Lấy tất cả ngày có data từ overrides + completions
        let cal = Calendar.current
        let keys = Set(store.overrides.map { $0.dateKey })
            .union(Set(store.completionLogs.map { $0.dateKey }))
        return keys.compactMap { key -> Date? in
            let year  = key / 10000
            let month = (key % 10000) / 100
            let day   = key % 100
            return cal.date(from: DateComponents(year: year, month: month, day: day))
        }.sorted()
    }

    struct EventStat: Identifiable {
        let id: UUID
        let title: String
        let icon: String
        let colorHex: String
        let kind: EventKind
        let habitType: HabitType?
        let completedCount: Int
        let totalDays: Int
    }

    var eventStats: [EventStat] {
        store.templates.compactMap { template -> EventStat? in  // 👈 thêm -> EventStat?
            let completed = store.completionLogs.filter {
                $0.templateID == template.id && ($0.completed == true)
            }.count
            guard completed > 0 else { return nil }

            // Tổng số ngày template này active
            let totalDays: Int = {
                switch template.recurrence {
                case .daily:
                    let firstLog = store.completionLogs
                         .filter { $0.templateID == template.id }
                         .compactMap { log -> Date? in
                             let key = log.dateKey
                             let y = key / 10000
                             let m = (key % 10000) / 100
                             let d = key % 100
                             return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
                         }
                         .min()
                     let start = firstLog ?? Date()
                     return max(1, Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 1)
                case .once:
                    return 1
                case .weekdays:
                    return max(1, completed)
                case .specific(let days):
                    return max(days.count, completed)
                case .dateRange(let s, let e):
                    return max(1, Calendar.current.dateComponents([.day], from: s, to: e).day ?? 1)
                }
            }()

            return EventStat(
                id: template.id,
                title: template.title,
                icon: template.icon,
                colorHex: template.colorHex,
                kind: template.kind,
                habitType: template.habitType,
                completedCount: completed,
                totalDays: totalDays
            )
        }.sorted { $0.completedCount > $1.completedCount }
    }

    var totalEventsCompleted: Int {
        eventStats.filter { $0.kind == .event }.reduce(0) { $0 + $1.completedCount }
    }

    var totalHabitsCompleted: Int {
        eventStats.filter { $0.kind == .habit && $0.habitType != .accumulative }
            .reduce(0) { $0 + $1.completedCount }
    }

    var totalAccumulativeCompleted: Int {
        eventStats.filter { $0.kind == .habit && $0.habitType == .accumulative }
            .reduce(0) { $0 + $1.completedCount }
    }

    var habitStats: [EventStat] { eventStats.filter { $0.kind == .habit } }
    var regularEventStats: [EventStat] { eventStats.filter { $0.kind == .event } }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: Top 3 summary cards
                    HStack(spacing: 12) {
                        lifetimeSummaryCard(
                            icon: "checkmark.circle.fill",
                            color: Color(red:0.45,green:0.90,blue:0.65),
                            value: totalEventsCompleted,
                            label: String(localized: "stats_events_done")
                        )
                        lifetimeSummaryCard(
                            icon: "repeat.circle.fill",
                            color: Color(red:1.0,green:0.72,blue:0.35),
                            value: totalHabitsCompleted,
                            label: String(localized: "stats_habits_done")
                        )
                        lifetimeSummaryCard(
                            icon: "chart.bar.fill",
                            color: Color(red:0.55,green:0.75,blue:1.0),
                            value: totalAccumulativeCompleted,
                            label: String(localized: "stats_accumulated")
                        )
                    }

                    // MARK: Habits breakdown
                    if !habitStats.isEmpty {
                        sectionHeader(
                            String(localized: "stats_habit_history"),
                            icon: "repeat.circle.fill",
                            color: Color(red:1.0,green:0.72,blue:0.35)
                        )

                        VStack(spacing: 10) {
                            ForEach(habitStats) { stat in
                                LifetimeRowView(stat: stat)
                            }
                        }
                    }

                    // MARK: Events breakdown
                    if !regularEventStats.isEmpty {
                        sectionHeader(
                            String(localized: "stats_event_history"),
                            icon: "calendar.circle.fill",
                            color: Color(red:0.45,green:0.90,blue:0.65)
                        )


                        VStack(spacing: 10) {
                            ForEach(regularEventStats) { stat in
                                LifetimeRowView(stat: stat)
                            }
                        }
                    }

                    if eventStats.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "stats_empty_title"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "stats_empty_subtitle"))
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        .padding(.horizontal, 40)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle(String(localized: "stats_lifetime_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    func lifetimeSummaryCard(icon: String, color: Color, value: Int, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Row View
struct LifetimeRowView: View {
    let stat: LifetimeDetailView.EventStat

    var color: Color { Color(hex: stat.colorHex) }

    var completionRate: Double {
        guard stat.totalDays > 0 else { return 0 }
        return min(1.0, Double(stat.completedCount) / Double(stat.totalDays))
    }

    var badgeText: String {
        if stat.habitType == .accumulative {
            return String(localized: "badge.accumulative")
        }
        if stat.kind == .habit {
            return String(localized: "badge.habit")
        }
        return String(localized: "badge.event")
    }
    
    
    var badgeColor: Color {
        if stat.habitType == .accumulative { return Color(red:0.55,green:0.75,blue:1.0) }
        if stat.kind == .habit { return Color(red:1.0,green:0.72,blue:0.35) }
        return Color(red:0.45,green:0.90,blue:0.65)
    }
    
    

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: stat.icon.isEmpty ? "star.fill" : stat.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Text(NSLocalizedString(stat.title, comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(badgeColor.opacity(0.15))
                        )
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        Capsule()
                            .fill(color.opacity(0.7))
                            .frame(width: geo.size.width * completionRate, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.completedCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(String(localized: "times"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

