import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(title: String, orderIndex: Int = 0) {
        self.id          = UUID()
        self.title       = title
        self.isCompleted = false
        self.orderIndex  = orderIndex
        self.createdAt   = Date()
        self.updatedAt   = Date()
    }

    /// Initialise from a remote Supabase payload.
    init(from payload: TaskItemPayload) {
        self.id          = payload.id
        self.title       = payload.title
        self.isCompleted = payload.isCompleted
        self.orderIndex  = payload.orderIndex
        self.createdAt   = payload.createdAt
        self.updatedAt   = payload.updatedAt
    }
}
