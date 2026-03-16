//
//  Preference.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
// MARK: - PreferencesStore
class PreferencesStore: ObservableObject {

    // Schedule
    @AppStorage("pref_first_weekday") var firstWeekday: Int = 2  // 1=Sun, 2=Mon

    // Appearance
    @AppStorage("pref_accent_hex")        var accentHex: String = "#4A70A6"
    @AppStorage("pref_timeline_density")  var timelineDensity: TimelineDensity = .normal
    @AppStorage("pref_hide_completed")    var hideCompleted: Bool = false

    // Productivity
    @AppStorage("pref_default_duration")  var defaultDuration: Int = 60
    @AppStorage("pref_snap_step")         var snapStep: Int = 5
    @AppStorage("pref_auto_suggest")      var autoSuggestSlot: Bool = true

    // Notifications
    @AppStorage("pref_morning_briefing")        var morningBriefing: Bool = false
    @AppStorage("pref_morning_briefing_hour")   var morningBriefingHour: Int = 7
    @AppStorage("pref_morning_briefing_minute") var morningBriefingMinute: Int = 30
    @AppStorage("pref_evening_review")          var eveningReview: Bool = false
    @AppStorage("pref_evening_review_hour")     var eveningReviewHour: Int = 21
    @AppStorage("pref_evening_review_minute")   var eveningReviewMinute: Int = 0
    @AppStorage("pref_habit_reminders")         var habitReminders: Bool = true

    // Stats
    @AppStorage("pref_week_start_stats")   var weekStartsOnMonday: Bool = true
    @AppStorage("pref_streak_threshold")   var streakThreshold: StreakThreshold = .half
}

enum TimelineDensity: String, CaseIterable {
    case compact     = "Compact"
    case normal      = "Normal"
    case comfortable = "Comfortable"

    var hourHeight: CGFloat {
        switch self {
        case .compact:     return 28
        case .normal:      return 36
        case .comfortable: return 48
        }
    }
}

extension TimelineDensity: RawRepresentable {}
extension TimelineDensity: Codable {}

enum StreakThreshold: String, CaseIterable {
    case quarter = "25%"
    case half    = "50%"
    case most    = "75%"
    case all     = "100%"

    var value: Double {
        switch self {
        case .quarter: return 0.25
        case .half:    return 0.50
        case .most:    return 0.75
        case .all:     return 1.00
        }
    }
}

extension StreakThreshold: RawRepresentable {}
extension StreakThreshold: Codable {}

// MARK: - PreferencesView
struct PreferencesView: View {

    @EnvironmentObject var store: TimelineStore
    @StateObject var prefs = PreferencesStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var showResetAlert = false
    @State private var showAccentPicker = false
    @State private var tempAccentColor: Color = Color(red: 0.29, green: 0.44, blue: 0.65)

    // Morning briefing time picker
    @State private var morningTime: Date = Date()
    @State private var eveningTime: Date = Date()
    
    // Thêm @State vào PreferencesView:
    @State private var showWakePicker = false
    @State private var showSleepPicker = false
    @State private var editWakeTime: Date = Date()
    @State private var editSleepTime: Date = Date()
    
