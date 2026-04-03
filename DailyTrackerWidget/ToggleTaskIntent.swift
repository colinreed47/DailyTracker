import AppIntents
import SwiftData
import WidgetKit

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { return .result() }

        let container = SharedDataStore.makeContainer()
        let context = ModelContext(container)

        let tasks = (try? context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.orderIndex)])
        )) ?? []

        guard let task = tasks.first(where: { $0.id == id }) else { return .result() }
        if !task.isPartial && !task.isCompleted {
            task.isPartial = true
        } else if task.isPartial {
            task.isPartial = false
            task.isCompleted = true
        } else {
            task.isCompleted = false
        }
        try? context.save()

        // Keep today's DayRecord in sync
        let today = DateFormatter.dayFormatter.string(from: Date())
        let allTitles = tasks.map(\.title)
        let completedTitles = tasks.filter(\.isCompleted).map(\.title)
        let partialTitles = tasks.filter(\.isPartial).map(\.title)

        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        if let existing = records.first(where: { $0.dateString == today }) {
            existing.allTaskTitles = allTitles
            existing.completedTaskTitles = completedTitles
            existing.partiallyCompletedTaskTitles = partialTitles
        } else {
            context.insert(DayRecord(
                dateString: today,
                allTaskTitles: allTitles,
                completedTaskTitles: completedTitles,
                partiallyCompletedTaskTitles: partialTitles
            ))
        }
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
