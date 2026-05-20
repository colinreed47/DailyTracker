import SwiftData
import Foundation

enum SharedDataStore {
    static let appGroupID = "group.com.colinreed.DailyTracker"

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
            let storeURL = groupURL.appendingPathComponent("DailyTracker.store")
            let config = ModelConfiguration(schema: schema, url: storeURL)
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }

            // Migration failed (e.g. schema added non-optional fields without a migration plan).
            // Delete the old store so the next open starts clean. Local data will re-sync from Supabase.
            let fm = FileManager.default
            for ext in ["", "-shm", "-wal"] {
                let url = groupURL.appendingPathComponent("DailyTracker.store\(ext)")
                try? fm.removeItem(at: url)
            }
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }
        }

        // Fallback: App Group not provisioned yet (e.g. first Xcode run)
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
    }
}
