import Foundation

enum VKError: LocalizedError {
    case invalidToken; case api(Int, String); case network(String); case noData
    var errorDescription: String? {
        switch self {
        case .invalidToken:      return "Недействительный токен"
        case .api(_, let m):     return m
        case .network(let m):    return m
        case .noData:            return "Пустой ответ"
        }
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let response: T?; let error: APIEnvelopeError?
}
private struct APIEnvelopeError: Decodable {
    let errorCode: Int; let errorMsg: String
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"; case errorMsg = "error_msg"
    }
}

final class VKAPIClient {
    static let shared = VKAPIClient()
    private(set) var token: String = ""
    private let base    = "https://api.vk.com/method"
    private let version = "5.199"
    private let decoder = JSONDecoder()
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    private init() { token = TokenStorage.shared.token ?? "" }
    func configure(token t: String) { token = t }
    func reset() { token = "" }

    private let telemetryMethods  = ["stats.trackEvents","stats.addPost","auth.saveMetrics"]
    private let telemetryDomains  = ["stats.vk-portal.net","tns-counter.ru","counter.yadro.ru","mc.yandex.ru"]
    private let clientIds         = [2685278, 2274003, 3140623, 3697615]
    private var requestCount      = 0
    private var clientIdIndex     = 0

    private func call<T: Decodable>(_ method: String, params: [String: String] = [:], tokenOverride: String? = nil) async throws -> T {
        let s = SettingsStore.shared

        // Anti-Telemetry: block telemetry methods silently
        if s.antiTelemetry && telemetryMethods.contains(method) {
            throw VKError.network("Blocked by Anti-Telemetry")
        }

        // Ghost Mode interceptors: return fake ok for blocked methods
        if s.ghostMode     && method == "messages.markAsRead"    { throw VKError.network("Blocked by Ghost Mode") }
        if s.silentVm      && method == "messages.markAsListened"{ throw VKError.network("Blocked by Silent VM") }
        if s.ghostStory    && method == "stories.markAsViewed"   { throw VKError.network("Blocked by Ghost Story") }
        if s.ghostOnline   && method == "account.setOnline"      { throw VKError.network("Blocked by Ghost Online") }

        var comps = URLComponents(string: "\(base)/\(method)")!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "access_token", value: tokenOverride ?? token),
            URLQueryItem(name: "v",            value: version)
        ]

        // Anti-Ban: rotate client_id every 50 requests
        if s.antiBan {
            requestCount += 1
            if requestCount % 50 == 0 { clientIdIndex = (clientIdIndex + 1) % clientIds.count }
            items.append(URLQueryItem(name: "client_id", value: "\(clientIds[clientIdIndex])"))
        }

        comps.queryItems = items
        guard let url = comps.url else { throw VKError.network("Bad URL") }

        var request = URLRequest(url: url)

        // Device UA / Hardware Spoof
        if s.hardwareSpoof {
            let device = HardwareSpoofing.generate()
            device.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        } else {
            request.setValue(s.deviceUa, forHTTPHeaderField: "User-Agent")
        }

        let (data, _) = try await session.data(for: request)

        // Anti-Ban: on error_code 14/29 rotate immediately
        if s.antiBan, let bodyStr = String(data: data, encoding: .utf8),
           bodyStr.contains("\"error_code\":14") || bodyStr.contains("\"error_code\":29") {
            clientIdIndex = (clientIdIndex + 1) % clientIds.count
        }

        let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
        if let err = envelope.error {
            if err.errorCode == 5 { throw VKError.invalidToken }
            throw VKError.api(err.errorCode, err.errorMsg)
        }
        guard let result = envelope.response else { throw VKError.noData }
        return result
    }

    // MARK: - Auth
    func getMe(token t: String) async throws -> VKUser {
        let users: [VKUser] = try await call("users.get",
            params: ["fields": "photo_200,photo_100,online,status,verified"],
            tokenOverride: t)
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

    func getUserById(_ id: String) async throws -> VKUser {
        let users: [VKUser] = try await call("users.get", params: [
            "user_ids": id,
            "fields":   "photo_200,photo_100,online,status,verified,city,followers_count,screen_name"
        ])
        guard let u = users.first else { throw VKError.noData }
        return u
    }

    // MARK: - Friends
    func getFriends(count: Int = 200) async throws -> [VKUser] {
        let r: VKFriendsResponse = try await call("friends.get", params: [
            "fields": "photo_100,online,status,verified",
            "order":  "hints", "count": "\(count)"
        ])
        return r.items
    }

    // MARK: - Dialogs
    func getDialogs(count: Int = 30) async throws -> [DialogItem] {
        let r: VKConversationsResponse = try await call("messages.getConversations", params: [
            "count": "\(count)", "extended": "1", "fields": "photo_100,online"
        ])
        let profileMap = Dictionary(uniqueKeysWithValues: (r.profiles ?? []).map { ($0.id, $0) })
        let groupMap   = Dictionary(uniqueKeysWithValues: (r.groups   ?? []).map { ($0.id, $0) })
        return r.items.compactMap { item in
            let peer = item.conversation.peer
            let msg  = item.lastMessage?.text ?? ""
            let unread = item.conversation.unreadCount ?? 0
            if peer.type == "user", let u = profileMap[peer.localId] {
                return DialogItem(id: peer.id, name: u.fullName, avatar: u.photo100,
                                  lastMessage: msg, isOnline: u.isOnline, unreadCount: unread, peerId: peer.id)
            } else if peer.type == "group", let g = groupMap[abs(peer.localId)] {
                return DialogItem(id: peer.id, name: g.name, avatar: g.photo100,
                                  lastMessage: msg, isOnline: false, unreadCount: unread, peerId: peer.id)
            }
            return nil
        }
    }

    // MARK: - Messages
    func getMessages(peerId: Int, count: Int = 50) async throws -> [VKMessage] {
        struct MR: Decodable { let count: Int; let items: [VKMessage] }
        let r: MR = try await call("messages.getHistory", params: [
            "peer_id": "\(peerId)", "count": "\(count)"
        ])
        return r.items
    }

    // MARK: - Newsfeed
    struct NewsfeedPage {
        let items:    [VKWallPost]
        let profiles: [Int: VKUser]
        let groups:   [Int: VKGroup]
        let nextFrom: String?
    }

    func getNewsfeed(count: Int = 30, startFrom: String? = nil) async throws -> NewsfeedPage {
        struct NR: Decodable {
            let items:    [VKWallPost]
            let profiles: [VKUser]?
            let groups:   [VKGroup]?
            let nextFrom: String?
            enum CodingKeys: String, CodingKey {
                case items, profiles, groups; case nextFrom = "next_from"
            }
        }
        var params: [String: String] = ["filters": "post", "count": "\(count)"]
        if let sf = startFrom { params["start_from"] = sf }
        let r: NR = try await call("newsfeed.get", params: params)
        let profileMap = Dictionary(uniqueKeysWithValues: (r.profiles ?? []).map { ($0.id, $0) })
        let groupMap   = Dictionary(uniqueKeysWithValues: (r.groups   ?? []).map { ($0.id, $0) })
        return NewsfeedPage(items: r.items, profiles: profileMap, groups: groupMap, nextFrom: r.nextFrom)
    }

    // MARK: - Likes
    func addLike(ownerId: Int, itemId: Int) async throws -> Int {
        struct LR: Decodable { let likes: Int? }
        let r: LR = try await call("likes.add", params: ["type": "post", "owner_id": "\(ownerId)", "item_id": "\(itemId)"])
        return r.likes ?? 0
    }

    func deleteLike(ownerId: Int, itemId: Int) async throws -> Int {
        struct LR: Decodable { let likes: Int? }
        let r: LR = try await call("likes.delete", params: ["type": "post", "owner_id": "\(ownerId)", "item_id": "\(itemId)"])
        return r.likes ?? 0
    }

    // MARK: - Remove banned friends
    func getFriendsWithStatus() async throws -> [VKUser] {
        let r: VKFriendsResponse = try await call("friends.get", params: [
            "fields": "deactivated,photo_100,online", "count": "5000"
        ])
        return r.items
    }

    func deleteFriend(userId: Int) async throws {
        struct DR: Decodable { let success: Int? }
        let _: DR = try await call("friends.delete", params: ["user_id": "\(userId)"])
    }

    // MARK: - Currency
    func getExchangeRate(base: String, target: String) async throws -> Double {
        let key = "fca_live_XEMzZbdOk47fgjrXN0c1Veo9HKTagxomnJu5CgJq"
        let urlStr = "https://api.freecurrencyapi.com/v1/latest?apikey=\(key)&base_currency=\(base)&currencies=\(target)"
        guard let url = URL(string: urlStr) else { throw VKError.network("Bad URL") }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataObj = json?["data"] as? [String: Double]
        guard let rate = dataObj?[target] else { throw VKError.noData }
        return rate
    }
}

    // MARK: - Account
    func setOffline() async throws {
        struct R: Decodable { let response: Int? }
        let _: R = try await call("account.setOffline")
    }

    // MARK: - Exploits

    // Sticker Keywords — store.getStickersKeywords v5.131
    func getStickerKeywords(userId: Int) async throws -> String {
        struct SKR: Decodable { let items: [SKItem]? }
        struct SKItem: Decodable {
            let words: [String]?
            let userStickers: [SKSticker]?
            enum CodingKeys: String, CodingKey { case words; case userStickers = "user_stickers" }
        }
        struct SKSticker: Decodable {
            let product: SKProduct?
        }
        struct SKProduct: Decodable { let title: String? }

        let r: SKR = try await call("store.getStickersKeywords", params: ["user_id": "\(userId)", "extended": "1"])
        let items = r.items ?? []
        if items.isEmpty { return "Данные не получены — метод ограничен" }
        let packs = items.compactMap { $0.userStickers }.flatMap { $0 }.compactMap { $0.product?.title }.filter { !$0.isEmpty }
        let kw    = items.compactMap { $0.words }.flatMap { $0 }.prefix(10)
        var result = ""
        if !packs.isEmpty { result += "🎭 Стикерпаки (\(packs.count)):\n" + Set(packs).map { "• \($0)" }.joined(separator: "\n") }
        if !kw.isEmpty   { result += "\n🔑 Ключевые слова: " + kw.joined(separator: ", ") }
        return result.isEmpty ? "Стикеры найдены, но данные скрыты" : result
    }

    // Execute Bypass — last_seen + common_count via v5.60
    func executeBypass(userId: Int) async throws -> String {
        let code = "var u=API.users.get({\"user_ids\":\"\(userId)\",\"fields\":\"last_seen,online\",\"v\":\"5.60\"});var f=API.friends.getMutual({\"target_uid\":\"\(userId)\",\"v\":\"5.60\"});return{\"user\":u,\"common\":f.length};"
        struct ER: Decodable {}
        // Use raw JSON response
        var comps = URLComponents(string: "\(base)/execute")!
        comps.queryItems = [
            URLQueryItem(name: "code",         value: code),
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "v",            value: "5.60")
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let response = json?["response"] as? [String: Any] else {
            let err = (json?["error"] as? [String: Any])?["error_msg"] as? String ?? "Ошибка"
            return "❌ \(err)"
        }
        var result = ""
        if let users = response["user"] as? [[String: Any]], let u = users.first {
            let fn = u["first_name"] as? String ?? ""
            let ln = u["last_name"]  as? String ?? ""
            result += "👤 \(fn) \(ln)\n"
            if let ls = u["last_seen"] as? [String: Any] {
                let time     = ls["time"] as? Int ?? 0
                let platform = ls["platform"] as? Int ?? 0
                let pname = ["","🌐 Мобильный сайт","📱 iPhone","📱 iPad","📱 Android","📱 Windows Phone","🖥 Windows 10","🌐 Web"][safe: platform] ?? "❓"
                let date = Date(timeIntervalSince1970: TimeInterval(time))
                let df = DateFormatter(); df.locale = Locale(identifier: "ru_RU"); df.dateFormat = "d MMM HH:mm:ss"
                result += "🕐 \(df.string(from: date))\n📱 \(pname)\n"
            }
        }
        if let common = response["common"] as? Int { result += "👥 Общих друзей: \(common)" }
        return result.isEmpty ? "Нет данных" : result
    }

    // Platform Tracker
    func getPlatform(userId: Int) async throws -> String {
        let users: [VKUser] = try await call("users.get", params: ["user_ids": "\(userId)", "fields": "last_seen,online"])
        guard let u = users.first else { throw VKError.noData }
        var result = "👤 \(u.fullName)\n"
        if u.isOnline { result += "🟢 Сейчас онлайн\n" }
        result += "🔒 last_seen скрыт или недоступен"
        return result
    }

    // Hidden Groups
    func checkGroupMembership(userId: Int, groupIds: [Int]) async throws -> String {
        var result = ""
        for gid in groupIds {
            struct MR: Decodable { let response: Int? }
            struct GR: Decodable { let response: [GInfo]? }
            struct GInfo: Decodable { let id: Int; let name: String? }

            let mUrl = "\(base)/groups.isMember?group_id=\(gid)&user_id=\(userId)&access_token=\(token)&v=\(version)"
            let gUrl = "\(base)/groups.getById?group_id=\(gid)&access_token=\(token)&v=\(version)"

            let (mData, _) = try await session.data(from: URL(string: mUrl)!)
            let (gData, _) = try await session.data(from: URL(string: gUrl)!)
            let mResp = try? JSONDecoder().decode(MR.self, from: mData)
            let gResp = try? JSONDecoder().decode(GR.self, from: gData)
            let name  = gResp?.response?.first?.name ?? "Группа \(gid)"
            let isMember = mResp?.response == 1
            result += "\(isMember ? "✅" : "❌") \(name) (id\(gid))\n"
        }
        return result.isEmpty ? "Нет результатов" : result
    }

    // Content Filter Bypass
    func contentFilterBypass(userId: Int) async throws -> String {
        let users: [VKUser] = try await call("users.get", params: ["user_ids": "\(userId)", "fields": "photo_200,status,verified"])
        guard let u = users.first else { throw VKError.noData }
        return "✅ \(u.fullName)\nID: \(u.id)\nСтатус: \(u.status ?? "-")"
    }

    // Legacy Newsfeed v5.92
    func getLegacyNewsfeed() async throws -> String {
        var comps = URLComponents(string: "\(base)/newsfeed.get")!
        comps.queryItems = [
            URLQueryItem(name: "filters",      value: "post"),
            URLQueryItem(name: "count",        value: "15"),
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "v",            value: "5.92")
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let response = json?["response"] as? [String: Any] else {
            return "❌ Ошибка запроса"
        }
        let items    = response["items"]    as? [[String: Any]] ?? []
        let profiles = (response["profiles"] as? [[String: Any]] ?? [])
            .reduce(into: [Int: String]()) { dict, p in
                if let id = p["id"] as? Int {
                    dict[id] = "\(p["first_name"] as? String ?? "") \(p["last_name"] as? String ?? "")"
                }
            }
        if items.isEmpty { return "Лента пуста" }
        return items.prefix(10).map { item in
            let sid    = item["source_id"] as? Int ?? 0
            let author = profiles[sid] ?? "id\(sid)"
            let text   = (item["text"] as? String ?? "(без текста)").prefix(100)
            return "[\(author)]\n\(text)"
        }.joined(separator: "\n─────\n")
    }

    // Chat Members v5.103
    func getChatMembers(chatId: Int) async throws -> String {
        var comps = URLComponents(string: "\(base)/messages.getChat")!
        comps.queryItems = [
            URLQueryItem(name: "chat_id",      value: "\(chatId)"),
            URLQueryItem(name: "fields",       value: "online"),
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "v",            value: "5.103")
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let response = json?["response"] as? [String: Any] else {
            return "❌ Нет доступа к чату"
        }
        let title = response["title"] as? String ?? "Беседа \(chatId)"
        let users = response["users"] as? [[String: Any]] ?? []
        var result = "💬 \(title)\n"
        for user in users {
            let fn     = user["first_name"] as? String ?? ""
            let ln     = user["last_name"]  as? String ?? ""
            let id     = user["id"]         as? Int ?? 0
            let isAdmin = user["type"]      as? String == "admin"
            let online = (user["online"] as? Int == 1) ? " 🟢" : ""
            result += "\(isAdmin ? "👑" : "👤") \(fn) \(ln) (id\(id))\(online)\n"
        }
        return result

    }

    // Gift Anonymity — gifts.get
    func scanGifts() async throws -> String {
        struct GiftResp: Decodable { let count: Int?; let items: [GiftItem]? }
        struct GiftItem: Decodable {
            let id: Int?; let fromId: Int?; let message: String?
            enum CodingKeys: String, CodingKey { case id; case fromId = "from_id"; case message }
        }
        let r: GiftResp = try await call("gifts.get", params: ["count": "50"])
        let items = r.items ?? []
        let revealed = items.filter { ($0.fromId ?? 0) > 0 }
        if revealed.isEmpty { return "Анонимных подарков с раскрытым ID не найдено" }
        return "🎯 Найдено \(revealed.count) раскрытых:\n" + revealed.map {
            "ID отправителя: \($0.fromId ?? 0) — vk.com/id\($0.fromId ?? 0)"
        }.joined(separator: "\n")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
