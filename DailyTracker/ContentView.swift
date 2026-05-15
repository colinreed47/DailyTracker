import SwiftUI

struct ContentView: View {
    @Environment(SupabaseManager.self) private var supabaseManager

    var body: some View {
        TabView {
            TasksView(userId: supabaseManager.userIdString)
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }

            CalendarView(userId: supabaseManager.userIdString)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

        }
    }
}
