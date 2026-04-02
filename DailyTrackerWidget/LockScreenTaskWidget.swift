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
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.total == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.title2.weight(.light))
            } else if entry.remaining == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
            } else {
                VStack(spacing: 0) {
                    Text("\(entry.remaining)")
                        .font(.title.bold())
                        .fontDesign(.rounded)
                        .minimumScaleFactor(0.6)
                    Text(entry.remaining == 1 ? "task" : "tasks")
                        .font(.caption2)
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
                    .font(.title3.weight(.light))
                Text("No tasks")
                    .font(.headline)
            } else if entry.remaining == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("All done!")
                    .font(.headline)
            } else {
                Text("\(entry.remaining)")
                    .font(.title.bold())
                    .fontDesign(.rounded)
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
        .configurationDisplayName("Tasks (Lock Screen)")
        .description("See how many tasks you have left today.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
