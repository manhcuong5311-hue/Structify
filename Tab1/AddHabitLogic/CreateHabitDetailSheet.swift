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

enum HabitRepeat: String, CaseIterable {
    
    case oneDay = "1 Day"
    case week = "1 Week"
    case month = "1 Month"
    case everyday = "Everyday"
}

enum HabitType: String, Codable {

    case binary
    case accumulative
}

struct CreateHabitDetailSheet: View {
    
    // MARK: Habit Data
    
    @State private var title: String = ""
    @State private var icon: String = "checkmark.circle.fill"
    
    @State private var color: Color = Color(
        red: 120/255,
        green: 156/255,
        blue: 123/255
    )
    
    @State private var date: Date = Date()
    
    @State private var isCompleted = false
    @State private var showIconPicker = false
    
    @Environment(\.dismiss) private var dismiss
    
    let onCreate: (
        String,
        String,
        Date,
        HabitType,
        Double?,
        String?,
        Int?,
        Double?   // increment
    ) -> Void
    
    let onOpenEvent: (() -> Void)?
    
    @State private var repeatMode: HabitRepeat = .everyday
    
    @State private var habitTime: Date = Date()
    @State private var isAnytime = true
    
    @State private var habitType: HabitType = .binary
    
    @State private var targetValue: Double = 1
    @State private var targetUnit: String = "km"
    
    let targetUnits = ["km", "ml", "L", "min", "pages", "times"]
    
    @State private var incrementValue: Double = 1
    
    @State private var previewProgress: Double = 0
  
    
    
    
    
    
    
    var headerScheduleText: String {
        
        if isAnytime {
            return dateRangeText
        } else {
            return "\(timeText) • \(dateRangeText)"
        }
    }
    
    // MARK: Body
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                AmbientBackground(
                    isCompleted: isCompleted,
                    color: color
                )
                
                ScrollView {
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
                        
                        CardSection {
                            repeatSection
                        }
                        
                        CardSection {
                            habitTimeSection
                        }
                        
                        CardSection {
                            habitTypeSection
                        }
                        
                        if habitType == .accumulative {
                            
                            CardSection {
                                accumulativeTargetSection
                            }
                            
                            CardSection {
                                incrementSection
                            }
                        }
                        
                        continueButton
                        
                        Spacer(minLength: 0)
                    }
                    
                    .padding(.horizontal,16)
                    .navigationBarHidden(true)
                    .onAppear {
                        updateDateForRepeatMode()
                    }
                    .onTapGesture {
                        hideKeyboard()
                    }
                }
            }
        }
    }
}


extension CreateHabitDetailSheet {

