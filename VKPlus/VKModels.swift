import Foundation

struct VKResponse<T: Decodable>: Decodable {
    let response: T?
    let error: VKAPIError?
}
struct VKAPIError: Decodable {
    let errorCode: Int; let errorMsg: String
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"; case errorMsg = "error_msg"
    }
}

struct VKUser: Decodable, Identifiable {
    let id: Int
    let firstName: String; let lastName: String
    let photo100: String?; let photo200: String?
    let online: Int?; let status: String?
    let verified: Int?; let deactivated: String?
    let city: VKCity?; let followersCount: Int?
    let bdate: String?
    enum CodingKeys: String, CodingKey {
        case id, status, verified, deactivated, online, city, bdate
        case firstName = "first_name"; case lastName = "last_name"
        case photo100 = "photo_100"; case photo200 = "photo_200"
        case followersCount = "followers_count"
    }
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var isOnline: Bool   { online == 1 }
    var isBanned: Bool   { deactivated != nil }
    var avatar: String?  { photo200 ?? photo100 }
}

struct VKCity: Decodable { let id: Int; let title: String }

struct VKMessage: Decodable, Identifiable {
    let id: Int; let fromId: Int; let text: String; let date: Int
    let attachments: [VKAttachment]?
    enum CodingKeys: String, CodingKey {
        case id, text, date, attachments; case fromId = "from_id"
    }
}

struct VKAttachment: Decodable {
    let type: String
    let photo: VKPhoto?
    let doc:   VKDoc?
    let link:  VKLinkAttach?
    let audioMessage: VKAudioMessage?
    enum CodingKeys: String, CodingKey {
        case type, photo, doc, link
        case audioMessage = "audio_message"
    }
}

struct VKPhoto: Decodable {
    let id: Int
    let sizes: [VKPhotoSize]?
    // Prefer x/y/z/w sizes (good quality), fallback to largest by width
    var maxUrl: String? {
        let preferred = ["z","y","x","w","r","q","p","o"]
        guard let sizes else { return nil }
        for p in preferred { if let s = sizes.first(where: { $0.type == p }) { return s.url } }
        return sizes.sorted { ($0.width ?? 0) > ($1.width ?? 0) }.first?.url
    }
}
struct VKPhotoSize: Decodable { let type: String; let url: String; let width: Int?; let height: Int? }
struct VKDoc: Decodable { let id: Int; let title: String; let url: String?; let ext: String? }
struct VKAudioMessage: Decodable {
    let id: Int; let duration: Int
    let linkMp3: String?; let linkOgg: String?
    enum CodingKeys: String, CodingKey {
        case id, duration; case linkMp3 = "link_mp3"; case linkOgg = "link_ogg"
    }
}

struct VKLikesObj: Decodable {
    var count:     Int?
    var userLikes: Int?   // 1 if current user liked
    enum CodingKeys: String, CodingKey { case count; case userLikes = "user_likes" }
    var isLiked: Bool { userLikes == 1 }
    init(count: Int?, userLikes: Int?) { self.count = count; self.userLikes = userLikes }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count     = try c.decodeIfPresent(Int.self, forKey: .count)
        userLikes = try c.decodeIfPresent(Int.self, forKey: .userLikes)
    }
}
struct VKCommentsObj: Decodable { let count: Int? }
struct VKRepostsObj:  Decodable { let count: Int? }
struct VKViewsObj:    Decodable { let count: Int? }
struct VKLinkAttach:  Decodable {
    let url: String; let title: String?; let description: String?
    let photo: VKPhoto?
}

struct VKWallPost: Decodable, Identifiable {
    let id: Int
    let fromId:   Int?    // from_id in wall
    let sourceId: Int?    // source_id in newsfeed
    let ownerId:  Int?
    let text: String
    let date: Int
    var likes:       VKLikesObj?
    let comments:    VKCommentsObj?
    let reposts:     VKRepostsObj?
    let views:       VKViewsObj?
    let attachments: [VKAttachment]?
    enum CodingKeys: String, CodingKey {
        case id, text, date, likes, comments, reposts, views, attachments
        case fromId   = "from_id"
        case sourceId = "source_id"
        case ownerId  = "owner_id"
    }
    var likesCount: Int { likes?.count ?? 0 }
    var authorId:   Int { fromId ?? sourceId ?? 0 }
    var postOwnerId: Int { ownerId ?? authorId }
}

struct VKConversationsResponse: Decodable {
    let count: Int; let items: [VKConversationItem]
    let profiles: [VKUser]?; let groups: [VKGroup]?
}
struct VKConversationItem: Decodable {
    let conversation: VKConversation; let lastMessage: VKMessage?
    enum CodingKeys: String, CodingKey {
        case conversation; case lastMessage = "last_message"
    }
}
struct VKConversation: Decodable {
    let peer: VKPeer; let unreadCount: Int?
    enum CodingKeys: String, CodingKey { case peer; case unreadCount = "unread_count" }
}
struct VKPeer: Decodable {
    let id: Int; let type: String; let localId: Int
    enum CodingKeys: String, CodingKey { case id, type; case localId = "local_id" }
}
struct VKGroup: Decodable, Identifiable {
    let id: Int; let name: String; let photo100: String?
    enum CodingKeys: String, CodingKey { case id, name; case photo100 = "photo_100" }
}

struct DialogItem: Identifiable {
    let id: Int; let name: String; let avatar: String?
    let lastMessage: String; let isOnline: Bool; let unreadCount: Int
    let peerId: Int
}

struct VKFriendsResponse: Decodable { let count: Int; let items: [VKUser] }

// Settings
struct AppSettings {
    var ghostMode      = false; var antiTyping   = false
    var forceOffline   = false; var ghostOnline  = false
    var antiTelemetry  = false; var antiScreen   = false
    var ghostStory     = false; var silentVm     = false
    var offlinePost    = false; var antiBan      = false
    var bypassActivity = false; var bypassLinks  = true
    var bypassShortUrl = false; var hardwareSpoof = false
    var verifyChecker  = true;  var fakeVerification = false
}

// Profile Changer
struct MirrorProfile {
    var userId: String = ""; var isActive = false
    var name = ""; var photo = ""; var status = ""
    var city = ""; var screenName = ""; var id = 0
    var isLoading = false; var error: String? = nil
}

// Currency Exchange
struct CurrencyState {
    var base = "USD"; var target = "RUB"
    var result: Double? = nil; var isLoading = false; var error: String? = nil
}

let ALL_CURRENCIES = ["USD","EUR","RUB","GBP","CNY","JPY","AED","TRY","KZT","BYN",
                      "CHF","CAD","AUD","SEK","NOK","PLN","CZK","HUF","INR","BRL"]

// ProxyEntry is defined in ProxyView.swift
