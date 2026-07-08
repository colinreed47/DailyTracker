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

/// Bridges the observable auth state into the view tree: shows the
/// onboarding choice for a genuinely new install, a blank screen while
/// resolving, or the app once an identity (real or cached-offline) is set.
struct RootView: View {
    private let supabase = SupabaseManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSaveAccountPrompt = false

    var body: some View {
        Group {
            switch supabase.phase {
            case .resolving:
                Color.clear
            case .needsOnboarding:
                WelcomeView()
            case .ready:
                ContentView(userId: supabase.userId?.uuidString ?? "", isAuthenticated: supabase.isAuthenticated)
                    .task(id: supabase.userId) {
                        await maybeShowSaveAccountPrompt()
                    }
                    .sheet(isPresented: $showingSaveAccountPrompt) {
                        SaveAccountPromptView()
                    }
            }
        }
        .task {
            await supabase.signInIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // A session-load failure at launch (e.g. no network right after
            // a reboot) isn't permanent — retry whenever the app comes back
            // to the foreground until it succeeds.
            guard newPhase == .active, supabase.phase == .ready, !supabase.isAuthenticated else { return }
            Task { await supabase.signInIfNeeded() }
        }
    }

    /// Nudges anonymous users to save their account once they've had a
    /// chance to actually use the app (not on the very first launch), and
    /// again after a cooldown if they dismiss it — until it's done or they
    /// stop seeing the app at all being enough of a reason to stop asking.
    private func maybeShowSaveAccountPrompt() async {
        guard supabase.isAuthenticated, supabase.linkedEmail == nil else { return }
        let defaults = SharedDataStore.sharedDefaults

        let firstSeenKey = "firstLaunchDate"
        let now = Date()
        guard let firstSeen = defaults.object(forKey: firstSeenKey) as? Date else {
            defaults.set(now, forKey: firstSeenKey)
            return
        }
        guard now.timeIntervalSince(firstSeen) > 60 * 60 * 24 else { return }

        let dismissedKey = "saveAccountPromptDismissedAt"
        if let dismissedAt = defaults.object(forKey: dismissedKey) as? Date,
           now.timeIntervalSince(dismissedAt) < 60 * 60 * 24 * 3 {
            return
        }

        showingSaveAccountPrompt = true
    }
}
