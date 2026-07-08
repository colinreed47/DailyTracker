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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ContentView(userId: supabase.userId?.uuidString ?? "", isAuthenticated: supabase.isAuthenticated)
            .task {
                await supabase.signInIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // A session-load failure at launch (e.g. no network right
                // after a reboot) isn't permanent — retry whenever the app
                // comes back to the foreground until it succeeds.
                guard newPhase == .active, !supabase.isAuthenticated else { return }
                Task { await supabase.signInIfNeeded() }
            }
    }
}
