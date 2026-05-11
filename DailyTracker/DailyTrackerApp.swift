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
                    let resolvedId = SupabaseManager.shared.userId?.uuidString ?? ""
                    SharedDataStore.sharedDefaults.set(resolvedId, forKey: "currentUserId")
                    userId = resolvedId
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
