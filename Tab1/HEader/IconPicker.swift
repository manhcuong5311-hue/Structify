//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 8/3/26.
//
import SwiftUI

import SwiftUI

// MARK: - IconPicker

struct IconPicker: View {

    @Binding var icon: String
    @Binding var color: Color

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Local state để tránh lag — chỉ sync về binding khi Done
    @State private var selectedIcon: String = ""
    @State private var selectedColor: Color = .blue

    @State private var recentIcons: [String] =
        UserDefaults.standard.stringArray(forKey: "recentIcons") ?? []
    @State private var showHexEditor = false
    @State private var iconScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header: preview + color swatches
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    Divider()
                        .opacity(0.4)

                    // Icon grid
                    ScrollView(showsIndicators: false) {
                        iconGridSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Chỉ sync về binding 1 lần khi Done
                        icon = selectedIcon
                        color = selectedColor
                        updateRecent(selectedIcon)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedColor)
                }
            }
        }
        .onAppear {
            selectedIcon = icon
            selectedColor = color
        }
        .sheet(isPresented: $showHexEditor) {
            ColorPickerSheet(color: $selectedColor)
                .presentationDetents([.height(420)])
        }
        .onChange(of: showHexEditor) { _, isShowing in
            // Sheet vừa đóng → save màu custom vào palette
            if !isShowing {
                var current = EventColorPalette.colors
                // Chỉ thêm nếu chưa có màu giống
                let alreadyExists = current.contains {
                    $0.toHex() == selectedColor.toHex()
                }
                if !alreadyExists {
                    // Giới hạn palette tối đa 20 màu
                    if current.count >= 20 {
                        // Xóa màu cuối (không xóa 13 màu default)
                        current.removeLast()
                    }
                    current.append(selectedColor)
                    EventColorPalette.colors = current
                }
            }
        }
    }

    // MARK: - Helpers

    func updateRecent(_ symbol: String) {
        if let i = recentIcons.firstIndex(of: symbol) { recentIcons.remove(at: i) }
        recentIcons.insert(symbol, at: 0)
        if recentIcons.count > 20 { recentIcons.removeLast() }
        UserDefaults.standard.set(recentIcons, forKey: "recentIcons")
    }
}

// MARK: - Header

extension IconPicker {

    var headerSection: some View {
        HStack(spacing: 20) {

            // Preview circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [selectedColor.opacity(0.9), selectedColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: selectedIcon.isEmpty ? "star.fill" : selectedIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(iconScale)
                    .id(selectedIcon) // force redraw only this
            }
            .shadow(color: selectedColor.opacity(0.35), radius: 10, y: 4)

            // Color swatches
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(28), spacing: 10), count: 7),
                spacing: 10
            ) {
                ForEach(EventColorPalette.colors, id: \.self) { c in
                    ColorSwatch(
                        color: c,
                        isSelected: selectedColor == c,
                        onTap: {
                            // Chỉ update local state — không trigger icon grid rebuild
                            selectedColor = c
                        }
                    )
                }

                // Custom color button
                Button {
                    showHexEditor = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                    center: .center
                                )
                            )
                            .frame(width: 28, height: 28)
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        )
    }
}

// MARK: - ColorSwatch (isolated component — không rebuild khi icon thay đổi)

struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)

                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                        .frame(width: 28, height: 28)

                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Icon Grid

extension IconPicker {

    var iconGridSection: some View {
        VStack(alignment: .leading, spacing: 28) {

            // Recent
            if !recentIcons.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Recent")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recentIcons, id: \.self) { sym in
                                IconCell(
                                    symbol: sym,
                                    accentColor: selectedColor,
                                    isSelected: selectedIcon == sym,
                                    onTap: { selectIcon(sym) }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Categories
            ForEach(IconCategoryCatalog.categories) { category in
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(category.title)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(52), spacing: 10), count: 6),
                        spacing: 10
                    ) {
                        ForEach(category.icons) { item in
                            IconCell(
                                symbol: item.symbol,
                                accentColor: selectedColor,
                                isSelected: selectedIcon == item.symbol,
                                onTap: { selectIcon(item.symbol) }
                            )
                        }
                    }
                }
            }
        }
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    func selectIcon(_ sym: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            selectedIcon = sym
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - IconCell (fully isolated — không nhận Binding, chỉ nhận value)

struct IconCell: View {
    let symbol: String
    let accentColor: Color
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? accentColor.opacity(0.15)
                        : Color(.secondarySystemBackground)
                    )

                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
                }

                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? accentColor : .primary)
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }
}










struct EventIcon: Identifiable, Hashable {

    let id = UUID()
    let symbol: String
    let name: String
}

struct IconCategoryCatalog {

