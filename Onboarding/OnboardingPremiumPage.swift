//
//  OnboardingPremiumPage.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//

import SwiftUI
import StoreKit

struct OnboardingPremiumPage: View {
    let onFinish: () -> Void

    @StateObject private var premium = PremiumStore.shared
    @State private var appear = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 70)
                        .padding(.bottom, 28)

                    featuresSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                    compareSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    ctaSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    footerLinks
                        .padding(.bottom, 100)
                }
            }

            // Skip / X button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onFinish()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
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
            Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.15))
                .blur(radius: 80)
                .frame(width: 300)
                .offset(x: -80, y: -200)
                .scaleEffect(glowPulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowPulse)

            Circle()
                .fill(Color(red: 0.4, green: 0.3, blue: 0.85).opacity(0.10))
                .blur(radius: 100)
                .frame(width: 350)
                .offset(x: 120, y: 100)
        }
    }

    // MARK: - Hero
    var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.95, green: 0.78, blue: 0.25),
                                 Color(red: 0.85, green: 0.55, blue: 0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.5),
                            radius: 16, y: 6)

                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appear ? 1 : 0.5)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appear)

            VStack(spacing: 6) {
                Text(String(localized: "onboarding.paywall.title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)

                Text(String(localized: "onboarding.paywall.unlock"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(localized: "onboarding.paywall.subtitle"))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)
        }
    }

    // MARK: - Features
    let features: [(String, Color, String, String)] = [
        (
            "infinity",
            Color(red: 0.95, green: 0.78, blue: 0.25),
            String(localized: "premium.feature.unlimited.title"),
            String(localized: "premium.feature.unlimited.subtitle")
        ),
        (
            "paintpalette.fill",
            Color(red: 0.6, green: 0.4, blue: 0.95),
            String(localized: "premium.feature.customization.title"),
            String(localized: "premium.feature.customization.subtitle")
        ),
        (
            "bell.badge.fill",
            Color(red: 1.0, green: 0.4, blue: 0.4),
            String(localized: "premium.feature.notifications.title"),
            String(localized: "premium.feature.notifications.subtitle")
        ),
        (
            "externaldrive.fill",
            Color(red: 0.3, green: 0.7, blue: 0.5),
            String(localized: "premium.feature.backup.title"),
            String(localized: "premium.feature.backup.subtitle")
        )
    ]

    var featuresSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(f.1.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: f.0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(f.1)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.2)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(f.3)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)
                .animation(.easeOut(duration: 0.4).delay(0.2 + Double(idx) * 0.07), value: appear)
            }
        }
    }

    // MARK: - Compare
    var compareSection: some View {
        HStack(spacing: 0) {
            // Free column
            VStack(spacing: 0) {
                Text(String(localized: "premium.free.title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.04))

                ForEach([
                    String(localized: "premium.free.limit.events"),
                    String(localized: "premium.free.limit.habits"),
                    String(localized: "premium.free.limit.icons"),
                    String(localized: "premium.free.limit.stats")
                ], id: \.self) { val in

                    Text(val)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            // Premium column
            VStack(spacing: 0) {
                Text(String(localized: "premium.title"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.08))

                ForEach([
                    String(localized: "premium.feature.events"),
                    String(localized: "premium.feature.habits"),
                    String(localized: "premium.feature.icons"),
                    String(localized: "premium.feature.stats")
                ], id: \.self) { val in
                    Text(val)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)
    }

    // MARK: - CTA
    var ctaSection: some View {
        VStack(spacing: 10) {
            if let error = premium.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Buy button
            Button {
                Task {
                    await premium.purchase()
                    // Mua xong (dù success hay fail) → onFinish sau 0.5s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if premium.isPremium { onFinish() }
                    }
                }
            } label: {
                ZStack {
                    if premium.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(String(localized: "premium.unlock_price"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.85, blue: 0.35),
                                 Color(red: 0.92, green: 0.65, blue: 0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.2).opacity(0.4),
                        radius: 14, y: 5)
            }
            .disabled(premium.isLoading || premium.isPremium)

            // Maybe later
            Button {
                onFinish()
            } label: {
                Text(String(localized: "premium.later"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }

            if premium.isPremium {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                    Text(String(localized: "premium.unlocked"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.65), value: appear)
    }

    // MARK: - Footer
    var footerLinks: some View {
        VStack(spacing: 14) {

            // Restore
            Button {
                Task { await premium.restore() }
            } label: {
                Text(premium.isLoading
                     ? String(localized: "premium.restoring")
                     : String(localized: "premium.restore"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .disabled(premium.isLoading)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Purchase description
            VStack(spacing: 5) {
                Text(String(localized: "premium.purchase_description"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)

                Text(String(localized: "premium.purchase_details"))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.18))
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
                    Text(String(localized: "legal.privacy_policy"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .underline()
                }

                Text("  ·  ")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.15))

                Button {
                    if let url = URL(string: "https://manhcuong5311-hue.github.io/Structify-legal/terms.html") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "legal.terms_of_use"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .underline()
                }

                Text("  ·  ")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.15))

                Button {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("EULA")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .underline()
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
