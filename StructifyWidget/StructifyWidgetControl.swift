//
//  StructifyWidgetControl.swift
//  StructifyWidget
//
//  Created by Sam Manh Cuong on 18/3/26.
//

import AppIntents
import SwiftUI
import WidgetKit

struct StructifyWidgetControl: ControlWidget {
    static let kind: String = "com.SamCorp.Structify.StructifyWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "start_timer_button",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(
                     isRunning ? "timer_on" : "timer_off",
                     systemImage: "timer"
                 )
            }
        }
        .displayName("widget_timer_title")
        .description("widget_timer_description")
    }
}

extension StructifyWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            StructifyWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = true // Check if the timer is running
            return StructifyWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "timer_config_title"

     @Parameter(title: "timer_name_param", default: "Timer")
     var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "start_timer_intent_title"

      @Parameter(title: "timer_name_param")
      var name: String

      @Parameter(title: "timer_running_param")
      var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}
