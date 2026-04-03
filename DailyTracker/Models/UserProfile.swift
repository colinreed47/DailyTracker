import Foundation

struct UserProfile: Codable {
    var userId: UUID
    var displayName: String
    var friendCode: String
    var isSharingEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case friendCode = "friend_code"
        case isSharingEnabled = "is_sharing_enabled"
    }
}
