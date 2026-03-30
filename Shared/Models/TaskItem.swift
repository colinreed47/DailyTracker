import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var orderIndex: Int
    var createdAt: Date

    init(title: String, orderIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}
