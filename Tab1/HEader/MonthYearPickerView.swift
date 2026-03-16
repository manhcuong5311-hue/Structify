//
//  MonthYearPickerView.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//

import SwiftUI

struct MonthYearPickerView: View {

    @Binding var selectedDate: Date
    var onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())

    private let months = Calendar.current.shortMonthSymbols
    private var brand: Color { Color(hex: PreferencesStore().accentHex) }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: selectedDate) - 1
    }
    private var currentYear: Int {
        Calendar.current.component(.year, from: selectedDate)
    }

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Year nav
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            pickerYear -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(brand)
                            .frame(width: 44, height: 44)
                            .background(brand.opacity(0.08))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("\(pickerYear)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: pickerYear)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            pickerYear += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(brand)
                            .frame(width: 44, height: 44)
                            .background(brand.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Month grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(Array(months.enumerated()), id: \.offset) { idx, month in
                        let isSelected = idx == currentMonth && pickerYear == currentYear
                        let isToday = idx == Calendar.current.component(.month, from: Date()) - 1
                                   && pickerYear == Calendar.current.component(.year, from: Date())

                        Button {
                            selectMonth(idx)
                        } label: {
                            Text(month)
                                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected
                                            ? brand
                                            : (isToday ? brand.opacity(0.1) : Color.primary.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(
                                                    isToday && !isSelected ? brand.opacity(0.4) : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                                .foregroundStyle(isSelected ? .white : (isToday ? brand : .primary))
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isSelected ? 1.04 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(brand)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { jumpToToday() }
                        .foregroundStyle(brand)
                }
            }
        }
        .onAppear {
            pickerYear = currentYear
        }
    }

    private func selectMonth(_ monthIdx: Int) {
        var components = DateComponents()
        components.year  = pickerYear
        components.month = monthIdx + 1
        components.day   = 1
        if let date = Calendar.current.date(from: components) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDate = Date()
            pickerYear = Calendar.current.component(.year, from: Date())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDismiss()
        }
    }
}
