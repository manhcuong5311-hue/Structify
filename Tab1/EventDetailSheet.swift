//
//  EventDetailSheet.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//


import SwiftUI

struct EventDetailSheet: View {

    let event: EventItem
    
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    
    
    
    
    
    
    var dateText: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy"
        formatter.locale = Locale(identifier: "vi")

        return formatter.string(from: Date())
    }
    
    var body: some View {

        NavigationStack {

            VStack(spacing:24) {

                ZStack {

                    Circle()
                        .fill(event.color.opacity(0.18))

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    event.color.opacity(0.9),
                                    event.color.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(8)

                    Image(systemName:event.icon)
                        .font(.system(size:32, weight:.bold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)

                }
                .frame(width:90,height:90)
                .shadow(color:event.color.opacity(0.35), radius:8, y:4)
                  

                Text(event.title)
                    .font(.title2.bold())

                VStack(spacing:6) {

                    Label(dateText, systemImage: "calendar")

                    if let end = event.endTime {
                        Label("\(event.time) – \(end)", systemImage: "clock")
                    } else {
                        Label(event.time, systemImage: "clock")
                    }

                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                // DELETE BUTTON
               

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {

                    Label("Delete Event", systemImage: "trash")
                        .frame(maxWidth:.infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius:12))
                }

            }
            .padding(30)
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
          
            
            .alert(
                event.kind == .habit ? "Delete this habit?" : "Delete this event?",
                isPresented: $showDeleteAlert
            ) {

                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }

                Button("Cancel", role: .cancel) {}

            } message: {

                Text(
                    event.kind == .habit
                    ? "This will permanently remove the habit \"\(event.title)\"."
                    : "This will permanently remove \"\(event.title)\" from your schedule."
                )
            }
            .toolbar {

                ToolbarItem(placement:.topBarTrailing) {

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

