import SwiftUI
import SwiftData

@main
struct DailyTrackerApp: App {
    let sharedModelContainer: ModelContainer = SharedDataStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
