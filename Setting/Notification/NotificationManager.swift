//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 15/3/26.
//

import UserNotifications
import Foundation

struct NotificationManager {

    static let shared = NotificationManager()

    // MARK: - Permission
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            print("Notification permission: \(granted)")
        }
    }

    // MARK: - Schedule cho 1 event/habit tại 1 ngày cụ thể
    func schedule(
        templateID: UUID,
        title: String,
        icon: String,
        minutes: Int,
        date: Date,
        isHabit: Bool,
        leadMinutes: Int = 5  // 👈 thêm param
    ) {
        let center = UNUserNotificationCenter.current()

        let offsetMinutes = isHabit ? 0 : -leadMinutes  // 👈 dùng leadMinutes
        let notifyMinutes = minutes + offsetMinutes
        guard notifyMinutes >= 0 else { return }

        let cal = Calendar.current
        guard let fireDate = cal.date(
            bySettingHour: notifyMinutes / 60,
            minute: notifyMinutes % 60,
            second: 0,
            of: date
        ) else { return }

        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = isHabit
            ? "Time for your habit \(icon)"
            : "Starting in \(leadMinutes) minutes \(icon)"  // 👈 dynamic text
        content.sound = .default
        content.userInfo = ["templateID": templateID.uuidString]

        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let dateKey = dateToKey(date)
        let identifier = "\(templateID.uuidString)_\(dateKey)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
    }
    // MARK: - Cancel 1 ngày cụ thể
    func cancel(templateID: UUID, date: Date) {
        let dateKey = dateToKey(date)
        let identifier = "\(templateID.uuidString)_\(dateKey)"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Cancel tất cả ngày của 1 template
    func cancelAll(templateID: UUID) {
        UNUserNotificationCenter.current()
            .getPendingNotificationRequests { requests in
                let ids = requests
                    .filter { $0.identifier.hasPrefix(templateID.uuidString) }
                    .map { $0.identifier }
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: ids)
            }
    }

    // MARK: - Schedule cho nhiều ngày (recurring)
    // iOS giới hạn 64 pending notifications — schedule 30 ngày tới
    func scheduleRecurring(template: EventTemplate, from startDate: Date = Date()) {
        cancelAll(templateID: template.id)

        // 👇 đọc settings từ UserDefaults
        let leadMinutes  = UserDefaults.standard.object(forKey: "notif_event_lead_minutes") as? Int ?? 5
        let habitOnTime  = UserDefaults.standard.object(forKey: "notif_habit_ontime") as? Bool ?? true
        let globalEnabled = UserDefaults.standard.object(forKey: "notif_global_enabled") as? Bool ?? true

        guard globalEnabled else { return }
        if template.kind == .habit && !habitOnTime { return }

        // 👇 check per-template toggle
        if let data = UserDefaults.standard.data(forKey: "notif_template_toggles"),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            let isEnabled = decoded[template.id.uuidString] ?? true
            if !isEnabled { return }
        }

        let cal = Calendar.current
        for dayOffset in 0..<30 {
            guard let date = cal.date(
                byAdding: .day, value: dayOffset, to: cal.startOfDay(for: startDate)
            ) else { continue }
            guard template.matches(date: date) else { continue }

            schedule(
                templateID: template.id,
                title: template.title,
                icon: template.icon,
                minutes: template.minutes,
                date: date,
                isHabit: template.kind == .habit,
                leadMinutes: leadMinutes  // 👈 truyền vào
            )
        }
    }

    // MARK: - Helper
    private func dateToKey(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
