import SwiftUI

enum AppTab {
    case schedule
    case stats
    case settings
    
    var icon: String {
        switch self {
        case .schedule: return "calendar"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {

    @State private var selectedTab: AppTab = .schedule
    @State private var showEventSheet = false
    @State private var showHabitSheet = false

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState

    var body: some View {

        ZStack(alignment: .bottom) {

            NavigationStack {
                switch selectedTab {
                case .schedule: ScheduleView()
                case .stats: StatsView()
                case .settings: SettingsView()
                }
            }

            FloatingTabBar(
                selectedTab: $selectedTab,
                onAddEvent: { showEventSheet = true },
                onAddHabit: { showHabitSheet = true }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture { hideKeyboard() }

        .sheet(isPresented: $showEventSheet) {
            let suggested = store.suggestFreeSlot(date: calendar.selectedDate, duration: 60)
            CreateEventDetailSheet(
                suggestedStart: suggested,
                initialDate: calendar.selectedDate,
                onOpenHabit: {
                    showEventSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showHabitSheet = true
                    }
                }
            ) { title, icon, minutes, duration, colorHex, recurrence in
                store.addEvent(title: title, icon: icon, minutes: minutes,
                               duration: duration, colorHex: colorHex, recurrence: recurrence)
            }
            .adaptiveSheet()
        }

        .sheet(isPresented: $showHabitSheet) {
            CreateHabitDetailSheet(
                onCreate: { title, icon, colorHex, date, type, target, unit, minutes, increment, repeatMode in
                    let recurrence: Recurrence = {
                        let cal = Calendar.current
                        switch repeatMode {
                        case .everyday: return .daily
                        case .oneDay: return .once(date)
                        case .week:
                            let start = cal.startOfDay(for: date)
                            let end = cal.startOfDay(for: cal.date(byAdding: .day, value: 6, to: start) ?? start)
                            return .dateRange(start, end)
                        case .month:
                            let start = cal.startOfDay(for: date)
                            let end = cal.startOfDay(for: cal.date(byAdding: .day, value: 29, to: start) ?? start)
                            return .dateRange(start, end)
                        }
                    }()
                    store.addHabit(title: title, icon: icon, colorHex: colorHex,
                                   minutes: minutes ?? store.suggestFreeSlot(date: date, duration: 0),
                                   habitType: type, targetValue: target, unit: unit,
                                   increment: increment, recurrence: recurrence)
                },
                onOpenEvent: {
                    showHabitSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showEventSheet = true
                    }
                }
            )
            .environmentObject(store)
            .adaptiveSheet()
        }
    }
}


struct FloatingTabBar: View {

    @Binding var selectedTab: AppTab
    var onAddEvent: () -> Void
    var onAddHabit: () -> Void

    @State private var isExpanded = false

    var body: some View {

        GeometryReader { geo in

            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let width = isPad ? geo.size.width * 0.65 : geo.size.width * 0.9

            HStack(spacing: 12) {

                // TAB CAPSULE
                HStack {
                    tabButton(.schedule)
                    Spacer()
                    tabButton(.stats)
                    Spacer()
                    tabButton(.settings)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.9))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
                )

                
                // ADD BUTTON + MENU
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(isExpanded ? Color.white.opacity(0.2) : Color.black)
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                        )
                }
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: 12) {
                        miniAction(
                            icon: "repeat.circle.fill",
                            label: "Add Habit",
                            show: isExpanded,
                            delay: 0.05
                        ) {
                            isExpanded = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onAddHabit() }
                        }

                        miniAction(
                            icon: "calendar.badge.plus",
                            label: "Add Event",
                            show: isExpanded,
                            delay: 0
                        ) {
                            isExpanded = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onAddEvent() }
                        }
                    }
                    .fixedSize()
                    .offset(y: -120)
                
                }
            }
            .frame(width: width)
            .frame(maxWidth: .infinity)
            .padding(.bottom, -20)
        }
        .frame(height: 90)
        // Tap ngoài để đóng
        .onTapGesture {
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Mini action button
    private func miniAction(
        icon: String,
        label: String,
        show: Bool,
        delay: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)  // khớp với nút +
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.9))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    )
            }
        }
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.8, anchor: .bottomTrailing)
        .offset(y: show ? 0 : 16)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.75)
            .delay(show ? delay : 0),
            value: show
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.45))
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
