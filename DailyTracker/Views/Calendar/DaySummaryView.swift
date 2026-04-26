import SwiftUI
import SwiftData

struct DaySummaryView: View {
    let dateString: String
    let record: DayRecord?

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    private var formattedDate: String {
        guard let date = DateFormatter.dayFormatter.date(from: dateString) else { return dateString }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }

    private var isPastOrToday: Bool {
        dateString <= Date().dayString
    }

    var body: some View {
        NavigationStack {
            Group {
                if let record, record.totalTaskCount > 0 {
                    SummaryListView(record: record, isPastOrToday: isPastOrToday, isEditing: isEditing)
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No task data was recorded for this day.")
                    )
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPastOrToday {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SummaryListView: View {
    let record: DayRecord
    let isPastOrToday: Bool
    let isEditing: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var taskToRename: String? = nil
    @State private var renameText = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.completedCount) of \(record.totalTaskCount) completed")
                                .font(.headline)
                            if record.partialCount > 0 {
                                Text("\(record.partialCount) partial")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Label(percentLabel(record.completionRatio), systemImage: statusIcon(record.completionRatio))
                            .font(.headline)
                            .foregroundStyle(statusColor(record.completionRatio))
                    }
                    ProgressView(value: record.completionRatio)
                        .tint(statusColor(record.completionRatio))
                }
                .padding(.vertical, 4)
            }

            if isPastOrToday && isEditing {
                Section {
                    Text("Tap the status icon to cycle completion. Tap the task name to rename it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let completedTitles = record.completedTaskTitles
            let partialTitles = record.partiallyCompletedTaskTitles
            let incompleteTitles = record.allTaskTitles.filter {
                !completedTitles.contains($0) && !partialTitles.contains($0)
            }

            if !completedTitles.isEmpty {
                Section("Completed") {
                    ForEach(completedTitles, id: \.self) { title in
                        taskRow(title: title, icon: "checkmark.circle.fill", color: .green)
                    }
                }
            }

            if !partialTitles.isEmpty {
                Section("Partial") {
                    ForEach(partialTitles, id: \.self) { title in
                        taskRow(title: title, icon: "circle.lefthalf.filled", color: .orange)
                    }
                }
            }

            if !incompleteTitles.isEmpty {
                Section("Not Completed") {
                    ForEach(incompleteTitles, id: \.self) { title in
                        taskRow(title: title, icon: "circle", color: .secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: Binding(get: { taskToRename != nil }, set: { if !$0 { taskToRename = nil } })) {
            if let title = taskToRename {
                RenameTaskView(currentTitle: title) { newTitle in
                    renameTask(from: title, to: newTitle)
                }
            }
        }
    }

    @ViewBuilder
    private func taskRow(title: String, icon: String, color: Color) -> some View {
        if isPastOrToday && isEditing {
            HStack(spacing: 12) {
                // Status icon — tap to cycle completion
                Button {
                    cycleTaskTitle(title)
                } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color == .secondary ? Color.secondary : color)
                }
                .buttonStyle(.plain)

                // Task name — tap to rename
                Button {
                    renameText = title
                    taskToRename = title
                } label: {
                    Text(title)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        } else {
            Label(title, systemImage: icon)
                .foregroundStyle(color == .secondary ? Color.secondary : Color.primary)
        }
    }

    // MARK: - Mutations

    private func cycleTaskTitle(_ title: String) {
        if record.completedTaskTitles.contains(title) {
            // complete → partial
            record.completedTaskTitles.removeAll { $0 == title }
            record.partiallyCompletedTaskTitles.append(title)
        } else if record.partiallyCompletedTaskTitles.contains(title) {
            // partial → incomplete
            record.partiallyCompletedTaskTitles.removeAll { $0 == title }
        } else {
            // incomplete → complete
            record.completedTaskTitles.append(title)
        }
        save()
    }

    private func renameTask(from oldTitle: String, to newTitle: String) {
        func replace(in array: inout [String]) {
            if let i = array.firstIndex(of: oldTitle) { array[i] = newTitle }
        }
        replace(in: &record.allTaskTitles)
        replace(in: &record.completedTaskTitles)
        replace(in: &record.partiallyCompletedTaskTitles)
        save()
    }

    private func save() {
        try? modelContext.save()
        Task { await SupabaseManager.shared.upsertDayRecord(record) }
    }

    private func percentLabel(_ ratio: Double) -> String {
        "\(Int(ratio * 100))%"
    }

    private func statusColor(_ ratio: Double) -> Color {
        if ratio == 1.0 { return .green }
        if ratio > 0 { return .yellow }
        return .red
    }

    private func statusIcon(_ ratio: Double) -> String {
        if ratio == 1.0 { return "checkmark.circle.fill" }
        if ratio > 0 { return "circle.lefthalf.filled" }
        return "xmark.circle.fill"
    }
}

// MARK: - Rename sheet

private struct RenameTaskView: View {
    let currentTitle: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task name", text: $title)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { submit() }
                }
            }
            .navigationTitle("Rename Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .disabled(trimmed.isEmpty || trimmed == currentTitle)
                }
            }
            .onAppear {
                title = currentTitle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isFocused = true
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func submit() {
        guard !trimmed.isEmpty, trimmed != currentTitle else { return }
        onSave(trimmed)
        dismiss()
    }
}

