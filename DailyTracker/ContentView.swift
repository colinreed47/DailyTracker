import SwiftUI
import SwiftData

struct ContentView: View {
    let userId: String

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            TasksView(userId: userId)
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }

            CalendarView(userId: userId)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .onChange(of: userId) { _, newId in
            guard !newId.isEmpty else { return }
            adoptOrphanedData(to: newId)
        }
    }

    /// Rebinds records stored under a stale identity to the current user.
    /// Covers both pre-auth legacy data (userId == "") and data orphaned when
    /// a failed session restore minted a fresh anonymous user. The app is
    /// single-user per device, so any non-matching userId is a past identity
    /// of the same person.
    private func adoptOrphanedData(to newId: String) {
        let orphanedTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId != newId })
        )) ?? []
        let orphanedRecords = (try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId != newId })
        )) ?? []
        guard !orphanedTasks.isEmpty || !orphanedRecords.isEmpty else { return }

        let currentTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId == newId })
        )) ?? []
        let currentRecords = (try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId == newId })
        )) ?? []

        var existingTitles = Set(currentTasks.map(\.title))
        var nextOrderIndex = (currentTasks.map(\.orderIndex).max() ?? -1) + 1
        for task in orphanedTasks {
            if existingTitles.contains(task.title) {
                modelContext.delete(task)
            } else {
                task.userId = newId
                task.orderIndex = nextOrderIndex
                nextOrderIndex += 1
                existingTitles.insert(task.title)
            }
        }

        var recordsByDate = Dictionary(
            currentRecords.map { ($0.dateString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for record in orphanedRecords {
            if let existing = recordsByDate[record.dateString] {
                existing.allTaskTitles = merged(existing.allTaskTitles, record.allTaskTitles)
                existing.completedTaskTitles = merged(existing.completedTaskTitles, record.completedTaskTitles)
                existing.partiallyCompletedTaskTitles = merged(existing.partiallyCompletedTaskTitles, record.partiallyCompletedTaskTitles)
                modelContext.delete(record)
            } else {
                record.userId = newId
                recordsByDate[record.dateString] = record
            }
        }

        try? modelContext.save()
    }

    private func merged(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set(first)
        return first + second.filter { seen.insert($0).inserted }
    }
}
