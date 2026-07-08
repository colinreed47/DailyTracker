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
    /// True only when `userId` is backed by a real Supabase session. False
    /// means `userId` is a locally-cached last-known identity (shown so the
    /// app isn't blank while offline) — writes and cloud reads must not run
    /// against it, since there is no session to authorize them.
    private(set) var isAuthenticated = false

    enum AuthPhase: Equatable {
        /// signInIfNeeded is in flight; nothing to show yet.
        case resolving
        /// No cached identity and no session: a genuine first launch, or a
        /// fresh install/reinstall with nothing local. Rather than silently
        /// minting a brand-new anonymous account here (which is exactly how
        /// accounts got orphaned before), the UI should ask whether this is
        /// a new user or someone signing back into an existing account.
        case needsOnboarding
        /// `userId` is set (authenticated or cached-offline) — show the app.
        case ready
    }
    private(set) var phase: AuthPhase = .resolving

    private static let currentUserIdKey = "currentUserId"

    private init() {
        // Seed synchronously from the cache so the very first frame can show
        // the last known user's data while signInIfNeeded() resolves in the
        // background. isAuthenticated stays false until a real session backs it.
        if let cached = SharedDataStore.sharedDefaults.string(forKey: Self.currentUserIdKey),
           let cachedId = UUID(uuidString: cached) {
            userId = cachedId
        }
    }

    func signInIfNeeded() async {
        phase = .resolving
        do {
            let session = try await client.auth.session
            applyAuthenticatedSession(session)
            phase = .ready
            return
        } catch {
            print("[Supabase] session load error: \(error)")
        }

        // A failure above (e.g. token refresh with no network right after a
        // reboot) does not mean the account is gone. Creating a new anonymous
        // user here would orphan all data keyed to the old user ID, so fall
        // back to the identity we already know about instead, and let the
        // caller retry signInIfNeeded later (e.g. on the next foreground)
        // rather than ever minting a second account behind the user's back.
        if let session = client.auth.currentSession {
            applyAuthenticatedSession(session)
            phase = .ready
            return
        }
        if userId != nil {
            isAuthenticated = false
            phase = .ready
            return
        }

        // No stored session and no previously known user: let the UI ask
        // whether to start fresh or sign into an existing account, instead
        // of assuming "fresh" the way this app used to.
        phase = .needsOnboarding
    }

    /// Called when the user explicitly chooses "Get Started" on a device
    /// with no prior identity. Only path left that creates a brand-new
    /// anonymous account — every other case reuses a known identity.
    func continueAsNewAccount() async {
        do {
            let session = try await client.auth.signInAnonymously()
            applyAuthenticatedSession(session)
            phase = .ready
        } catch {
            print("[Supabase] Auth error: \(error)")
            phase = .needsOnboarding
        }
    }

    private func applyAuthenticatedSession(_ session: Session) {
        userId = session.user.id
        linkedEmail = session.user.email
        isAuthenticated = true
        SharedDataStore.sharedDefaults.set(session.user.id.uuidString, forKey: Self.currentUserIdKey)
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
        isAuthenticated = true
        phase = .ready
        SharedDataStore.sharedDefaults.set(response.user.id.uuidString, forKey: Self.currentUserIdKey)
        SharedDataStore.sharedDefaults.set(true, forKey: "needsCloudRestore")
    }

    // MARK: - Cloud restore (read path)

    enum SyncError: Error {
        case notAuthenticated
    }

    /// Throws (rather than swallowing into an empty array) so callers doing a
    /// one-shot restore can tell "confirmed nothing on the server" apart from
    /// "the fetch failed" and only consume their one-shot restore flag on the
    /// former.
    func fetchRemoteTasks() async throws -> [TaskItemRow] {
        guard isAuthenticated, let userId else { throw SyncError.notAuthenticated }
        return try await client.from("task_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("order_index")
            .execute()
            .value
    }

    func fetchRemoteDayRecords() async throws -> [DayRecordRow] {
        guard isAuthenticated, let userId else { throw SyncError.notAuthenticated }
        return try await client.from("day_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
    }

    // MARK: - Write path

    func upsertTask(_ task: TaskItem) async {
        guard isAuthenticated, let userId else { return }
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
        guard isAuthenticated, let userId else { return }
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
        guard isAuthenticated, let userId else { return }
        let row = DayRecordRow(
            id: record.id,
            userId: userId,
            dateString: record.dateString,
            allTaskTitles: record.allTaskTitles,
            completedTaskTitles: record.completedTaskTitles,
            partiallyCompletedTaskTitles: record.partiallyCompletedTaskTitles
        )
        do {
            // Target the natural key (one row per user per day), not the
            // primary key: a locally-created record's id can legitimately
            // differ from a same-day row that already exists server-side
            // (e.g. after merging in restored data), and a plain PK upsert
            // would try to INSERT a second row and violate the unique
            // (user_id, date_string) constraint instead of updating it.
            try await client.from("day_records")
                .upsert(row, onConflict: "user_id,date_string")
                .execute()
        } catch {
            print("[Supabase] upsert day record error: \(error)")
        }
    }
}

struct TaskItemRow: Codable {
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

struct DayRecordRow: Codable {
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
