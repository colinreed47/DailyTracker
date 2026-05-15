import SwiftUI
import SwiftData

@main
struct DailyTrackerApp: App {
    @State private var supabaseManager = SupabaseManager.shared
    let sharedModelContainer: ModelContainer = SharedDataStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(supabaseManager)
                .task {
                    await supabaseManager.signInIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
