import SwiftUI

// Curated event presets shown as a horizontal carousel at the top of the
// create-event sheet. Tapping a preset pre-fills title/icon/color/duration
// and, when set, a suggested time of day.
//
// Note: the type is named `EventPreset` (not `EventTemplate`) to avoid clashing
// with the persisted `EventTemplate` struct in TimelineStore.swift.

struct EventPreset: Identifiable {
    let id = UUID()
    let titleKey: String              // localization key for display name
    let icon: String                  // SF Symbol
    let colorHex: String
    let category: EventCategory
    let durationMinutes: Int          // typical length for this kind of event
    let suggestedMinutes: Int?        // optional time of day; nil = use slot suggestion
}

enum EventCategory: String, CaseIterable, Identifiable {
    case work, personal, health, learning, lifestyle
    var id: String { rawValue }

    var localized: String {
        switch self {
        case .work:      return String(localized: "event_category_work")
        case .personal:  return String(localized: "event_category_personal")
        case .health:    return String(localized: "event_category_health")
        case .learning:  return String(localized: "event_category_learning")
        case .lifestyle: return String(localized: "event_category_lifestyle")
        }
    }

    var icon: String {
        switch self {
        case .work:      return "briefcase.fill"
        case .personal:  return "person.fill"
        case .health:    return "heart.fill"
        case .learning:  return "book.fill"
        case .lifestyle: return "house.fill"
        }
    }

    var accent: Color {
        switch self {
        case .work:      return Color(red: 0.45, green: 0.55, blue: 0.95)
        case .personal:  return Color(red: 0.95, green: 0.62, blue: 0.45)
        case .health:    return Color(red: 0.95, green: 0.45, blue: 0.45)
        case .learning:  return Color(red: 0.62, green: 0.42, blue: 0.85)
        case .lifestyle: return Color(red: 0.55, green: 0.70, blue: 0.50)
        }
    }
}

enum EventPresetCatalog {
    static let all: [EventPreset] = [

        // ─── Work ───
        EventPreset(titleKey: "event_tpl_meeting", icon: "person.2.fill",
                    colorHex: "#5B82F0", category: .work,
                    durationMinutes: 60, suggestedMinutes: 10 * 60),
        EventPreset(titleKey: "event_tpl_call", icon: "phone.fill",
                    colorHex: "#3DB5B0", category: .work,
                    durationMinutes: 30, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_standup", icon: "figure.stand",
                    colorHex: "#6A7AE0", category: .work,
                    durationMinutes: 15, suggestedMinutes: 9 * 60),
        EventPreset(titleKey: "event_tpl_interview", icon: "person.text.rectangle.fill",
                    colorHex: "#3F4D7A", category: .work,
                    durationMinutes: 60, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_focus_block", icon: "laptopcomputer",
                    colorHex: "#7059D6", category: .work,
                    durationMinutes: 90, suggestedMinutes: 9 * 60),
        EventPreset(titleKey: "event_tpl_review", icon: "checklist",
                    colorHex: "#4B82C0", category: .work,
                    durationMinutes: 45, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_presentation", icon: "chart.bar.fill",
                    colorHex: "#E07A4B", category: .work,
                    durationMinutes: 60, suggestedMinutes: nil),

        // ─── Personal ───
        EventPreset(titleKey: "event_tpl_lunch", icon: "fork.knife",
                    colorHex: "#7BC15B", category: .personal,
                    durationMinutes: 60, suggestedMinutes: 12 * 60),
        EventPreset(titleKey: "event_tpl_coffee", icon: "cup.and.saucer.fill",
                    colorHex: "#A86B3F", category: .personal,
                    durationMinutes: 45, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_dinner", icon: "fork.knife.circle.fill",
                    colorHex: "#4FA86F", category: .personal,
                    durationMinutes: 90, suggestedMinutes: 19 * 60),
        EventPreset(titleKey: "event_tpl_errands", icon: "bag.fill",
                    colorHex: "#E5A23A", category: .personal,
                    durationMinutes: 60, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_shopping", icon: "cart.fill",
                    colorHex: "#EC6C8A", category: .personal,
                    durationMinutes: 90, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_appointment", icon: "calendar.badge.clock",
                    colorHex: "#D85B82", category: .personal,
                    durationMinutes: 45, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_date", icon: "heart.fill",
                    colorHex: "#E26B8E", category: .personal,
                    durationMinutes: 120, suggestedMinutes: 19 * 60),

        // ─── Health ───
        EventPreset(titleKey: "event_tpl_gym", icon: "dumbbell.fill",
                    colorHex: "#EA5757", category: .health,
                    durationMinutes: 60, suggestedMinutes: 7 * 60),
        EventPreset(titleKey: "event_tpl_workout", icon: "figure.run",
                    colorHex: "#FF8A3A", category: .health,
                    durationMinutes: 45, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_yoga", icon: "figure.yoga",
                    colorHex: "#E07AAE", category: .health,
                    durationMinutes: 45, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_doctor", icon: "cross.case.fill",
                    colorHex: "#D8645B", category: .health,
                    durationMinutes: 30, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_therapy", icon: "brain.head.profile",
                    colorHex: "#2EB7A7", category: .health,
                    durationMinutes: 60, suggestedMinutes: nil),

        // ─── Learning ───
        EventPreset(titleKey: "event_tpl_class", icon: "graduationcap.fill",
                    colorHex: "#4B82C0", category: .learning,
                    durationMinutes: 90, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_study", icon: "book.fill",
                    colorHex: "#9C6CDC", category: .learning,
                    durationMinutes: 60, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_reading", icon: "book.closed.fill",
                    colorHex: "#6A7AB0", category: .learning,
                    durationMinutes: 45, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_course", icon: "laptopcomputer",
                    colorHex: "#A36AE0", category: .learning,
                    durationMinutes: 60, suggestedMinutes: nil),

        // ─── Lifestyle ───
        EventPreset(titleKey: "event_tpl_commute", icon: "car.fill",
                    colorHex: "#7B8794", category: .lifestyle,
                    durationMinutes: 30, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_travel", icon: "airplane",
                    colorHex: "#5BA8D6", category: .lifestyle,
                    durationMinutes: 60, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_break", icon: "pause.circle.fill",
                    colorHex: "#9CD0E5", category: .lifestyle,
                    durationMinutes: 15, suggestedMinutes: nil),
        EventPreset(titleKey: "event_tpl_sleep", icon: "moon.zzz.fill",
                    colorHex: "#6C7AA6", category: .lifestyle,
                    durationMinutes: 480, suggestedMinutes: 22 * 60),
        EventPreset(titleKey: "event_tpl_family", icon: "house.fill",
                    colorHex: "#7BC15B", category: .lifestyle,
                    durationMinutes: 60, suggestedMinutes: nil)
    ]

    static func filtered(by category: EventCategory?) -> [EventPreset] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}
