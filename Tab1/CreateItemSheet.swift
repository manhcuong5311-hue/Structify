import SwiftUI



struct CreateItemSheet: View {

    @Environment(\.dismiss) private var dismiss

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
                    Text("Event").tag(EventKind.event)
                    Text("Habit").tag(EventKind.habit)
                }
                .pickerStyle(.segmented)

                Spacer()

                // Continue button
                Button {

                    showNext = true

                } label: {

                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth:.infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius:14))
                }

            }
            .padding(24)
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement:.topBarLeading) {
                    Button("Cancel") { dismiss() }
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
                ) { title, icon, date, duration in

                    onCreate?(
                        .event,
                        title,
                        icon,
                        date,
                        duration
                    )
                }

            } else {

                CreateHabitDetailSheet { title, icon, date in

                    onCreate?(
                        .habit,
                        title,
                        icon,
                        date,
                        0
                    )

                }
            }
        }
    }
}