    static let categories: [IconCategory] = [

        IconCategory(
            title: "Work",
            icons: [
                EventIcon(symbol: "briefcase.fill", name: "Work"),
                EventIcon(symbol: "calendar", name: "Schedule"),
                EventIcon(symbol: "doc.text.fill", name: "Document"),
                EventIcon(symbol: "folder.fill", name: "Files"),
                EventIcon(symbol: "tray.full.fill", name: "Inbox"),
                EventIcon(symbol: "archivebox.fill", name: "Archive"),
                EventIcon(symbol: "paperplane.fill", name: "Send"),
                EventIcon(symbol: "envelope.fill", name: "Email"),
                EventIcon(symbol: "clock.fill", name: "Deadline"),
                EventIcon(symbol: "checkmark.circle.fill", name: "Done"),
                EventIcon(symbol: "flag.fill", name: "Priority"),
                EventIcon(symbol: "chart.bar.fill", name: "Analytics"),
                EventIcon(symbol: "chart.pie.fill", name: "Report"),
                EventIcon(symbol: "chart.line.uptrend.xyaxis", name: "Growth"),
                EventIcon(symbol: "doc.richtext.fill", name: "Notes"),
                EventIcon(symbol: "signature", name: "Signature"),
                EventIcon(symbol: "paperclip", name: "Attachment"),
                EventIcon(symbol: "rectangle.and.pencil.and.ellipsis", name: "Edit"),
                EventIcon(symbol: "person.crop.circle.badge.checkmark", name: "Assigned"),
                EventIcon(symbol: "person.3.fill", name: "Team")
            ]
        ),

        IconCategory(
            title: "Study",
            icons: [
                EventIcon(symbol: "book.fill", name: "Study"),
                EventIcon(symbol: "books.vertical.fill", name: "Library"),
                EventIcon(symbol: "graduationcap.fill", name: "Learning"),
                EventIcon(symbol: "pencil", name: "Writing"),
                EventIcon(symbol: "highlighter", name: "Highlight"),
                EventIcon(symbol: "brain.head.profile", name: "Thinking"),
                EventIcon(symbol: "note.text", name: "Notes"),
                EventIcon(symbol: "doc.plaintext", name: "Research"),
                EventIcon(symbol: "lightbulb.fill", name: "Idea"),
                EventIcon(symbol: "bookmark.fill", name: "Bookmark"),
                EventIcon(symbol: "text.book.closed.fill", name: "Reading"),
                EventIcon(symbol: "magnifyingglass", name: "Search"),
                EventIcon(symbol: "list.bullet.rectangle", name: "Checklist"),
                EventIcon(symbol: "questionmark.circle.fill", name: "Question"),
                EventIcon(symbol: "exclamationmark.triangle.fill", name: "Important"),
                EventIcon(symbol: "text.alignleft", name: "Text"),
                EventIcon(symbol: "text.cursor", name: "Typing"),
                EventIcon(symbol: "pencil.and.outline", name: "Edit"),
                EventIcon(symbol: "square.and.pencil", name: "Write"),
                EventIcon(symbol: "note", name: "Memo")
            ]
        ),

        IconCategory(
            title: "Health",
            icons: [
                EventIcon(symbol: "heart.fill", name: "Health"),
                EventIcon(symbol: "figure.walk", name: "Walk"),
                EventIcon(symbol: "figure.run", name: "Run"),
                EventIcon(symbol: "figure.strengthtraining.traditional", name: "Gym"),
                EventIcon(symbol: "dumbbell.fill", name: "Workout"),
                EventIcon(symbol: "bed.double.fill", name: "Sleep"),
                EventIcon(symbol: "leaf.fill", name: "Meditation"),
                EventIcon(symbol: "lungs.fill", name: "Breathing"),
                EventIcon(symbol: "drop.fill", name: "Water"),
                EventIcon(symbol: "cross.case.fill", name: "Medical"),
                EventIcon(symbol: "cross.fill", name: "HealthCare"),
                EventIcon(symbol: "waveform.path.ecg", name: "HeartRate"),
                EventIcon(symbol: "figure.cooldown", name: "Cooldown"),
                EventIcon(symbol: "figure.yoga", name: "Yoga"),
                EventIcon(symbol: "figure.mind.and.body", name: "Mindfulness"),
                EventIcon(symbol: "pill.fill", name: "Medicine"),
                EventIcon(symbol: "bandage.fill", name: "FirstAid"),
                EventIcon(symbol: "stethoscope", name: "Doctor"),
                EventIcon(symbol: "applelogo", name: "Nutrition"),
                EventIcon(symbol: "fork.knife.circle.fill", name: "Diet")
            ]
        ),

        IconCategory(
            title: "Life",
            icons: [
                EventIcon(symbol: "house.fill", name: "Home"),
                EventIcon(symbol: "cup.and.saucer.fill", name: "Coffee"),
                EventIcon(symbol: "fork.knife", name: "Food"),
                EventIcon(symbol: "cart.fill", name: "Shopping"),
                EventIcon(symbol: "gift.fill", name: "Gift"),
                EventIcon(symbol: "sparkles", name: "Special"),
                EventIcon(symbol: "person.fill", name: "Personal"),
                EventIcon(symbol: "person.2.fill", name: "Friends"),
                EventIcon(symbol: "person.3.fill", name: "Group"),
                EventIcon(symbol: "phone.fill", name: "Call"),
                EventIcon(symbol: "message.fill", name: "Chat"),
                EventIcon(symbol: "bubble.left.and.bubble.right.fill", name: "Conversation"),
                EventIcon(symbol: "bell.fill", name: "Reminder"),
                EventIcon(symbol: "alarm.fill", name: "Alarm"),
                EventIcon(symbol: "clock.arrow.circlepath", name: "Routine"),
                EventIcon(symbol: "wand.and.stars", name: "Magic"),
                EventIcon(symbol: "paintpalette.fill", name: "Art"),
                EventIcon(symbol: "camera.fill", name: "Photo"),
                EventIcon(symbol: "music.note", name: "Music"),
                EventIcon(symbol: "gamecontroller.fill", name: "Gaming")
            ]
        ),

        IconCategory(
            title: "Tech",
            icons: [
                EventIcon(symbol: "laptopcomputer", name: "Laptop"),
                EventIcon(symbol: "desktopcomputer", name: "Desktop"),
                EventIcon(symbol: "keyboard", name: "Keyboard"),
                EventIcon(symbol: "ipad", name: "Tablet"),
                EventIcon(symbol: "iphone", name: "Phone"),
                EventIcon(symbol: "wifi", name: "Internet"),
                EventIcon(symbol: "antenna.radiowaves.left.and.right", name: "Signal"),
                EventIcon(symbol: "gearshape.fill", name: "Settings"),
                EventIcon(symbol: "gearshape.2.fill", name: "System"),
                EventIcon(symbol: "cpu.fill", name: "CPU"),
                EventIcon(symbol: "memorychip.fill", name: "Chip"),
                EventIcon(symbol: "externaldrive.fill", name: "Storage"),
                EventIcon(symbol: "icloud.fill", name: "Cloud"),
                EventIcon(symbol: "bolt.fill", name: "Power"),
                EventIcon(symbol: "terminal.fill", name: "Terminal"),
                EventIcon(symbol: "chevron.left.slash.chevron.right", name: "Code"),
                EventIcon(symbol: "app.badge.fill", name: "App"),
                EventIcon(symbol: "network", name: "Network"),
                EventIcon(symbol: "server.rack", name: "Server"),
                EventIcon(symbol: "lock.shield.fill", name: "Security")
            ]
        ),

        IconCategory(
            title: "Travel",
            icons: [
                EventIcon(symbol: "airplane", name: "Travel"),
                EventIcon(symbol: "car.fill", name: "Drive"),
                EventIcon(symbol: "tram.fill", name: "Transport"),
                EventIcon(symbol: "bicycle", name: "Bike"),
                EventIcon(symbol: "scooter", name: "Scooter"),
                EventIcon(symbol: "map.fill", name: "Map"),
                EventIcon(symbol: "location.fill", name: "Location"),
                EventIcon(symbol: "mappin.and.ellipse", name: "Pin"),
                EventIcon(symbol: "sun.max.fill", name: "Morning"),
                EventIcon(symbol: "moon.fill", name: "Night"),
                EventIcon(symbol: "cloud.sun.fill", name: "Weather"),
                EventIcon(symbol: "cloud.rain.fill", name: "Rain"),
                EventIcon(symbol: "snowflake", name: "Snow"),
                EventIcon(symbol: "camera.aperture", name: "Photo"),
                EventIcon(symbol: "binoculars.fill", name: "Explore"),
                EventIcon(symbol: "suitcase.fill", name: "Trip"),
                EventIcon(symbol: "tent.fill", name: "Camping"),
                EventIcon(symbol: "ferry.fill", name: "Boat"),
                EventIcon(symbol: "fuelpump.fill", name: "Fuel"),
                EventIcon(symbol: "star.fill", name: "Favorite")
            ]
        )
    ]
}

struct IconCategory: Identifiable {

    let id = UUID()
    let title: String
    let icons: [EventIcon]
}

struct EventColorPalette {

    static let defaultColors: [Color] = [
        .blue,
        .green,
        .purple,
        .pink,
        .orange,
        .red,
        .teal,
        .indigo,
        .mint,
        .yellow,
        .cyan,
        .brown,
        .gray
    ]

    static var colors: [Color] {

        get {

            let hexes = UserDefaults.standard.stringArray(forKey: "presetColors")

            if let hexes {
                return hexes.map { Color(hex: $0) }
            }

            return defaultColors
        }

        set {

            let hexes = newValue.map { $0.toHex() }

            UserDefaults.standard.set(hexes, forKey: "presetColors")
        }
    }
}




extension Color {

    static let paper = Color(
        UIColor { trait in

            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
            } else {
                return UIColor(red: 248/255, green: 247/255, blue: 244/255, alpha: 1)
            }

        }
    )
}
