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

    // Weighted ratio: completed tasks count full, partial tasks count half
    private var progressRatio: Double {
        guard let record, record.totalTaskCount > 0 else { return 0 }
        return Double(record.completedCount * 2 + record.partialCount) / Double(record.totalTaskCount * 2)
    }

    // Traffic-light stops: red (low) → orange (mid) → green (high)
    private var progressColor: Color {
        switch progressRatio {
        case ..<0.4:  return .red
        case 0.4..<0.75: return .orange
        default:      return .green
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color.clear

                switch dayCompletion {
                case .complete:
                    Circle()
                        .fill(Color.green.opacity(0.28))
                        .padding(2)
                case .partial:
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .padding(2)
                    Circle()
                        .trim(from: 0, to: progressRatio)
                        .stroke(progressColor.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(4)
                case .missed:
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
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
        switch dayCompletion {
        case .complete: return isToday ? .white : .primary
        case .partial, .missed: return .primary
        case .none: return isToday ? .white : .primary
        }
    }

    private var accessibilityLabel: String {
        guard
            let date = DateFormatter.dayFormatter.date(from: dateString)
        else { return dateString }
        let dateLabel = date.formatted(.dateTime.month(.wide).day().year())
        switch dayCompletion {
        case .complete: return "\(dateLabel), all tasks complete"
        case .partial:  return "\(dateLabel), \(Int(progressRatio * 100))% complete"
        case .missed:   return "\(dateLabel), no tasks completed"
        case .none:     return dateLabel
        }
    }
}
