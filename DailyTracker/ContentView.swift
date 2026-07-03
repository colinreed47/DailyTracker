import SwiftUI
import SwiftData
import WidgetKit

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
        .task(id: userId) {
            guard !userId.isEmpty else { return }
            adoptOrphanedData(to: userId)
            await restoreFromCloudIfNeeded()
        }
    }

    /// Pulls this user's tasks and history down from Supabase. Runs after an
    /// account recovery, or when the local store has nothing for this user
    /// (fresh install / new device). The cloud is otherwise write-only, so
    /// without this there is no way to get server-side data back.
    private func restoreFromCloudIfNeeded() async {
        let defaults = SharedDataStore.sharedDefaults
        let flagged = defaults.bool(forKey: "needsCloudRestore")
        let uid = userId

        let localTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId == uid })
        )) ?? []
        let localRecords = (try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId == uid })
        )) ?? []
        guard flagged || (localTasks.isEmpty && localRecords.isEmpty) else { return }

        let remoteTasks = await SupabaseManager.shared.fetchRemoteTasks()
        let remoteRecords = await SupabaseManager.shared.fetchRemoteDayRecords()
        defaults.set(false, forKey: "needsCloudRestore")
        guard !remoteTasks.isEmpty || !remoteRecords.isEmpty else { return }

        var existingTaskIds = Set(localTasks.map(\.id))
        var existingTitles = Set(localTasks.map(\.title))
        var nextOrderIndex = (localTasks.map(\.orderIndex).max() ?? -1) + 1
        for remote in remoteTasks {
            guard !existingTaskIds.contains(remote.id),
                  !existingTitles.contains(remote.title) else { continue }
            let task = TaskItem(title: remote.title, orderIndex: nextOrderIndex, userId: userId)
            task.id = remote.id
            task.isCompleted = remote.isCompleted
            task.isPartial = remote.isPartial
            task.createdAt = remote.createdAt
            modelContext.insert(task)
            existingTaskIds.insert(remote.id)
            existingTitles.insert(remote.title)
            nextOrderIndex += 1
        }

        var recordsByDate = Dictionary(
            localRecords.map { ($0.dateString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for remote in remoteRecords {
            if let existing = recordsByDate[remote.dateString] {
                existing.allTaskTitles = merged(existing.allTaskTitles, remote.allTaskTitles)
                existing.completedTaskTitles = merged(existing.completedTaskTitles, remote.completedTaskTitles)
                existing.partiallyCompletedTaskTitles = merged(existing.partiallyCompletedTaskTitles, remote.partiallyCompletedTaskTitles)
            } else {
                let record = DayRecord(
                    dateString: remote.dateString,
                    allTaskTitles: remote.allTaskTitles,
                    completedTaskTitles: remote.completedTaskTitles,
                    partiallyCompletedTaskTitles: remote.partiallyCompletedTaskTitles,
                    userId: userId
                )
                record.id = remote.id
                modelContext.insert(record)
                recordsByDate[remote.dateString] = record
            }
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
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
