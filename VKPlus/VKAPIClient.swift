import Foundation

enum VKError: LocalizedError {
    case invalidToken
    case api(Int, String)
    case network(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidToken:      return "Недействительный токен"
        case .api(_, let msg):   return msg
        case .network(let msg):  return msg
        case .noData:            return "Пустой ответ"
        }
    }
}

// MARK: - Internal wrapper
private struct APIEnvelope<T: Decodable>: Decodable {
    let response: T?
    let error: APIEnvelopeError?
}
private struct APIEnvelopeError: Decodable {
    let errorCode: Int
    let errorMsg: String
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg  = "error_msg"
    }
}

// MARK: - Client
final class VKAPIClient {
    static let shared = VKAPIClient()
    private(set) var token: String = ""
    private let base    = "https://api.vk.com/method"
    private let version = "5.199"
    private let decoder = JSONDecoder()

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 15
        cfg.timeoutIntervalForResource = 30
        return URLSession(configuration: cfg)
    }()

    private init() {
        token = TokenStorage.shared.token ?? ""
    }

    func configure(token t: String) { token = t }
    func reset() { token = "" }

    // MARK: Generic request
    private func call<T: Decodable>(_ method: String,
                                    params: [String: String] = [],
                                    token override: String? = nil) async throws -> T {
        var comps = URLComponents(string: "\(base)/\(method)")!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "access_token", value: override ?? token),
            URLQueryItem(name: "v",            value: version)
        ]
        comps.queryItems = items

        guard let url = comps.url else { throw VKError.network("Bad URL") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw VKError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw VKError.network("HTTP \(http.statusCode)")
        }

        let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)

        if let err = envelope.error {
            if err.errorCode == 5 { throw VKError.invalidToken }
            throw VKError.api(err.errorCode, err.errorMsg)
        }

        guard let result = envelope.response else { throw VKError.noData }
        return result
    }

    // MARK: - Auth check
    func getMe(token t: String) async throws -> VKUser {
        let users: [VKUser] = try await call("users.get", params: [
            "fields": "photo_200,photo_100,online,status,verified"
        ], token: t)
        guard let u = users.first else { throw VKError.noData }
        return u
    }

    // MARK: - Profile
    func getProfile() async throws -> VKUser {
        let users: [VKUser] = try await call("users.get", params: [
            "fields": "photo_200,photo_100,online,status,verified,city,followers_count,bdate"
        ])
        guard let u = users.first else { throw VKError.noData }
        return u
    }

    // MARK: - Friends
    func getFriends(count: Int = 200) async throws -> [VKUser] {
        let r: VKFriendsResponse = try await call("friends.get", params: [
            "fields": "photo_100,online,status,verified",
            "order":  "hints",
            "count":  "\(count)"
        ])
        return r.items
    }

    // MARK: - Dialogs
    func getDialogs(count: Int = 30) async throws -> [DialogItem] {
        let r: VKConversationsResponse = try await call("messages.getConversations", params: [
            "count":    "\(count)",
            "extended": "1",
            "fields":   "photo_100,online"
        ])

        let profileMap = Dictionary(uniqueKeysWithValues: (r.profiles ?? []).map { ($0.id, $0) })
        let groupMap   = Dictionary(uniqueKeysWithValues: (r.groups   ?? []).map { ($0.id, $0) })

        return r.items.map { item in
            let peer = item.conversation.peer
            let msg  = item.lastMessage?.text ?? ""
            if peer.type == "user", let u = profileMap[peer.localId] {
                return DialogItem(
                    id: peer.id, name: u.fullName, avatar: u.photo100,
                    lastMessage: msg, isOnline: u.isOnline,
                    unreadCount: item.conversation.unreadCount ?? 0
                )
            } else if peer.type == "group", let g = groupMap[abs(peer.localId)] {
                return DialogItem(
                    id: peer.id, name: g.name, avatar: g.photo100,
                    lastMessage: msg, isOnline: false,
                    unreadCount: item.conversation.unreadCount ?? 0
                )
            }
            return DialogItem(
                id: peer.id, name: "Диалог \(peer.id)", avatar: nil,
                lastMessage: msg, isOnline: false, unreadCount: 0
            )
        }
    }

    // MARK: - Messages
    func getMessages(peerId: Int, count: Int = 50) async throws -> [VKMessage] {
        struct MR: Decodable { let count: Int; let items: [VKMessage] }
        let r: MR = try await call("messages.getHistory", params: [
            "peer_id": "\(peerId)",
            "count":   "\(count)"
        ])
        return r.items
    }

    // MARK: - Newsfeed
    func getNewsfeed(count: Int = 30) async throws -> [VKWallPost] {
        struct NR: Decodable { let items: [VKWallPost] }
        let r: NR = try await call("newsfeed.get", params: [
            "filters": "post",
            "count":   "\(count)"
        ])
        return r.items
    }

    // MARK: - User by ID
    func getUserById(_ id: String) async throws -> VKUser {
        let users: [VKUser] = try await call("users.get", params: [
            "user_ids": id,
            "fields":   "photo_200,photo_100,online,status,verified,city,followers_count"
        ])
        guard let u = users.first else { throw VKError.noData }
        return u
    }
}
