//
//  ColorToolkit.swift
//  Structify
//
//  Created by Sam Manh Cuong on 8/3/26.
//

//
//  ColorToolkit.swift
//  Structify
//

import SwiftUI

extension Color {

    // MARK: - Init HEX

    init(hex: String) {

        let hex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        var rgb: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&rgb) else {
            self = .gray
            return
        }

        let r, g, b, a: Double

        switch hex.count {

        case 3: // RGB (12-bit)
            r = Double((rgb >> 8) & 0xF) / 15
            g = Double((rgb >> 4) & 0xF) / 15
            b = Double(rgb & 0xF) / 15
            a = 1

        case 6: // RGB (24-bit)
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
            a = 1

        case 8: // RGBA (32-bit)
            r = Double((rgb >> 24) & 0xFF) / 255
            g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8) & 0xFF) / 255
            a = Double(rgb & 0xFF) / 255

        default:
            self = .gray
            return
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - Convert to HEX

    func toHex() -> String {

        let ui = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ui.getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }

    // MARK: - Lighter

    func lighter(_ amount: CGFloat = 0.2) -> Color {

        let ui = UIColor(self)

        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return Color(
            UIColor(
                hue: h,
                saturation: s,
                brightness: min(b + amount, 1),
                alpha: a
            )
        )
    }

    // MARK: - Darker

    func darker(_ amount: CGFloat = 0.2) -> Color {

        let ui = UIColor(self)

        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return Color(
            UIColor(
                hue: h,
                saturation: s,
                brightness: max(b - amount, 0),
                alpha: a
            )
        )
    }

    // MARK: - Check if Light Color

    var isLight: Bool {

        let ui = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ui.getRed(&r, green: &g, blue: &b, alpha: &a)

        let brightness = (r * 299 + g * 587 + b * 114) / 1000

        return brightness > 0.6
    }

    // MARK: - Gradient

    var gradient: LinearGradient {

        LinearGradient(
            colors: [
                self.lighter(0.15),
                self.darker(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Random Color

    static func random() -> Color {

        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}


import SwiftUI

struct ColorPickerSheet: View {

    @Binding var color: Color
    @Environment(\.dismiss) var dismiss

    @State private var hue: Double = 0
    @State private var brightness: Double = 1
    @State private var editingPresets = false
    
    @State private var presets: [Color] = EventColorPalette.colors
    
    var hex: String {
        color.toHex().replacingOccurrences(of: "#", with: "")
    }
    
    func updateColor() {
        color = Color(
            hue: hue,
            saturation: 0.8,
            brightness: brightness
        )
    }
    
    func addPreset(_ color: Color) {
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            presets.append(color)
        }

        if presets.contains(where: { $0.toHex() == color.toHex() }) {
            return
        }

        presets.append(color)
        EventColorPalette.colors = presets
    }

    var body: some View {

        VStack(spacing: 0) {

            header
                .padding(.horizontal,24)
                .padding(.top,20)

            ScrollView {

                VStack(spacing: 24) {

                    hueSlider

                    brightnessSlider

                    presetSection

                    Spacer(minLength: 20)
                }
                .padding(24)
            }
        }
        .background(.ultraThinMaterial)
        .onAppear {

            presets = EventColorPalette.colors

            let ui = UIColor(color)

            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            hue = Double(h)
            brightness = Double(b)
        }
    }
}

extension ColorPickerSheet {

    var header: some View {

        HStack {

            Text(String(localized: "choose_color"))
                .font(.title2.bold())

            Spacer()

            HStack(spacing:4) {

                Text("#")
                    .foregroundStyle(.pink)

                Text(hex)
                    .fontWeight(.medium)
            }
            .padding(.horizontal,10)
            .padding(.vertical,6)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius:8))

            Button {
                dismiss()
            } label: {

                Image(systemName: "xmark")
                    .font(.system(size:16,weight:.bold))
                    .frame(width:34,height:34)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
        }
    }
}

extension ColorPickerSheet {

    var hueSlider: some View {

        Slider(value: $hue)
            .onChange(of: hue) { updateColor() }
            .accentColor(.clear)
            .background(

                LinearGradient(
                    colors: [
                        .red,.yellow,.green,.cyan,.blue,.purple,.pink,.red
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule())
            )
            .frame(height:20)
    }
}

extension ColorPickerSheet {

    var brightnessSlider: some View {

        Slider(value: $brightness)
            .onChange(of: brightness) { updateColor() }
            .accentColor(.clear)
            .background(

                LinearGradient(
                    colors: [
                        .black,
                        Color(hue: hue, saturation: 0.8, brightness: brightness)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule())
            )
            .frame(height:20)
    }
}

extension ColorPickerSheet {

    func removePreset(_ color: Color) {
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            presets.removeAll { $0.toHex() == color.toHex() }
        }

        presets.removeAll {
            $0.toHex() == color.toHex()
        }

        if presets.isEmpty {
            presets = EventColorPalette.defaultColors
        }

        EventColorPalette.colors = presets
    }
    
    
    var presetSection: some View {

        VStack(alignment:.leading, spacing:16) {

            HStack {

                Text(String(localized: "presets"))

                    .font(.title3.bold())

                Spacer()

                Button {
                    editingPresets.toggle()
                } label: {

                    Label(
                        String(localized: "edit"),
                        systemImage: "pencil"
                    )
                        .padding(.horizontal,12)
                        .padding(.vertical,6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 44))],
                spacing: 18
            ) {

                ForEach(presets, id:\.self) { c in

                    ZStack {

                        Circle()
                            .fill(c)
                            .frame(width:44,height:44)
                            .onTapGesture {

                                if !editingPresets {
                                    color = c
                                }
                            }

                        if editingPresets {

                            VStack {

                                HStack {

                                    Spacer()

                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .background(.white)
                                        .clipShape(Circle())
                                        .onTapGesture {
                                            removePreset(c)
                                        }
                                }

                                Spacer()
                            }
                        }
                    }
                }

                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName:"plus")
                    )
                    .frame(width:44,height:44)
                    .onTapGesture {

                        addPreset(color)
                    }
            }
        }
    }
}

