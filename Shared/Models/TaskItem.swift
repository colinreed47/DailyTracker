import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    @Attribute var userId: String
    var title: String
    var isCompleted: Bool
    var isPartial: Bool
    var orderIndex: Int
    var createdAt: Date

    init(title: String, orderIndex: Int = 0, userId: String = "") {
        self.id = UUID()
        self.userId = userId
        self.title = title
        self.isCompleted = false
        self.isPartial = false
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}
