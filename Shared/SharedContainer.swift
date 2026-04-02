import SwiftData
import Foundation

enum SharedDataStore {
    static let appGroupID = "group.com.colinreed.DailyHabits"

    /// UserDefaults accessible by both the app and the widget extension.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, DayRecord.self])

        // Use the App Group container so the widget shares the same store
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent("DailyHabits.store")
            if let container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            ) {
                return container
            }
        }

        // Fallback: App Group not provisioned yet (e.g. first Xcode run)
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
    }

    // MARK: - Pending Sync Tracking

    private static let pendingSyncKey  = "pendingSyncIDs"
    private static let pendingDeleteKey = "pendingDeleteIDs"

    /// IDs of local objects that have been mutated and need to be upserted to Supabase.
    static var pendingSyncIDs: Set<String> {
        get { Set((sharedDefaults.array(forKey: pendingSyncKey) as? [String]) ?? []) }
        set { sharedDefaults.set(Array(newValue), forKey: pendingSyncKey) }
    }

    /// IDs of tasks that have been deleted locally and need to be deleted from Supabase.
    static var pendingDeleteIDs: Set<String> {
        get { Set((sharedDefaults.array(forKey: pendingDeleteKey) as? [String]) ?? []) }
        set { sharedDefaults.set(Array(newValue), forKey: pendingDeleteKey) }
    }

    static func markPending(id: UUID) {
        pendingSyncIDs.insert(id.uuidString)
    }

    static func markPendingDelete(id: UUID) {
        pendingDeleteIDs.insert(id.uuidString)
        pendingSyncIDs.remove(id.uuidString)   // no point upserting a deleted row
    }

    static func clearPending(ids: [UUID]) {
        var current = pendingSyncIDs
        ids.forEach { current.remove($0.uuidString) }
        pendingSyncIDs = current
    }

    static func clearPendingDeletes(ids: [UUID]) {
        var current = pendingDeleteIDs
        ids.forEach { current.remove($0.uuidString) }
        pendingDeleteIDs = current
    }
}