    @State private var showShareSheet = false
    @State private var csvURL: URL? = nil
    @State private var showBackupShareSheet = false
    @State private var backupURL: URL? = nil
    @State private var showRestorePicker = false
    @State private var showRestoreSuccessAlert = false
    @State private var showRestoreErrorAlert = false
    private var isPremium: Bool { PremiumStore.shared.isPremium }
    
    
    @ViewBuilder
    func premiumRow<Content: View>(_ content: () -> Content) -> some View {
        ZStack(alignment: .trailing) {
            content()
                .opacity(isPremium ? 1 : 0.45)
                .allowsHitTesting(isPremium)

            if !isPremium {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPremium {
                NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
            }
        }
    }
    
    
    
    
    
    
    

    var brand: Color { Color(hex: prefs.accentHex) }

    var pageBg: Color {
        scheme == .dark
        ? Color(.systemBackground)
        : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    var surface: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    
    // Thêm vào PreferencesView (cạnh các func helper):
    func generateCSVFile() -> URL? {
        let csv = store.exportCSV()
        let fileName = "structify_export_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("CSV write error: \(error)")
            return nil
        }
    }
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // MARK: Section 1 — Schedule
                        prefSection(
                            title: "Schedule",
                            icon: "calendar",
                            iconColor: brand
                        ) {
                            scheduleSection
                        }

                        // MARK: Section 2 — Appearance
                        prefSection(
                            title: "Appearance",
                            icon: "paintbrush.fill",
                            iconColor: .purple
                        ) {
                            appearanceSection
                        }

                        // MARK: Section 3 — Productivity
                        prefSection(
                            title: "Productivity",
                            icon: "bolt.fill",
                            iconColor: .orange
                        ) {
                            productivitySection
                        }

                        // MARK: Section 4 — Notifications
                        prefSection(
                            title: "Notifications",
                            icon: "bell.fill",
                            iconColor: .red
                        ) {
                            notificationsSection
                        }

                        // MARK: Section 5 — Stats & Data
                        prefSection(
                            title: "Stats & Data",
                            icon: "chart.bar.fill",
                            iconColor: .green
                        ) {
                            statsSection
                        }

                        // MARK: Danger Zone
                        dangerSection

                        // App version
                        Text("Structify • v1.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Notify các view cần refresh
                        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
                        dismiss()
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(brand)
                }
            }
            .onAppear { syncTimeDates() }
            .sheet(isPresented: $showWakePicker) {
                TimeEditSheet(
                    title: "Morning Start",
                    icon: "sunrise.fill",
                    iconColor: Color(red: 0.96, green: 0.63, blue: 0.38),
                    initialMinutes: store.wakeMinutes,
                    limitMinutes: store.sleepMinutes - 30,
                    brand: brand
                ) { newMinutes in
                    store.updateSystemEvents(
                        wakeMinutes: newMinutes,
                        sleepMinutes: store.sleepMinutes
                    )
                }
            }
            .sheet(isPresented: $showSleepPicker) {
                TimeEditSheet(
                    title: "Night Reset",
                    icon: "moon.stars.fill",
                    iconColor: Color(red: 0.42, green: 0.48, blue: 0.65),
                    initialMinutes: store.sleepMinutes,
                    limitMinutes: store.wakeMinutes + 30,
                    brand: brand
                ) { newMinutes in
                    store.updateSystemEvents(
                        wakeMinutes: store.wakeMinutes,
                        sleepMinutes: newMinutes
                    )
                }
            }
            .alert("Reset All Data", isPresented: $showResetAlert) {
                Button("Reset Everything", role: .destructive) {
                    store.resetAllData()
                    NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all events, habits, and completion history. This cannot be undone.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
            // Backup share sheet
            .sheet(isPresented: $showBackupShareSheet) {
                if let url = backupURL {
                    ShareSheet(items: [url])
                }
            }

            // Restore file picker
            .fileImporter(
                isPresented: $showRestorePicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    // iOS security: cần startAccessingSecurityScopedResource
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        try store.restoreBackup(from: url)
                        showRestoreSuccessAlert = true
                        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
                    } catch {
                        showRestoreErrorAlert = true
                    }
                case .failure:
                    showRestoreErrorAlert = true
                }
            }

            // Success alert
            .alert("Restore Successful", isPresented: $showRestoreSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your data has been restored. The app will refresh automatically.")
            }

