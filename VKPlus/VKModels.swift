import Foundation

// MARK: - Generic VK response wrapper
struct VKResponse<T: Decodable>: Decodable {
    let response: T?
    let error: VKAPIError?
}

struct VKAPIError: Decodable {
    let errorCode: Int
    let errorMsg: String
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg  = "error_msg"
    }
}

// MARK: - User
struct VKUser: Decodable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let photo100: String?
    let photo200: String?
    let online: Int?
    let status: String?
    let verified: Int?
    let deactivated: String?

    enum CodingKeys: String, CodingKey {
        case id, status, verified, deactivated, online
        case firstName = "first_name"
        case lastName  = "last_name"
        case photo100  = "photo_100"
        case photo200  = "photo_200"
    }

    var fullName: String  { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var isOnline: Bool    { online == 1 }
    var isBanned: Bool    { deactivated != nil }
    var avatar: String?   { photo200 ?? photo100 }
}

// MARK: - Message
struct VKMessage: Decodable, Identifiable {
    let id: Int
    let fromId: Int
    let text: String
    let date: Int

    enum CodingKeys: String, CodingKey {
        case id, text, date
        case fromId = "from_id"
    }
}

// MARK: - Newsfeed post
// VK API returns "likes" as an object {"count":N}, not a plain Int
struct VKLikesObj: Decodable {
    let count: Int?
}

struct VKWallPost: Decodable, Identifiable {
    let id: Int
    let fromId: Int
    let text: String
    let date: Int
    let likes: VKLikesObj?

    enum CodingKeys: String, CodingKey {
        case id, text, date, likes
        case fromId = "from_id"
    }

    var likesCount: Int { likes?.count ?? 0 }
}

// MARK: - Conversations
struct VKConversationsResponse: Decodable {
    let count: Int
    let items: [VKConversationItem]
    let profiles: [VKUser]?
    let groups: [VKGroup]?
}

struct VKConversationItem: Decodable {
    let conversation: VKConversation
    let lastMessage: VKMessage?
    enum CodingKeys: String, CodingKey {
        case conversation
        case lastMessage = "last_message"
    }
}

struct VKConversation: Decodable {
    let peer: VKPeer
    let unreadCount: Int?
    enum CodingKeys: String, CodingKey {
        case peer
        case unreadCount = "unread_count"
    }
}

struct VKPeer: Decodable {
    let id: Int
    let type: String
    let localId: Int
    enum CodingKeys: String, CodingKey {
        case id, type
        case localId = "local_id"
    }
}

struct VKGroup: Decodable, Identifiable {
    let id: Int
    let name: String
    let photo100: String?
    enum CodingKeys: String, CodingKey {
        case id, name
        case photo100 = "photo_100"
    }
}

// MARK: - Dialog item for UI
struct DialogItem: Identifiable {
    let id: Int
    let name: String
    let avatar: String?
    let lastMessage: String
    let isOnline: Bool
    let unreadCount: Int
}

// MARK: - Friends response
struct VKFriendsResponse: Decodable {
    let count: Int
    let items: [VKUser]
}
