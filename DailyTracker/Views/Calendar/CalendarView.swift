import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var dayRecords: [DayRecord]
    @Query private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext

    let userId: String

    @State private var currentMonth: Date = Date()
    @State private var selectedDayString: String? = nil

    init(userId: String) {
        self.userId = userId
        let uid = userId
        _dayRecords = Query(
            filter: #Predicate<DayRecord> { $0.userId == uid }
        )
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.userId == uid },
            sort: [SortDescriptor(\TaskItem.orderIndex)]
        )
    }

    private var currentTaskTitles: [String] { tasks.map(\.title) }

    var body: some View {
        NavigationStack {
            CalendarGridView(currentMonth: $currentMonth) { dayString in
                DayCell(
                    dateString: dayString,
                    record: record(for: dayString),
                    currentTaskCount: currentTaskTitles.count
                ) {
                    selectedDayString = dayString
                }
            }
            .navigationTitle("Calendar")
            .sheet(item: selectedDayBinding) { selected in
                DaySummaryView(
                    dateString: selected.dateString,
                    record: record(for: selected.dateString),
                    fallbackTaskTitles: currentTaskTitles
                )
            }
            .task {
                await syncDayRecords()
            }
        }
    }

    private func syncDayRecords() async {
        guard let rows = try? await SupabaseManager.shared.fetchDayRecords() else { return }
        let existingDates = Set(dayRecords.map(\.dateString))
        for row in rows where !existingDates.contains(row.dateString) {
            let record = DayRecord(
                userId: userId,
                dateString: row.dateString,
                allTaskTitles: row.allTaskTitles,
                completedTaskTitles: row.completedTaskTitles,
                partiallyCompletedTaskTitles: row.partiallyCompletedTaskTitles
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func record(for dateString: String) -> DayRecord? {
        dayRecords.first(where: { $0.dateString == dateString })
    }

    private var selectedDayBinding: Binding<SelectedDay?> {
        Binding(
            get: { selectedDayString.map(SelectedDay.init) },
            set: { selectedDayString = $0?.dateString }
        )
    }
}

struct SelectedDay: Identifiable {
    let dateString: String
    var id: String { dateString }
}
