import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TaskItem.orderIndex) private var tasks: [TaskItem]
    @Query private var dayRecords: [DayRecord]

    @State private var showingAddTask = false

    private var todayString: String { Date().dayString }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + to add your daily tasks.")
                    )
                } else {
                    List {
                        ForEach(tasks) { task in
                            TaskRowView(task: task) {
                                toggleTask(task)
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(.insetGrouped)
                    .animation(.default, value: tasks.map(\.isCompleted))
                }
            }
            .navigationTitle("Today's Tasks")
            .toolbar {
                if !tasks.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView { title in
                    addTask(title: title)
                }
            }
            .onAppear {
                performDayResetIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    performDayResetIfNeeded()
                }
            }
        }
    }

    // MARK: - Day Reset

    private func performDayResetIfNeeded() {
        let today = todayString
        let lastReset = UserDefaults.standard.string(forKey: "lastResetDate")

        if lastReset == nil {
            // First launch — initialize and record today
            UserDefaults.standard.set(today, forKey: "lastResetDate")
            saveRecord(from: tasks)
            return
        }

        guard lastReset != today else { return }

        // New day — uncheck all tasks, update the reset date
        for task in tasks {
            task.isCompleted = false
        }
        UserDefaults.standard.set(today, forKey: "lastResetDate")
        try? modelContext.save()
        saveRecord(from: tasks)
    }

    // MARK: - Task Actions

    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        try? modelContext.save()
        saveRecord(from: tasks)
    }

    private func addTask(title: String) {
        let task = TaskItem(title: title, orderIndex: tasks.count)
        modelContext.insert(task)
        try? modelContext.save()
        // Build the updated list manually so the record is accurate before @Query refreshes
        saveRecord(from: tasks + [task])
    }

    private func deleteTasks(at offsets: IndexSet) {
        var remaining = tasks
        for index in offsets.sorted(by: >) {
            modelContext.delete(tasks[index])
            remaining.remove(at: index)
        }
        try? modelContext.save()
        saveRecord(from: remaining)
    }

    // MARK: - Persistence

    private func saveRecord(from taskList: [TaskItem]) {
        let today = todayString
        let allTitles = taskList.map { $0.title }
        let completedTitles = taskList.filter { $0.isCompleted }.map { $0.title }

        if let existing = dayRecords.first(where: { $0.dateString == today }) {
            existing.allTaskTitles = allTitles
            existing.completedTaskTitles = completedTitles
        } else {
            let record = DayRecord(
                dateString: today,
                allTaskTitles: allTitles,
                completedTaskTitles: completedTitles
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }
}
