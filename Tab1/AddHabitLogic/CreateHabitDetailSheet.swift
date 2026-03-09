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

import SwiftUI

struct CreateHabitDetailSheet: View {

    // MARK: Habit Data

    @State private var title: String = ""
    @State private var icon: String = "checkmark.circle.fill"

    @State private var color: Color = Color(
        red: 108/255,
        green: 74/255,
        blue: 47/255
    )

    @State private var date: Date = Date()

    @State private var isCompleted = false
    @State private var showIconPicker = false

    @Environment(\.dismiss) private var dismiss

    let onCreate: (String,String,Date) -> Void

    // MARK: Body

    var body: some View {

        NavigationStack {

            ZStack {

                AmbientBackground(
                    isCompleted: isCompleted,
                    color: color
                )

                VStack(spacing: 14) {

                    header
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 28,
                                style: .continuous
                            )
                        )
                        .padding(.horizontal,-24)

                    CardSection {
                        datePickerSection
                    }

                    continueButton

                    Spacer(minLength: 0)
                }
                .padding(.horizontal,16)
                .navigationBarHidden(true)
            }
        }
    }
}

extension CreateHabitDetailSheet {

    var header: some View {

        ZStack(alignment: .topLeading) {

            LinearGradient(
                colors: [
                    color.opacity(0.95),
                    color.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing:20) {

                HStack {

                    Button {
                        dismiss()
                    } label: {

                        Image(systemName:"xmark")
                            .font(.system(size:20,weight:.bold))
                            .foregroundStyle(.black)
                            .frame(width:40,height:40)
                            .background(Color.white.opacity(0.6))
                            .clipShape(Circle())
                    }

                    Spacer()
                }

                HStack(spacing:16) {

                    Button {
                        showIconPicker = true
                    } label: {

                        ZStack {

                            Circle()
                                .fill(.ultraThinMaterial)

                            Circle()
                                .fill(Color.white.opacity(0.18))

                            Circle()
                                .stroke(
                                    Color.white.opacity(0.35),
                                    lineWidth:1
                                )

                            Image(systemName:icon)
                                .font(.system(size:30,weight:.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width:72,height:72)
                        .shadow(
                            color:.black.opacity(0.25),
                            radius:8,
                            y:4
                        )
                    }

                    VStack(alignment:.leading,spacing:4) {

                        Text("Habit")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        TextField("Tên habit",text:$title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical,8)
                            .padding(.horizontal,12)
                            .background(
                                RoundedRectangle(cornerRadius:10)
                                    .fill(Color.white.opacity(0.18))
                            )
                    }

                    Spacer()

                    Button {

                        withAnimation(.spring()) {
                            isCompleted.toggle()
                        }

                    } label: {

                        ZStack {

                            Circle()
                                .fill(
                                    isCompleted
                                    ? Color.white.opacity(0.25)
                                    : Color.clear
                                )
                                .frame(width:30,height:30)

                            Circle()
                                .stroke(Color.white,lineWidth:2)

                            AnimatedCheckmark(
                                progress: isCompleted ? 1 : 0
                            )
                        }
                    }
                    .frame(width:30,height:30)
                }

            }
            .padding(.horizontal,20)
            .padding(.top,50)
            .padding(.bottom,30)
        }
        .sheet(isPresented:$showIconPicker) {

            IconPicker(
                icon:$icon,
                color:$color
            )
            .presentationBackground(Color.paper)
        }
    }
}

extension CreateHabitDetailSheet {

    var datePickerSection: some View {

        HStack {

            Image(systemName:"calendar")
                .foregroundStyle(.primary)

            Text(dateText)

            Spacer()

            DatePicker(
                "",
                selection:$date,
                displayedComponents:[.date]
            )
            .labelsHidden()
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(
            RoundedRectangle(cornerRadius:16)
        )
    }

    var dateText:String {

        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy"
        formatter.locale = Locale(identifier:"vi")

        return formatter.string(from:date)
    }
}

extension CreateHabitDetailSheet {

    var continueButton: some View {

        Button {

            onCreate(
                title,
                icon,
                date
            )

            dismiss()

        } label: {

            Text("Create Habit")
                .font(.title3.bold())
                .frame(maxWidth:.infinity)
                .padding()
                .background(Color(.label))
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Capsule())
        }
        .padding(.top,10)
    }
}
