import Foundation
import SwiftData

@Model
final class DayRecord {
    var id: UUID
    /// Date stored as "yyyy-MM-dd" string for easy keying
    var dateString: String
    /// All task titles that existed this day (for showing incomplete tasks in summary)
    var allTaskTitles: [String]
    /// Titles of tasks that were fully completed
    var completedTaskTitles: [String]
    /// Titles of tasks that were partially completed
    var partiallyCompletedTaskTitles: [String]

    var totalTaskCount: Int { allTaskTitles.count }
    var completedCount: Int { completedTaskTitles.count }
    var partialCount: Int { partiallyCompletedTaskTitles.count }
    var completionRatio: Double {
        guard totalTaskCount > 0 else { return 0 }
        return (Double(completedCount) + Double(partialCount) * 0.5) / Double(totalTaskCount)
    }

    init(dateString: String, allTaskTitles: [String], completedTaskTitles: [String], partiallyCompletedTaskTitles: [String] = []) {
        self.id = UUID()
        self.dateString = dateString
        self.allTaskTitles = allTaskTitles
        self.completedTaskTitles = completedTaskTitles
        self.partiallyCompletedTaskTitles = partiallyCompletedTaskTitles
    }
}
