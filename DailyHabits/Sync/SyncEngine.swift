import SwiftData
import WidgetKit
import Supabase
import Foundation

@MainActor
@Observable
final class SyncEngine {
    static let shared = SyncEngine()

    private(set) var isSyncing = false

    private init() {}

    // MARK: - Public Interface

    func syncOnForeground(modelContext: ModelContext) {
        guard !isSyncing else { return }
        Task {
            isSyncing = true
            defer { isSyncing = false }
            await push(modelContext: modelContext)
            await pull(modelContext: modelContext)
        }
    }

    // MARK: - Push

    private func push(modelContext: ModelContext) async {
        guard let session = try? await SupabaseManager.client.auth.session else { return }
        let userID = session.user.id

        let pendingIDs     = SharedDataStore.pendingSyncIDs
        let pendingDeletes = SharedDataStore.pendingDeleteIDs
        guard !pendingIDs.isEmpty || !pendingDeletes.isEmpty else { return }

        do {
            // Upsert mutated tasks
            let tasks = (try? modelContext.fetch(FetchDescriptor<TaskItem>())) ?? []
            let taskPayloads = tasks
                .filter { pendingIDs.contains($0.id.uuidString) }
                .map { TaskItemPayload(task: $0, userID: userID) }

            if !taskPayloads.isEmpty {
                try await SupabaseManager.client
                    .from("task_items")
                    .upsert(taskPayloads)
                    .execute()
                SharedDataStore.clearPending(ids: taskPayloads.map(\.id))
            }

            // Upsert mutated day records
            let records = (try? modelContext.fetch(FetchDescriptor<DayRecord>())) ?? []
            let recordPayloads = records
                .filter { pendingIDs.contains($0.id.uuidString) }
                .map { DayRecordPayload(record: $0, userID: userID) }

            if !recordPayloads.isEmpty {
                try await SupabaseManager.client
                    .from("day_records")
                    .upsert(recordPayloads, onConflict: "user_id,date_string")
                    .execute()
                SharedDataStore.clearPending(ids: recordPayloads.map(\.id))
            }

            // Delete remotely — one request for the whole set
            if !pendingDeletes.isEmpty {
                try await SupabaseManager.client
                    .from("task_items")
                    .delete()
                    .in("id", values: Array(pendingDeletes))
                    .execute()
                SharedDataStore.clearPendingDeletes(ids: pendingDeletes.compactMap { UUID(uuidString: $0) })
            }
        } catch {
            // Leave items in the pending sets — they will retry on next foreground.
        }
    }

    // MARK: - Pull

    private func pull(modelContext: ModelContext) async {
        guard (try? await SupabaseManager.client.auth.session) != nil else { return }

        do {
            // RLS ensures we only receive rows belonging to the authenticated user.
            let remoteTasks: [TaskItemPayload] = try await SupabaseManager.client
                .from("task_items")
                .select()
                .execute()
                .value

            let remoteRecords: [DayRecordPayload] = try await SupabaseManager.client
                .from("day_records")
                .select()
                .execute()
                .value

            mergeTaskItems(remote: remoteTasks, into: modelContext)
            mergeDayRecords(remote: remoteRecords, into: modelContext)
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Sync failed; will retry on next foreground.
        }
    }

    // MARK: - Merge

    private func mergeTaskItems(remote: [TaskItemPayload], into context: ModelContext) {
        let local      = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let pendingIDs = SharedDataStore.pendingSyncIDs

        for payload in remote {
            if let existing = local.first(where: { $0.id == payload.id }) {
                guard existing.updatedAt < payload.updatedAt else { continue }
                existing.title       = payload.title
                existing.isCompleted = payload.isCompleted
                existing.orderIndex  = payload.orderIndex
                existing.updatedAt   = payload.updatedAt
            } else {
                context.insert(TaskItem(from: payload))
            }
        }

        // Delete local tasks that no longer exist remotely (deleted on another device),
        // but only if they are not pending an upload from this device.
        let remoteIDs = Set(remote.map(\.id))
        for task in local where !remoteIDs.contains(task.id) && !pendingIDs.contains(task.id.uuidString) {
            context.delete(task)
        }
    }

    private func mergeDayRecords(remote: [DayRecordPayload], into context: ModelContext) {
        let local = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []

        for payload in remote {
            if let existing = local.first(where: { $0.id == payload.id }) {
                guard existing.updatedAt < payload.updatedAt else { continue }
                existing.allTaskTitles       = payload.allTaskTitles
                existing.completedTaskTitles = payload.completedTaskTitles
                existing.updatedAt           = payload.updatedAt
            } else {
                context.insert(DayRecord(from: payload))
            }
        }
    }
}
