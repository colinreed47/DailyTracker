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
        resetTasksIfNewDay(context: context)
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return TaskCountEntry(
            date: Date(),
            completed: tasks.filter(\.isCompleted).count,
            total: tasks.count
        )
    }

    private func resetTasksIfNewDay(context: ModelContext) {
        let today = DateFormatter.dayFormatter.string(from: Date())
        let defaults = SharedDataStore.sharedDefaults
        guard defaults.string(forKey: "lastResetDate") != today else { return }
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        for task in tasks { task.isCompleted = false }
        try? context.save()
        defaults.set(today, forKey: "lastResetDate")
    }
}

// MARK: - View

struct TaskCountWidgetView: View {
    let entry: TaskCountEntry

    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            accessoryCircularBody
        case .accessoryRectangular:
            accessoryRectangularBody
        default:
            systemSmallBody
        }
    }

    private var ringColor: Color {
        if entry.total == 0 { return .secondary }
        if entry.remaining == 0 { return .green }
        switch entry.ratio {
        case ..<0.4:     return .red
        case 0.4..<0.75: return .orange
        default:         return .green
        }
    }

    // MARK: systemSmall

    private var systemSmallBody: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: entry.ratio)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
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
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(entry.remaining == 1 ? "task left" : "tasks left")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: accessoryCircular

    private var accessoryCircularBody: some View {
        Gauge(value: entry.ratio, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            if entry.total == 0 {
                Image(systemName: "minus")
                    .font(.caption.bold())
            } else if entry.remaining == 0 {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
            } else {
                Text("\(entry.remaining)")
                    .font(.caption.bold())
                    .minimumScaleFactor(0.6)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: accessoryRectangular

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.total == 0 {
                Label("No tasks", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if entry.remaining == 0 {
                Label("All done!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
            } else {
                Text("\(entry.remaining) \(entry.remaining == 1 ? "task left" : "tasks left")")
                    .font(.headline)
                    .minimumScaleFactor(0.8)
            }
            ProgressView(value: entry.ratio, total: 1.0)
                .tint(ringColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
