import SwiftUI

/// Shared calendar grid used by both CalendarView (own data) and FriendCalendarView.
/// Provides month navigation, weekday header, and day grid layout.
/// The caller supplies the cell view for each date string via the `cell` closure.
struct CalendarGridView<Cell: View>: View {
    @Binding var currentMonth: Date
    @ViewBuilder let cell: (String) -> Cell

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
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
                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, dayString in
                        if dayString.isEmpty {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            cell(dayString)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(currentMonth, format: .dateTime.month(.wide).year())
                .font(.title2.weight(.bold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next month")
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

    var calendarDays: [String] {
        let calendar = Calendar.current
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
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
}
