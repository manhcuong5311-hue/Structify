import SwiftUI

// Curated habit presets shown as a horizontal carousel at the top of the
// create-habit sheet. Tapping a template pre-fills the form so users don't
// have to invent name/icon/target/unit/increment from scratch.
//
// target/unit/increment are non-optional: even binary templates carry sensible
// defaults so that if the user flips to "accumulative" after picking, say,
// Meditate, they get "10 min, +5" instead of stale values from the previous
// template (e.g. Walk's "8000 steps, +1000").

struct HabitTemplate: Identifiable {
    let id = UUID()
    let titleKey: String              // localization key for display name
    let icon: String                  // SF Symbol
    let colorHex: String
    let category: HabitCategory
    let type: HabitType
    let target: Double                // sensible default for this habit
    let unit: CreateHabitDetailSheet.TargetUnit
    let increment: Double
    let suggestedMinutes: Int?        // optional time of day; nil = anytime
}

enum HabitCategory: String, CaseIterable, Identifiable {
    case health, mindfulness, productivity, learning, creative, social, lifestyle
    var id: String { rawValue }

    var localized: String {
        switch self {
        case .health:       return String(localized: "habit_category_health")
        case .mindfulness:  return String(localized: "habit_category_mindfulness")
        case .productivity: return String(localized: "habit_category_productivity")
        case .learning:     return String(localized: "habit_category_learning")
        case .creative:     return String(localized: "habit_category_creative")
        case .social:       return String(localized: "habit_category_social")
        case .lifestyle:    return String(localized: "habit_category_lifestyle")
        }
    }

    var icon: String {
        switch self {
        case .health:       return "heart.fill"
        case .mindfulness:  return "leaf.fill"
        case .productivity: return "checklist"
        case .learning:     return "book.fill"
        case .creative:     return "paintpalette.fill"
        case .social:       return "person.2.fill"
        case .lifestyle:    return "house.fill"
        }
    }

    var accent: Color {
        switch self {
        case .health:       return Color(red: 0.95, green: 0.45, blue: 0.45)
        case .mindfulness:  return Color(red: 0.30, green: 0.72, blue: 0.55)
        case .productivity: return Color(red: 0.45, green: 0.55, blue: 0.95)
        case .learning:     return Color(red: 0.62, green: 0.42, blue: 0.85)
        case .creative:     return Color(red: 0.95, green: 0.62, blue: 0.30)
        case .social:       return Color(red: 0.95, green: 0.45, blue: 0.65)
        case .lifestyle:    return Color(red: 0.55, green: 0.70, blue: 0.50)
        }
    }
}

