import SwiftUI

// Single-sheet container that hosts both event and habit creation forms.
// Switching between the two is an inline animation — no dismiss/reopen
// dance. Habit is the default because this is a habit-focused app.

struct CreateItemSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TimelineStore

    @State private var mode: EventKind

    // Common fields preserved across mode toggle. nil for icon/color means
    // "no preserved value yet — let the child sheet use its own default".
    @State private var sharedTitle: String = ""
    @State private var sharedIcon: String? = nil
    @State private var sharedColorHex: String? = nil

    let suggestedMinutes: Int
    let initialDate: Date

    init(suggestedMinutes: Int = 540, initialDate: Date = Date(), initialMode: EventKind = .habit) {
        self.suggestedMinutes = suggestedMinutes
        self.initialDate = initialDate
        _mode = State(initialValue: initialMode)
    }

    private func captureCommonFields(_ title: String, _ icon: String, _ colorHex: String) {
        sharedTitle    = title
        sharedIcon     = icon
        sharedColorHex = colorHex
    }

    var body: some View {
        Group {
            if mode == .habit {
                CreateHabitDetailSheet(
                    initialMinutes: nil,  // anytime by default — user can set time inside sheet
                    initialTitle: sharedTitle,
                    initialIcon: sharedIcon,
                    initialColorHex: sharedColorHex,
                    onCreate: { title, icon, colorHex, date, type, target, unit, minutes, increment, repeatMode in
                        let cal = Calendar.current
                        // Anytime habits: ask the slot finder for a real gap that fits the
                        // habit's overlap footprint (30 min). duration:0 used to short-circuit
                        // the loop and pile new anytime habits at the end of the first event.
                        let startMinutes = minutes ?? store.suggestFreeSlot(
                            date: date,
                            duration: TimelineStore.habitOverlapFootprint,
                            includeHabits: true
                        )

                        let recurrence: Recurrence = {
                            switch repeatMode {
                            case .everyday: return .daily
                            case .weekdays: return .weekdays
                            case .oneDay:   return .once(date)
                            case .week:
                                let start = cal.startOfDay(for: date)
                                let end   = cal.startOfDay(for: cal.date(byAdding: .day, value: 6, to: start) ?? start)
                                return .dateRange(start, end)
                            case .month:
                                let start = cal.startOfDay(for: date)
                                let end   = cal.startOfDay(for: cal.date(byAdding: .day, value: 29, to: start) ?? start)
                                return .dateRange(start, end)
                            }
                        }()

                        store.addHabit(
                            title: title,
                            icon: icon,
                            colorHex: colorHex,
                            minutes: startMinutes,
                            habitType: type,
                            targetValue: target,
                            unit: unit,
                            increment: increment,
                            recurrence: recurrence
                        )
                        dismiss()
                    },
                    onOpenEvent: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            mode = .event
                        }
                    },
                    onCommonFieldsChange: captureCommonFields
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                CreateEventDetailSheet(
                    suggestedStart: suggestedMinutes,
                    initialDate: initialDate,
                    initialTitle: sharedTitle,
                    initialIcon: sharedIcon,
                    initialColorHex: sharedColorHex,
                    onOpenHabit: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            mode = .habit
                        }
                    },
                    onCommonFieldsChange: captureCommonFields,
                    onCreate: { title, icon, minutes, duration, colorHex, recurrence in
                        store.addEvent(
                            title: title,
                            icon: icon,
                            minutes: minutes,
                            duration: duration,
                            colorHex: colorHex,
                            recurrence: recurrence
                        )
                        dismiss()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
}
