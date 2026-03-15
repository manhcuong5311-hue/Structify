//
//  NotificationsSettingsView.swift
//  Structify
//
//  Created by Sam Manh Cuong on 15/3/26.
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {

    @EnvironmentObject var store: TimelineStore
    @Environment(\.colorScheme) private var scheme

    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var globalEnabled: Bool = true
    @State private var eventLeadTime: Int = 5       // phút trước event
    @State private var habitOnTime: Bool = true     // đúng giờ habit
    @State private var notifToggles: [UUID: Bool] = [:]
    @State private var showPermissionAlert = false

    // UserDefaults keys
    private let globalKey    = "notif_global_enabled"
    private let leadTimeKey  = "notif_event_lead_minutes"
    private let habitOnTimeKey = "notif_habit_ontime"
    private let togglesKey   = "notif_template_toggles"

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    var pageBg: Color {
        scheme == .dark ? Color(.systemBackground) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    var nonSystemTemplates: [EventTemplate] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.templates.filter { t in
            guard !t.isSystemEvent else { return false }
            switch t.recurrence {
            case .daily, .weekdays, .specific:
                return true  // luôn active
            case .once(let d):
                return Calendar.current.startOfDay(for: d) >= today  // chỉ hôm nay trở đi
            case .dateRange(_, let end):
                return Calendar.current.startOfDay(for: end) >= today  // chưa hết range
            }
        }
    }

    var events: [EventTemplate] {
        nonSystemTemplates.filter { $0.kind == .event }
    }

    var habits: [EventTemplate] {
        nonSystemTemplates.filter { $0.kind == .habit }
    }

    
    // MARK: - Body

    var body: some View {
        ZStack {
            pageBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Permission banner
                    if permissionStatus == .denied {
                        permissionBanner
                    }

                    // Global toggle
                    globalSection

                    if globalEnabled && permissionStatus != .denied {

                        // Event lead time
                        leadTimeSection

                        // Habit timing
                        habitTimingSection

                        // Per-event toggles
                        if !events.isEmpty {
                            templateSection(
                                title: "Events",
                                icon: "calendar",
                                iconColor: .blue,
                                templates: events
                            )
                        }

                        // Per-habit toggles
                        if !habits.isEmpty {
                            templateSection(
                                title: "Habits",
                                icon: "repeat.circle.fill",
                                iconColor: .green,
                                templates: habits
                            )
                        }

                        if nonSystemTemplates.isEmpty {
                            emptyState
                        }
                        
                        
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadSettings()
            checkPermission()
        }
        .alert("Enable Notifications", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled. Go to Settings → Structify to enable them.")
        }
    }

    // MARK: - Permission Banner

    var permissionBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications Disabled")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Tap to open Settings and enable them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                )
        )
        .onTapGesture { showPermissionAlert = true }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Global Section

    var globalSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(globalEnabled ? Color.indigo : Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .animation(.easeInOut(duration: 0.2), value: globalEnabled)
                    Image(systemName: globalEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("All Notifications")
                        .font(.body.weight(.semibold))
                    Text(globalEnabled ? "Reminders are active" : "All reminders paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $globalEnabled)
                    .labelsHidden()
                    .tint(.indigo)
                    .onChange(of: globalEnabled) {
                        saveSettings()
                        rescheduleAll()
                    }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 8, y: 2)
            )
        }
    }

    // MARK: - Lead Time Section

    var leadTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Event Reminders")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange)
                            .frame(width: 30, height: 30)
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Remind me before")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $eventLeadTime) {
                        ForEach([5, 10, 15, 30], id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.orange)
                    .onChange(of: eventLeadTime) {
                        saveSettings()
                        rescheduleAll()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 8, y: 2)
            )
        }
    }

   

    // MARK: - Habit Timing Section

    var habitTimingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Habit Reminders")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                            .frame(width: 30, height: 30)
                        Image(systemName: "repeat.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notify at habit time")
                            .font(.body)
                        Text("Remind exactly when the habit starts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $habitOnTime)
                        .labelsHidden()
                        .tint(.green)
                        .onChange(of: habitOnTime) {
                            saveSettings()
                            rescheduleAll()
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 8, y: 2)
            )
        }
    }

    // MARK: - Per-Template Section

    func templateSection(
        title: String,
        icon: String,
        iconColor: Color,
        templates: [EventTemplate]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)

            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { idx, template in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: template.colorHex).opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: template.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: template.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(timeLabel(for: template))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: toggleBinding(for: template.id))
                            .labelsHidden()
                            .tint(Color(hex: template.colorHex))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())

                    if idx < templates.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 8, y: 2)
            )
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No events or habits yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add events and habits to manage their notifications here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(surface)
        )
    }

    // MARK: - Helpers

    func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .padding(.leading, 4)
    }

    func timeLabel(for template: EventTemplate) -> String {
        let t = TimelineEngine.formatTime(template.minutes)
        if template.kind == .event {
            return "Reminder \(eventLeadTime)m before · \(t)"
        } else {
            return "Reminder at \(t)"
        }
    }

    func toggleBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { notifToggles[id] ?? true },
            set: { newVal in
                notifToggles[id] = newVal
                saveSettings()
                // reschedule hoặc cancel cho template này
                if let template = store.templates.first(where: { $0.id == id }) {
                    if newVal && globalEnabled {
                        NotificationManager.shared.scheduleRecurring(template: template)
                    } else {
                        NotificationManager.shared.cancelAll(templateID: id)
                    }
                }
            }
        )
    }

    // MARK: - Permission

    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                permissionStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Persist

    func loadSettings() {
        globalEnabled = UserDefaults.standard.object(forKey: globalKey) as? Bool ?? true
        eventLeadTime = UserDefaults.standard.object(forKey: leadTimeKey) as? Int ?? 5
        habitOnTime   = UserDefaults.standard.object(forKey: habitOnTimeKey) as? Bool ?? true

        if let data = UserDefaults.standard.data(forKey: togglesKey),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            notifToggles = Dictionary(uniqueKeysWithValues: decoded.compactMap {
                guard let id = UUID(uuidString: $0.key) else { return nil }
                return (id, $0.value)
            })
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(globalEnabled, forKey: globalKey)
        UserDefaults.standard.set(eventLeadTime, forKey: leadTimeKey)
        UserDefaults.standard.set(habitOnTime, forKey: habitOnTimeKey)

        let encodable = Dictionary(uniqueKeysWithValues: notifToggles.map {
            ($0.key.uuidString, $0.value)
        })
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: togglesKey)
        }
    }

    // MARK: - Reschedule All

    func rescheduleAll() {
        for template in store.templates where !template.isSystemEvent {
            let enabled = (notifToggles[template.id] ?? true) && globalEnabled
            if enabled {
                NotificationManager.shared.scheduleRecurring(template: template)
            } else {
                NotificationManager.shared.cancelAll(templateID: template.id)
            }
        }
    }
}