enum HabitTemplateCatalog {
    static let all: [HabitTemplate] = [

        // ─── Health ───
        HabitTemplate(titleKey: "habit_tpl_water", icon: "drop.fill",
                      colorHex: "#3AA6FF", category: .health, type: .accumulative,
                      target: 2000, unit: .ml, increment: 250, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_exercise", icon: "figure.run",
                      colorHex: "#FF8A3A", category: .health, type: .binary,
                      target: 30, unit: .min, increment: 15, suggestedMinutes: 7 * 60),
        HabitTemplate(titleKey: "habit_tpl_walk", icon: "figure.walk",
                      colorHex: "#4CD980", category: .health, type: .accumulative,
                      target: 8000, unit: .steps, increment: 1000, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_yoga", icon: "figure.yoga",
                      colorHex: "#E07AAE", category: .health, type: .binary,
                      target: 20, unit: .min, increment: 5, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_stretch", icon: "figure.cooldown",
                      colorHex: "#F0888D", category: .health, type: .binary,
                      target: 10, unit: .min, increment: 5, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_vitamins", icon: "pills.fill",
                      colorHex: "#EA5757", category: .health, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 8 * 60),
        HabitTemplate(titleKey: "habit_tpl_sleep", icon: "moon.zzz.fill",
                      colorHex: "#6C7AA6", category: .health, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 22 * 60),
        HabitTemplate(titleKey: "habit_tpl_healthy_meal", icon: "fork.knife",
                      colorHex: "#7BC15B", category: .health, type: .binary,
                      target: 3, unit: .times, increment: 1, suggestedMinutes: 12 * 60),
        HabitTemplate(titleKey: "habit_tpl_fruit", icon: "leaf.fill",
                      colorHex: "#E5A23A", category: .health, type: .binary,
                      target: 3, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_no_sugar", icon: "nosign",
                      colorHex: "#A86B3F", category: .health, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),

        // ─── Mindfulness ───
        HabitTemplate(titleKey: "habit_tpl_meditate", icon: "figure.mind.and.body",
                      colorHex: "#2EB7A7", category: .mindfulness, type: .binary,
                      target: 10, unit: .min, increment: 5, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_journal", icon: "pencil.line",
                      colorHex: "#E2B53E", category: .mindfulness, type: .binary,
                      target: 1, unit: .pages, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_gratitude", icon: "heart.fill",
                      colorHex: "#EC6C8A", category: .mindfulness, type: .binary,
                      target: 3, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_breathwork", icon: "wind",
                      colorHex: "#8FCBE5", category: .mindfulness, type: .binary,
                      target: 5, unit: .min, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_detox", icon: "iphone.slash",
                      colorHex: "#7B8794", category: .mindfulness, type: .binary,
                      target: 60, unit: .min, increment: 30, suggestedMinutes: 21 * 60),
        HabitTemplate(titleKey: "habit_tpl_nature", icon: "tree.fill",
                      colorHex: "#5AAF6A", category: .mindfulness, type: .binary,
                      target: 30, unit: .min, increment: 10, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_affirmations", icon: "quote.bubble.fill",
                      colorHex: "#C285E0", category: .mindfulness, type: .binary,
                      target: 3, unit: .times, increment: 1, suggestedMinutes: nil),

        // ─── Productivity ───
        HabitTemplate(titleKey: "habit_tpl_plan_day", icon: "list.clipboard.fill",
                      colorHex: "#5B82F0", category: .productivity, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 8 * 60),
        HabitTemplate(titleKey: "habit_tpl_deep_work", icon: "laptopcomputer",
                      colorHex: "#3F4D7A", category: .productivity, type: .accumulative,
                      target: 120, unit: .min, increment: 30, suggestedMinutes: 9 * 60),
        HabitTemplate(titleKey: "habit_tpl_review_week", icon: "calendar",
                      colorHex: "#6C7AA6", category: .productivity, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_inbox_zero", icon: "tray.fill",
                      colorHex: "#4FA8D0", category: .productivity, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_no_social", icon: "hand.raised.fill",
                      colorHex: "#D8645B", category: .productivity, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_focus_session", icon: "timer",
                      colorHex: "#7059D6", category: .productivity, type: .accumulative,
                      target: 60, unit: .min, increment: 25, suggestedMinutes: nil),

        // ─── Learning ───
        HabitTemplate(titleKey: "habit_tpl_read", icon: "book.fill",
                      colorHex: "#9C6CDC", category: .learning, type: .accumulative,
                      target: 30, unit: .min, increment: 10, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_language", icon: "character.bubble.fill",
                      colorHex: "#A36AE0", category: .learning, type: .binary,
                      target: 15, unit: .min, increment: 5, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_podcast", icon: "mic.fill",
                      colorHex: "#C75BAF", category: .learning, type: .accumulative,
                      target: 30, unit: .min, increment: 15, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_course", icon: "graduationcap.fill",
                      colorHex: "#4B82C0", category: .learning, type: .accumulative,
                      target: 60, unit: .min, increment: 20, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_practice", icon: "target",
                      colorHex: "#E26B6B", category: .learning, type: .binary,
                      target: 30, unit: .min, increment: 10, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_notes", icon: "note.text",
                      colorHex: "#E5A23A", category: .learning, type: .binary,
                      target: 1, unit: .pages, increment: 1, suggestedMinutes: nil),

        // ─── Creative ───
        HabitTemplate(titleKey: "habit_tpl_draw", icon: "paintpalette.fill",
                      colorHex: "#F39C42", category: .creative, type: .binary,
                      target: 30, unit: .min, increment: 10, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_music", icon: "music.note",
                      colorHex: "#E25A8E", category: .creative, type: .binary,
                      target: 30, unit: .min, increment: 15, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_write", icon: "pencil.tip",
                      colorHex: "#6A7AB0", category: .creative, type: .accumulative,
                      target: 30, unit: .min, increment: 15, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_photo", icon: "camera.fill",
                      colorHex: "#7E97C8", category: .creative, type: .binary,
                      target: 5, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_cook_new", icon: "frying.pan.fill",
                      colorHex: "#E07A4B", category: .creative, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 18 * 60),

        // ─── Social ───
        HabitTemplate(titleKey: "habit_tpl_call_family", icon: "phone.fill",
                      colorHex: "#E26B8E", category: .social, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_text_friend", icon: "message.fill",
                      colorHex: "#5BA8D6", category: .social, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_date_night", icon: "heart.text.square.fill",
                      colorHex: "#D85B82", category: .social, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 19 * 60),
        HabitTemplate(titleKey: "habit_tpl_compliment", icon: "hands.sparkles.fill",
                      colorHex: "#E2A23E", category: .social, type: .binary,
                      target: 3, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_quality_time", icon: "person.2.fill",
                      colorHex: "#7BC15B", category: .social, type: .binary,
                      target: 60, unit: .min, increment: 15, suggestedMinutes: nil),

        // ─── Lifestyle (home, self-care, finance) ───
        HabitTemplate(titleKey: "habit_tpl_make_bed", icon: "bed.double.fill",
                      colorHex: "#6C7AA6", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 7 * 60),
        HabitTemplate(titleKey: "habit_tpl_tidy", icon: "sparkles",
                      colorHex: "#9CD0E5", category: .lifestyle, type: .binary,
                      target: 10, unit: .min, increment: 5, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_cook_home", icon: "takeoutbag.and.cup.and.straw.fill",
                      colorHex: "#E07A4B", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 18 * 60),
        HabitTemplate(titleKey: "habit_tpl_save_money", icon: "dollarsign.circle.fill",
                      colorHex: "#4FA86F", category: .lifestyle, type: .binary,
                      target: 100, unit: .times, increment: 10, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_budget", icon: "chart.pie.fill",
                      colorHex: "#3E8A7A", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_laundry", icon: "washer.fill",
                      colorHex: "#7E97C8", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_groceries", icon: "cart.fill",
                      colorHex: "#E5A23A", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_skincare", icon: "face.smiling.fill",
                      colorHex: "#E07AAE", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: 21 * 60),
        HabitTemplate(titleKey: "habit_tpl_water_plants", icon: "leaf.circle.fill",
                      colorHex: "#5AAF6A", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil),
        HabitTemplate(titleKey: "habit_tpl_pet_walk", icon: "pawprint.fill",
                      colorHex: "#A8714B", category: .lifestyle, type: .binary,
                      target: 1, unit: .times, increment: 1, suggestedMinutes: nil)
    ]

    static func filtered(by category: HabitCategory?) -> [HabitTemplate] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}
