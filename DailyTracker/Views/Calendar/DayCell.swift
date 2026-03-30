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

    private var completionColor: Color? {
        guard let record, record.totalTaskCount > 0 else { return nil }
        let ratio = record.completionRatio
        if ratio == 1.0 { return .green }
        if ratio > 0 { return .yellow }
        if isPastOrToday { return .red }
        return nil
    }

    private var circleColor: Color? {
        if isToday { return completionColor ?? .accentColor }
        return completionColor
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Transparent base guarantees the cell fills its column
                Color.clear

                if let color = circleColor {
                    Circle()
                        .fill(isToday ? color : color.opacity(0.28))
                        .padding(2)
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
