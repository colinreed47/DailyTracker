import SwiftUI

struct DayCell: View {
    let dateString: String
    let record: DayRecord?
    let onTap: () -> Void

    private var dayNumber: String {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[2]) else { return "" }
        return "\(day)"
    }

    private var isToday: Bool {
        dateString == Date().dayString
    }

    private var isPastOrToday: Bool {
        dateString <= Date().dayString
    }

    private enum DayCompletion {
        case complete, partial, missed, none
    }

    private var dayCompletion: DayCompletion {
        guard let record, record.totalTaskCount > 0 else { return .none }
        if record.completedCount == record.totalTaskCount { return .complete }
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
                    // Stroke-only ring so colorblind users can distinguish from filled complete
                    Circle()
                        .stroke(Color.red.opacity(isToday ? 1.0 : 0.5), lineWidth: 1.5)
                        .padding(2)
                case .none:
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .padding(2)
                    }
                }

                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(textColor)
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

    private var textColor: Color {
        // Missed uses stroke (no fill), so text stays primary regardless of today status
        if dayCompletion == .missed { return .primary }
        return isToday ? .white : .primary
    }

    private var accessibilityLabel: String {
        guard
            let date = DateFormatter.dayFormatter.date(from: dateString)
        else { return dateString }
        let dateLabel = date.formatted(.dateTime.month(.wide).day().year())
        switch dayCompletion {
        case .complete: return "\(dateLabel), all tasks complete"
        case .partial:  return "\(dateLabel), partially complete"
        case .missed:   return "\(dateLabel), no tasks completed"
        case .none:     return dateLabel
        }
    }
}
