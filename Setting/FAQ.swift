//
//  FAQ.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//

import SwiftUI

// MARK: - FAQ Data

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let icon: String
    let color: Color
}

struct FAQCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let items: [FAQItem]
}

private let faqData: [FAQCategory] = [
    FAQCategory(
        title: String(localized: "getting_started"),
        icon: "sparkles",
        color: Color(red: 0.98, green: 0.75, blue: 0.25),
        items: [
            FAQItem(
                question: String(localized: "faq_structify_question"),
                answer: String(localized: "faq_structify_answer"),
                icon: "calendar.badge.clock",
                color: Color(red: 0.98, green: 0.75, blue: 0.25)
            ),
            FAQItem(
                question: String(localized: "faq_create_event_question"),
                answer: String(localized: "faq_create_event_answer"),
                icon: "plus.circle.fill",
                color: .blue
            ),
            FAQItem(
                question: String(localized: "faq_event_vs_habit_question"),
                answer: String(localized: "faq_event_vs_habit_answer"),
                icon: "arrow.triangle.2.circlepath",
                color: .green
            ),
        ]
    ),
    FAQCategory(
        title: String(localized: "faq_timeline_title"),
        icon: "list.bullet.rectangle",
        color: .blue,
        items: [
            FAQItem(
                question: String(localized: "faq_timeline_move_event_q"),
                answer: String(localized: "faq_timeline_move_event_a"),
                icon: "hand.draw.fill",
                color: .orange
            ),
            FAQItem(
                question: String(localized: "faq_timeline_resize_event_q"),
                answer: String(localized: "faq_timeline_resize_event_a"),
                icon: "arrow.up.and.down",
                color: .purple
            ),
            FAQItem(
                question: String(localized: "faq_timeline_morning_night_q"),
                answer: String(localized: "faq_timeline_morning_night_a"),
                icon: "sun.and.horizon.fill",
                color: Color(red: 0.98, green: 0.6, blue: 0.2)
            ),
            FAQItem(
                question: String(localized: "faq_timeline_gap_q"),
                answer: String(localized: "faq_timeline_gap_a"),
                icon: "text.bubble.fill",
                color: .teal
            ),
            FAQItem(
                question: String(localized: "faq_timeline_view_days_q"),
                answer: String(localized: "faq_timeline_view_days_a"),
                icon: "calendar",
                color: .indigo
            ),
        ]
    )
    
    ,
    
    
    FAQCategory(
        title: String(localized: "faq_habits_title"),
        icon: "repeat.circle.fill",
        color: .green,
        items: [
            FAQItem(
                question: String(localized: "faq_habits_mark_done_q"),
                answer: String(localized: "faq_habits_mark_done_a"),
                icon: "checkmark.circle.fill",
                color: .green
            ),
            FAQItem(
                question: String(localized: "faq_habits_accumulative_q"),
                answer: String(localized: "faq_habits_accumulative_a"),
                icon: "chart.bar.fill",
                color: .blue
            ),
            FAQItem(
                question: String(localized: "faq_habits_repeat_options_q"),
                answer: String(localized: "faq_habits_repeat_options_a"),
                icon: "arrow.clockwise",
                color: .orange
            ),
            FAQItem(
                question: String(localized: "faq_habits_streak_q"),
                answer: String(localized: "faq_habits_streak_a"),
                icon: "flame.fill",
                color: Color(red: 1.0, green: 0.4, blue: 0.2)
            ),
        ]
    )
    
    ,
    
    FAQCategory(
        title: String(localized: "faq_customization_title"),
        icon: "paintpalette.fill",
        color: .purple,
        items: [
            FAQItem(
                question: String(localized: "faq_customization_accent_color_q"),
                answer: String(localized: "faq_customization_accent_color_a"),
                icon: "paintbrush.fill",
                color: .purple
            ),
            FAQItem(
                question: String(localized: "faq_customization_density_q"),
                answer: String(localized: "faq_customization_density_a"),
                icon: "rectangle.compress.vertical",
                color: .teal
            ),
            FAQItem(
                question: String(localized: "faq_customization_event_icon_q"),
                answer: String(localized: "faq_customization_event_icon_a"),
                icon: "square.on.circle",
                color: .blue
            ),
            FAQItem(
                question: String(localized: "faq_customization_hide_completed_q"),
                answer: String(localized: "faq_customization_hide_completed_a"),
                icon: "eye.slash.fill",
                color: .gray
            ),
        ]
    )
    
    ,
    
    
    FAQCategory(
        title: String(localized: "faq_notifications_title"),
        icon: "bell.badge.fill",
        color: .red,
        items: [
            FAQItem(
                question: String(localized: "faq_notifications_event_setup_q"),
                answer: String(localized: "faq_notifications_event_setup_a"),
                icon: "bell.fill",
                color: .red
            ),
            FAQItem(
                question: String(localized: "faq_notifications_morning_briefing_q"),
                answer: String(localized: "faq_notifications_morning_briefing_a"),
                icon: "sun.max.fill",
                color: Color(red: 0.98, green: 0.75, blue: 0.25)
            ),
            FAQItem(
                question: String(localized: "faq_notifications_evening_review_q"),
                answer: String(localized: "faq_notifications_evening_review_a"),
                icon: "moon.stars.fill",
                color: .indigo
            ),
            FAQItem(
                question: String(localized: "faq_notifications_not_receiving_q"),
                answer: String(localized: "faq_notifications_not_receiving_a"),
                icon: "bell.slash.fill",
                color: .orange
            ),
        ]
    )
    
    ,
    
    
    FAQCategory(
        title: String(localized: "faq_data_backup_title"),
        icon: "externaldrive.fill",
        color: .cyan,
        items: [
            FAQItem(
                question: String(localized: "faq_data_where_question"),
                answer: String(localized: "faq_data_where_answer"),
                icon: "lock.fill",
                color: .green
            ),
            FAQItem(
                question: String(localized: "faq_backup_how_question"),
                answer: String(localized: "faq_backup_how_answer"),
                icon: "arrow.up.doc.fill",
                color: .blue
            ),
            FAQItem(
                question: String(localized: "faq_export_csv_question"),
                answer: String(localized: "faq_export_csv_answer"),
                icon: "tablecells.fill",
                color: .teal
            ),
            FAQItem(
                question: String(localized: "faq_delete_app_question"),
                answer: String(localized: "faq_delete_app_answer"),
                icon: "trash.fill",
                color: .red
            ),
        ]
    )
    
    ,
    
    
    FAQCategory(
        title: String(localized: "faq_premium_title"),
        icon: "crown.fill",
        color: Color(red: 0.98, green: 0.75, blue: 0.25),
        items: [
            FAQItem(
                question: String(localized: "faq_premium_what_question"),
                answer: String(localized: "faq_premium_what_answer"),
                icon: "star.fill",
                color: Color(red: 0.98, green: 0.75, blue: 0.25)
            ),
            FAQItem(
                question: String(localized: "faq_premium_subscription_question"),
                answer: String(localized: "faq_premium_subscription_answer"),
                icon: "creditcard.fill",
                color: .green
            ),
            FAQItem(
                question: String(localized: "faq_premium_restore_question"),
                answer: String(localized: "faq_premium_restore_answer"),
                icon: "arrow.clockwise",
                color: .blue
            ),
            FAQItem(
                question: String(localized: "faq_premium_refund_question"),
                answer: String(localized: "faq_premium_refund_answer"),
                icon: "dollarsign.circle.fill",
                color: .orange
            ),
        ]
    )
    
    ,
    
    
]

