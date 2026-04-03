import SwiftUI

struct FriendCalendarView: View {
    let friend: FriendEntry
    let vm: FriendsViewModel

    @State private var currentMonth: Date = Date()
    @State private var records: [FriendDayRecord] = []
    @State private var isLoading = false
    @State private var selectedDay: SelectedFriendDay? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                CalendarGridView(currentMonth: $currentMonth) { dayString in
                    let rec = record(for: dayString)
                    FriendDayCell(dateString: dayString, record: rec) {
                        if let r = rec {
                            selectedDay = SelectedFriendDay(dateString: dayString, record: r)
                        }
                    }
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(friend.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedDay) { day in
                FriendDaySummary(dateString: day.dateString, record: day.record)
            }
            .task {
                isLoading = true
                records = await vm.fetchFriendCalendar(userId: friend.userId)
                isLoading = false
            }
        }
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
                        .stroke(Color.red.opacity(isToday ? 1.0 : 0.5), lineWidth: 1.5)
                        .padding(2)
                case .none:
                    if isToday {
                        Circle().fill(Color.accentColor).padding(2)
                    }
                }
                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(dayCompletion == .missed ? .primary : (isToday ? .white : .primary))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let date = DateFormatter.dayFormatter.date(from: dateString) else { return dateString }
        let dateLabel = date.formatted(.dateTime.month(.wide).day().year())
        switch dayCompletion {
        case .complete: return "\(dateLabel), all tasks complete"
        case .partial:  return "\(dateLabel), partially complete"
        case .missed:   return "\(dateLabel), no tasks completed"
        case .none:     return dateLabel
        }
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

    private var statusIcon: String {
        if record.completionRatio == 1.0 { return "checkmark.circle.fill" }
        if record.completionRatio > 0 { return "circle.lefthalf.filled" }
        return "xmark.circle.fill"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(statusColor)
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
        .presentationDetents([.height(320)])
    }
}
