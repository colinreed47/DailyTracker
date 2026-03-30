import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline

struct TaskCountEntry: TimelineEntry {
    let date: Date
    let completed: Int
    let total: Int

    var remaining: Int { total - completed }
    var ratio: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

struct TaskCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskCountEntry {
        TaskCountEntry(date: Date(), completed: 3, total: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskCountEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskCountEntry>) -> Void) {
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86400)
        completion(Timeline(entries: [makeEntry()], policy: .after(nextMidnight)))
    }

    private func makeEntry() -> TaskCountEntry {
        let container = SharedDataStore.makeContainer()
        let context = ModelContext(container)
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return TaskCountEntry(
            date: Date(),
            completed: tasks.filter(\.isCompleted).count,
            total: tasks.count
        )
    }
}

// MARK: - View

struct TaskCountWidgetView: View {
    let entry: TaskCountEntry

    var body: some View {
        VStack(spacing: 4) {
            if entry.total == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.remaining == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                Text("All done!")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                Text("\(entry.remaining)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                Text(entry.remaining == 1 ? "task left" : "tasks left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget

struct TaskCountWidget: Widget {
    let kind = "TaskCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskCountProvider()) { entry in
            TaskCountWidgetView(entry: entry)
        }
        .configurationDisplayName("Tasks Remaining")
        .description("See how many tasks you have left today.")
        .supportedFamilies([.systemSmall])
    }
}
