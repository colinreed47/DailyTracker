import SwiftUI
import SwiftData

struct ContentView: View {
    let userId: String

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DayRecord> { $0.userId == "" }) private var legacyRecords: [DayRecord]
    @Query(filter: #Predicate<TaskItem> { $0.userId == "" }) private var legacyTasks: [TaskItem]

    var body: some View {
        TabView {
            TasksView(userId: userId)
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }

            CalendarView(userId: userId)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .onChange(of: userId) { _, newId in
            guard !newId.isEmpty else { return }
            for record in legacyRecords { record.userId = newId }
            for task in legacyTasks { task.userId = newId }
            try? modelContext.save()
        }
    }
}
