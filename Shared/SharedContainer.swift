import SwiftData
import Foundation

enum SharedDataStore {
    static let appGroupID = "group.com.colinreed.DailyTracker"

    static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, DayRecord.self])

        // Use the App Group container so the widget shares the same store
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent("DailyTracker.store")
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
}
