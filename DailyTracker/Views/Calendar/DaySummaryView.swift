import SwiftUI

struct DaySummaryView: View {
    let dateString: String
    let record: DayRecord?

    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        guard let date = DateFormatter.dayFormatter.date(from: dateString) else { return dateString }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let record, record.totalTaskCount > 0 {
                    summaryList(record: record)
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No task data was recorded for this day.")
                    )
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func summaryList(record: DayRecord) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(record.completedCount) of \(record.totalTaskCount) tasks completed")
                            .font(.headline)
                        Spacer()
                        Text(percentLabel(record.completionRatio))
                            .font(.headline)
                            .foregroundStyle(statusColor(record.completionRatio))
                    }
                    ProgressView(value: record.completionRatio)
                        .tint(statusColor(record.completionRatio))
                }
                .padding(.vertical, 4)
            }

            if !record.completedTaskTitles.isEmpty {
                Section("Completed") {
                    ForEach(record.completedTaskTitles, id: \.self) { title in
                        Label(title, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.primary)
                    }
                }
            }

            let incomplete = record.allTaskTitles.filter { !record.completedTaskTitles.contains($0) }
            if !incomplete.isEmpty {
                Section("Not Completed") {
                    ForEach(incomplete, id: \.self) { title in
                        Label(title, systemImage: "circle")
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func percentLabel(_ ratio: Double) -> String {
        "\(Int(ratio * 100))%"
    }

    private func statusColor(_ ratio: Double) -> Color {
        if ratio == 1.0 { return .green }
        if ratio > 0 { return .yellow }
        return .red
    }
}
