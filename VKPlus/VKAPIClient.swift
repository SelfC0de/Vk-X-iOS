import Foundation

enum VKError: LocalizedError {
    case invalidToken; case api(Int, String); case network(String); case noData
    var errorDescription: String? {
        switch self {
        case .invalidToken:    return "Недействительный токен"
        case .api(_, let m):   return m
        case .network(let m):  return m
        case .noData:          return "Пустой ответ"
        }
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let response: T?; let error: EnvError?
}
private struct EnvError: Decodable {
    let errorCode: Int; let errorMsg: String
    enum CodingKeys: String, CodingKey { case errorCode = "error_code"; case errorMsg = "error_msg" }
}

final class VKAPIClient {
    static let shared = VKAPIClient()
    private(set) var token: String = ""
    private let base    = "https://api.vk.com/method"
    private let version = "5.199"
    private let decoder = JSONDecoder()
    var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    private init() { token = TokenStorage.shared.token ?? "" }
    func configure(token t: String) { token = t }
    func reset() { token = "" }

    private func call<T: Decodable>(_ method: String,
                                    params: [String: String] = [:],
                                    tokenOverride: String? = nil,
                                    versionOverride: String? = nil) async throws -> T {
        var comps = URLComponents(string: "\(base)/\(method)")!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "access_token", value: tokenOverride ?? token),
            URLQueryItem(name: "v",            value: versionOverride ?? version)
        ]
        comps.queryItems = items
        guard let url = comps.url else { throw VKError.network("Bad URL") }

        var req = URLRequest(url: url)
        let s = SettingsStore.shared
        if s.hardwareSpoof {
            let dev = HardwareSpoofing.generate()
            req.setValue(dev.userAgent, forHTTPHeaderField: "User-Agent")
            dev.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        } else {
            req.setValue(s.deviceUa, forHTTPHeaderField: "User-Agent")
        }

