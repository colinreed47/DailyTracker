import WidgetKit
import SwiftUI

// MARK: - View

struct LockScreenTaskWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TaskCountEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.total == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24, weight: .light))
            } else if entry.remaining == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
            } else {
                VStack(spacing: 0) {
                    Text("\(entry.remaining)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text(entry.remaining == 1 ? "task" : "tasks")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {}
    }

    private var rectangularView: some View {
        HStack(spacing: 6) {
            if entry.total == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18, weight: .light))
                Text("No tasks")
                    .font(.headline)
            } else if entry.remaining == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                Text("All done!")
                    .font(.headline)
            } else {
                Text("\(entry.remaining)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text(entry.remaining == 1 ? "task\nleft" : "tasks\nleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {}
    }
}

// MARK: - Widget

struct LockScreenTaskWidget: Widget {
    let kind = "LockScreenTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskCountProvider()) { entry in
            LockScreenTaskWidgetView(entry: entry)
        }
        .configurationDisplayName("Tasks Remaining")
        .description("See how many tasks you have left today.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