// MARK: - FAQ View

struct FAQView: View {

    @Environment(\.colorScheme) private var scheme
    @State private var searchText = ""
    @State private var expandedItem: UUID? = nil
    @State private var selectedCategory: UUID? = nil

    var filteredCategories: [FAQCategory] {
        if searchText.isEmpty {
            if let cat = selectedCategory {
                return faqData.filter { $0.id == cat }
            }
            return faqData
        }
        let q = searchText.lowercased()
        return faqData.compactMap { category in
            let items = category.items.filter {
                $0.question.lowercased().contains(q) ||
                $0.answer.lowercased().contains(q)
            }
            guard !items.isEmpty else { return nil }
            return FAQCategory(
                title: category.title,
                icon: category.icon,
                color: category.color,
                items: items
            )
        }
    }

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    var pageBg: Color {
        scheme == .dark
            ? Color(.systemBackground)
            : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Search bar
                        searchBar
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // Category chips
                        if searchText.isEmpty {
                            categoryChips
                        }

                        // FAQ content
                        if filteredCategories.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredCategories) { category in
                                categorySection(category)
                                    .padding(.horizontal, 20)
                            }
                        }

                        // Contact footer
                        contactFooter
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Search Bar

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(String(localized: "faq_search_placeholder"), text: $searchText)

                .font(.body)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(surface)
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0 : 0.04),
                    radius: 6, y: 2
                )
        )
    }

    // MARK: - Category Chips

    var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All chip
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCategory = nil
                    }
                } label: {
                    Text(String(localized: "faq_filter_all"))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil
                                ? Color.primary
                                : Color.primary.opacity(0.08)
                        )
                        .foregroundStyle(
                            selectedCategory == nil
                                ? Color(scheme == .dark ? .black : .white)
                                : .primary
                        )
                        .clipShape(Capsule())
                }

                ForEach(faqData) { category in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = selectedCategory == category.id
                                ? nil
                                : category.id
                            expandedItem = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(category.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category.id
                                ? category.color
                                : category.color.opacity(0.1)
                        )
                        .foregroundStyle(
                            selectedCategory == category.id
                                ? .white
                                : category.color
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Category Section

    func categorySection(_ category: FAQCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: category.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(category.color)
                }
                Text(category.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            .padding(.leading, 4)

            // Items
            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { idx, item in
                    FAQRowView(
                        item: item,
                        isExpanded: expandedItem == item.id,
                        isLast: idx == category.items.count - 1
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            expandedItem = expandedItem == item.id ? nil : item.id
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(
                        color: .black.opacity(scheme == .dark ? 0 : 0.03),
                        radius: 8, y: 2
                    )
            )
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)

            Text(String(localized: "faq_no_results", defaultValue: "No results for \"\(searchText)\""))

                .font(.headline)
                .foregroundStyle(.secondary)

            Text(String(localized: "faq_try_search"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Contact Footer

    var contactFooter: some View {
        VStack(spacing: 14) {
            Text(String(localized: "faq_still_questions"))

                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Button {
                if let url = URL(string: "mailto:Manhcuong531@gmail.com") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.teal)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "faq_contact_support"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Manhcuong531@gmail.com")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(surface)
                        .shadow(
                            color: .black.opacity(scheme == .dark ? 0 : 0.03),
                            radius: 8, y: 2
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - FAQ Row

struct FAQRowView: View {

    let item: FAQItem
    let isExpanded: Bool
    let isLast: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(item.color.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(item.color)
                    }

                    Text(item.question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(item.color.opacity(0.3))
                        .frame(width: 2)
                        .padding(.leading, 28)

                    Text(item.answer)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 14)
                        .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !isLast {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}
