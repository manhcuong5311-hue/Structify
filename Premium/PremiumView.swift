//
//  PremiumView.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//

import SwiftUI

struct PremiumView: View {
    @StateObject private var premium = PremiumStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var appear = false
    @State private var glowPulse = false
    @State private var selectedFeature: Int? = nil

    var body: some View {
        ZStack {
            // Background
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    heroSection
                        .padding(.top, 60)
                        .padding(.bottom, 32)

                    // Features
                    featuresSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    // Compare table
                    compareSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)

                    // CTA
                    ctaSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // Restore + Terms
                    footerLinks
                        .padding(.bottom, 48)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Background
    var background: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            // Ambient glows
            Circle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.18))
                .blur(radius: 80)
                .frame(width: 300)
                .offset(x: -80, y: -200)
                .scaleEffect(glowPulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowPulse)

            Circle()
                .fill(Color(red: 0.4, green: 0.3, blue: 0.85).opacity(0.12))
                .blur(radius: 100)
                .frame(width: 350)
                .offset(x: 120, y: 100)
                .scaleEffect(glowPulse ? 1.0 : 1.2)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: glowPulse)

            // Subtle star dots
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.2...0.5)))
                    .frame(width: CGFloat.random(in: 1.5...3.5))
                    .position(
                        x: CGFloat([42, 88, 156, 220, 290, 55, 180, 310, 130, 270,
                                    60, 200, 340, 90, 250, 30, 170, 320, 110, 280][i % 20]),
                        y: CGFloat([80, 150, 60, 200, 120, 320, 280, 380, 440, 350,
                                    500, 480, 420, 560, 600, 650, 520, 580, 700, 680][i % 20])
                    )
                    .opacity(appear ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(Double(i) * 0.05), value: appear)
            }
        }
    }

    // MARK: - Hero
    var heroSection: some View {
        VStack(spacing: 16) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.78, blue: 0.25),
                                Color(red: 0.85, green: 0.55, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.5), radius: 20, y: 8)

                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appear ? 1 : 0.5)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appear)

            VStack(spacing: 8) {
                Text(String(localized: "premium_title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(localized: "premium_subtitle"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .offset(y: appear ? 0 : 16)
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)

            // Price badge
            Text(String(localized: "premium_price"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.3), lineWidth: 1)
                        )
                )
                .offset(y: appear ? 0 : 10)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)
        }
    }

    // MARK: - Features
    let features: [(icon: String, color: Color, title: String, desc: String)] = [
        ("infinity", Color(red: 0.95, green: 0.78, blue: 0.25),
         String(localized: "feature_unlimited_title"),
         String(localized: "feature_unlimited_desc")),
        
        ("paintpalette.fill", Color(red: 0.6, green: 0.4, blue: 0.95),
         String(localized: "feature_customization_title"),
         String(localized: "feature_customization_desc")),
        
        ("bell.badge.fill", Color(red: 1.0, green: 0.4, blue: 0.4),
         String(localized: "feature_notifications_title"),
         String(localized: "feature_notifications_desc")),
        
        ("flame.fill", Color(red: 1.0, green: 0.5, blue: 0.2),
         String(localized: "feature_stats_title"),
         String(localized: "feature_stats_desc")),
        
        ("externaldrive.fill", Color(red: 0.3, green: 0.7, blue: 0.5),
         String(localized: "feature_backup_title"),
         String(localized: "feature_backup_desc")),
        
        ("square.grid.2x2.fill", Color(red: 0.3, green: 0.65, blue: 1.0),
         String(localized: "feature_icons_title"),
         String(localized: "feature_icons_desc"))
    ]

    var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                featureRow(feature, index: idx)
            }
        }
    }

    func featureRow(_ f: (icon: String, color: Color, title: String, desc: String), index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(f.color.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: f.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(f.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(f.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(f.desc)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .offset(y: appear ? 0 : 20)
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.45).delay(0.15 + Double(index) * 0.06), value: appear)
    }

    // MARK: - Compare
    var compareSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "compare_feature"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(localized: "compare_free"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 60, alignment: .center)
                Text(String(localized: "compare_premium"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                    .frame(width: 70, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            let rows: [(String, String, String)] = [
                (String(localized: "row_events"), String(localized: "row_events_free"), String(localized: "row_events_premium")),
                
                (String(localized: "row_habits"), String(localized: "row_habits_free"), String(localized: "row_habits_premium")),
                
                (String(localized: "row_icons"), String(localized: "row_icons_free"), String(localized: "row_icons_premium")),
                
                (String(localized: "row_stats"), String(localized: "row_stats_free"), String(localized: "row_stats_premium")),
                
                (String(localized: "row_colors"), String(localized: "row_colors_free"), String(localized: "row_colors_premium")),
                
                (String(localized: "row_notifications"), String(localized: "row_notifications_free"), String(localized: "row_notifications_premium")),
                
                (String(localized: "row_backup"), String(localized: "row_backup_free"), String(localized: "row_backup_premium")),
            ]

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack {
                    Text(row.0)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 60, alignment: .center)
                    Text(row.2)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            row.2 == "✗"
                            ? Color.red.opacity(0.6)
                            : Color(red: 0.95, green: 0.78, blue: 0.25)
                        )
                        .frame(width: 70, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(idx % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .offset(y: appear ? 0 : 20)
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.6), value: appear)
    }

    // MARK: - CTA
    var ctaSection: some View {
        VStack(spacing: 12) {
            if let error = premium.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await premium.purchase() }
            } label: {
                ZStack {
                    if premium.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(String(localized: "premium_unlock_button"))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.85, blue: 0.35),
                            Color(red: 0.92, green: 0.65, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.2).opacity(0.5), radius: 16, y: 6)
            }
            .disabled(premium.isLoading || premium.isPremium)
            .scaleEffect(premium.isLoading ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: premium.isLoading)
            .offset(y: appear ? 0 : 16)
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: appear)

            if premium.isPremium {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                    Text(String(localized: "premium_owned_message"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Footer
    var footerLinks: some View {
        VStack(spacing: 16) {

            // Restore
            Button {
                Task { await premium.restore() }
            } label: {
                Text(premium.isLoading
                     ? String(localized: "premium_restoring")
                     : String(localized: "premium_restore_button"))

                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .disabled(premium.isLoading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Purchase description
            VStack(spacing: 6) {
                Text(String(localized: "premium_price_note"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)

                Text(String(localized: "premium_payment_note"))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.22))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            // Legal links
            HStack(spacing: 0) {
                Button {
                    if let url = URL(string: "https://manhcuong5311-hue.github.io/Structify-legal/") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "privacy_policy"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .underline()
                }

                Text("  ·  ")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.2))

                Button {
                    if let url = URL(string: "https://manhcuong5311-hue.github.io/Structify-legal/terms.html") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "terms_of_use"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .underline()
                }

                Text("  ·  ")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.2))

                Button {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("EULA")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .underline()
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