    var header: some View {

        ZStack(alignment: .topLeading) {

            LinearGradient(
                colors: [
                    Color(hex:"#789C7B"),
                    Color(hex:"#A3C2A4")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Color.white
                    .opacity(
                        habitType == .binary && isCompleted
                        ? 0.06
                        : 0
                    )
                    .blendMode(.overlay)
                    .animation(.easeOut(duration:0.25), value:isCompleted)
            )
            .scaleEffect(
                habitType == .binary && isCompleted
                ? 1.02
                : 1
            )
            .brightness(
                habitType == .binary && isCompleted
                ? 0.04
                : 0
            )
            .animation(.easeInOut(duration:0.35), value:isCompleted)

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

                    Button {

                        dismiss()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onOpenEvent?()
                        }

                    } label: {

                        Text("Add Event")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal,14)
                            .padding(.vertical,8)
                            .background(Color.white.opacity(0.6))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
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

                    VStack(alignment:.leading,spacing:2) {

                        if isAnytime {

                            Text(dateRangeText)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))

                        } else {

                            Label(headerScheduleText, systemImage: "clock")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        TextField("Habit name",text:$title)
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

                            if habitType == .binary {

                                isCompleted.toggle()
                                
                                UIImpactFeedbackGenerator(style:.medium)
                                       .impactOccurred()

                            } else {

                                previewProgress += incrementValue

                                if previewProgress >= targetValue {
                                    isCompleted = true
                                }
                            }
                        }

                    } label: {

                        ZStack {

                            if habitType == .binary {

                                Circle()
                                    .fill(
                                        isCompleted
                                        ? Color.white.opacity(0.25)
                                        : Color.clear
                                    )

                                Circle()
                                    .stroke(Color.white,lineWidth:2)

                                AnimatedCheckmark(
                                    progress: isCompleted ? 1 : 0
                                )

                            } else {

                                let progress = min(previewProgress / max(targetValue,1), 1)

                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth:3)

                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        Color.white,
                                        style: StrokeStyle(
                                            lineWidth:3,
                                            lineCap:.round
                                        )
                                    )
                                    .rotationEffect(.degrees(-90))

                                Text("\(Int(previewProgress))")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width:30,height:30)
                        .animation(.easeOut(duration:0.25), value: previewProgress)
                    }
    
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
    
    var habitTimeSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Time of day")
                .font(.title3.bold())

            HStack {

                if !isAnytime {

                    DatePicker(
                        "",
                        selection: $habitTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                }

                Spacer()

                Button {

                    withAnimation(.spring()) {
                        isAnytime.toggle()
                    }

                } label: {

                    Text("Anytime")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal,14)
                        .padding(.vertical,8)
                        .background(
                            isAnytime
                            ? color
                            : Color.gray.opacity(0.15)
                        )
                        .foregroundStyle(
                            isAnytime ? .white : .primary
                        )
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    var habitTypeSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Habit type")
                .font(.title3.bold())

            HStack(spacing: 12) {

                habitTypeButton(.binary, icon: "checkmark.circle")

                habitTypeButton(.accumulative, icon: "chart.bar")
            }
        }
    }
    
    var accumulativeTargetSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Target")
                .font(.title3.bold())

            HStack(spacing: 12) {

                TextField("Amount", value: $targetValue, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical,10)
                    .padding(.horizontal,12)
                    .background(
                        RoundedRectangle(cornerRadius:12)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .frame(width:100)

                Picker("", selection: $targetUnit) {

                    ForEach(targetUnits, id:\.self) {
                        Text($0)
                    }

                }
                .pickerStyle(.menu)
                .font(.subheadline.weight(.semibold))

                Spacer()
            }
        }
    }
    
    
    var incrementSection: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Increment per tap")
                .font(.title3.bold())
            
            HStack(spacing:12) {
                
                TextField("Value", value: $incrementValue, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical,10)
                    .padding(.horizontal,12)
                    .background(
                        RoundedRectangle(cornerRadius:12)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .frame(width:100)
                
                Text(targetUnit)
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
            }
            
            Text("Each tap will add this amount.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    
    
    
    var timeText: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return formatter.string(from: habitTime)
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
            .disabled(repeatMode != .oneDay)
            .opacity(repeatMode == .oneDay ? 1 : 0.4)
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(
            RoundedRectangle(cornerRadius:16)
        )
    }
    
    var repeatSection: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing:12) {
                
                ForEach(HabitRepeat.allCases, id:\.self) { mode in
                    
                    Button {
                        
                        withAnimation(.spring()) {
                            repeatMode = mode
                            updateDateForRepeatMode()
                        }
                        
                    } label: {
                        
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal,14)
                            .padding(.vertical,8)
                            .background(
                                repeatMode == mode
                                ? color
                                : Color.gray.opacity(0.15)
                            )
                            .foregroundStyle(
                                repeatMode == mode
                                ? .white
                                : .primary
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal,4)
        }
    }
    
    var dateRangeText: String {
        
        let calendar = Calendar.current
        
        switch repeatMode {
            
        case .oneDay:
            
            if calendar.isDateInToday(date) {
                return "Today"
            } else {
                return formattedDate(date)
            }
            
        case .everyday:
            return "Every day"
            
        case .week:
            
            guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
                return ""
            }
            
            return "\(shortDate(week.start)) – \(shortDate(week.end.addingTimeInterval(-1)))"
            
        case .month:
            
            guard let month = calendar.dateInterval(of: .month, for: date) else {
                return ""
            }
            
            return "\(shortDate(month.start)) – \(shortDate(month.end.addingTimeInterval(-1)))"
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM"
        formatter.locale = Locale(identifier:"vi")
        
        return formatter.string(from: date)
    }

    func shortDate(_ date: Date) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier:"vi")
        
        return formatter.string(from: date)
    }
    
    func updateDateForRepeatMode() {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch repeatMode {

        case .oneDay:
            break

        case .everyday:
            date = today

        case .week:
            date = today

        case .month:
            date = today
        }
    }
    
    func habitTypeButton(_ type: HabitType, icon: String) -> some View {

        let selected = habitType == type

        return Button {

            withAnimation(.spring()) {
                habitType = type
            }

        } label: {

            HStack(spacing:8) {

                Image(systemName: icon)

                Text(type.rawValue)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth:.infinity)
            .padding(.vertical,12)
            .background(
                selected
                ? color
                : Color.gray.opacity(0.15)
            )
            .foregroundStyle(
                selected ? .white : .primary
            )
            .clipShape(Capsule())
        }
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

            let minutes = isAnytime
                ? nil
                : Calendar.current.component(.hour, from: habitTime) * 60 +
                  Calendar.current.component(.minute, from: habitTime)

            onCreate(
                title,
                icon,
                date,
                habitType,
                habitType == .accumulative ? targetValue : nil,
                habitType == .accumulative ? targetUnit : nil,
                minutes,
                habitType == .accumulative ? incrementValue : nil
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
















