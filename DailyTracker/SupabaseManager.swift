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
    /// Email linked to the current account, if any. A linked email makes the
    /// account recoverable even if the local session is ever lost.
    private(set) var linkedEmail: String?

    private init() {}

    func signInIfNeeded() async {
        do {
            let session = try await client.auth.session
            userId = session.user.id
            linkedEmail = session.user.email
            return
        } catch {
            print("[Supabase] session load error: \(error)")
        }

        // A failure above (e.g. token refresh with no network right after a
        // reboot) does not mean the account is gone. Creating a new anonymous
        // user here would orphan all data keyed to the old user ID, so fall
        // back to the identity we already know about instead.
        if let session = client.auth.currentSession {
            userId = session.user.id
            linkedEmail = session.user.email
            return
        }
        if let cached = SharedDataStore.sharedDefaults.string(forKey: "currentUserId"),
           let cachedId = UUID(uuidString: cached) {
            userId = cachedId
            return
        }

        // No stored session and no previously known user: true first launch.
        do {
            let session = try await client.auth.signInAnonymously()
            userId = session.user.id
        } catch {
            print("[Supabase] Auth error: \(error)")
        }
    }

    // MARK: - Email linking & account recovery

    /// Attaches an email to the current (anonymous) account. Supabase sends a
    /// confirmation link; once the user taps it the email is active and the
    /// account can be recovered on any device via `sendRecoveryCode`.
    func linkEmail(_ email: String) async throws {
        try await client.auth.update(user: UserAttributes(email: email))
    }

    /// Emails a one-time sign-in code. `shouldCreateUser: false` ensures this
    /// can only reach an existing account and never silently mints a new one.
    func sendRecoveryCode(to email: String) async throws {
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: false)
    }

    /// Verifies the emailed code and switches this device to the recovered
    /// account. Marks the local store for a cloud restore so the recovered
    /// account's data is pulled back down.
    func verifyRecoveryCode(email: String, code: String) async throws {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        userId = response.user.id
        linkedEmail = response.user.email
        SharedDataStore.sharedDefaults.set(response.user.id.uuidString, forKey: "currentUserId")
        SharedDataStore.sharedDefaults.set(true, forKey: "needsCloudRestore")
    }

    // MARK: - Cloud restore (read path)

    struct RemoteTask: Decodable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let isPartial: Bool
        let orderIndex: Int
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case isCompleted = "is_completed"
            case isPartial = "is_partial"
            case orderIndex = "order_index"
            case createdAt = "created_at"
        }
    }

    struct RemoteDayRecord: Decodable {
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

    func fetchRemoteTasks() async -> [RemoteTask] {
        guard let userId else { return [] }
        do {
            return try await client.from("task_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("order_index")
                .execute()
                .value
        } catch {
            print("[Supabase] fetch tasks error: \(error)")
            return []
        }
    }

    func fetchRemoteDayRecords() async -> [RemoteDayRecord] {
        guard let userId else { return [] }
        do {
            return try await client.from("day_records")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
        } catch {
            print("[Supabase] fetch day records error: \(error)")
            return []
        }
    }

    // MARK: - Write path

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
        guard let userId else { return }
        do {
            try await client.from("task_items")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            print("[Supabase] delete task error: \(error)")
        }
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
