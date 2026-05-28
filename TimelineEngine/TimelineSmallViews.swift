import SwiftUI

struct TimeNowIndicator: View {

    let time: String

    var body: some View {

        HStack(spacing: 8) {

            // giờ bên trái
            Text(time)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

struct FlyingIncrementButton: View {
    let color: Color
    let isCompleted: Bool
    let isAccumulative: Bool
    let incrementValue: Double
    let onTap: () -> Void

    @State private var flyItems: [(id: UUID, offset: CGFloat, opacity: Double, scale: CGFloat)] = []

    func formatIncrement(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "+\(Int(v))" : String(format: "+%.1f", v)
    }

    let btnSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28

    var body: some View {
        ZStack {

            Button {
                guard !(isAccumulative && isCompleted) else { return }
                onTap()
                guard isAccumulative && !isCompleted else { return }
                let id = UUID()
                flyItems.append((id: id, offset: 0, opacity: 1, scale: 1))
                withAnimation(.easeOut(duration: 0.55)) {
                    if let i = flyItems.firstIndex(where: { $0.id == id }) {
                        flyItems[i].offset  = -36
                        flyItems[i].opacity = 0
                        flyItems[i].scale   = 1.3
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    flyItems.removeAll { $0.id == id }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isCompleted ? color.opacity(0.25) : Color.clear)
                        .frame(width: btnSize, height: btnSize)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)
                    Circle()
                        .stroke(color.opacity(0.8), lineWidth: 2)
                    AnimatedCheckmark(progress: isCompleted ? 1 : 0)
                }
            }
            .buttonStyle(.plain)

            ForEach(flyItems, id: \.id) { item in
                Text(formatIncrement(incrementValue))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .scaleEffect(item.scale)
                    .offset(y: item.offset)
                    .opacity(item.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: btnSize, height: btnSize)
    }
}

struct ReorderHintArrows: View {

    let show: Bool
    let trigger: Bool

    @State private var slide: CGFloat = 0

    var body: some View {

        VStack(spacing: 6) {

            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .opacity(show ? 1 : 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .offset(x: slide)
                .opacity(trigger ? 1 : 0.6)
                .animation(
                    trigger ?
                        .easeInOut(duration:0.6).repeatForever(autoreverses:true)
                    : .default,
                    value: trigger
                )


            Image(systemName: "arrow.down")
                .font(.system(size: 12, weight: .bold))
                .opacity(show ? 1 : 0)
        }
        .foregroundStyle(.secondary)
        .scaleEffect(show ? 1 : 0.6)
        .opacity(show ? 1 : 0)
        .onChange(of: trigger) { _, value in

            if value {

                withAnimation(
                    .easeInOut(duration: 0.35)
                    .repeatForever(autoreverses: true)
                ) {
                    slide = 12
                }

            } else {

                withAnimation(.easeOut(duration: 0.15)) {
                    slide = 0
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: show)
    }
}

// MARK: - PremiumLimitPill

/// Replaces the Create button when the user has hit the free-tier limit.
/// Tapping opens the paywall — the user never wastes time filling a form
/// that will be rejected on submit.
struct PremiumLimitPill: View {

    let message: String
    let onTap: () -> Void

    var body: some View {

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        } label: {

            HStack(spacing: 10) {

                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "premium_limit_cta"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.24, blue: 0.62),
                        Color(red: 0.55, green: 0.32, blue: 0.78)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.purple.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TimelineEmptyState

struct TimelineEmptyState: View {

    let onAddEvent: () -> Void
    let onAddHabit: () -> Void

    @Environment(\.colorScheme) private var scheme
    @AppStorage("pref_accent_hex") private var accentHex: String = "#4A70A6"

    private var brand: Color { Color(hex: accentHex) }

    var body: some View {

        VStack(spacing: 16) {

            ZStack {
                Circle()
                    .fill(brand.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(brand)
            }

            VStack(spacing: 6) {

                Text(String(localized: "empty_timeline_title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "empty_timeline_subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAddEvent()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text(String(localized: "empty_add_event"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(brand))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAddHabit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(String(localized: "empty_add_habit"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(brand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(brand.opacity(0.12))
                            .overlay(Capsule().stroke(brand.opacity(0.25), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(scheme == .dark ? Color(.systemGray6) : Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(scheme == .dark ? 0.3 : 0.06), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(brand.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - UndoToast

struct UndoToast: View {

    let title: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(
                title.isEmpty
                ? String(localized: "undo_toast_generic")
                : String(format: String(localized: "undo_toast_deleted %@"), title)
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 8)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onUndo()
            } label: {
                Text(String(localized: "undo_action"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(Color.secondary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "undo_dismiss_a11y")))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(scheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 14, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
