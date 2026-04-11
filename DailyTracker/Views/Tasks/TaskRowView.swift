import SwiftUI
import UIKit

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onEdit: (String) -> Void

    @State private var checkBounce = false
    @State private var particlesVisible = false
    @State private var particleProgress: CGFloat = 0
    @State private var isEditing = false
    @State private var editingText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let particleColors: [Color] = [.green, .teal, .mint]
    private let particleCount = 8

    private var checkboxIcon: String {
        if task.isCompleted { return "checkmark.circle.fill" }
        if task.isPartial { return "circle.lefthalf.filled" }
        return "circle"
    }

    private var checkboxColor: Color {
        if task.isCompleted { return .green }
        if task.isPartial { return .orange }
        return .secondary
    }

    private var checkboxAccessibilityLabel: String {
        if task.isCompleted { return "Completed: \(task.title). Tap to mark incomplete." }
        if task.isPartial { return "Partial: \(task.title). Tap to mark complete." }
        return "Incomplete: \(task.title). Tap to mark partial."
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: triggerAnimation) {
                checkboxView
                    .onChange(of: task.isCompleted) { _, newValue in
                        UIImpactFeedbackGenerator(style: newValue ? .medium : .light)
                            .impactOccurred()
                    }
                    .onChange(of: task.isPartial) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Task name", text: $editingText)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { commitEdit() }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(task.title)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)
                    .animation(.default, value: task.isCompleted)
                    .animation(.default, value: task.isPartial)
                    .onTapGesture { startEditing() }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityLabel(checkboxAccessibilityLabel)
    }

    // MARK: - Inline Editing

    private func startEditing() {
        editingText = task.title
        isEditing = true
        isTextFieldFocused = true
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != task.title {
            onEdit(trimmed)
        } else {
            editingText = task.title
        }
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

            Image(systemName: checkboxIcon)
                .font(.title3)
                .foregroundStyle(checkboxColor)
                .scaleEffect(checkBounce ? 1.3 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.45), value: checkBounce)
                .animation(.spring(duration: 0.2), value: task.isCompleted)
                .animation(.spring(duration: 0.2), value: task.isPartial)
        }
        .frame(width: 28, height: 28)
    }

    // MARK: - Animation Trigger

    private func triggerAnimation() {
        onToggle()

        checkBounce = true
        particlesVisible = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            particleProgress = 1
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            checkBounce = false

            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeIn(duration: 0.2)) {
                particleProgress = 0
            }

            try? await Task.sleep(for: .milliseconds(200))
            particlesVisible = false
        }
    }
}
