import SwiftUI

struct FriendCalendarView: View {
    let friend: FriendEntry
    let vm: FriendsViewModel

    @State private var currentMonth: Date = Date()
    @State private var records: [FriendDayRecord] = []
    @State private var selectedDay: SelectedFriendDay? = nil

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
                        ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, dayString in
                            if dayString.isEmpty {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            } else {
                                let rec = record(for: dayString)
                                FriendDayCell(dateString: dayString, record: rec) {
                                    if let r = rec {
                                        selectedDay = SelectedFriendDay(dateString: dayString, record: r)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(friend.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedDay) { day in
                FriendDaySummary(dateString: day.dateString, record: day.record)
            }
            .task {
                records = await vm.fetchFriendCalendar(userId: friend.userId)
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
                Image(systemName: "chevron.left").fontWeight(.semibold).frame(width: 44, height: 44)
            }
            Spacer()
            Text(currentMonth, format: .dateTime.month(.wide).year()).font(.title2.weight(.bold))
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right").fontWeight(.semibold).frame(width: 44, height: 44)
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarDays: [String] {
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

    private func record(for dateString: String) -> FriendDayRecord? {
        records.first { $0.dateString == dateString }
    }
}

// MARK: - Supporting types

struct SelectedFriendDay: Identifiable {
    let dateString: String
    let record: FriendDayRecord
    var id: String { dateString }
}

struct FriendDayCell: View {
    let dateString: String
    let record: FriendDayRecord?
    let onTap: () -> Void

    private var dayNumber: String {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[2]) else { return "" }
        return "\(day)"
    }

    private var isToday: Bool { dateString == Date().dayString }
    private var isPastOrToday: Bool { dateString <= Date().dayString }

    private enum DayCompletion { case complete, partial, missed, none }

    private var dayCompletion: DayCompletion {
        guard let record, record.totalCount > 0 else { return .none }
        if record.completedCount == record.totalCount { return .complete }
        if record.completedCount + record.partialCount > 0 { return .partial }
        if isPastOrToday { return .missed }
        return .none
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color.clear
                switch dayCompletion {
                case .complete:
                    Circle()
                        .fill(Color.green.opacity(isToday ? 1.0 : 0.28))
                        .padding(2)
                case .partial:
                    HStack(spacing: 0) {
                        Color.orange.opacity(isToday ? 1.0 : 0.35)
                        Color.gray.opacity(isToday ? 0.4 : 0.14)
                    }
                    .clipShape(Circle())
                    .padding(2)
                case .missed:
                    Circle()
                        .fill(Color.red.opacity(isToday ? 1.0 : 0.28))
                        .padding(2)
                case .none:
                    if isToday {
                        Circle().fill(Color.accentColor).padding(2)
                    }
                }
                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FriendDaySummary: View {
    let dateString: String
    let record: FriendDayRecord

    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        guard let date = DateFormatter.dayFormatter.date(from: dateString) else { return dateString }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }

    private var statusColor: Color {
        if record.completionRatio == 1.0 { return .green }
        if record.completionRatio > 0 { return .yellow }
        return .red
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Text("\(Int(record.completionRatio * 100))%")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                    Text("\(record.completedCount) of \(record.totalCount) tasks completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if record.partialCount > 0 {
                        Text("\(record.partialCount) partial")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                ProgressView(value: record.completionRatio)
                    .tint(statusColor)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
