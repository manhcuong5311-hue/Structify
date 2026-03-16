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
        title: "Getting Started",
        icon: "sparkles",
        color: Color(red: 0.98, green: 0.75, blue: 0.25),
        items: [
            FAQItem(
                question: "What is Structify?",
                answer: "Structify is a daily timeline and habit tracker that helps you visualize your entire day from wake to sleep. You can create timed events, build recurring habits, and see everything laid out on a single scrollable timeline — so you always know what's next.",
                icon: "calendar.badge.clock",
                color: Color(red: 0.98, green: 0.75, blue: 0.25)
            ),
            FAQItem(
                question: "How do I create my first event?",
                answer: "Tap the + button at the bottom right of the main screen. You can create a timed Event (with a start time and duration) or a Habit (recurring daily task). Fill in the title, pick an icon and color, then tap Create.",
                icon: "plus.circle.fill",
                color: .blue
            ),
            FAQItem(
                question: "What's the difference between an Event and a Habit?",
                answer: "Events are one-off or recurring time blocks — like meetings, workouts, or study sessions. They have a start time and an optional duration. Habits are recurring tasks you want to build consistency with — they show a completion ring and track your streaks over time.",
                icon: "arrow.triangle.2.circlepath",
                color: .green
            ),
        ]
    ),
    FAQCategory(
        title: "Timeline",
        icon: "list.bullet.rectangle",
        color: .blue,
        items: [
            FAQItem(
                question: "How do I move an event on the timeline?",
                answer: "Long press on any event until it lifts (you'll feel a haptic). Then drag it up or down to the new time slot. Release to drop it. For recurring events, you'll be asked whether to move just today or all days.",
                icon: "hand.draw.fill",
                color: .orange
            ),
            FAQItem(
                question: "How do I resize an event?",
                answer: "Long press an event to enter hold mode, then drag the end time (shown at the bottom of the event pill) up or down to adjust the duration. The duration preview updates in real time as you drag.",
                icon: "arrow.up.and.down",
                color: .purple
            ),
            FAQItem(
                question: "What are Morning Start and Night Reset?",
                answer: "These are system events that define your day's boundaries. Morning Start is your wake time and Night Reset is your sleep time. All other events are constrained within this window. You can adjust both times in Settings → Preferences → Schedule.",
                icon: "sun.and.horizon.fill",
                color: Color(red: 0.98, green: 0.6, blue: 0.2)
            ),
            FAQItem(
                question: "What does the gap message between events mean?",
                answer: "When there's free time between two events, Structify shows a subtle message like \"A quiet hour — worth filling\". Tap it to quickly create a new event in that gap, pre-filled with the right start time.",
                icon: "text.bubble.fill",
                color: .teal
            ),
            FAQItem(
                question: "How do I view other days?",
                answer: "Use the week strip at the top of the screen to swipe between days. You can also tap the date header to jump to any date. Past days are shown with reduced opacity to indicate they're read-only.",
                icon: "calendar",
                color: .indigo
            ),
        ]
    ),
    FAQCategory(
        title: "Habits",
        icon: "repeat.circle.fill",
        color: .green,
        items: [
            FAQItem(
                question: "How do I mark a habit as done?",
                answer: "Tap the circle button on the right side of any habit row. For binary habits it toggles complete/incomplete. For accumulative habits, each tap adds your set increment — keep tapping until you reach the target.",
                icon: "checkmark.circle.fill",
                color: .green
            ),
            FAQItem(
                question: "What is an Accumulative habit?",
                answer: "An accumulative habit has a numeric target — like drinking 2,000 ml of water or walking 10,000 steps. Each tap adds your increment (e.g. +250 ml). A progress ring fills as you go, completing when you hit your target.",
                icon: "chart.bar.fill",
                color: .blue
            ),
            FAQItem(
                question: "What repeat options are available for habits?",
                answer: "You can set a habit to repeat Every Day, on Weekdays only, on specific days of the week, for a fixed range (1 week or 1 month), or just once on a single day.",
                icon: "arrow.clockwise",
                color: .orange
            ),
            FAQItem(
                question: "Can I track my habit streaks?",
                answer: "Yes — open the Stats tab (chart icon in the tab bar) to see your current streak, best streak, and a 30-day completion calendar for each habit. You can adjust the streak threshold in Settings → Preferences.",
                icon: "flame.fill",
                color: Color(red: 1.0, green: 0.4, blue: 0.2)
            ),
        ]
    ),
    FAQCategory(
        title: "Customization",
        icon: "paintpalette.fill",
        color: .purple,
        items: [
            FAQItem(
                question: "How do I change the app accent color?",
                answer: "Go to Settings → Preferences → Appearance → Accent Color. Choose from the preset palette or use the color picker to set any custom color. The accent color applies to the timeline line, buttons, and highlights throughout the app.",
                icon: "paintbrush.fill",
                color: .purple
            ),
            FAQItem(
                question: "What is Timeline Density?",
                answer: "Timeline Density controls how much vertical space is allocated between events. Compact fits more on screen, while Comfortable adds more breathing room. Adjust it in Settings → Preferences → Appearance.",
                icon: "rectangle.compress.vertical",
                color: .teal
            ),
            FAQItem(
                question: "How do I change an event's icon or color?",
                answer: "Tap on any event to open its detail sheet. Tap the icon at the top to open the Icon & Color picker. You can search for any SF Symbol and choose from hundreds of icons, then select a custom color.",
                icon: "square.on.circle",
                color: .blue
            ),
            FAQItem(
                question: "Can I hide completed events?",
                answer: "Yes. Go to Settings → Preferences → Productivity and toggle on Hide Completed Events. Completed events will be hidden from the timeline until you toggle it off again.",
                icon: "eye.slash.fill",
                color: .gray
            ),
        ]
    ),
    FAQCategory(
        title: "Notifications",
        icon: "bell.badge.fill",
        color: .red,
        items: [
            FAQItem(
                question: "How do I set up notifications for events?",
                answer: "Go to Settings → Notifications and enable the global toggle. You can set a lead time (how many minutes before an event you're notified) and toggle notifications on or off for individual event types.",
                icon: "bell.fill",
                color: .red
            ),
            FAQItem(
                question: "What is Morning Briefing?",
                answer: "Morning Briefing sends you a notification each morning with a summary of your day's schedule. Set the time in Settings → Preferences → Notifications → Morning Briefing. Premium feature.",
                icon: "sun.max.fill",
                color: Color(red: 0.98, green: 0.75, blue: 0.25)
            ),
            FAQItem(
                question: "What is Evening Review?",
                answer: "Evening Review sends you a nightly reminder to reflect on your day and plan tomorrow. Set your preferred time in Settings → Preferences → Notifications → Evening Review. Premium feature.",
                icon: "moon.stars.fill",
                color: .indigo
            ),
            FAQItem(
                question: "Why am I not receiving notifications?",
                answer: "Make sure notifications are enabled in both Structify (Settings → Notifications) and in iOS Settings → Structify → Notifications. Also check that Focus modes aren't blocking the app.",
                icon: "bell.slash.fill",
                color: .orange
            ),
        ]
    ),
    FAQCategory(
        title: "Data & Backup",
        icon: "externaldrive.fill",
        color: .cyan,
        items: [
            FAQItem(
                question: "Where is my data stored?",
                answer: "All your data is stored locally on your device. Structify does not have any servers — your events, habits, and logs never leave your iPhone unless you choose to export them.",
                icon: "lock.fill",
                color: .green
            ),
            FAQItem(
                question: "How do I back up my data?",
                answer: "Go to Settings → Preferences → Stats & Data → Export Backup. This creates a JSON file you can save to Files, iCloud Drive, or share anywhere. To restore, tap Restore Backup and select your backup file.",
                icon: "arrow.up.doc.fill",
                color: .blue
            ),
            FAQItem(
                question: "Can I export my history to a spreadsheet?",
                answer: "Yes — go to Settings → Preferences → Stats & Data → Export CSV. This exports your last 90 days of events and habits with completion status into a CSV file that opens in Numbers, Excel, or Google Sheets.",
                icon: "tablecells.fill",
                color: .teal
            ),
            FAQItem(
                question: "What happens if I delete the app?",
                answer: "All local data will be permanently deleted. We strongly recommend exporting a backup before uninstalling. If you have iCloud Backup enabled on your iPhone, some data may be included in your device backup.",
                icon: "trash.fill",
                color: .red
            ),
        ]
    ),
    FAQCategory(
        title: "Premium",
        icon: "crown.fill",
        color: Color(red: 0.98, green: 0.75, blue: 0.25),
        items: [
            FAQItem(
                question: "What do I get with Premium?",
                answer: "Structify Premium unlocks: unlimited events and habits (free is limited to 3 each), all accent colors, all icons, full notification features (Morning Briefing & Evening Review), Backup & Export, and 90-day stats history.",
                icon: "star.fill",
                color: Color(red: 0.98, green: 0.75, blue: 0.25)
            ),
            FAQItem(
                question: "Is Premium a subscription?",
                answer: "No — Structify Premium is a one-time purchase of $4.99 USD. You pay once and own it forever. There are no monthly fees, no renewals, and no surprise charges.",
                icon: "creditcard.fill",
                color: .green
            ),
            FAQItem(
                question: "How do I restore my purchase on a new device?",
                answer: "Go to Settings → Account → Restore Purchase, or open the Premium screen and tap Restore Purchase at the bottom. As long as you're signed in with the same Apple ID, your purchase will be restored instantly.",
                icon: "arrow.clockwise",
                color: .blue
            ),
            FAQItem(
                question: "Can I get a refund?",
                answer: "Refunds are handled by Apple. Visit reportaproblem.apple.com, sign in with your Apple ID, find the Structify purchase, and submit a refund request. Apple typically processes refunds within a few days.",
                icon: "dollarsign.circle.fill",
                color: .orange
            ),
        ]
    ),
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

            TextField("Search questions...", text: $searchText)
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
                    Text("All")
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

            Text("No results for \"\(searchText)\"")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Contact Footer

    var contactFooter: some View {
        VStack(spacing: 14) {
            Text("Still have questions?")
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
                        Text("Contact Support")
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
