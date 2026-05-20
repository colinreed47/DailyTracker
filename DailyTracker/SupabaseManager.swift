import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://bchsgwwlqojfbnrcyqem.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJjaHNnd3dscW9qZmJucmN5cWVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwOTU4MzgsImV4cCI6MjA5MDY3MTgzOH0.3ivNaGbt69PofhQvhVD8RL_J1ZkDMHocIanLyYBlDlQ"
    )

    private(set) var userId: UUID?

    /// The userId string used by SwiftData queries; empty string before auth resolves.
    var userIdString: String { userId?.uuidString ?? "" }

    private init() {
        // Restore from cache so userIdString is synchronously available on re-launch
        if let stored = SharedDataStore.sharedDefaults.string(forKey: "currentUserId"),
           let id = UUID(uuidString: stored) {
            userId = id
        }
    }

    func signInIfNeeded() async {
        do {
            let session = try await client.auth.session
            userId = session.user.id
        } catch {
            do {
                let session = try await client.auth.signInAnonymously()
                userId = session.user.id
            } catch {
                print("[Supabase] Auth error: \(error)")
            }
        }
        if let id = userId {
            SharedDataStore.sharedDefaults.set(id.uuidString, forKey: "currentUserId")
        }
    }

    func upsertTask(_ task: TaskItem) async {
        guard let userId else { return }
        let record = TaskItemRow(
            id: task.id,
            userId: userId,
            title: task.title,
            isCompleted: task.isCompleted,
            isPartial: task.isPartial,
            orderIndex: task.orderIndex,
            createdAt: task.createdAt
        )
        do {
            try await client.from("task_items").upsert(record).execute()
        } catch {
            print("[Supabase] upsert task error: \(error)")
        }
    }

    func deleteTask(id: UUID) async {
        guard userId != nil else { return }
        do {
            try await client.from("task_items").delete().eq("id", value: id.uuidString).execute()
        } catch {
            print("[Supabase] delete task error: \(error)")
        }
    }

    func fetchTasks() async throws -> [TaskItemRowDecodable] {
        guard let userId else { return [] }
        return try await client
            .from("task_items")
            .select("id, title, is_completed, is_partial, order_index, created_at")
            .eq("user_id", value: userId.uuidString)
            .order("order_index")
            .execute()
            .value
    }

    func fetchDayRecords() async throws -> [DayRecordRowDecodable] {
        guard let userId else { return [] }
        return try await client
            .from("day_records")
            .select("id, date_string, all_task_titles, completed_task_titles, partially_completed_task_titles")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
    }

    func upsertDayRecord(_ record: DayRecord) async {
        guard let userId else { return }
        let row = DayRecordRow(
            id: record.id,
            userId: userId,
            dateString: record.dateString,
            allTaskTitles: record.allTaskTitles,
            completedTaskTitles: record.completedTaskTitles,
            partiallyCompletedTaskTitles: record.partiallyCompletedTaskTitles
        )
        do {
            try await client.from("day_records").upsert(row).execute()
        } catch {
            print("[Supabase] upsert day record error: \(error)")
        }
    }
}

struct TaskItemRowDecodable: Decodable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let isPartial: Bool
    let orderIndex: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case isCompleted = "is_completed"
        case isPartial = "is_partial"
        case orderIndex = "order_index"
        case createdAt = "created_at"
    }
}

struct DayRecordRowDecodable: Decodable {
    let id: UUID
    let dateString: String
    let allTaskTitles: [String]
    let completedTaskTitles: [String]
    let partiallyCompletedTaskTitles: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case dateString = "date_string"
        case allTaskTitles = "all_task_titles"
        case completedTaskTitles = "completed_task_titles"
        case partiallyCompletedTaskTitles = "partially_completed_task_titles"
    }
}

private struct TaskItemRow: Encodable {
    let id: UUID
    let userId: UUID
    let title: String
    let isCompleted: Bool
    let isPartial: Bool
    let orderIndex: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case isCompleted = "is_completed"
        case isPartial = "is_partial"
        case orderIndex = "order_index"
        case createdAt = "created_at"
    }
}

private struct DayRecordRow: Encodable {
    let id: UUID
    let userId: UUID
    let dateString: String
    let allTaskTitles: [String]
    let completedTaskTitles: [String]
    let partiallyCompletedTaskTitles: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dateString = "date_string"
        case allTaskTitles = "all_task_titles"
        case completedTaskTitles = "completed_task_titles"
        case partiallyCompletedTaskTitles = "partially_completed_task_titles"
    }
}
