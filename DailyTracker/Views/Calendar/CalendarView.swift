import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var dayRecords: [DayRecord]

    @State private var currentMonth: Date = Date()
    @State private var selectedDayString: String? = nil

    var body: some View {
        NavigationStack {
            CalendarGridView(currentMonth: $currentMonth) { dayString in
                DayCell(
                    dateString: dayString,
                    record: record(for: dayString)
                ) {
                    selectedDayString = dayString
                }
            }
            .navigationTitle("Calendar")
            .sheet(item: selectedDayBinding) { selected in
                DaySummaryView(
                    dateString: selected.dateString,
                    record: record(for: selected.dateString)
                )
            }
        }
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
