import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var dayRecords: [DayRecord]

    @State private var currentMonth: Date = Date()
    @State private var selectedDayString: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthNavigator
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                weekdayHeader
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                Divider()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(calendarDays, id: \.self) { dayString in
                            if dayString.isEmpty {
                                Color.clear.aspectRatio(1, contentMode: .fill)
                            } else {
                                DayCell(
                                    dateString: dayString,
                                    record: record(for: dayString)
                                ) {
                                    selectedDayString = dayString
                                }
                            }
                        }
                    }
                    .padding()
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

    // MARK: - Header Views

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonth = Calendar.current.date(
                        byAdding: .month, value: -1, to: currentMonth
                    ) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(currentMonth, format: .dateTime.month(.wide).year())
                .font(.title2.weight(.bold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonth = Calendar.current.date(
                        byAdding: .month, value: 1, to: currentMonth
                    ) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Logic

    private var calendarDays: [String] {
        let calendar = Calendar.current
        guard
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: currentMonth)
            ),
            let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        var days: [String] = Array(repeating: "", count: firstWeekday)

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            days.append(DateFormatter.dayFormatter.string(from: date))
        }

        return days
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
