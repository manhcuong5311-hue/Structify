import SwiftUI

struct TimelineEventRow: View {

    let time: String
    let endTime: String?
    let title: String
    let icon: String
    let color: Color
    let kind: EventKind
    let isHolding: Bool
    let hasDuration: Bool
    let durationMinutes: Int?
    let isNearNowIndicator: Bool
    let isNowApproachingStart: Bool
    let nearSwapTarget: Bool
    let durationPreview: String?
    let startMinutes: Int
    let isCompleted: Bool
    let isSystemEvent: Bool
    var recurrenceLabel: String = String(localized: "recurrence_daily")
    var progressFraction: CGFloat = 0
    var incrementValue: Double = 1
    var onToggleComplete: (() -> Void)?


    var onTap: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    var onIconHold: (() -> Void)? = nil
    var onResizeEnd: ((CGFloat) -> Void)?
    var onResizeFinal: ((CGFloat) -> Void)? = nil

    let isLocked: Bool
    let isToday: Bool

    @Environment(\.colorScheme) private var scheme

    var brandRing: Color {
        let brand = Color(hex: PreferencesStore.shared.accentHex)
        if scheme == .dark {
            return brand.opacity(0.85)
        } else {
            return brand.opacity(0.65)
        }
    }


    private func pillHeight(durationMinutes: Int?) -> CGFloat {
        guard let d = durationMinutes else { return 50 }
        let h = 50 + CGFloat(d - 15) * (80.0 / 105.0)
        return min(max(h, 50), 130)
    }

    private func isNowNearEndTime() -> Bool {
        guard isToday, let d = durationMinutes else { return false }
        let now = TimelineEngine.currentMinutes()
        let end = startMinutes + d
        return now >= end - 10 && now <= end + 2
    }

    func isRunning() -> Bool {
        guard isToday, let durationMinutes else { return false }
        let now = TimelineEngine.currentMinutes()
        return now >= startMinutes && now <= startMinutes + durationMinutes
    }


    func progress() -> CGFloat {
        guard let durationMinutes else { return 0 }

        let now = TimelineEngine.currentMinutes()
        let start = startMinutes
        let end = start + durationMinutes

        if now <= start { return 0 }
        if now >= end { return 1 }

        return CGFloat(now - start) / CGFloat(durationMinutes)
    }


    private var timeScale: CGFloat {
        guard let durationMinutes else { return 1 }
        let scale = 1 + CGFloat(durationMinutes) / 240
        return min(scale, 1.35)
    }

    private var timeSpacing: CGFloat {
        guard let durationMinutes else { return 2 }
        let spacing = CGFloat(durationMinutes) / 6
        return min(max(spacing, 2), 18)
    }

    private var durationText: String? {
        if let durationPreview {
            return durationPreview
        }
        guard let durationMinutes else { return nil }

        if isRunning() && isToday {
            let now = TimelineEngine.currentMinutes()
            let remaining = (startMinutes + durationMinutes) - now
            if remaining > 0 {
                let h = remaining / 60
                let m = remaining % 60
                if h > 0 && m > 0 { return "\(h)h \(m)m left" }
                else if h > 0 { return "\(h)h left" }
                else { return "\(m)m left" }
            }
        }

        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        else if h > 0 { return "\(h)h" }
        else { return "\(m)m" }
    }

    private func isNowNearStartTime() -> Bool {
        guard isToday else { return false }
        if isNowApproachingStart { return true }
        guard let d = durationMinutes else { return false }
        let now = TimelineEngine.currentMinutes()
        return now >= startMinutes && now <= startMinutes + d
    }


