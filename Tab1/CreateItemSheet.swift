import SwiftUI



struct CreateItemSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TimelineStore
    @State private var kind: EventKind = .event
    @State private var showNext = false
    var onCreate: ((EventKind, String, String, Date, Int) -> Void)?
    
    
    var body: some View {

        NavigationStack {

            VStack(spacing: 28) {

                // Icon preview
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width:64,height:64)
                    .overlay(
                        Image(systemName: kind == .event ? "calendar" : "repeat")
                            .font(.title2)
                    )

                // Segmented picker
                Picker("", selection: $kind) {
                    Text(String(localized: "event_type_event"))
                        .tag(EventKind.event)
                    
                    Text(String(localized: "event_type_habit"))
                        .tag(EventKind.habit)
                }

                .pickerStyle(.segmented)

                Spacer()

                // Continue button
                Button {

                    showNext = true

                } label: {

                    Text(String(localized: "continue"))
                        .font(.headline)
                        .frame(maxWidth:.infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius:14))
                }

            }
            .padding(24)
            .navigationTitle(String(localized: "new_item_title"))
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement:.topBarLeading) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                }
            }
        }

        // STEP 2 sheet
        .sheet(isPresented: $showNext) {

            if kind == .event {

                CreateEventDetailSheet(
                    suggestedStart: 540,
                    onOpenHabit: {
                        showNext = false
                        kind = .habit
                        showNext = true
                    }
                ) { title, icon, minutes, duration, colorHex, recurrence in

                    onCreate?(
                        .event,
                        title,
                        icon,
                        Date(),
                        duration
                    )
                }

            } else {

                CreateHabitDetailSheet(
                    onCreate: { title, icon, colorHex, date, type, target, unit, minutes, increment, repeatMode in
                        let cal = Calendar.current
                        let startMinutes = minutes ?? 540

                        let recurrence: Recurrence = {
                            switch repeatMode {
                            case .everyday: return .daily
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

                        store.addHabit(           // 👈 gọi store trực tiếp
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

                        onCreate?(.habit, title, icon, date, 0)
                        dismiss()
                    },

                    onOpenEvent: {
                        showNext = false
                        kind = .event
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showNext = true
                        }
                    }
                )
            }
        }
    }
}
