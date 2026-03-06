//
//  Addevent.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//


import SwiftUI

struct AddEventButton: View {

    var action: () -> Void

    var body: some View {

        Button(action: action) {

            HStack(spacing:6) {

                Image(systemName: "plus.circle.fill")

                Text("Add Event")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal,12)
            .padding(.vertical,6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }
}


import SwiftUI

struct CreateEventDetailSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var icon = "calendar"

    @State private var startTime = Date()
    @State private var durationMinutes: Int = 60

    let presets = [30, 60, 90, 120]

    var body: some View {

        NavigationStack {

            VStack(alignment: .leading, spacing: 24) {

                // HEADER
                HStack(spacing:16) {

                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width:56,height:56)
                        .overlay(Image(systemName: icon))

                    TextField("Event title", text:$title)
                        .font(.title3)
                }

                // START TIME
                VStack(alignment: .leading, spacing: 8) {

                    Text("Start Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                // DURATION PRESETS
                VStack(alignment: .leading, spacing: 8) {

                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing:10) {

                        ForEach(presets, id:\.self) { value in

                            Button {

                                durationMinutes = value

                            } label: {

                                Text(label(for:value))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal,12)
                                    .padding(.vertical,6)
                                    .background(
                                        durationMinutes == value
                                        ? Color.accentColor
                                        : Color.gray.opacity(0.15)
                                    )
                                    .foregroundStyle(
                                        durationMinutes == value ? .white : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // CUSTOM DURATION
                Stepper(
                    "Custom: \(label(for: durationMinutes))",
                    value: $durationMinutes,
                    in: 5...480,
                    step: 5
                )

                Spacer()
            }
            .padding(24)
            .navigationTitle("New Event")

            .toolbar {

                ToolbarItem(placement:.topBarTrailing) {

                    Button("Create") {

                        print("title:", title)
                        print("start:", startTime)
                        print("duration:", durationMinutes)

                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Helpers

    func label(for minutes:Int) -> String {

        let h = minutes / 60
        let m = minutes % 60

        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        }

        if h > 0 {
            return "\(h)h"
        }

        return "\(m)m"
    }
}
