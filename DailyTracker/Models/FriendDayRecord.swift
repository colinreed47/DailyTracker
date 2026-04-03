import Foundation

struct FriendDayRecord: Decodable {
    let dateString: String
    let totalCount: Int
    let completedCount: Int
    let partialCount: Int

    var completionRatio: Double {
        guard totalCount > 0 else { return 0 }
        return (Double(completedCount) + Double(partialCount) * 0.5) / Double(totalCount)
    }

    enum CodingKeys: String, CodingKey {
        case dateString = "date_string"
        case totalCount = "total_count"
        case completedCount = "completed_count"
        case partialCount = "partial_count"
    }
}
