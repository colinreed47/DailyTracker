import SwiftUI
import UIKit

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void

    @State private var checkBounce = false
    @State private var particlesVisible = false
    @State private var particleProgress: CGFloat = 0

    private let particleColors: [Color] = [.green, .teal, .mint]
    private let particleCount = 8

    var body: some View {
        Button(action: triggerAnimation) {
            HStack(spacing: 12) {
                checkboxView
                    .onChange(of: task.isCompleted) { _, newValue in
                        UIImpactFeedbackGenerator(style: newValue ? .medium : .light)
                            .impactOccurred()
                    }

                Text(task.title)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)
                    .animation(.default, value: task.isCompleted)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Checkbox + Particles

    private var checkboxView: some View {
        ZStack {
            if particlesVisible {
                ForEach(0..<particleCount, id: \.self) { i in
                    let angle = (Double(i) / Double(particleCount)) * 2 * .pi
                    Circle()
                        .fill(particleColors[i % particleColors.count])
                        .frame(width: 5, height: 5)
                        .offset(
                            x: cos(angle) * 18 * particleProgress,
                            y: sin(angle) * 18 * particleProgress
                        )
                        .opacity(Double(particleProgress))
                        .allowsHitTesting(false)
                }
            }

            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                .scaleEffect(checkBounce ? 1.3 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.45), value: checkBounce)
                .animation(.spring(duration: 0.2), value: task.isCompleted)
        }
        .frame(width: 28, height: 28)
    }

    // MARK: - Animation Trigger

    private func triggerAnimation() {
        onToggle()

        // Scale pop
        checkBounce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            checkBounce = false
        }

        // Particle burst
        particlesVisible = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            particleProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeIn(duration: 0.2)) {
                particleProgress = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            particlesVisible = false
        }
    }
}
