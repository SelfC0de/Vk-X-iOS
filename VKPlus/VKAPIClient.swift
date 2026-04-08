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
        let s = SettingsStore.shared
        // Ghost Online / Force Offline: tell VK server not to update online status
        if s.ghostOnline || s.forceOffline {
            items.append(URLQueryItem(name: "online", value: "0"))
        }
        comps.queryItems = items
        guard let url = comps.url else { throw VKError.network("Bad URL") }

        var req = URLRequest(url: url)
        let mode = s.currentSpoofMode
        if mode != .off {
            let dev = HardwareSpoofing.generate(mode: mode)
            req.setValue(dev.userAgent, forHTTPHeaderField: "User-Agent")
            if mode.isAndroid {
                dev.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            }
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
        let _s = SettingsStore.shared
        if _s.ghostOnline || _s.forceOffline {
            items.append(URLQueryItem(name: "online", value: "0"))
        }
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


    // MARK: - Status
    func getStatus() async throws -> String {
        let json = try await rawCall("status.get", params: [:])
        return (json["response"] as? [String: Any])?["text"] as? String ?? ""
    }

    func setStatus(_ text: String) async throws {
        _ = try await rawCall("status.set", params: ["text": text])
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
            params: ["fields": "photo_200,photo_100,online,status,verified,last_seen"],
            tokenOverride: t)
        guard let u = users.first else { throw VKError.noData }
        return u
    }

    // MARK: - Profile
    func getProfile() async throws -> VKUser {
        let json = try await rawCall("users.get", params: [
            "fields": "photo_200,photo_100,online,status,verified,has_mobile,verification_info,city,followers_count,bdate,last_seen"
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
            "count": "\(count)", "extended": "1", "fields": "photo_100,online,last_seen"
        ])
        guard let response = json["response"] as? [String: Any] else { return [] }
        let items    = response["items"]    as? [[String: Any]] ?? []
        let rawProfs = response["profiles"] as? [[String: Any]] ?? []
        let rawGrps  = response["groups"]   as? [[String: Any]] ?? []

        // Build profile map: id -> (name, photo, online, platform)
        var profMap = [Int: (name: String, photo: String?, online: Bool, platform: Int?)]()
        let myId = TokenStorage.shared.cachedUserId ?? 0
        let s = SettingsStore.shared
        for p in rawProfs {
            guard let id = p["id"] as? Int else { continue }
            let fn = p["first_name"] as? String ?? ""
            let ln = p["last_name"]  as? String ?? ""
            let ph = p["photo_100"]  as? String
            // Never show self as online when ghost/forceOffline is on
            // Also filter self from appearing as a "contact" with online dot
            var on = (p["online"] as? Int) == 1
            if id == myId { on = false }
            if s.ghostOnline || s.forceOffline { on = false }
            let platform = (p["last_seen"] as? [String: Any])?["platform"] as? Int
            profMap[id] = (fn + " " + ln, ph, on, platform)
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
                                  isOnline: u.online, unreadCount: unread, peerId: peerId,
                                  platform: u.platform)
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
        let ghostMode = SettingsStore.shared.ghostMode
        var params: [String: String] = ["peer_id": "\(peerId)", "count": "\(count)"]
        if ghostMode { params["mark_as_read"] = "0" }
        let json = try await rawCall("messages.getHistory", params: params)
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
        guard let uploadUrl = (urlJson["response"] as? [String: Any])?["upload_url"] as? String,
              !uploadUrl.isEmpty else {
            let msg = (urlJson["error"] as? [String: Any])?["error_msg"] as? String ?? "No upload URL for voice"
            throw VKError.api(0, msg)
        }
        let file = try await uploadMultipartRaw(url: uploadUrl, data: data, name: "file",
                                                filename: "voice.m4a", mimeType: "audio/m4a")
        let saveJson = try await rawCall("docs.save", params: ["file": file])
        // docs.save response for audio_message
        let responseVal = saveJson["response"]
        let responseDict: [String: Any]?
        if let dict = responseVal as? [String: Any]       { responseDict = dict }
        else if let arr = responseVal as? [[String: Any]] { responseDict = arr.first }
        else                                               { responseDict = nil }
        guard let response = responseDict,
              let obj      = response["audio_message"] as? [String: Any],
              let docId    = obj["id"]       as? Int,
              let ownerId  = obj["owner_id"] as? Int else {
            let msg = (saveJson["error"] as? [String: Any])?["error_msg"] as? String ?? "Voice save failed"
            throw VKError.api(0, msg)
        }
        return "doc\(ownerId)_\(docId)"
    }


    // MARK: - Upload audio file (mp3/ogg) via audio.upload + audio.add
    func uploadAudioFile(data: Data, filename: String, artist: String, title: String) async throws -> String {
        // 1. Get audio upload server URL
        let serverJson = try await rawCall("audio.getUploadServer", params: [:])
        if let apiErr = serverJson["error"] as? [String: Any],
           let errMsg = apiErr["error_msg"] as? String {
            throw VKError.api((apiErr["error_code"] as? Int) ?? 0, errMsg)
        }
        guard let uploadUrl = (serverJson["response"] as? [String: Any])?["upload_url"] as? String,
              !uploadUrl.isEmpty else {
            throw VKError.api(0, "audio.getUploadServer: нет URL")
        }

        // 2. Upload mp3
        let fileToken = try await uploadMultipartRaw(
            url: uploadUrl, data: data, name: "file", filename: filename, mimeType: "audio/mpeg")

        // 3. Save via audio.save
        // fileToken is JSON string: {"server":...,"audio":...,"hash":...}
        // Parse it to extract server, audio, hash
        guard let tokenData = fileToken.data(using: .utf8),
              let tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let server    = tokenJson["server"].map({ "\($0)" }),
              let audio     = tokenJson["audio"]  as? String,
              let hash      = tokenJson["hash"]   as? String else {
            throw VKError.api(0, "Audio token parse failed: \(fileToken)")
        }
        let saveParams: [String: String] = [
            "server": server,
            "audio":  audio,
            "hash":   hash,
            "artist": artist,
            "title":  title
        ]
        let saveJson = try await rawCall("audio.save", params: saveParams)
        if let apiErr = saveJson["error"] as? [String: Any],
           let errMsg = apiErr["error_msg"] as? String {
            throw VKError.api((apiErr["error_code"] as? Int) ?? 0, errMsg)
        }
        guard let resp    = saveJson["response"] as? [String: Any],
              let audioId = resp["id"]       as? Int,
              let ownerId = resp["owner_id"] as? Int else {
            throw VKError.api(0, "audio.save parse failed: \(saveJson)")
        }
        return "audio\(ownerId)_\(audioId)"
    }

    // MARK: - Upload doc (video/audio/file) to messages
    func uploadDocForMessage(peerId: Int, data: Data, filename: String, mimeType: String) async throws -> String {
        let isVideo = mimeType.hasPrefix("video")

        // 1. Get upload URL
        // audio/doc: docs.getUploadServer — accepts any file type
        // video: docs.getMessagesUploadServer with type=video
        let urlJson: [String: Any]
        if isVideo {
            urlJson = try await rawCall("docs.getMessagesUploadServer",
                                        params: ["peer_id": "\(peerId)", "type": "video"])
        } else {
            // docs.getUploadServer accepts audio, docs, etc. without filetype restrictions
            urlJson = try await rawCall("docs.getUploadServer", params: [:])
        }

        // Check for error in response
        if let apiErr = urlJson["error"] as? [String: Any],
           let errMsg = apiErr["error_msg"] as? String {
            throw VKError.api((apiErr["error_code"] as? Int) ?? 0, errMsg)
        }

        guard let uploadUrl = (urlJson["response"] as? [String: Any])?["upload_url"] as? String,
              !uploadUrl.isEmpty else {
            throw VKError.api(0, "Нет URL загрузки. Ответ: \(urlJson)")
        }

        // 2. Upload multipart (bypasses PrivacyURLProtocol)
        let fileToken = try await uploadMultipartRaw(
            url: uploadUrl, data: data, name: "file", filename: filename, mimeType: mimeType)

        // 3. Save
        let titleNoExt = (filename as NSString).deletingPathExtension
        let saveJson   = try await rawCall("docs.save", params: ["file": fileToken, "title": titleNoExt])

        if let apiErr = saveJson["error"] as? [String: Any],
           let errMsg = apiErr["error_msg"] as? String {
            throw VKError.api((apiErr["error_code"] as? Int) ?? 0, errMsg)
        }

        // Parse response — can be dict or array
        let responseVal  = saveJson["response"]
        let responseDict: [String: Any]?
        if let dict = responseVal as? [String: Any]       { responseDict = dict }
        else if let arr = responseVal as? [[String: Any]] { responseDict = arr.first }
        else                                               { responseDict = nil }

        guard let response = responseDict else {
            throw VKError.api(0, "Save: пустой ответ \(saveJson)")
        }
        let docType = response["type"] as? String ?? "doc"
        if let obj     = response[docType] as? [String: Any],
           let docId   = obj["id"]       as? Int,
           let ownerId = obj["owner_id"] as? Int {
            return "\(docType)\(ownerId)_\(docId)"
        }
        throw VKError.api(0, "Save parse: \(response)")
    }

    // MARK: - Multipart uploader — returns "file" token string from VK upload server
    private func uploadMultipartRaw(url: String, data: Data, name: String, filename: String, mimeType: String) async throws -> String {
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
        req.timeoutInterval = 120
        // Bypass PrivacyURLProtocol — upload server is not VK API
        let cfg = URLSessionConfiguration.default
        cfg.protocolClasses = (cfg.protocolClasses ?? []).filter { $0 != PrivacyURLProtocol.self }
        cfg.timeoutIntervalForRequest  = 120
        cfg.timeoutIntervalForResource = 300
        let session = URLSession(configuration: cfg)
        let (respData, _) = try await session.data(for: req)
        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] ?? [:]
        if let file = json["file"] as? String, !file.isEmpty { return file }
        throw VKError.api(0, "Upload server error: \(json)")
    }

    // Legacy wrapper kept for voice message uploader
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
        for (k, v) in json { if let s = v as? String { result[k] = s } else { result[k] = "\(v)" } }
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

    func deleteMessage(messageIds: [Int], peerId: Int, forAll: Bool = true) async throws {
        let ids  = messageIds.map(String.init).joined(separator: ",")
        let json = try await rawCall("messages.delete", params: [
            "message_ids":    ids,
            "peer_id":        "\(peerId)",
            "delete_for_all": forAll ? "1" : "0",
            "spam":           "0"
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

    func getNewsfeed(count: Int = 50, startFrom: String? = nil, startTime: Int? = nil) async throws -> NewsfeedPage {
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
        if let st = startTime { params["start_time"] = "\(st)" }
        let r: NR = try await call("newsfeed.get", params: params)
        let profileMap = Dictionary(uniqueKeysWithValues: (r.profiles ?? []).map { ($0.id, $0) })
        let groupMap   = Dictionary(uniqueKeysWithValues: (r.groups   ?? []).map { ($0.id, $0) })
        return NewsfeedPage(items: r.items, profiles: profileMap, groups: groupMap, nextFrom: r.nextFrom)
    }


    // MARK: - Video
    func getVideo(ownerId: Int, videoId: Int) async throws -> VKVideoAttachment? {
        let key = "\(ownerId)_\(videoId)"
        let json = try await rawCall("video.get", params: [
            "videos": key, "extended": "1"
        ])
        guard let resp = json["response"] as? [String: Any],
              let items = resp["items"] as? [[String: Any]],
              let item  = items.first else { return nil }

        // Parse files dict → prefer best quality
        var directUrl: String? = nil
        if let files = item["files"] as? [String: Any] {
            for q in ["mp4_1080","mp4_720","mp4_480","mp4_360","mp4_240"] {
                if let u = files[q] as? String, !u.isEmpty { directUrl = u; break }
            }
        }
        let playerUrl = item["player"] as? String

        return VKVideoAttachment(
            id:       (item["id"] as? Int) ?? videoId,
            ownerId:  (item["owner_id"] as? Int) ?? ownerId,
            title:    item["title"] as? String,
            photo320: item["photo_320"] as? String,
            photo800: item["photo_800"] as? String,
            duration: item["duration"] as? Int,
            player:   playerUrl,
            files:    nil,    // already extracted above
            _directUrl: directUrl
        )
    }


    // MARK: - Groups (Communities)
    func getMyGroups(count: Int = 100, offset: Int = 0) async throws -> [VKGroup] {
        let json = try await rawCall("groups.get", params: [
            "extended": "1", "count": "\(count)", "offset": "\(offset)",
            "fields": "photo_100,photo_200,members_count,description,activity,is_member,is_closed,screen_name"
        ])
        guard let resp = json["response"] as? [String: Any],
              let items = resp["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { parseGroup($0) }
    }

    func searchGroups(query: String, count: Int = 50) async throws -> [VKGroup] {
        let json = try await rawCall("groups.search", params: [
            "q": query, "count": "\(count)", "type": "group,page,event",
            "fields": "photo_100,photo_200,members_count,description,activity,is_member,is_closed,screen_name"
        ])
        guard let resp = json["response"] as? [String: Any],
              let items = resp["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { parseGroup($0) }
    }

    func getGroupById(groupId: Int) async throws -> VKGroup? {
        let json = try await rawCall("groups.getById", params: [
            "group_id": "\(groupId)",
            "fields": "photo_100,photo_200,members_count,description,activity,is_member,is_closed,screen_name"
        ])
        if let resp = json["response"] as? [String: Any],
           let items = resp["groups"] as? [[String: Any]],
           let item = items.first {
            return parseGroup(item)
        }
        // Older API may return array directly
        if let arr = json["response"] as? [[String: Any]], let item = arr.first {
            return parseGroup(item)
        }
        return nil
    }

    // Shared wall response decoder
    private struct WallResponse: Decodable {
        let items: [VKWallPost]; let profiles: [VKUser]?; let groups: [VKGroup]?
    }
    private func wallPage(_ r: WallResponse) -> NewsfeedPage {
        let pm = Dictionary(uniqueKeysWithValues: (r.profiles ?? []).map { ($0.id, $0) })
        let gm = Dictionary(uniqueKeysWithValues: (r.groups   ?? []).map { ($0.id, $0) })
        return NewsfeedPage(items: r.items, profiles: pm, groups: gm, nextFrom: nil)
    }

    func getUserWall(userId: Int, count: Int = 20, offset: Int = 0) async throws -> NewsfeedPage {
        let r: WallResponse = try await call("wall.get", params: [
            "owner_id": "\(userId)", "count": "\(count)", "offset": "\(offset)",
            "extended": "1", "fields": "photo_100,screen_name,name,first_name,last_name"
        ])
        return wallPage(r)
    }

    func getUnreadCount() async throws -> Int {
        // account.getCounters: try both field names across API versions
        let json = try await rawCall("account.getCounters", params: ["filter": "messages"])
        if let resp = json["response"] as? [String: Any] {
            // newer API uses "new_messages", older uses "messages"
            if let n = resp["new_messages"] as? Int { return n }
            if let n = resp["messages"]     as? Int { return n }
        }
        // Fallback: sum unread_count from conversations
        let convJson = try await rawCall("messages.getConversations", params: [
            "count": "20", "filter": "unread", "extended": "0"
        ])
        if let resp = convJson["response"] as? [String: Any],
           let count = resp["count"] as? Int {
            return count
        }
        return 0
    }

    func getGroupWall(groupId: Int, count: Int = 20, offset: Int = 0) async throws -> NewsfeedPage {
        let r: WallResponse = try await call("wall.get", params: [
            "owner_id": "-\(groupId)", "count": "\(count)", "offset": "\(offset)",
            "extended": "1",
            "fields": "photo_100,screen_name,name,first_name,last_name"
        ])
        let pm = Dictionary(uniqueKeysWithValues: (r.profiles ?? []).map { ($0.id, $0) })
        let gm = Dictionary(uniqueKeysWithValues: (r.groups   ?? []).map { ($0.id, $0) })
        return NewsfeedPage(items: r.items, profiles: pm, groups: gm, nextFrom: nil)
    }

    func joinGroup(groupId: Int) async throws {
        _ = try await rawCall("groups.join", params: ["group_id": "\(groupId)"])
    }

    func leaveGroup(groupId: Int) async throws {
        _ = try await rawCall("groups.leave", params: ["group_id": "\(groupId)"])
    }

    private func parseGroup(_ d: [String: Any]) -> VKGroup? {
        guard let id = d["id"] as? Int, let name = d["name"] as? String else { return nil }
        return VKGroup(
            id: id, name: name,
            photo100:     d["photo_100"] as? String,
            photo200:     d["photo_200"] as? String,
            membersCount: d["members_count"] as? Int,
            description:  d["description"] as? String,
            activity:     d["activity"] as? String,
            isMember:     d["is_member"] as? Int,
            isAdmin:      d["is_admin"] as? Int,
            isClosed:     d["is_closed"] as? Int,
            screenName:   d["screen_name"] as? String
        )
    }

    // MARK: - Likes
    private struct LikesResponse: Decodable { let likes: Int? }

    func addLike(ownerId: Int, itemId: Int) async throws -> Int {
        let r: LikesResponse = try await call("likes.add", params: ["type": "post", "owner_id": "\(ownerId)", "item_id": "\(itemId)"])
        return r.likes ?? 0
    }

    func deleteLike(ownerId: Int, itemId: Int) async throws -> Int {
        let r: LikesResponse = try await call("likes.delete", params: ["type": "post", "owner_id": "\(ownerId)", "item_id": "\(itemId)"])
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



    func getPoll(pollId: Int, ownerId: Int) async throws -> VKPoll? {
        struct PR: Decodable { let response: VKPoll? }
        let json = try await rawCall("polls.getById", params: [
            "poll_id":  "\(pollId)",
            "owner_id": "\(ownerId)",
            "extended": "1",
            "fields":   "photo_200"
        ])
        guard let resp = json["response"] as? [String: Any],
              let id       = resp["id"]        as? Int,
              let ownerId  = resp["owner_id"]  as? Int,
              let question = resp["question"]  as? String,
              let votes    = resp["votes"]     as? Int,
              let answersRaw = resp["answers"] as? [[String: Any]]
        else { return nil }

        let answers = answersRaw.compactMap { a -> VKPollAnswer? in
            guard let aid  = a["id"]    as? Int,
                  let text = a["text"]  as? String,
                  let av   = a["votes"] as? Int,
                  let rate = a["rate"]  as? Double
            else { return nil }
            return VKPollAnswer(id: aid, text: text, votes: av, rate: rate)
        }
        // answer_ids — array of Int the user voted for
        let answerIds: [Int]?
        if let arr = resp["answer_ids"] as? [Int] { answerIds = arr }
        else if let single = resp["answer_id"] as? Int { answerIds = [single] }
        else { answerIds = nil }

        return VKPoll(id: id, ownerId: ownerId, question: question, votes: votes,
                      answers: answers,
                      anonymous: resp["anonymous"] as? Int,
                      multiple:  resp["multiple"]  as? Int,
                      closed:    resp["is_closed"] as? Int,
                      endDate:   resp["end_date"]  as? Int,
                      answerIds: answerIds,
                      canVote:   resp["can_vote"]  as? Int)
    }


    // Direct typing signal — bypasses PrivacyEngine URLProtocol
    func sendTypingDirect(peerId: Int, type: String = "typing") async {
        guard let token = TokenStorage.shared.token else { return }
        guard let url = URL(string: "https://api.vk.com/method/messages.setActivity") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "peer_id=\(peerId)&type=\(type)&v=5.199&access_token=\(token)"
        req.httpBody = body.data(using: .utf8)
        // Bypass PrivacyEngine URLProtocol by stripping it from protocol classes
        let cfg = URLSessionConfiguration.default
        cfg.protocolClasses = (cfg.protocolClasses ?? []).filter { $0 != PrivacyURLProtocol.self }
        let session = URLSession(configuration: cfg)
        if let (data, _) = try? await session.data(for: req),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Log error for debugging if response contains error
            if let err = json["error"] as? [String: Any] {
                print("[TypeStatus] setActivity error:", err["error_msg"] ?? "unknown")
            }
        }
    }




    // MARK: - Poll voting
    func addPollVote(pollId: Int, ownerId: Int, answerIds: [Int]) async throws -> Bool {
        let ids = answerIds.map { String($0) }.joined(separator: ",")
        let json = try await rawCall("polls.addVote", params: [
            "poll_id":    "\(pollId)",
            "owner_id":   "\(ownerId)",
            "answer_ids": ids
        ])
        return (json["response"] as? Int) == 1
    }

    func deletePollVote(pollId: Int, ownerId: Int, answerId: Int) async throws -> Bool {
        let json = try await rawCall("polls.deleteVote", params: [
            "poll_id":   "\(pollId)",
            "owner_id":  "\(ownerId)",
            "answer_id": "\(answerId)"
        ])
        return (json["response"] as? Int) == 1
    }

    // MARK: - Last Activity (точное время, не округлённое)
    func getLastActivity(userId: Int) async throws -> String {
        let json = try await rawCall("messages.getLastActivity", params: ["user_id": "\(userId)"])
        guard let resp = json["response"] as? [String: Any] else { return "Недоступно" }
        let online = (resp["online"] as? Int) ?? 0
        if online == 1 { return "Сейчас онлайн" }
        guard let time = resp["time"] as? Int, time > 0 else { return "Недоступно" }
        let date = Date(timeIntervalSince1970: TimeInterval(time))
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            df.dateFormat = "Сегодня в HH:mm"
        } else if cal.isDateInYesterday(date) {
            df.dateFormat = "Вчера в HH:mm"
        } else if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            df.dateFormat = "d MMMM в HH:mm"
        } else {
            df.dateFormat = "d MMMM yyyy в HH:mm"
        }
        return "Был(а) в сети: \(df.string(from: date))"
    }

    // MARK: - Friends requests (входящие/исходящие)
    func getFriendRequests(out: Bool = false) async throws -> [(id: Int, name: String, photo: String?, mutual: Int)] {
        let json = try await rawCall("friends.getRequests", params: [
            "extended": "1", "out": out ? "1" : "0",
            "fields": "photo_100,first_name,last_name,common_count"
        ])
        guard let resp = json["response"] as? [String: Any],
              let items = resp["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { d in
            guard let id = d["id"] as? Int else { return nil }
            let name = "\(d["first_name"] as? String ?? "") \(d["last_name"] as? String ?? "")".trimmingCharacters(in: .whitespaces)
            let photo = d["photo_100"] as? String
            let mutual = d["common_count"] as? Int ?? 0
            return (id: id, name: name, photo: photo, mutual: mutual)
        }
    }

    // MARK: - Recent friends
    func getRecentFriends() async throws -> [VKUser] {
        let json = try await rawCall("friends.getRecent", params: ["count": "20"])
        guard let resp = json["response"] as? [String: Any],
              let items = resp["items"] as? [Int] else {
            // Older API returns plain array
            let arr = json["response"] as? [Int] ?? []
            if arr.isEmpty { return [] }
            let idsStr = arr.prefix(20).map { "\($0)" }.joined(separator: ",")
            let users = try await rawCall("users.get", params: ["user_ids": idsStr, "fields": "photo_100,online,last_seen"])
            return (users["response"] as? [[String: Any]])?.compactMap { dict in
                guard let data = try? JSONSerialization.data(withJSONObject: dict),
                      let u = try? JSONDecoder().decode(VKUser.self, from: data) else { return nil }
                return u
            } ?? []
        }
        if items.isEmpty { return [] }
        let idsStr = items.prefix(20).map { "\($0)" }.joined(separator: ",")
        let users = try await rawCall("users.get", params: ["user_ids": idsStr, "fields": "photo_100,online,last_seen"])
        return (users["response"] as? [[String: Any]])?.compactMap { dict in
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let u = try? JSONDecoder().decode(VKUser.self, from: data) else { return nil }
            return u
        } ?? []
    }

    // MARK: - Blacklist check
    func checkBlacklist(userId: Int) async throws -> String {
        let json = try await rawCall("users.get", params: [
            "user_ids": "\(userId)",
            "fields": "blacklisted,blacklisted_by_me,first_name,last_name,can_write_private_message"
        ])
        guard let items = json["response"] as? [[String: Any]], let u = items.first else { return "Нет данных" }
        let name = "\(u["first_name"] as? String ?? "") \(u["last_name"] as? String ?? "")".trimmingCharacters(in: .whitespaces)
        let blockedMe  = (u["blacklisted"]    as? Int) == 1
        let iBlockedHim = (u["blacklisted_by_me"] as? Int) == 1
        let canWrite   = (u["can_write_private_message"] as? Int) == 1
        var lines = ["👤 Пользователь: \(name)"]
        lines.append(blockedMe    ? "🚫 Этот пользователь заблокировал тебя" : "✅ Ты не в его чёрном списке")
        lines.append(iBlockedHim  ? "🔒 Ты заблокировал(а) этого пользователя" : "✅ Ты его не блокировал(а)")
        lines.append(canWrite     ? "💬 Написать сообщение: можно" : "💬 Написать сообщение: нельзя")
        return lines.joined(separator: "\n")
    }

    // MARK: - Stories download
    func getStoriesDownloadUrls(userId: Int) async throws -> [(type: String, url: String, date: Int)] {
        let json = try await rawCall("stories.get", params: [
            "owner_id": "\(userId)", "extended": "0"
        ])
        guard let resp = json["response"] as? [String: Any],
              let items = resp["items"] as? [[String: Any]] else { return [] }
        var result: [(type: String, url: String, date: Int)] = []
        for group in items {
            let stories = group["stories"] as? [[String: Any]] ?? (group["items"] as? [[String: Any]] ?? [])
            for s in stories {
                let date = s["date"] as? Int ?? 0
                if let video = s["video"] as? [String: Any] {
                    // Video story
                    let files = video["files"] as? [String: Any] ?? [:]
                    for q in ["mp4_1080","mp4_720","mp4_480","mp4_240"] {
                        if let url = files[q] as? String { result.append((type: "video", url: url, date: date)); break }
                    }
                } else if let photo = s["photo"] as? [String: Any] {
                    // Photo story
                    let sizes = photo["sizes"] as? [[String: Any]] ?? []
                    if let last = sizes.last, let url = last["url"] as? String {
                        result.append((type: "photo", url: url, date: date))
                    }
                }
            }
        }
        return result
    }

    // MARK: - Phantom View (stats.trackVisitor)
    func phantomVisit(userId: Int) async throws -> Bool {
        // Visit as another user — sends trackVisitor to their profile
        let json = try await rawCall("stats.trackVisitor", params: ["id": "\(userId)"])
        return (json["response"] as? Int) == 1
    }

    // MARK: - Short links
    func getShortLink(url: String, private_stat: Bool = true) async throws -> String {
        let json = try await rawCall("utils.getShortLink", params: [
            "url": url, "private": private_stat ? "1" : "0"
        ])
        guard let resp = json["response"] as? [String: Any],
              let short = resp["short_url"] as? String else { throw VKError.noData }
        return short
    }

    func getLinkStats(key: String) async throws -> String {
        // key = part after vk.cc/
        let json = try await rawCall("utils.getLinkStats", params: [
            "key": key, "access_key": key, "interval": "forever", "intervals_count": "1", "extended": "0"
        ])
        guard let resp = json["response"] as? [String: Any] else { return "Нет данных" }
        let stats = (resp["stats"] as? [[String: Any]])?.first
        let views = stats?["views"] as? Int ?? 0
        return "👁 Переходов всего: \(views)"
    }

    func searchMessages(query: String, peerId: Int? = nil, count: Int = 20) async throws -> [VKMessage] {
        var params: [String: String] = ["q": query, "count": "\(count)", "extended": "0"]
        if let pid = peerId { params["peer_id"] = "\(pid)" }
        struct SR: Decodable { let items: [VKMessage]? }
        let r: SR = try await call("messages.search", params: params)
        return r.items ?? []
    }

    func getAccountInfo() async throws -> String {
        let json = try await rawCall("account.getInfo", params: [:])
        guard let resp = json["response"] as? [String: Any] else { return "Нет данных" }
        var lines: [String] = []
        if let country = resp["country"]      as? String { lines.append("🌍 Страна: \(country)") }
        if let lang    = resp["lang"]         as? Int    { lines.append("🌐 Язык: \(lang)") }
        if let no2fa   = resp["no_wall_replies"] as? Int { lines.append("📝 Комментарии к стене: \(no2fa == 0 ? "вкл" : "выкл")") }
        if let intro   = resp["intro"]        as? Int    { lines.append("👋 Intro: \(intro)") }
        if let own     = resp["own_posts_default"] as? Int { lines.append("📌 Посты по умолчанию: \(own == 1 ? "мои" : "все")") }
        // 2FA status via account.getProfileInfo
        let pi = try? await rawCall("account.getProfileInfo", params: [:])
        if let r2 = pi?["response"] as? [String: Any] {
            if let phone = r2["phone"] as? String { lines.append("📱 Телефон: \(phone)") }
            if let name  = r2["first_name"] as? String,
               let ln    = r2["last_name"]  as? String { lines.append("👤 Имя: \(name) \(ln)") }
            if let bdate = r2["bdate"]      as? String { lines.append("🎂 Дата рождения: \(bdate)") }
            if let rel   = r2["relation"]   as? Int    {
                let rels = ["", "Одинок(а)", "В отношениях", "Помолвлен(а)", "Женат/Замужем", "Всё сложно", "В активном поиске", "Влюблён(а)", "В гражданском браке"]
                if rel < rels.count { lines.append("❤️ Отношения: \(rels[rel])") }
            }
        }
        return lines.isEmpty ? "Нет данных" : lines.joined(separator: "\n")
    }

    func getFirstMessage(userId: Int) async throws -> String {
        // Get first message via reverse history
        let json = try await rawCall("messages.getHistory", params: [
            "peer_id": "\(userId)", "count": "1", "rev": "1", "extended": "0"
        ])
        guard let resp   = json["response"] as? [String: Any],
              let items  = resp["items"]    as? [[String: Any]],
              let first  = items.first else { return "Переписка пуста или недоступна" }
        let text    = first["text"]   as? String ?? "(без текста)"
        let fromId  = first["from_id"] as? Int ?? 0
        let date    = first["date"]   as? Int ?? 0
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMM yyyy, HH:mm"
        let dateStr = df.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
        let who = fromId > 0 ? "от вас" : "от собеседника"
        return "📅 Первое сообщение: \(dateStr)\n📨 Кто написал: \(who)\n💬 \(text)"
    }

    func viewBlockedProfile(userId: Int) async throws -> (user: VKUser?, result: String) {
        // Method 1: execute() runs server-side — bypasses client-level blocks
        let fields = "photo_200,photo_100,status,online,last_seen,followers_count,bdate,city,verified"
        let code = """
var u=API.users.get({"user_ids":"\(userId)","fields":"\(fields)","v":"5.131"});
var m=API.friends.getMutual({"target_uid":"\(userId)","v":"5.131"});
return {"user":u,"mutual":m.length};
"""
        let json = try await rawCall("execute", params: ["code": code], versionOverride: "5.131")

        if let resp = json["response"] as? [String: Any],
           let usersArr = resp["user"] as? [[String: Any]],
           let ud = usersArr.first, ud["deactivated"] == nil {

            // Parse into VKUser
            let id        = ud["id"]         as? Int    ?? userId
            let firstName = ud["first_name"] as? String ?? ""
            let lastName  = ud["last_name"]  as? String ?? ""
            let photo100  = ud["photo_100"]  as? String
            let photo200  = ud["photo_200"]  as? String
            let status    = ud["status"]     as? String
            let online    = ud["online"]     as? Int
            let followers = ud["followers_count"] as? Int
            let verified  = ud["verified"]   as? Int
            let bdate     = ud["bdate"]      as? String
            var cityObj: VKCity? = nil
            if let ct = ud["city"] as? [String: Any],
               let cid = ct["id"] as? Int, let ctitle = ct["title"] as? String {
                cityObj = VKCity(id: cid, title: ctitle)
            }

            let user = VKUser(
                id: id, firstName: firstName, lastName: lastName,
                photo100: photo100, photo200: photo200,
                online: online, status: status, lastSeen: nil, verified: verified,
                deactivated: nil, hasMobile: nil, verificationInfo: nil,
                city: cityObj, followersCount: followers, bdate: bdate
            )

            var info = "✅ Профиль получен через Execute Bypass\n"
            info += "👤 \(firstName) \(lastName)\n"
            info += "🆔 ID: \(id)\n"
            if let s = status, !s.isEmpty { info += "💬 \(s)\n" }
            if let f = followers { info += "👥 Подписчики: \(f)\n" }
            if let m = resp["mutual"] as? Int, m > 0 { info += "🤝 Общих друзей: \(m)" }
            return (user, info)
        }

        // Method 2: try direct users.get with old API version
        let json2 = try await rawCall("users.get",
            params: ["user_ids": "\(userId)", "fields": fields], versionOverride: "5.60")
        if let users = json2["response"] as? [[String: Any]],
           let ud = users.first, ud["deactivated"] == nil,
           let fn = ud["first_name"] as? String {
            let ln = ud["last_name"] as? String ?? ""
            let user = VKUser(
                id: userId, firstName: fn, lastName: ln,
                photo100: ud["photo_100"] as? String,
                photo200: ud["photo_200"] as? String,
                online: nil, status: ud["status"] as? String,
                lastSeen: nil, verified: nil, deactivated: nil, hasMobile: nil,
                verificationInfo: nil, city: nil,
                followersCount: ud["followers_count"] as? Int, bdate: nil
            )
            return (user, "✅ Получено через legacy API v5.60\n👤 \(fn) \(ln)")
        }

        return (nil, "❌ Профиль недоступен — пользователь полностью заблокировал доступ или удалил аккаунт")
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