            // Error alert
            .alert("Restore Failed", isPresented: $showRestoreErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not read the backup file. Make sure it's a valid Structify backup.")
            }
            
            
        }
        
    }

    // MARK: - Generic Section Wrapper

    func prefSection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor)
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            // Content card
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surface)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 8, y: 2)
            )
        }
    }

    // MARK: - Schedule Section

    var scheduleSection: some View {
        VStack(spacing: 0) {
            
            Button { showWakePicker = true } label: {
                prefRow(
                    icon: "sunrise.fill",
                    iconBg: Color(red: 0.96, green: 0.63, blue: 0.38),
                    label: "Morning Start",
                    value: formatMinutes(store.wakeMinutes)
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            rowDivider

            Button { showSleepPicker = true } label: {
                prefRow(
                    icon: "moon.stars.fill",
                    iconBg: Color(red: 0.42, green: 0.48, blue: 0.65),
                    label: "Night Reset",
                    value: formatMinutes(store.sleepMinutes)
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            rowDivider

            // First day of week
            VStack(spacing: 0) {
                HStack {
                    rowIcon("calendar.badge.clock", bg: .blue)
                    Text("Week starts on")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    ForEach([(1,"Sun"),(2,"Mon"),(3,"Tue"),(4,"Wed"),(5,"Thu"),(6,"Fri"),(7,"Sat")], id: \.0) { day in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                prefs.firstWeekday = day.0
                            }
                        } label: {
                            Text(day.1)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(prefs.firstWeekday == day.0 ? brand : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(prefs.firstWeekday == day.0 ? .white : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Appearance Section

    var appearanceSection: some View {
        VStack(spacing: 0) {
            // Accent color
            VStack(spacing: 0) {
                HStack {
                    rowIcon("paintpalette.fill", bg: tempAccentColor)
                    Text("Accent Color")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    ColorPicker("", selection: $tempAccentColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: tempAccentColor) { _, newColor in
                            prefs.accentHex = newColor.toHex()
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                // Color presets
                HStack(spacing: 10) {
                    // TÌM toàn bộ ForEach accentPresets, ĐỔI THÀNH:
                    ForEach(Array(accentPresets.enumerated()), id: \.element) { idx, hex in
                        let isLocked = !isPremium && idx >= 3
                        Button {
                            if isLocked {
                                NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                                return
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                prefs.accentHex = hex
                                tempAccentColor = Color(hex: hex)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                if prefs.accentHex == hex && !isLocked {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2.5)
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .opacity(isLocked ? 0.35 : 1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }

            rowDivider

            // Timeline density
            VStack(spacing: 0) {
                HStack {
                    rowIcon("rectangle.compress.vertical", bg: .indigo)
                    Text("Timeline Density")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    ForEach(TimelineDensity.allCases, id: \.self) { density in
                        let isLocked = !isPremium && density != .normal
                        Button {
                            if isLocked {
                                NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                                return
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                prefs.timelineDensity = density
                            }
                        } label: {
                            // TÌM HStack(spacing: 3) trong density button label, ĐỔI THÀNH:
                            VStack(spacing: 4) {
                                densityPreviewIcon(density)
                                Text(density.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(prefs.timelineDensity == density
                                        ? brand.opacity(0.12)
                                        : Color.primary.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(prefs.timelineDensity == density
                                                ? brand.opacity(0.4)
                                                : Color.clear, lineWidth: 1.5)
                                    )
                            )
                            .foregroundStyle(prefs.timelineDensity == density ? brand : .secondary)
                            .opacity(isLocked ? 0.35 : 1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(prefs.timelineDensity == density
                                        ? brand.opacity(0.12)
                                        : Color.primary.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(prefs.timelineDensity == density
                                                ? brand.opacity(0.4)
                                                : Color.clear, lineWidth: 1.5)
                                    )
                            )
                            .foregroundStyle(prefs.timelineDensity == density ? brand : .secondary)
                            .opacity(isLocked ? 0.55 : 1)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }

            rowDivider

            // Hide completed
            prefToggleRow(
                icon: "checkmark.circle.fill",
                iconBg: .green,
                label: "Hide Completed Events",
                sublabel: "Completed events fade from timeline",
                binding: $prefs.hideCompleted
            )
        }
    }

    // MARK: - Productivity Section

    var productivitySection: some View {
        VStack(spacing: 0) {
            // Default duration
            VStack(spacing: 0) {
                HStack {
                    rowIcon("timer", bg: .orange)
                    Text("Default Duration")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(formatDuration(prefs.defaultDuration))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                prefs.defaultDuration = mins
                            }
                        } label: {
                            Text(formatDuration(mins))
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(prefs.defaultDuration == mins
                                            ? .orange
                                            : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(prefs.defaultDuration == mins ? .white : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }

            rowDivider

            // Snap step
            VStack(spacing: 0) {
                HStack {
                    rowIcon("arrow.left.and.right", bg: Color(red: 0.9, green: 0.5, blue: 0.2))
                    Text("Drag Snap")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Every \(prefs.snapStep) min")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    ForEach([1, 5, 10, 15], id: \.self) { step in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                prefs.snapStep = step
                            }
                        } label: {
                            Text("\(step)m")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(prefs.snapStep == step ? .orange : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(prefs.snapStep == step ? .white : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }

            rowDivider

            prefToggleRow(
                icon: "wand.and.stars",
                iconBg: Color(red: 0.55, green: 0.35, blue: 0.85),
                label: "Auto-suggest Free Slot",
                sublabel: "Finds the best gap when creating events",
                binding: $prefs.autoSuggestSlot
            )
        }
    }

    // MARK: - Notifications Section

    var notificationsSection: some View {
        VStack(spacing: 0) {
            // Morning briefing
            VStack(spacing: 0) {
                // TÌM prefToggleRow Morning Briefing, BỌC VÀO:
                prefToggleRow(
                    icon: "sun.horizon.fill",
                    iconBg: Color(red: 1.0, green: 0.7, blue: 0.2),
                    label: "Morning Briefing",
                    sublabel: isPremium ? "Daily plan reminder at wake time" : "Premium feature",
                    binding: Binding(
                        get: { prefs.morningBriefing },
                        set: { val in
                            guard isPremium else {
                                NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                                return
                            }
                            prefs.morningBriefing = val
                            if val {
                                NotificationManager.shared.scheduleMorningBriefing(
                                    hour: prefs.morningBriefingHour,
                                    minute: prefs.morningBriefingMinute
                                )
                            } else {
                                NotificationManager.shared.cancelMorningBriefing()
                            }
                        }
                    )
                )
                .opacity(isPremium ? 1 : 0.4)
                .allowsHitTesting(isPremium)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isPremium {
                        NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                    }
                }

                if prefs.morningBriefing {
                    HStack {
                        Spacer()
                        DatePicker(
                            "",
                            selection: $morningTime,
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .onChange(of: morningTime) { _, v in
                            prefs.morningBriefingHour   = Calendar.current.component(.hour,   from: v)
                            prefs.morningBriefingMinute = Calendar.current.component(.minute, from: v)
                            if prefs.morningBriefing {
                                NotificationManager.shared.scheduleMorningBriefing(
                                    hour: prefs.morningBriefingHour,
                                    minute: prefs.morningBriefingMinute
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: prefs.morningBriefing)

            rowDivider

            // Evening review
            VStack(spacing: 0) {
                // TÌM prefToggleRow Evening Review, BỌC TƯƠNG TỰ:
                prefToggleRow(
                    icon: "moon.haze.fill",
                    iconBg: Color(red: 0.35, green: 0.35, blue: 0.75),
                    label: "Evening Review",
                    sublabel: isPremium ? "Completion check-in reminder" : "Premium feature",
                    binding: Binding(
                        get: { prefs.eveningReview },
                        set: { val in
                            guard isPremium else {
                                NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                                return
                            }
                            prefs.eveningReview = val
                            if val {
                                NotificationManager.shared.scheduleEveningReview(
                                    hour: prefs.eveningReviewHour,
                                    minute: prefs.eveningReviewMinute
                                )
                            } else {
                                NotificationManager.shared.cancelEveningReview()
                            }
                        }
                    )
                )
                .opacity(isPremium ? 1 : 0.4)
                .allowsHitTesting(isPremium)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isPremium {
                        NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                    }
                }

                if prefs.eveningReview {
                    HStack {
                        Spacer()
                        DatePicker(
                            "",
                            selection: $eveningTime,
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .onChange(of: eveningTime) { _, v in
                            prefs.eveningReviewHour   = Calendar.current.component(.hour,   from: v)
                            prefs.eveningReviewMinute = Calendar.current.component(.minute, from: v)
                            if prefs.eveningReview {
                                NotificationManager.shared.scheduleEveningReview(
                                    hour: prefs.eveningReviewHour,
                                    minute: prefs.eveningReviewMinute
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: prefs.eveningReview)

            rowDivider

            prefToggleRow(
                icon: "bell.badge.fill",
                iconBg: .red,
                label: "Habit Reminders",
                sublabel: "Notify at each habit's scheduled time",
                binding: Binding(
                    get: { prefs.habitReminders },
                    set: { val in
                        prefs.habitReminders = val
                        // Sync với NotificationManager key
                        UserDefaults.standard.set(val, forKey: "notif_habit_ontime")
                        // Reschedule tất cả habits
                        // (store không available ở đây → dùng NotificationCenter)
                        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
                    }
                )
            )
        }
    }

    // MARK: - Stats Section

    var statsSection: some View {
        VStack(spacing: 0) {
            // Streak threshold
            VStack(spacing: 0) {
                HStack {
                    rowIcon("flame.fill", bg: Color(red: 1.0, green: 0.45, blue: 0.2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Streak Threshold")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Min % of habits to count a day")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(prefs.streakThreshold.rawValue)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    ForEach(StreakThreshold.allCases, id: \.self) { t in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                prefs.streakThreshold = t
                            }
                        } label: {
                            Text(t.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(prefs.streakThreshold == t
                                            ? Color(red: 1.0, green: 0.45, blue: 0.2)
                                            : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(prefs.streakThreshold == t ? .white : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }

            rowDivider

            // Export (placeholder)
            Button {
                guard isPremium else {
                    NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                    return
                }
                if let url = generateCSVFile() {
                    csvURL = url
                    showShareSheet = true
                }
            } label: {
                HStack {
                    rowIcon("square.and.arrow.up", bg: .teal)
                    Text("Export Data (CSV)")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isPremium ? "chevron.right" : "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .opacity(isPremium ? 1 : 0.5)
            }
            
            rowDivider

            // Backup
            Button {
                guard isPremium else {
                    NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                    return
                }
                if let url = store.exportBackup() {
                    backupURL = url
                    showBackupShareSheet = true
                }
            } label: {
                HStack {
                    rowIcon("externaldrive.fill", bg: .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Backup Data")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Export full backup to Files or AirDrop")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: isPremium ? "chevron.right" : "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .opacity(isPremium ? 1 : 0.5)
            }

            rowDivider

            // Restore
            Button {
                guard isPremium else {
                    NotificationCenter.default.post(name: .showPremiumPaywall, object: nil)
                    return
                }
                showRestorePicker = true
            } label: {
                HStack {
                    rowIcon("externaldrive.badge.plus", bg: Color(red: 0.2, green: 0.6, blue: 0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restore Backup")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Import from a .json backup file")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: isPremium ? "chevron.right" : "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .opacity(isPremium ? 1 : 0.5)
            }
            
        }
    }

    // MARK: - Danger Section

    var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 26, height: 26)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("DANGER ZONE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Reset All Data")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Row Helpers

    @ViewBuilder
    func prefRow<Trailing: View>(
        icon: String,
        iconBg: Color,
        label: String,
        value: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, bg: iconBg)
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    func prefToggleRow(
        icon: String,
        iconBg: Color,
        label: String,
        sublabel: String? = nil,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, bg: iconBg)
            VStack(alignment: .leading, spacing: sublabel != nil ? 2 : 0) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let sub = sublabel {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(brand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    func rowIcon(_ icon: String, bg: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(bg)
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    var rowDivider: some View {
        Divider().padding(.leading, 54)
    }

    var comingSoonBadge: some View {
        Text("Soon")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.primary.opacity(0.08))
            )
    }

    @ViewBuilder
    func densityPreviewIcon(_ density: TimelineDensity) -> some View {
        VStack(spacing: density == .comfortable ? 5 : density == .normal ? 3 : 1) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(prefs.timelineDensity == density ? brand : Color.primary.opacity(0.2))
                    .frame(width: 28, height: density == .comfortable ? 10 : density == .normal ? 7 : 5)
            }
        }
        .frame(height: 36)
    }

    // MARK: - Helpers

    var accentPresets: [String] {
        ["#4A70A6", "#34C759", "#FF6B35", "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00", "#FF9500"]
    }

    func formatMinutes(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }

    func formatDuration(_ m: Int) -> String {
        let h = m / 60; let min = m % 60
        if h > 0 && min > 0 { return "\(h)h\(min)m" }
        if h > 0 { return "\(h)h" }
        return "\(min)m"
    }

    func syncTimeDates() {
        let cal = Calendar.current
        var mc = cal.dateComponents([.year,.month,.day], from: Date())
        mc.hour = prefs.morningBriefingHour; mc.minute = prefs.morningBriefingMinute
        morningTime = cal.date(from: mc) ?? Date()
        var ec = cal.dateComponents([.year,.month,.day], from: Date())
        ec.hour = prefs.eveningReviewHour; ec.minute = prefs.eveningReviewMinute
        eveningTime = cal.date(from: ec) ?? Date()
        tempAccentColor = Color(hex: prefs.accentHex)
    }
}

// Thêm vào extension Notification.Name (trong Preference.swift):
extension Notification.Name {
    static let preferencesDidChange = Notification.Name("preferencesDidChange")
    static let showPremiumPaywall   = Notification.Name("showPremiumPaywall")  // 👈 thêm
}



    // Thêm vào cuối file Preference.swift:
    struct ShareSheet: UIViewControllerRepresentable {
        let items: [Any]
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }
        
        func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
    }