        let (data, _) = try await session.data(for: req)
        let envelope  = try decoder.decode(Envelope<T>.self, from: data)
        if let err = envelope.error {
            if err.errorCode == 5 { throw VKError.invalidToken }
            throw VKError.api(err.errorCode, err.errorMsg)
        }
        guard let result = envelope.response else { throw VKError.noData }
        return result
    }

    // raw JSON call (for methods returning non-standard responses)
    func rawCall(_ method: String,
                         params: [String: String] = [:],
                         versionOverride: String? = nil) async throws -> [String: Any] {
        var comps = URLComponents(string: "\(base)/\(method)")!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "v",            value: versionOverride ?? version)
        ]
        comps.queryItems = items
        guard let url = comps.url else { throw VKError.network("Bad URL") }
        let (data, _) = try await session.data(from: url)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    // MARK: - Raw call with custom headers (for verification endpoint)
    func rawCallWithHeaders(_ method: String,
                            params: [String: String] = [:],
                            headers: [String: String] = [:]) async throws -> [String: Any] {
        var comps = URLComponents(string: "\(base)/\(method)")!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "v", value: version)
        ]
        comps.queryItems = items
        guard let url = comps.url else { throw VKError.network("Bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // POST body
        let body = items.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        // Custom headers
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, _) = try await session.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    // MARK: - Get user verification via execute (Android UA for full verification_info)
    func getUserVerification(userId: Int) async throws -> VKVerificationInfo? {
        let code = """
        var u = \(userId);
        return API.users.get({
            'user_ids': u,
            'fields': 'verification_info,verified,is_verified,service_description',
            'v': '5.199',
            'extend': 1
        })[0];
        """
        let deviceId = (0..<16).map { _ in "0123456789abcdef".randomElement()! }.map(String.init).joined()
        let json = try await rawCallWithHeaders("execute", params: ["code": code], headers: [
            "User-Agent": "VKAndroidApp/8.55-12345 (Android 14; SDK 34; arm64-v8a; ru)",
            "X-VK-Android-Client": "new",
            "X-VK-Device-Id": deviceId,
            "X-VK-App-Build": "12345",
            "X-Get-User-Verification": "1"
        ])
        guard let response = json["response"] as? [String: Any] else { return nil }
        // Parse verification_info from response
        if let vi = response["verification_info"] as? [String: Any],
           let rawVerifs = vi["verifications"] as? [[String: Any]] {
            let verifs = rawVerifs.compactMap { v -> VKVerification? in
                guard let type = v["type"] as? String else { return nil }
                return VKVerification(type: type,
                                      priority: v["priority"] as? Int,
                                      name: v["name"] as? String)
            }
            return VKVerificationInfo(verifications: verifs)
        }
        // Fallback — check verified field
        if let verified = response["verified"] as? Int, verified == 1 {
            return VKVerificationInfo(verifications: [])
        }
        return nil
    }

    // MARK: - Proxy support
    func setProxy(_ entry: ProxyEntry?) {
        var config: URLSessionConfiguration
        if let e = entry {
            config = URLSessionConfiguration.default
            if e.type == "SOCKS5" {
                config.connectionProxyDictionary = [
                    "SOCKSEnable":   1,
                    "SOCKSProxy":    e.host,
                    "SOCKSPort":     e.port,
                    kCFStreamPropertySOCKSProxyHost as String: e.host,
                    kCFStreamPropertySOCKSProxyPort as String: e.port
                ]
            } else {
                // MTProto / HTTP fallback — kCFNetworkProxiesHTTPS* unavailable on iOS
                // Use string keys directly
                config.connectionProxyDictionary = [
                    "HTTPEnable":  1,
                    "HTTPProxy":   e.host,
                    "HTTPPort":    e.port,
                    "HTTPSEnable": 1,
                    "HTTPSProxy":  e.host,
                    "HTTPSPort":   e.port
                ]
            }
        } else {
            config = URLSessionConfiguration.default
            config.connectionProxyDictionary = [:]
        }
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
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
        let json = try await rawCall("users.get", params: [
            "fields": "photo_200,photo_100,online,status,verified,has_mobile,verification_info,city,followers_count,bdate"
        ])
        guard let items = json["response"] as? [[String: Any]],
              let dict = items.first,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let u = try? JSONDecoder().decode(VKUser.self, from: data)
        else { throw VKError.noData }
        return u
    }

    func getUserById(_ id: String) async throws -> VKUser {
        let json = try await rawCall("users.get", params: [
            "user_ids": id,
            "fields": "photo_200,photo_100,online,status,verified,has_mobile,verification_info,city,followers_count,screen_name"
        ])
        guard let items = json["response"] as? [[String: Any]],
              let dict = items.first,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let u = try? JSONDecoder().decode(VKUser.self, from: data)
        else { throw VKError.noData }
        return u
    }

    func searchUsers(query: String, count: Int = 20) async throws -> [VKUser] {
        let json = try await rawCall("users.search", params: [
            "q": query, "count": "\(count)", "fields": "photo_100,online,verified,has_mobile,city"
        ])
        guard let response = json["response"] as? [String: Any],
              let items = response["items"] as? [[String: Any]] else { return [] }
        let decoder = JSONDecoder()
        return items.compactMap { dict -> VKUser? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(VKUser.self, from: data)
        }
    }

    func resolveScreenName(_ name: String) async throws -> Int? {
        let json = try await rawCall("utils.resolveScreenName", params: ["screen_name": name])
        guard let r = json["response"] as? [String: Any],
              let type = r["type"] as? String, type == "user",
              let id = r["object_id"] as? Int else { return nil }
        return id
    }

    func getUsers(ids: String) async throws -> [VKUser] {
        let json = try await rawCall("users.get", params: [
            "user_ids": ids,
            "fields": "photo_100,photo_200,online,verified,has_mobile,verification_info,city,bdate,followers_count,status"
        ])
        guard let items = json["response"] as? [[String: Any]] else { return [] }
        let decoder = JSONDecoder()
        return items.compactMap { dict -> VKUser? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(VKUser.self, from: data)
        }
    }

    // MARK: - Friends
    func getFriends(count: Int = 200) async throws -> [VKUser] {
        let r: VKFriendsResponse = try await call("friends.get", params: [
            "fields": "photo_100,online,status,verified,has_mobile,verification_info",
            "order":  "hints", "count": "\(count)"
        ])
        return r.items
    }

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

    // MARK: - Dialogs
    func getDialogs(count: Int = 30) async throws -> [DialogItem] {
        let json = try await rawCall("messages.getConversations", params: [
            "count": "\(count)", "extended": "1", "fields": "photo_100,online"
        ])
        guard let response = json["response"] as? [String: Any] else { return [] }
        let items    = response["items"]    as? [[String: Any]] ?? []
        let rawProfs = response["profiles"] as? [[String: Any]] ?? []
        let rawGrps  = response["groups"]   as? [[String: Any]] ?? []

        // Build profile map: id -> (name, photo, online)
        var profMap = [Int: (name: String, photo: String?, online: Bool)]()
        for p in rawProfs {
            guard let id = p["id"] as? Int else { continue }
            let fn = p["first_name"] as? String ?? ""
            let ln = p["last_name"]  as? String ?? ""
            let ph = p["photo_100"]  as? String
            let on = (p["online"] as? Int) == 1
            profMap[id] = (fn + " " + ln, ph, on)
        }
        var grpMap = [Int: (name: String, photo: String?)]()
        for g in rawGrps {
            guard let id = g["id"] as? Int else { continue }
            grpMap[id] = (g["name"] as? String ?? "Сообщество", g["photo_100"] as? String)
        }

        return items.compactMap { item -> DialogItem? in
            guard let conv   = item["conversation"] as? [String: Any],
                  let peer   = conv["peer"]         as? [String: Any],
                  let peerId = peer["id"]            as? Int,
                  let pType  = peer["type"]          as? String,
                  let localId = peer["local_id"]     as? Int else { return nil }

            let lastMsg   = (item["last_message"] as? [String: Any])?["text"] as? String ?? ""
            let unread    = (conv["unread_count"] as? Int) ?? 0

            if pType == "user", let u = profMap[localId] {
                return DialogItem(id: peerId, name: u.name.trimmingCharacters(in: .whitespaces),
                                  avatar: u.photo, lastMessage: lastMsg,
                                  isOnline: u.online, unreadCount: unread, peerId: peerId)
            } else if pType == "group", let g = grpMap[abs(localId)] {
                return DialogItem(id: peerId, name: g.name, avatar: g.photo,
                                  lastMessage: lastMsg, isOnline: false, unreadCount: unread, peerId: peerId)
            } else if pType == "chat" {
                let title = (conv["chat_settings"] as? [String: Any])?["title"] as? String ?? "Беседа"
                let photo = ((conv["chat_settings"] as? [String: Any])?["photo"] as? [String: Any])?["photo_100"] as? String
                return DialogItem(id: peerId, name: title, avatar: photo,
                                  lastMessage: lastMsg, isOnline: false, unreadCount: unread, peerId: peerId)
            }
            return nil
        }
    }

    // MARK: - Messages
    func getMessages(peerId: Int, count: Int = 50) async throws -> [VKMessage] {
        let json = try await rawCall("messages.getHistory", params: [
            "peer_id": "\(peerId)", "count": "\(count)"
        ])
        guard let response = json["response"] as? [String: Any],
              let items = response["items"] as? [[String: Any]] else { return [] }
        let decoder = JSONDecoder()
        return items.compactMap { dict -> VKMessage? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(VKMessage.self, from: data)
        }
    }

    // MARK: - Upload photo to messages
    func uploadPhotoForMessage(peerId: Int, imageData: Data) async throws -> String {
        // 1. Get upload URL
        let urlJson = try await rawCall("photos.getMessagesUploadServer", params: ["peer_id": "\(peerId)"])
        guard let uploadUrl = (urlJson["response"] as? [String: Any])?["upload_url"] as? String else {
            throw VKError.api(0, "No upload URL")
        }
        // 2. Upload
        let uploaded = try await uploadMultipart(url: uploadUrl, data: imageData, name: "photo", filename: "photo.jpg", mimeType: "image/jpeg")
        guard let server = uploaded["server"],
              let photo  = uploaded["photo"],
              let hash   = uploaded["hash"] else { throw VKError.api(0, "Upload failed") }
        // 3. Save
        let saveJson = try await rawCall("photos.saveMessagesPhoto", params: [
            "server": server, "photo": photo, "hash": hash
        ])
        guard let items = saveJson["response"] as? [[String: Any]],
              let item  = items.first,
              let photoId  = item["id"] as? Int,
              let ownerId  = item["owner_id"] as? Int else { throw VKError.api(0, "Save failed") }
        return "photo\(ownerId)_\(photoId)"
    }

    // MARK: - Upload voice message (audio_message type)
    func uploadVoiceMessage(peerId: Int, data: Data) async throws -> String {
        let urlJson = try await rawCall("docs.getMessagesUploadServer", params: [
            "peer_id": "\(peerId)", "type": "audio_message"
        ])
        guard let uploadUrl = (urlJson["response"] as? [String: Any])?["upload_url"] as? String else {
            throw VKError.api(0, "No upload URL for voice")
        }
        let uploaded = try await uploadMultipart(url: uploadUrl, data: data, name: "file",
                                                 filename: "voice.m4a", mimeType: "audio/m4a")
        guard let file = uploaded["file"] else { throw VKError.api(0, "Voice upload failed") }
        let saveJson = try await rawCall("docs.save", params: ["file": file])
        guard let response = saveJson["response"] as? [String: Any],
              let obj = response["audio_message"] as? [String: Any],
              let docId  = obj["id"] as? Int,
              let ownerId = obj["owner_id"] as? Int else {
            throw VKError.api(0, "Voice save failed")
        }
        return "doc\(ownerId)_\(docId)"
    }

    // MARK: - Upload doc (video/audio/file) to messages
    func uploadDocForMessage(peerId: Int, data: Data, filename: String, mimeType: String) async throws -> String {
        // 1. Get upload URL
        let type = mimeType.hasPrefix("video") ? "video" : (mimeType.hasPrefix("audio") ? "audio_message" : "doc")
        let urlJson = try await rawCall("docs.getMessagesUploadServer", params: ["peer_id": "\(peerId)", "type": type])
        guard let uploadUrl = (urlJson["response"] as? [String: Any])?["upload_url"] as? String else {
            throw VKError.api(0, "No upload URL")
        }
        // 2. Upload
        let uploaded = try await uploadMultipart(url: uploadUrl, data: data, name: "file", filename: filename, mimeType: mimeType)
        guard let file = uploaded["file"] else { throw VKError.api(0, "Upload failed") }
        // 3. Save
        let saveJson = try await rawCall("docs.save", params: ["file": file, "title": filename])
        // Response can be {type: "doc"/"audio_message", doc/audio_message: {...}}
        guard let response = saveJson["response"] as? [String: Any] else { throw VKError.api(0, "Save failed") }
        let docType = response["type"] as? String ?? "doc"
        if let obj = response[docType] as? [String: Any],
           let docId = obj["id"] as? Int,
           let ownerId = obj["owner_id"] as? Int {
            return "\(docType)\(ownerId)_\(docId)"
        }
        throw VKError.api(0, "Save parse failed")
    }

    // MARK: - Multipart uploader
    private func uploadMultipart(url: String, data: Data, name: String, filename: String, mimeType: String) async throws -> [String: String] {
        guard let uploadUrl = URL(string: url) else { throw VKError.api(0, "Bad URL") }
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        var req = URLRequest(url: uploadUrl)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (respData, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] ?? [:]
        var result: [String: String] = [:]
        for (k, v) in json { result[k] = "\(v)" }
        return result
    }

    func sendMessage(peerId: Int, text: String, replyTo: Int? = nil, attachment: String? = nil) async throws -> Int {
        var params: [String: String] = [
            "peer_id":   "\(peerId)",
            "message":   text,
            "random_id": "\(Int.random(in: 1...Int.max))",
            "v":         version
        ]
        if let r = replyTo    { params["reply_to"]   = "\(r)" }
        if let a = attachment { params["attachment"] = a }
        let json = try await rawCall("messages.send", params: params)
        if let msgId = json["response"] as? Int { return msgId }
        if let err = (json["error"] as? [String: Any])?["error_msg"] as? String {
            throw VKError.api(0, err)
        }
        return 0
    }

    func editMessage(peerId: Int, messageId: Int, text: String) async throws {
        let json = try await rawCall("messages.edit", params: [
            "peer_id": "\(peerId)", "message_id": "\(messageId)", "message": text
        ])
        if let err = (json["error"] as? [String: Any])?["error_msg"] as? String {
            throw VKError.api(0, err)
        }
        // response == 1 means success, anything else is fine too
    }

    func deleteMessage(messageIds: [Int], forAll: Bool = true) async throws {
        let ids = messageIds.map(String.init).joined(separator: ",")
        let json = try await rawCall("messages.delete", params: [
            "message_ids": ids, "delete_for_all": forAll ? "1" : "0"
        ])
        if let err = (json["error"] as? [String: Any])?["error_msg"] as? String {
            throw VKError.api(0, err)
        }
    }

    // MARK: - Newsfeed
    struct NewsfeedPage {
        let items:    [VKWallPost]
        let profiles: [Int: VKUser]
        let groups:   [Int: VKGroup]
        let nextFrom: String?
    }

    func getNewsfeed(count: Int = 50, startFrom: String? = nil) async throws -> NewsfeedPage {
        struct NR: Decodable {
            let items:    [VKWallPost]
            let profiles: [VKUser]?
            let groups:   [VKGroup]?
            let nextFrom: String?
            enum CodingKeys: String, CodingKey {
                case items, profiles, groups; case nextFrom = "next_from"
            }
        }
        // filters=post shows posts from friends AND groups the user follows
        // return_banned=0 excludes hidden sources
        var params: [String: String] = [
            "filters":       "post",
            "count":         "\(count)",
            "return_banned": "0",
            "fields":        "photo_100,screen_name,name,first_name,last_name"
        ]
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
    // MARK: - Currency
    func getExchangeRate(base cur: String, target: String) async throws -> Double {
        let key = "fca_live_XEMzZbdOk47fgjrXN0c1Veo9HKTagxomnJu5CgJq"
        let urlStr = "https://api.freecurrencyapi.com/v1/latest?apikey=\(key)&base_currency=\(cur)&currencies=\(target)"
        guard let url = URL(string: urlStr) else { throw VKError.network("Bad URL") }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let rate = (json?["data"] as? [String: Double])?[target] else { throw VKError.noData }
        return rate
    }

    // MARK: - Account
    func setOffline() async throws {
        struct R: Decodable { let response: Int? }
        let _: R = try await call("account.setOffline")
    }

    // MARK: - Exploits

    func getStickerKeywords(userId: Int) async throws -> String {
        struct SKR: Decodable { let items: [SKItem]? }
        struct SKItem: Decodable {
            let words: [String]?
            let userStickers: [SKSticker]?
            enum CodingKeys: String, CodingKey { case words; case userStickers = "user_stickers" }
        }
        struct SKSticker: Decodable { let product: SKProduct? }
        struct SKProduct: Decodable { let title: String? }

        let r: SKR = try await call("store.getStickersKeywords",
                                    params: ["user_id": "\(userId)", "extended": "1"])
        let items = r.items ?? []
        if items.isEmpty { return "Данные не получены — метод ограничен" }
        let packs = Array(Set(
            items.compactMap { $0.userStickers }.flatMap { $0 }
                 .compactMap { $0.product?.title }.filter { !$0.isEmpty }
        ))
        let kw = Array(items.compactMap { $0.words }.flatMap { $0 }.prefix(10))
        var result = ""
        if !packs.isEmpty { result += "🎭 Стикерпаки (\(packs.count)):\n" + packs.map { "• \($0)" }.joined(separator: "\n") }
        if !kw.isEmpty    { result += (result.isEmpty ? "" : "\n") + "🔑 Ключевые слова: " + kw.joined(separator: ", ") }
        return result.isEmpty ? "Стикеры найдены, но данные скрыты" : result
    }

    func executeBypass(userId: Int) async throws -> String {
        let code = "var u=API.users.get({\"user_ids\":\"\(userId)\",\"fields\":\"last_seen,online\",\"v\":\"5.60\"});var f=API.friends.getMutual({\"target_uid\":\"\(userId)\",\"v\":\"5.60\"});return{\"user\":u,\"common\":f.length};"
        let json = try await rawCall("execute", params: ["code": code], versionOverride: "5.60")
        guard let response = json["response"] as? [String: Any] else {
            return "❌ " + ((json["error"] as? [String: Any])?["error_msg"] as? String ?? "Ошибка")
        }
        var result = ""
        if let users = response["user"] as? [[String: Any]], let u = users.first {
            result += "👤 \(u["first_name"] as? String ?? "") \(u["last_name"] as? String ?? "")\n"
            if let ls = u["last_seen"] as? [String: Any] {
                let time = ls["time"] as? Int ?? 0
                let platform = ls["platform"] as? Int ?? 0
                let names = ["","🌐 Мобильный сайт","📱 iPhone","📱 iPad","📱 Android","📱 Windows Phone","🖥 Windows 10","🌐 Web"]
                let pname = platform < names.count ? names[platform] : "❓"
                let df = DateFormatter(); df.locale = Locale(identifier: "ru_RU"); df.dateFormat = "d MMM HH:mm:ss"
                result += "🕐 \(df.string(from: Date(timeIntervalSince1970: TimeInterval(time))))\n📱 \(pname)\n"
            }
        }
        if let common = response["common"] as? Int { result += "👥 Общих друзей: \(common)" }
        return result.isEmpty ? "Нет данных" : result
    }

    func getPlatform(userId: Int) async throws -> String {
        let users: [VKUser] = try await call("users.get",
                                             params: ["user_ids": "\(userId)", "fields": "last_seen,online"])
        guard let u = users.first else { throw VKError.noData }
        var result = "👤 \(u.fullName)\n"
        if u.isOnline { result += "🟢 Сейчас онлайн\n" }
        result += "🔒 last_seen скрыт или недоступен"
        return result
    }

    func checkGroupMembership(userId: Int, groupIds: [Int]) async throws -> String {
        struct MR: Decodable { let response: Int? }
        struct GR: Decodable { let response: [GInfo]? }
        struct GInfo: Decodable { let id: Int; let name: String? }
        var result = ""
        for gid in groupIds {
            let mJson = try await rawCall("groups.isMember", params: ["group_id": "\(gid)", "user_id": "\(userId)"])
            let gJson = try await rawCall("groups.getById",  params: ["group_id": "\(gid)"])
            let isMember = (mJson["response"] as? Int) == 1
            let name = ((gJson["response"] as? [[String: Any]])?.first?["name"] as? String) ?? "Группа \(gid)"
            result += "\(isMember ? "✅" : "❌") \(name) (id\(gid))\n"
        }
        return result.isEmpty ? "Нет результатов" : result
    }

    func contentFilterBypass(userId: Int) async throws -> String {
        let users: [VKUser] = try await call("users.get",
                                             params: ["user_ids": "\(userId)", "fields": "photo_200,status,verified"])
        guard let u = users.first else { throw VKError.noData }
        return "✅ \(u.fullName)\nID: \(u.id)\nСтатус: \(u.status ?? "-")"
    }

    func getLegacyNewsfeed() async throws -> String {
        let json = try await rawCall("newsfeed.get",
                                     params: ["filters": "post", "count": "15"],
                                     versionOverride: "5.92")
        guard let response = json["response"] as? [String: Any] else { return "❌ Ошибка запроса" }
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
            let text   = String((item["text"] as? String ?? "(без текста)").prefix(100))
            return "[\(author)]\n\(text)"
        }.joined(separator: "\n─────\n")
    }

    func getChatMembers(chatId: Int) async throws -> String {
        let json = try await rawCall("messages.getChat",
                                     params: ["chat_id": "\(chatId)", "fields": "online"],
                                     versionOverride: "5.103")
        guard let response = json["response"] as? [String: Any] else { return "❌ Нет доступа к чату" }
        let title = response["title"] as? String ?? "Беседа \(chatId)"
        let users = response["users"] as? [[String: Any]] ?? []
        var result = "💬 \(title)\n"
        for user in users {
            let fn      = user["first_name"] as? String ?? ""
            let ln      = user["last_name"]  as? String ?? ""
            let id      = user["id"]         as? Int ?? 0
            let isAdmin = user["type"]       as? String == "admin"
            let online  = (user["online"]    as? Int == 1) ? " 🟢" : ""
            result += "\(isAdmin ? "👑" : "👤") \(fn) \(ln) (id\(id))\(online)\n"
        }
        return result
    }

    func scanGifts() async throws -> String {
        struct GiftResp: Decodable { let count: Int?; let items: [GiftItem]? }
        struct GiftItem: Decodable {
            let id: Int?; let fromId: Int?; let message: String?
            enum CodingKeys: String, CodingKey { case id; case fromId = "from_id"; case message }
        }
        let r: GiftResp = try await call("gifts.get", params: ["count": "50"])
        let items    = r.items ?? []
        let revealed = items.filter { ($0.fromId ?? 0) > 0 }
        if revealed.isEmpty { return "Анонимных подарков с раскрытым ID не найдено" }
        return "🎯 Найдено \(revealed.count) раскрытых:\n" + revealed.map {
            "ID отправителя: \($0.fromId ?? 0) — vk.com/id\($0.fromId ?? 0)"
        }.joined(separator: "\n")
    }
}
