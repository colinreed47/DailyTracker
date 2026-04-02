import Foundation

// MARK: - TaskItem DTO

struct TaskItemPayload: Codable {
    var id: UUID
    var userId: UUID
    var title: String
    var isCompleted: Bool
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case title
        case isCompleted  = "is_completed"
        case orderIndex   = "order_index"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    init(task: TaskItem, userID: UUID) {
        id           = task.id
        userId       = userID
        title        = task.title
        isCompleted  = task.isCompleted
        orderIndex   = task.orderIndex
        createdAt    = task.createdAt
        updatedAt    = task.updatedAt
    }
}

// MARK: - DayRecord DTO

struct DayRecordPayload: Codable {
    var id: UUID
    var userId: UUID
    var dateString: String
    var allTaskTitles: [String]
    var completedTaskTitles: [String]
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId               = "user_id"
        case dateString           = "date_string"
        case allTaskTitles        = "all_task_titles"
        case completedTaskTitles  = "completed_task_titles"
        case updatedAt            = "updated_at"
    }

    init(record: DayRecord, userID: UUID) {
        id                   = record.id
        userId               = userID
        dateString           = record.dateString
        allTaskTitles        = record.allTaskTitles
        completedTaskTitles  = record.completedTaskTitles
        updatedAt            = record.updatedAt
    }
}
