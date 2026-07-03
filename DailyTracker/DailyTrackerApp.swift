import SwiftUI
import SwiftData

@main
struct DailyTrackerApp: App {
    let sharedModelContainer: ModelContainer = SharedDataStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Bridges the observable auth state into the view tree so the UI re-queries
/// whenever the signed-in user changes (initial sign-in or account recovery).
struct RootView: View {
    private let supabase = SupabaseManager.shared

    /// Last known user, so the app keeps showing data when auth is
    /// temporarily unavailable (e.g. offline right after a reboot).
    @State private var fallbackUserId: String =
        SharedDataStore.sharedDefaults.string(forKey: "currentUserId") ?? ""

    var body: some View {
        ContentView(userId: supabase.userId?.uuidString ?? fallbackUserId)
            .task {
                await supabase.signInIfNeeded()
            }
            .onChange(of: supabase.userId) { _, newId in
                guard let newId else { return }
                SharedDataStore.sharedDefaults.set(newId.uuidString, forKey: "currentUserId")
                fallbackUserId = newId.uuidString
            }
    }
}
