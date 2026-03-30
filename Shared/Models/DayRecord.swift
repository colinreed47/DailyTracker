import Foundation
import SwiftData

@Model
final class DayRecord {
    var id: UUID
    /// Date stored as "yyyy-MM-dd" string for easy keying
    var dateString: String
    /// All task titles that existed this day (for showing incomplete tasks in summary)
    var allTaskTitles: [String]
    /// Titles of tasks that were completed
    var completedTaskTitles: [String]

    var totalTaskCount: Int { allTaskTitles.count }
    var completedCount: Int { completedTaskTitles.count }
    var completionRatio: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalTaskCount)
    }

    init(dateString: String, allTaskTitles: [String], completedTaskTitles: [String]) {
        self.id = UUID()
        self.dateString = dateString
        self.allTaskTitles = allTaskTitles
        self.completedTaskTitles = completedTaskTitles
    }
}
