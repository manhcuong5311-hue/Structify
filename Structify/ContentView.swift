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

import SwiftUI

struct ContentView: View {

    @State private var selectedTab: AppTab = .schedule
    @State private var showAdd = false

    var body: some View {

        ZStack(alignment: .bottom) {

            NavigationStack {

                switch selectedTab {

                case .schedule:
                    ScheduleView()

                case .stats:
                    StatsView()

                case .settings:
                    SettingsView()
                }
            }

            FloatingTabBar(
                selectedTab: $selectedTab,
                onAdd: {
                    showAdd = true
                }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture {
            hideKeyboard()
        }
    }
}


struct FloatingTabBar: View {

    @Binding var selectedTab: AppTab
    var onAdd: () -> Void

    var body: some View {

        GeometryReader { geo in

            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let width = isPad
                ? geo.size.width * 0.65
                : geo.size.width * 0.9

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
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
                )

                // ADD BUTTON
                Button {
                    onAdd()
                } label: {

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.black)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                        )
                }
            }
            .frame(width: width)
            .frame(maxWidth: .infinity)   // center
            .padding(.bottom, -20)
        }
        .frame(height: 90)
    }

    private func tabButton(_ tab: AppTab) -> some View {

        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {

            Image(systemName: tab.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(
                    isSelected
                    ? Color.white
                    : Color.white.opacity(0.45)
                )
        }
    }
}

extension View {

    func hideKeyboard() {

        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
