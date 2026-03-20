//
//  TimeEditSheet.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//
import SwiftUI

struct TimeEditSheet: View {
    let title: String
    let icon: String
    let iconColor: Color
    let initialMinutes: Int
    let limitMinutes: Int  // wake: max = sleep-30, sleep: min = wake+30
    let brand: Color
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    private let isSleep: Bool

    init(title: String, icon: String, iconColor: Color,
         initialMinutes: Int, limitMinutes: Int, brand: Color,
         onSave: @escaping (Int) -> Void) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.initialMinutes = initialMinutes
        self.limitMinutes = limitMinutes
        self.brand = brand
        self.onSave = onSave
        self.isSleep = title == String(localized: "night_reset")
        _selectedDate = State(initialValue: minutesToDate(initialMinutes))
    }

    var selectedMinutes: Int {
        Calendar.current.component(.hour, from: selectedDate) * 60 +
        Calendar.current.component(.minute, from: selectedDate)
    }

    var isValid: Bool {
        isSleep
        ? selectedMinutes > limitMinutes      // sleep > wake+30
        : selectedMinutes < limitMinutes      // wake < sleep-30
    }

    var validationMessage: String {
        isSleep
        ? String(localized: "must_be_after_morning_start")
        : String(localized: "must_be_before_night_reset")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Icon header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    Text(title)
                        .font(.title2.bold())
                }
                .padding(.top, 24)

                // Time picker
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                // Validation warning
                if !isValid {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(validationMessage)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.9))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Save button
                Button {
                    onSave(selectedMinutes)
                    dismiss()
                } label: {
                    Text(String(localized: "save"))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? brand : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(!isValid)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.2), value: isValid)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

private func minutesToDate(_ minutes: Int) -> Date {
    var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    c.hour = minutes / 60
    c.minute = minutes % 60
    return Calendar.current.date(from: c) ?? Date()
}
