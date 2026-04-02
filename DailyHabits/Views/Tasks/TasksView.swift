import SwiftUI
import SwiftData
import WidgetKit

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TaskItem.orderIndex) private var tasks: [TaskItem]
    @Query private var dayRecords: [DayRecord]

    @State private var showingAddTask = false
    @State private var showCelebration = false

    private var todayString: String { Date().dayString }

    var body: some View {
        ZStack {
            navigationContent

            if showCelebration {
                ConfettiView()

                Text("All done! 🎉")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    private var navigationContent: some View {
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
                    SyncEngine.shared.syncOnForeground(modelContext: modelContext)
                }
            }
        }
    }


    // MARK: - Day Reset

    private func performDayResetIfNeeded() {
        let today = todayString
        let lastReset = SharedDataStore.sharedDefaults.string(forKey: "lastResetDate")

        if lastReset == nil {
            SharedDataStore.sharedDefaults.set(today, forKey: "lastResetDate")
            saveRecord(from: tasks)
            return
        }

        guard lastReset != today else { return }

        for task in tasks {
            task.isCompleted = false
            task.updatedAt   = Date()
            SharedDataStore.markPending(id: task.id)
        }
        SharedDataStore.sharedDefaults.set(today, forKey: "lastResetDate")
        try? modelContext.save()
        saveRecord(from: tasks)
    }

    // MARK: - Task Actions

    private func toggleTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        task.updatedAt = Date()
        SharedDataStore.markPending(id: task.id)
        try? modelContext.save()
        saveRecord(from: tasks)
        WidgetCenter.shared.reloadAllTimelines()

        if tasks.allSatisfy(\.isCompleted) && !tasks.isEmpty {
            withAnimation(.spring()) {
                showCelebration = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showCelebration = false
                }
            }
        }
    }

    private func addTask(title: String) {
        let task = TaskItem(title: title, orderIndex: tasks.count)
        modelContext.insert(task)
        SharedDataStore.markPending(id: task.id)
        try? modelContext.save()
        saveRecord(from: tasks + [task])
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func deleteTasks(at offsets: IndexSet) {
        var remaining = tasks
        for index in offsets.sorted(by: >) {
            SharedDataStore.markPendingDelete(id: tasks[index].id)
            modelContext.delete(tasks[index])
            remaining.remove(at: index)
        }
        try? modelContext.save()
        saveRecord(from: remaining)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Persistence

    private func saveRecord(from taskList: [TaskItem]) {
        let today = todayString
        let allTitles       = taskList.map { $0.title }
        let completedTitles = taskList.filter { $0.isCompleted }.map { $0.title }

        if let existing = dayRecords.first(where: { $0.dateString == today }) {
            existing.allTaskTitles       = allTitles
            existing.completedTaskTitles = completedTitles
            existing.updatedAt           = Date()
            SharedDataStore.markPending(id: existing.id)
        } else {
            let record = DayRecord(
                dateString: today,
                allTaskTitles: allTitles,
                completedTaskTitles: completedTitles
            )
            modelContext.insert(record)
            SharedDataStore.markPending(id: record.id)
        }
        try? modelContext.save()
    }
}
