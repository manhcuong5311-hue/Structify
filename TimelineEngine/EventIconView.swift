import SwiftUI

struct EventIconView: View {

    let icon: String
    let color: Color
    let kind: EventKind
    let isHolding: Bool
    let durationMinutes: Int?
    let startMinutes: Int
    let isCompleted: Bool
    let isSystemEvent: Bool
    let isToday: Bool
    let progressFraction: CGFloat   // 0...1
    let isAccumulative: Bool

    @Environment(\.colorScheme) private var scheme

    // Chiều cao pill scale theo duration
    private var pillHeight: CGFloat {
        guard let d = durationMinutes else { return 50 }
        // 15 phút → 50pt, 60 phút → 80pt, 120 phút → 110pt, cap 130pt
        let h = 50 + CGFloat(d - 15) * (80.0 / 105.0)
        return min(max(h, 50), 130)
    }


    var brandRing: Color {
        let brand = Color(hex: PreferencesStore.shared.accentHex)
        return scheme == .dark ? brand.opacity(0.85) : brand.opacity(0.65)
    }

    func isRunning() -> Bool {
        guard isToday, let d = durationMinutes else { return false }
        let now = TimelineEngine.currentMinutes()
        return now >= startMinutes && now <= startMinutes + d
    }

    func progress() -> CGFloat {
        guard let d = durationMinutes else { return 0 }
        let now = TimelineEngine.currentMinutes()
        let start = startMinutes
        let end = start + d
        if now <= start { return 0 }
        if now >= end { return 1 }
        return CGFloat(now - start) / CGFloat(d)
    }


    private var pillWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 60 : 50
    }



    var body: some View {
        Group {
            if kind == .habit {
                ZStack {
                    Circle()
                        .fill(color)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    // badge repeat
                    Image(systemName: "repeat")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 14, y: 14)

                    // Progress ring cho accumulative
                    if isAccumulative {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                            .frame(width: 56, height: 56)

                        Circle()
                            .trim(from: 0, to: progressFraction)
                            .stroke(
                                isCompleted ? Color.green : Color.white,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 56, height: 56)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progressFraction)
                    }
                }
                .frame(width: pillWidth, height: pillWidth)

            } else {
                ZStack {
                    // Nền pill
                    RoundedRectangle(cornerRadius: pillWidth / 2)
                        .fill(
                            isSystemEvent
                            ? color
                            : (scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07))
                        )



                    // Stroke viền màu khi running
                    if isRunning() {
                        RoundedRectangle(cornerRadius: pillWidth / 2)
                            .stroke(
                                isSystemEvent ? Color.white.opacity(0.5) : color,
                                lineWidth: 2.5
                            )
                            .animation(.easeInOut, value: isRunning())
                    }

                    // Icon giữa pill
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSystemEvent ? .white : color)
                }
                .frame(width: pillWidth, height: pillHeight)
            }
        }
        // hold scale áp dụng cho cả 2
        .scaleEffect(isHolding ? 1.15 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHolding)
        .shadow(
            color: color.opacity(isHolding ? 0.3 : 0.15),
            radius: isHolding ? 12 : 4,
            y: isHolding ? 6 : 2
        )
        .background(
            // halo blur phía sau
            Group {
                if kind == .habit {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                } else {
                    RoundedRectangle(cornerRadius: pillWidth / 2 + 5)
                        .fill(.ultraThinMaterial)
                        .frame(width: pillWidth + 10, height: pillHeight + 10)
                }
            }
        )
        .overlay(
            Group {
                if kind == .habit {
                    Circle()
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: pillWidth / 2)
                        .stroke(Color.white.opacity(isHolding ? 0.25 : 0.12), lineWidth: 1)
                }
            }
        )
    }
}
