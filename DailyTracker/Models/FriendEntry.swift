import Foundation

struct FriendEntry: Decodable, Identifiable {
    let friendshipId: UUID
    let status: String
    let isRequester: Bool
    let userId: UUID
    let displayName: String
    let friendCode: String
    let isSharingEnabled: Bool

    var id: UUID { friendshipId }
    var isPending: Bool { status == "pending" }
    var isAccepted: Bool { status == "accepted" }
    var isIncomingRequest: Bool { isPending && !isRequester }

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case status
        case isRequester = "is_requester"
        case userId = "user_id"
        case displayName = "display_name"
        case friendCode = "friend_code"
        case isSharingEnabled = "is_sharing_enabled"
    }
}
