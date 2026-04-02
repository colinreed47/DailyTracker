import SwiftUI
import SwiftData

@main
struct DailyHabitsApp: App {
    let sharedModelContainer: ModelContainer = SharedDataStore.makeContainer()
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environment(authViewModel)
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
