//
//  AppIntent.swift
//  StructifyWidget
//
//  Created by Sam Manh Cuong on 18/3/26.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "intent_config_title" }
      static var description: IntentDescription { "intent_config_desc" }


    // An example configurable parameter.
    @Parameter(title: "intent_favorite_emoji", default: "😃")
    var favoriteEmoji: String
}


import AppIntents
import WidgetKit

struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_toggle_habit_title"

    @Parameter(title: "intent_template_id")
    var templateID: String

    init() {}
    init(templateID: String) {
        self.templateID = templateID
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.samcorp.structify")

        // Đọc completion logs
        var logs: [[String: Any]] = []
        if let data = defaults?.data(forKey: "completionLogs"),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            logs = decoded
        }

        let today = Calendar.current.startOfDay(for: Date())
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: today)
        let dateKey = (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)

        // Toggle completion
        if let idx = logs.firstIndex(where: {
            ($0["templateID"] as? String) == templateID &&
            ($0["dateKey"] as? Int) == dateKey
        }) {
            let current = logs[idx]["completed"] as? Bool ?? false
            logs[idx]["completed"] = !current
        } else {
            logs.append([
                "templateID": templateID,
                "dateKey": dateKey,
                "completed": true
            ])
        }

        if let data = try? JSONSerialization.data(withJSONObject: logs) {
            defaults?.set(data, forKey: "completionLogs")
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
