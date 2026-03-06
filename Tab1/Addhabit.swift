//
//  Addhabit.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI

struct AddHabitButton: View {

    var action: () -> Void = {}

    var body: some View {

        Button(action: action) {

            HStack(spacing:6) {

                Image(systemName: "repeat")

                Text("Add Habit")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal,12)
            .padding(.vertical,6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }
}

struct CreateHabitDetailSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var icon = "repeat"

    var body: some View {

        NavigationStack {

            VStack(spacing:20) {

                HStack(spacing:16) {

                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width:56,height:56)
                        .overlay(Image(systemName: icon))

                    TextField("Habit name", text:$title)
                        .font(.title3)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("New Habit")

            .toolbar {

                ToolbarItem(placement:.topBarTrailing) {

                    Button("Create") {

                        print("create habit")

                        dismiss()
                    }
                }
            }
        }
    }
}
