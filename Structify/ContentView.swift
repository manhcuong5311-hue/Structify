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
    @State private var isTabBarHidden = false

    /// Unified create flow. When nil the sheet is dismissed; otherwise the value
    /// is the initial mode (event or habit). `CreateItemSheet` handles in-flow
    /// toggling internally — no dismiss/re-present dance.
    @State private var createMode: EventKind? = nil

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

            if !isTabBarHidden {
                FloatingTabBar(
                    selectedTab: $selectedTab,
                    onAddEvent: { createMode = .event },
                    onAddHabit: { createMode = .habit }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture { hideKeyboard() }
        .onReceive(
            NotificationCenter.default.publisher(for: .setTabBarHidden)
        ) { notif in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTabBarHidden = notif.object as? Bool ?? false
            }
        }
        .sheet(item: $createMode) { mode in
            let suggested = store.suggestFreeSlot(
                date: calendar.selectedDate,
                duration: PreferencesStore.shared.defaultDuration,
                includeHabits: true
            )
            CreateItemSheet(
                suggestedMinutes: suggested,
                initialDate: calendar.selectedDate,
                initialMode: mode
            )
            .environmentObject(store)
            .adaptiveSheet()
        }
    }
}

// Lets EventKind drive `.sheet(item:)` so the FloatingTabBar can pick an initial
// mode without juggling two separate Bool flags.
extension EventKind: Identifiable {
    public var id: String { rawValue }
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
                            label: String(localized: "action_add_habit"),
                            show: isExpanded,
                            delay: 0.05
                        ) {
                            isExpanded = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onAddHabit() }
                        }

                        miniAction(
                            icon: "calendar.badge.plus",
                            label: String(localized: "action_add_event"),
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

// Thêm extension này cuối file ContentView.swift (cạnh .cancelTimelineHold)
extension Notification.Name {
    static let setTabBarHidden = Notification.Name("setTabBarHidden")
}
