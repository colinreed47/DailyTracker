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
    @State private var taskToEdit: TaskItem? = nil
    @State private var showingFriends = false

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
                            .swipeActions(edge: .leading) {
                                Button {
                                    taskToEdit = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") {
                                    taskToEdit = task
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                                        deleteTasks(at: IndexSet([index]))
                                    }
                                }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFriends = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
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
            .sheet(isPresented: $showingFriends) {
                FriendsView()
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView { title in
                    addTask(title: title)
                }
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(currentTitle: task.title) { newTitle in
                    renameTask(task, to: newTitle)
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
        let lastReset = SharedDataStore.sharedDefaults.string(forKey: "lastResetDate")

        if lastReset == nil {
            SharedDataStore.sharedDefaults.set(today, forKey: "lastResetDate")
            saveRecord(from: tasks)
            return
        }

        guard lastReset != today else { return }

        for task in tasks {
            task.isCompleted = false
            task.isPartial = false
        }
        SharedDataStore.sharedDefaults.set(today, forKey: "lastResetDate")
        try? modelContext.save()
        saveRecord(from: tasks)
    }

    // MARK: - Task Actions

    private func toggleTask(_ task: TaskItem) {
        if !task.isPartial && !task.isCompleted {
            task.isPartial = true
        } else if task.isPartial {
            task.isPartial = false
            task.isCompleted = true
        } else {
            task.isCompleted = false
        }
        try? modelContext.save()
        saveRecord(from: tasks)
        WidgetCenter.shared.reloadAllTimelines()

        Task { await SupabaseManager.shared.upsertTask(task) }

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

    private func renameTask(_ task: TaskItem, to newTitle: String) {
        task.title = newTitle
        try? modelContext.save()
        saveRecord(from: tasks)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await SupabaseManager.shared.upsertTask(task) }
    }

    private func addTask(title: String) {
        let task = TaskItem(title: title, orderIndex: tasks.count)
        modelContext.insert(task)
        try? modelContext.save()
        saveRecord(from: tasks + [task])
        WidgetCenter.shared.reloadAllTimelines()

        Task { await SupabaseManager.shared.upsertTask(task) }
    }

    private func deleteTasks(at offsets: IndexSet) {
        var remaining = tasks
        let deletedIds = offsets.map { tasks[$0].id }
        for index in offsets.sorted(by: >) {
            modelContext.delete(tasks[index])
            remaining.remove(at: index)
        }
        try? modelContext.save()
        saveRecord(from: remaining)
        WidgetCenter.shared.reloadAllTimelines()

        for id in deletedIds {
            Task { await SupabaseManager.shared.deleteTask(id: id) }
        }
    }

    // MARK: - Persistence

    private func saveRecord(from taskList: [TaskItem]) {
        let today = todayString
        let allTitles = taskList.map { $0.title }
        let completedTitles = taskList.filter { $0.isCompleted }.map { $0.title }
        let partialTitles = taskList.filter { $0.isPartial }.map { $0.title }

        let record: DayRecord
        if let existing = dayRecords.first(where: { $0.dateString == today }) {
            existing.allTaskTitles = allTitles
            existing.completedTaskTitles = completedTitles
            existing.partiallyCompletedTaskTitles = partialTitles
            record = existing
        } else {
            record = DayRecord(
                dateString: today,
                allTaskTitles: allTitles,
                completedTaskTitles: completedTitles,
                partiallyCompletedTaskTitles: partialTitles
            )
            modelContext.insert(record)
        }
        try? modelContext.save()

        Task { await SupabaseManager.shared.upsertDayRecord(record) }
    }
}