    var body: some View {

        let isPad = UIDevice.current.userInterfaceIdiom == .pad


        HStack(alignment: .center, spacing: isPad ? 8 : 4) {

            let ph = pillHeight(durationMinutes: durationMinutes)

            ZStack(alignment: .topLeading) {

                Text(time)
                    .font(.system(
                        size: isPad ? 15 : 13,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .opacity(isNowNearStartTime() ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isNowNearStartTime())
                    .allowsHitTesting(false)


                if let endTime {
                    Text(endTime)
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, isHolding ? 6 : 0)
                        .padding(.vertical, isHolding ? 2 : 0)
                        .background(
                            Capsule()
                                .fill(isHolding ? Color.primary.opacity(0.08) : .clear)
                        )
                        .gesture(
                            isHolding && !isLocked ?
                            DragGesture()
                                .onChanged { value in onResizeEnd?(value.translation.height) }
                                .onEnded   { value in
                                    onResizeEnd?(value.translation.height)
                                    onResizeFinal?(value.translation.height)
                                }
                            : nil
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .opacity(isNowNearEndTime() ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isNowNearEndTime())
                }
            }
            .frame(width: isPad ? 85 : 70, height: ph, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHolding)


            EventIconView(
                icon: icon,
                color: color,
                kind: kind,
                isHolding: isHolding,
                durationMinutes: durationMinutes,
                startMinutes: startMinutes,
                isCompleted: isCompleted,
                isSystemEvent: isSystemEvent,
                isToday: isToday,
                progressFraction: progressFraction,
                isAccumulative: kind == .habit && incrementValue > 0
            )
            .offset(x: -0.5)
            .overlay(alignment: .top) {
                if isHolding {
                    DragTimeBubble(time: time, color: color)
                        .offset(y: -38)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isHolding)
                }
            }



            VStack(alignment: .leading, spacing: 2) {

                if kind == .habit {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(isPad ? .title3.weight(.semibold) : .headline)
                            .opacity(durationPreview != nil ? 0.7 : 1)
                            .opacity(isCompleted ? 0.45 : 1)
                            .overlay(
                                Rectangle()
                                    .fill(Color.primary)
                                    .frame(height: 1.5)
                                    .scaleEffect(x: isCompleted ? 1 : 0, anchor: .leading)
                                    .animation(.easeOut(duration: 0.25), value: isCompleted),
                                alignment: .center
                            )

                        Text(recurrenceLabel)
                            .font(.system(size: isPad ? 12 : 10, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color.opacity(0.12)))
                            .fixedSize()
                            .opacity(isCompleted ? 0.45 : 1)
                    }
                } else {
                    Text(title)
                        .font(isPad ? .title3.weight(.semibold) : .headline)
                        .opacity(durationPreview != nil ? 0.7 : 1)
                        .opacity(isCompleted ? 0.45 : 1)
                        .overlay(
                            Rectangle()
                                .fill(Color.primary)
                                .frame(height: 1.5)
                                .scaleEffect(x: isCompleted ? 1 : 0, anchor: .leading)
                                .animation(.easeOut(duration: 0.25), value: isCompleted),
                            alignment: .center
                        )
                }

                if kind == .event {

                    HStack(spacing: 6) {

                        Text(time)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        if let durationText {

                            if durationPreview != nil {

                                Text(durationText)
                                    .font(.caption.bold())
                                    .monospacedDigit()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(color.opacity(0.18))
                                    )
                                    .foregroundStyle(color)
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(response:0.25,dampingFraction:0.8), value: durationPreview)

                            } else {

                                Text("• \(durationText)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if isRunning() && hasDuration {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 3)
                            Capsule()
                                .fill(color.opacity(0.6))
                                .frame(width: geo.size.width * progress(), height: 3)
                                .animation(.linear(duration: 30), value: progress())
                        }
                    }
                    .frame(height: 3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            .gesture(
                DragGesture().onChanged { _ in }
            )

            Spacer()

            FlyingIncrementButton(
                color: color,
                isCompleted: isCompleted,
                isAccumulative: kind == .habit && incrementValue > 0,
                incrementValue: incrementValue,
                onTap: { onToggleComplete?() }
            )

            ReorderHintArrows(
                show: isHolding,
                trigger: nearSwapTarget
            )
            .frame(width: 24)
            .offset(x: -8)
        }
    }
}
