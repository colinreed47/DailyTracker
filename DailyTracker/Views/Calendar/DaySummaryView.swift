import SwiftUI
import SwiftData

struct DaySummaryView: View {
    let dateString: String
    let record: DayRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.orderIndex) private var taskItems: [TaskItem]
    @State private var createdRecord: DayRecord? = nil

    private var activeRecord: DayRecord? { record ?? createdRecord }

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
                if let active = activeRecord, active.totalTaskCount > 0 {
                    summaryList(record: active)
                } else if isPastOrToday && !taskItems.isEmpty {
                    emptyEditableDay()
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
                        EditButton()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func summaryList(record: DayRecord) -> some View {
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

            if isPastOrToday {
                Section {
                    Text("Tap a task to cycle its completion status.")
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
                        taskRow(title: title, icon: "checkmark.circle.fill", color: .green, record: record)
                    }
                    .onDelete { offsets in
                        removeFromCompleted(at: offsets, record: record)
                    }
                }
            }

            if !partialTitles.isEmpty {
                Section("Partial") {
                    ForEach(partialTitles, id: \.self) { title in
                        taskRow(title: title, icon: "circle.lefthalf.filled", color: .orange, record: record)
                    }
                    .onDelete { offsets in
                        removeFromPartial(at: offsets, record: record)
                    }
                }
            }

            if !incompleteTitles.isEmpty {
                Section("Not Completed") {
                    ForEach(incompleteTitles, id: \.self) { title in
                        taskRow(title: title, icon: "circle", color: .secondary, record: record)
                    }
                    .onDelete { offsets in
                        removeFromIncomplete(offsets, titles: incompleteTitles, record: record)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func taskRow(title: String, icon: String, color: Color, record: DayRecord) -> some View {
        if isPastOrToday {
            Button {
                cycleTaskTitle(title, in: record)
            } label: {
                Label(title, systemImage: icon)
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
        } else {
            Label(title, systemImage: icon)
                .foregroundStyle(color == .secondary ? Color.secondary : Color.primary)
        }
    }

    @ViewBuilder
    private func emptyEditableDay() -> some View {
        List {
            Section {
                Text("Tap a task to cycle its completion status.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Not Completed") {
                ForEach(taskItems) { task in
                    Button {
                        let newRecord = makeRecord()
                        cycleTaskTitle(task.title, in: newRecord)
                    } label: {
                        Label(task.title, systemImage: "circle")
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func makeRecord() -> DayRecord {
        if let existing = try? modelContext.fetch(
            FetchDescriptor<DayRecord>(predicate: #Predicate { $0.dateString == dateString })
        ).first {
            createdRecord = existing
            return existing
        }
        let newRecord = DayRecord(
            dateString: dateString,
            allTaskTitles: taskItems.map { $0.title },
            completedTaskTitles: []
        )
        modelContext.insert(newRecord)
        createdRecord = newRecord
        return newRecord
    }

    // MARK: - Mutations

    private func cycleTaskTitle(_ title: String, in record: DayRecord) {
        if record.completedTaskTitles.contains(title) {
            record.completedTaskTitles.removeAll { $0 == title }
        } else if record.partiallyCompletedTaskTitles.contains(title) {
            record.partiallyCompletedTaskTitles.removeAll { $0 == title }
            record.completedTaskTitles.append(title)
        } else {
            record.partiallyCompletedTaskTitles.append(title)
        }
        save(record)
    }

    private func removeFromCompleted(at offsets: IndexSet, record: DayRecord) {
        let titles = offsets.map { record.completedTaskTitles[$0] }
        record.completedTaskTitles.remove(atOffsets: offsets)
        record.allTaskTitles.removeAll { titles.contains($0) }
        save(record)
    }

    private func removeFromPartial(at offsets: IndexSet, record: DayRecord) {
        let titles = offsets.map { record.partiallyCompletedTaskTitles[$0] }
        record.partiallyCompletedTaskTitles.remove(atOffsets: offsets)
        record.allTaskTitles.removeAll { titles.contains($0) }
        save(record)
    }

    private func removeFromIncomplete(_ offsets: IndexSet, titles incompleteTitles: [String], record: DayRecord) {
        let toRemove = offsets.map { incompleteTitles[$0] }
        record.allTaskTitles.removeAll { toRemove.contains($0) }
        save(record)
    }

    private func save(_ record: DayRecord) {
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
