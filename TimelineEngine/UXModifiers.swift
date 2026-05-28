import SwiftUI

// Press-down feedback: subtle scale + opacity, snappy spring.
// Use as `.buttonStyle(PressFeedbackButtonStyle())` on any Button to get
// Structured-style tactile response.
struct PressFeedbackButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var opacity: Double = 0.85

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Equivalent for tappable non-Button views (uses gesture-driven scale).
struct PressFeedbackModifier: ViewModifier {
    var scale: CGFloat = 0.97
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isPressed { isPressed = true } }
                    .onEnded   { _ in isPressed = false }
            )
    }
}

extension View {
    func pressFeedback(scale: CGFloat = 0.97) -> some View {
        modifier(PressFeedbackModifier(scale: scale))
    }
}

// Live time bubble shown above a held event during drag.
// Updates as the event's time changes; uses .numericText content transition
// so the digits roll smoothly instead of swapping abruptly.
struct DragTimeBubble: View {
    let time: String
    let color: Color

    var body: some View {
        Text(time)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: time)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.45), radius: 8, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .fixedSize()
            .accessibilityHidden(true)
    }
}
