import Observation
import Foundation
import Supabase

@Observable
final class FriendsViewModel {
    var profile: UserProfile? = nil
    var friends: [FriendEntry] = []
    var isLoading = false

    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var userId: UUID? { SupabaseManager.shared.userId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchProfile() }
            group.addTask { await self.fetchFriends() }
        }
    }

    // MARK: - Profile

    func fetchProfile() async {
        guard let userId else { return }
        do {
            profile = try await client
                .from("profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value
        } catch {
            await createProfile()
        }
    }

    private func createProfile() async {
        guard let userId else { return }
        struct Insert: Encodable {
            let userId: UUID
            let displayName: String
            let isSharingEnabled: Bool
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case displayName = "display_name"
                case isSharingEnabled = "is_sharing_enabled"
            }
        }
        do {
            profile = try await client
                .from("profiles")
                .insert(Insert(userId: userId, displayName: "Friend", isSharingEnabled: true))
                .select()
                .single()
                .execute()
                .value
        } catch {
            print("[Friends] create profile error: \(error)")
        }
    }

    func updateDisplayName(_ name: String) async {
        guard let userId else { return }
        struct Update: Encodable {
            let displayName: String
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
        do {
            try await client
                .from("profiles")
                .update(Update(displayName: name))
                .eq("user_id", value: userId.uuidString)
                .execute()
            profile?.displayName = name
        } catch {
            print("[Friends] update name error: \(error)")
        }
    }

    func toggleSharing(_ enabled: Bool) async {
        guard let userId else { return }
        struct Update: Encodable {
            let isSharingEnabled: Bool
            enum CodingKeys: String, CodingKey { case isSharingEnabled = "is_sharing_enabled" }
        }
        do {
            try await client
                .from("profiles")
                .update(Update(isSharingEnabled: enabled))
                .eq("user_id", value: userId.uuidString)
                .execute()
            profile?.isSharingEnabled = enabled
        } catch {
            print("[Friends] toggle sharing error: \(error)")
        }
    }

    // MARK: - Friends

    func fetchFriends() async {
        do {
            friends = try await client
                .rpc("get_my_friends")
                .execute()
                .value
        } catch {
            print("[Friends] fetch friends error: \(error)")
        }
    }

    /// Returns nil on success, or a user-facing error string.
    func addFriend(code: String) async -> String? {
        struct Params: Encodable {
            let pFriendCode: String
            enum CodingKeys: String, CodingKey { case pFriendCode = "p_friend_code" }
        }
        struct Result: Decodable {
            let success: Bool?
            let error: String?
        }
        do {
            let result: Result = try await client
                .rpc("add_friend_by_code", params: Params(pFriendCode: code.uppercased().trimmingCharacters(in: .whitespaces)))
                .execute()
                .value
            if let err = result.error {
                switch err {
                case "code_not_found": return "No user found with that code."
                case "self":           return "That's your own code!"
                case "already_exists": return "Already friends or request pending."
                default:               return "Something went wrong."
                }
            }
            await fetchFriends()
            return nil
        } catch {
            return "Failed to send request."
        }
    }

    func acceptFriend(friendshipId: UUID) async {
        struct Update: Encodable { let status: String }
        do {
            try await client
                .from("friendships")
                .update(Update(status: "accepted"))
                .eq("id", value: friendshipId.uuidString)
                .execute()
            await fetchFriends()
        } catch {
            print("[Friends] accept error: \(error)")
        }
    }

    // MARK: - Friend Calendar

    func fetchFriendCalendar(userId: UUID) async -> [FriendDayRecord] {
        do {
            return try await client
                .from("friend_calendar_view")
                .select("date_string, total_count, completed_count, partial_count")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
        } catch {
            print("[Friends] fetch calendar error: \(error)")
            return []
        }
    }
}
