//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 8/3/26.
//
import SwiftUI

struct IconPicker: View {
    
    @Binding var icon: String
    @Binding var color: Color
    
    @Environment(\.dismiss) var dismiss
    
    @State private var search = ""
    
    @State private var iconScale: CGFloat = 1
    @State private var favoriteIcons: [String] = UserDefaults.standard.stringArray(forKey: "favoriteIcons") ?? []
    
    @State private var hexInput = ""
    @State private var showHexEditor = false
    
    @State private var hue: Double = 0
    @State private var brightness: Double = 1
    
    var scrollContent: some View {
        
        ScrollView {
            
                categoryGrid
            
        }
        .frame(maxHeight: .infinity)
    }
    
    func updateFavorite(_ symbol: String) {

        if let index = favoriteIcons.firstIndex(of: symbol) {
            favoriteIcons.remove(at: index)
        }

        favoriteIcons.insert(symbol, at: 0)

        if favoriteIcons.count > 8 {
            favoriteIcons.removeLast()
        }

        UserDefaults.standard.set(favoriteIcons, forKey: "favoriteIcons")
    }
    
    
    var body: some View {

        NavigationStack {

            VStack(spacing:20) {

                iconHeader

                ScrollView {
                    categoryGrid
                }
            }
            .padding()
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showHexEditor) {

            ColorPickerSheet(color: $color)
                .presentationDetents([.height(420)])
        }
    }
    
    
}

extension IconPicker {

    var categoryGrid: some View {

        VStack(spacing: 28) {
            
            if !favoriteIcons.isEmpty {

                VStack(alignment: .leading, spacing: 12) {

                    Text("Favorites")
                        .font(.headline)

                    LazyVGrid(columns: gridColumns, spacing: 18) {

                        ForEach(favoriteIcons, id:\.self) { symbol in

                            iconCell(
                                EventIcon(symbol: symbol, name: symbol)
                            )
                        }
                    }
                }
            }

            ForEach(IconCategoryCatalog.categories) { category in

                VStack(alignment: .leading, spacing: 12) {

                    Text(category.title)
                        .font(.headline)

                    HStack {

                        LazyVGrid(
                            columns: gridColumns,
                            spacing: 18
                        ) {

                            ForEach(category.icons) { item in
                                iconCell(item)
                            }
                        }

                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    
    
    
    var gridColumns: [GridItem] {

        Array(
            repeating: GridItem(
                .fixed(48),
                spacing: 16
            ),
            count: 5
        )
    }
    
    
    func iconCell(_ item: EventIcon) -> some View {

        Button {

            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                icon = item.symbol
                iconScale = 1.2
            }

            updateFavorite(item.symbol)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                iconScale = 1
            }

        } label: {

            Image(systemName: item.symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size:20, weight:.medium))
                .foregroundStyle(.primary)
                .frame(width:48,height:48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            icon == item.symbol
                            ? color.opacity(0.2)
                            : Color(.systemGray6)
                        )
                )
                .shadow(
                    color: icon == item.symbol ? color.opacity(0.3) : .clear,
                    radius: 6,
                    y: 2
                )
        }
        .buttonStyle(.plain)
    }
    
    
    
}


extension IconPicker {

    var colorPicker: some View {

        HStack(spacing:16) {

            ForEach(EventColorPalette.colors,id:\.self) { c in

                Button {

                    color = c

                } label: {

                    Circle()
                        .fill(c)
                        .frame(width:32,height:32)
                        .overlay(
                            Circle()
                                .stroke(.white,lineWidth:2)
                                .opacity(color == c ? 1 : 0)
                        )
                }
            }
        }
    }
}



extension IconPicker {

    var preview: some View {

        ZStack {

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.9),
                            color.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .shadow(color: color.opacity(0.25), radius: 6, y: 3)

            Circle()
                .stroke(color.opacity(0.35), lineWidth: 1)

            Image(systemName: icon)
                .font(.system(size: 48, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white)
                .scaleEffect(iconScale)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: icon)
        }
        .shadow(color: color.opacity(0.35), radius: 12, y: 5)
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

extension IconPicker {

    var iconHeader: some View {

        HStack(alignment: .center, spacing: 20) {

            preview
                .fixedSize()

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 28), spacing: 12)
                ],
                spacing: 12
            ) {

                ForEach(EventColorPalette.colors, id: \.self) { c in

                    Button {
                        color = c
                    } label: {

                        Circle()
                            .fill(c)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                                    .opacity(color == c ? 1 : 0)
                            )
                    }
                }
                
                Button {
                    showHexEditor = true
                } label: {

                    ZStack {

                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 28, height: 28)

                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                
                
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
        )
    }
}


