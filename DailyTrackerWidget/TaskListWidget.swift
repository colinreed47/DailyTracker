import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline

struct TaskListEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskSnapshot]
}

/// Lightweight value type snapshot — avoids passing @Model objects across the timeline boundary.
struct TaskSnapshot: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let isPartial: Bool

    var checkboxIcon: String {
        if isCompleted { return "checkmark.circle.fill" }
        if isPartial { return "circle.lefthalf.filled" }
        return "circle"
    }

    var checkboxColor: Color {
        if isCompleted { return .green }
        if isPartial { return .orange }
        return .secondary
    }
}

struct TaskListProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskListEntry {
        TaskListEntry(date: Date(), tasks: [
            TaskSnapshot(id: UUID(), title: "Morning workout", isCompleted: true, isPartial: false),
            TaskSnapshot(id: UUID(), title: "Read 30 minutes", isCompleted: false, isPartial: true),
            TaskSnapshot(id: UUID(), title: "Drink 8 glasses of water", isCompleted: false, isPartial: false),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskListEntry) -> Void) {
        completion(TaskListEntry(date: Date(), tasks: fetchSnapshots()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskListEntry>) -> Void) {
        let entry = TaskListEntry(date: Date(), tasks: fetchSnapshots())
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func fetchSnapshots() -> [TaskSnapshot] {
        let container = SharedDataStore.makeContainer()
        let context = ModelContext(container)
        resetTasksIfNewDay(context: context)
        let tasks = (try? context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.orderIndex)])
        )) ?? []
        return tasks.map { TaskSnapshot(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, isPartial: $0.isPartial) }
    }

    private func resetTasksIfNewDay(context: ModelContext) {
        let today = DateFormatter.dayFormatter.string(from: Date())
        let defaults = SharedDataStore.sharedDefaults
        guard defaults.string(forKey: "lastResetDate") != today else { return }
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        for task in tasks {
            task.isCompleted = false
            task.isPartial = false
        }
        try? context.save()
        defaults.set(today, forKey: "lastResetDate")
    }
}

// MARK: - View

struct TaskListWidgetView: View {
    let entry: TaskListEntry

    private var completedCount: Int { entry.tasks.filter(\.isCompleted).count }
    private var totalCount: Int { entry.tasks.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(totalCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            Divider()
                .padding(.bottom, 8)

            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No tasks added yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                // Show up to 7 tasks; remaining count shown if list is longer
                let visible = Array(entry.tasks.prefix(7))
                let overflow = entry.tasks.count - visible.count

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visible) { task in
                        Button(intent: ToggleTaskIntent(taskID: task.id)) {
                            HStack(spacing: 10) {
                                Image(systemName: task.checkboxIcon)
                                    .foregroundStyle(task.checkboxColor)
                                    .font(.body)

                                Text(task.title)
                                    .font(.subheadline)
                                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                                    .strikethrough(task.isCompleted)
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if overflow > 0 {
                        Text("+ \(overflow) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget

struct TaskListWidget: Widget {
    let kind = "TaskListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskListProvider()) { entry in
            TaskListWidgetView(entry: entry)
        }
        .configurationDisplayName("Task List")
        .description("See and check off your daily tasks.")
        .supportedFamilies([.systemLarge])
    }
}
