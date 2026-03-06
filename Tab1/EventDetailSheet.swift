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

    var body: some View {

        NavigationStack {

            VStack(spacing:24) {

                Circle()
                    .fill(event.color.opacity(0.2))
                    .frame(width:80,height:80)
                    .overlay(
                        Image(systemName:event.icon)
                            .font(.largeTitle)
                            .foregroundStyle(event.color)
                    )

                Text(event.title)
                    .font(.title2.bold())

                Text("\(event.time) - \(event.endTime ?? "")")
                    .foregroundStyle(.secondary)

                Spacer()

                // DELETE BUTTON
               

                    Button(role: .destructive) {

                        onDelete()
                        dismiss()

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
