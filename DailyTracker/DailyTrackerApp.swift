import SwiftUI
import SwiftData

@main
struct DailyTrackerApp: App {
    let sharedModelContainer: ModelContainer = SharedDataStore.makeContainer()
    @State private var userId: String = ""

    var body: some Scene {
        WindowGroup {
            ContentView(userId: userId)
                .task {
                    await SupabaseManager.shared.signInIfNeeded()
                    if let resolvedId = SupabaseManager.shared.userId?.uuidString {
                        SharedDataStore.sharedDefaults.set(resolvedId, forKey: "currentUserId")
                        userId = resolvedId
                    } else if let cached = SharedDataStore.sharedDefaults.string(forKey: "currentUserId"),
                              !cached.isEmpty {
                        // Auth unavailable (e.g. offline first launch after reboot):
                        // keep showing the data for the last known user.
                        userId = cached
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
