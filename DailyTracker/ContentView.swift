import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    let userId: String
    /// True only when `userId` is backed by a real Supabase session (see
    /// SupabaseManager.isAuthenticated). Adoption and cloud restore must not
    /// run against a merely-cached identity — if the cache and the eventual
    /// session ever disagreed, that would silently mix two accounts' data.
    let isAuthenticated: Bool

    @Environment(\.modelContext) private var modelContext

    private struct SyncKey: Equatable {
        let userId: String
        let isAuthenticated: Bool
    }

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
        .task(id: SyncKey(userId: userId, isAuthenticated: isAuthenticated)) {
            guard isAuthenticated, !userId.isEmpty else { return }
            adoptOrphanedData(to: userId)
            await restoreFromCloudIfNeeded()
        }
    }

    // MARK: - Cloud Restore

    /// Pulls this user's tasks and history down from Supabase. Runs after an
    /// account recovery, or when the local store has nothing for this user
    /// (fresh install / new device). The cloud is otherwise write-only, so
    /// without this there is no way to get server-side data back.
    private func restoreFromCloudIfNeeded() async {
        let defaults = SharedDataStore.sharedDefaults
        let uid = userId
        let flagged = defaults.bool(forKey: "needsCloudRestore")
        // Per-user marker so a genuinely-empty account doesn't hit the
        // network on every single launch forever — but a pending recovery
        // (`flagged`) always overrides it and forces a fresh attempt.
        let checkedKey = "cloudRestoreChecked-\(uid)"
        guard flagged || !defaults.bool(forKey: checkedKey) else { return }

        let localTaskCount = (try? modelContext.fetchCount(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId == uid })
        )) ?? 0
        let localRecordCount = (try? modelContext.fetchCount(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId == uid })
        )) ?? 0
        guard flagged || (localTaskCount == 0 && localRecordCount == 0) else {
            defaults.set(true, forKey: checkedKey)
            return
        }

        let remoteTasks: [TaskItemRow]
        let remoteRecords: [DayRecordRow]
        do {
            async let tasksFetch = SupabaseManager.shared.fetchRemoteTasks()
            async let recordsFetch = SupabaseManager.shared.fetchRemoteDayRecords()
            (remoteTasks, remoteRecords) = try await (tasksFetch, recordsFetch)
        } catch {
            // Don't touch either flag: a network failure should be retried
            // on the next launch, not treated as "there's nothing to restore".
            print("[Restore] fetch failed, will retry: \(error)")
            return
        }

        defaults.set(false, forKey: "needsCloudRestore")
        defaults.set(true, forKey: checkedKey)
        guard !remoteTasks.isEmpty || !remoteRecords.isEmpty else { return }

        let localTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId == uid })
        )) ?? []
        let localRecords = (try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId == uid })
        )) ?? []

        var existingTaskIds = Set(localTasks.map(\.id))
        var existingTitles = Set(localTasks.map(\.title))
        var nextOrderIndex = (localTasks.map(\.orderIndex).max() ?? -1) + 1
        for remote in remoteTasks {
            guard !existingTaskIds.contains(remote.id),
                  !existingTitles.contains(remote.title) else { continue }
            let task = TaskItem(title: remote.title, orderIndex: nextOrderIndex, userId: uid)
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
                mergeTitles(
                    into: existing,
                    all: remote.allTaskTitles,
                    completed: remote.completedTaskTitles,
                    partial: remote.partiallyCompletedTaskTitles
                )
                // Adopt the server's id for this date: `existing` was created
                // locally (e.g. while offline) and never synced, so its id
                // has no row on the server. Taking over remote.id makes the
                // next upsert an unambiguous PK match instead of an INSERT
                // that would violate the unique (user_id, date_string)
                // constraint against the row we just merged in.
                existing.id = remote.id
            } else {
                let record = DayRecord(
                    dateString: remote.dateString,
                    allTaskTitles: remote.allTaskTitles,
                    completedTaskTitles: remote.completedTaskTitles,
                    partiallyCompletedTaskTitles: remote.partiallyCompletedTaskTitles,
                    userId: uid
                )
                record.id = remote.id
                modelContext.insert(record)
                recordsByDate[remote.dateString] = record
            }
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Orphan Adoption

    /// Rebinds records stored under a stale identity to the current user.
    /// Covers both pre-auth legacy data (userId == "") and data orphaned when
    /// a failed session restore minted a fresh anonymous user. The app is
    /// single-user per device, so any non-matching userId is a past identity
    /// of the same person.
    private func adoptOrphanedData(to newId: String) {
        let orphanTaskCount = (try? modelContext.fetchCount(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId != newId })
        )) ?? 0
        let orphanRecordCount = (try? modelContext.fetchCount(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId != newId })
        )) ?? 0
        guard orphanTaskCount > 0 || orphanRecordCount > 0 else { return }

        // Sorted so re-numbering below preserves the orphaned list's relative
        // order instead of scrambling it into fetch-order.
        let orphanedTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.userId != newId },
                sortBy: [SortDescriptor(\.orderIndex)]
            )
        )) ?? []
        let orphanedRecords = (try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId != newId })
        )) ?? []

        let currentTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.userId == newId })
        )) ?? []
        let currentRecords = (try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.userId == newId })
        )) ?? []

        var tasksByTitle = Dictionary(
            currentTasks.map { ($0.title, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var nextOrderIndex = (currentTasks.map(\.orderIndex).max() ?? -1) + 1
        for task in orphanedTasks {
            if let existing = tasksByTitle[task.title] {
                // Same-titled task already exists under the current
                // identity. Keep whichever copy has more progress instead of
                // always discarding the orphan, so an in-progress task never
                // silently reverts to unstarted.
                if progress(of: task) > progress(of: existing) {
                    existing.isCompleted = task.isCompleted
                    existing.isPartial = task.isPartial
                }
                modelContext.delete(task)
            } else {
                task.userId = newId
                // A fresh id: this task's old id may already be a synced row
                // owned by the now-unreachable prior identity, and reusing it
                // would make every future upsert collide with that row
                // (RLS-blocked) instead of creating this account's own.
                task.id = UUID()
                task.orderIndex = nextOrderIndex
                nextOrderIndex += 1
                tasksByTitle[task.title] = task
            }
        }

        var recordsByDate = Dictionary(
            currentRecords.map { ($0.dateString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for record in orphanedRecords {
            if let existing = recordsByDate[record.dateString] {
                mergeTitles(
                    into: existing,
                    all: record.allTaskTitles,
                    completed: record.completedTaskTitles,
                    partial: record.partiallyCompletedTaskTitles
                )
                modelContext.delete(record)
            } else {
                record.userId = newId
                record.id = UUID()
                recordsByDate[record.dateString] = record
            }
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Shared merge helpers

    private func progress(of task: TaskItem) -> Int {
        if task.isCompleted { return 2 }
        if task.isPartial { return 1 }
        return 0
    }

    private func mergeTitles(into record: DayRecord, all: [String], completed: [String], partial: [String]) {
        record.allTaskTitles = merged(record.allTaskTitles, all)
        record.completedTaskTitles = merged(record.completedTaskTitles, completed)
        record.partiallyCompletedTaskTitles = merged(record.partiallyCompletedTaskTitles, partial)
    }

    private func merged(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set(first)
        return first + second.filter { seen.insert($0).inserted }
    }
}
