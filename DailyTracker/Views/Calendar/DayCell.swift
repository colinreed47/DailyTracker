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
                    partialCircle
                        .padding(2)
                case .missed:
                    Circle()
                        .fill(Color.red.opacity(isToday ? 1.0 : 0.28))
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
    }

    // Left half orange, right half gray — indicates partial completion
    private var partialCircle: some View {
        let opacity = isToday ? 1.0 : 0.35
        return HStack(spacing: 0) {
            Color.orange.opacity(opacity)
            Color.gray.opacity(opacity * 0.4)
        }
        .clipShape(Circle())
    }

    private var textColor: Color {
        isToday ? .white : .primary
    }
}
