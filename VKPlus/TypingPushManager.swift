import Foundation
import UserNotifications

// MARK: - Predict Push System
// Monitors VK LongPoll for typing events, applies smart filters,
// fires local push notifications.

final class TypingPushManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TypingPushManager()
    private override init() { super.init() }

    private var pollTask: Task<Void, Never>? = nil
    private var server:   LongPollServer?    = nil
    private var ts:       Int = 0

    // Cooldown per user (adaptive: DM=10s, group=30s)
    private var lastNotif: [Int: Date] = [:]

    // Cache: peerId → member count (to avoid repeated API calls)
    private var memberCountCache: [Int: Int] = [:]

    // MARK: - Permission
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    ToastManager.shared.show("Уведомления включены", icon: "bell.fill", style: .success)
                }
            }
        }
    }

    // MARK: - Start / Stop
    func start() {
        guard pollTask == nil else { return }
        UNUserNotificationCenter.current().delegate = self
        pollTask = Task { [weak self] in await self?.runLoop() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        server = nil
    }

    // MARK: - LongPoll loop
    private func runLoop() async {
        while !Task.isCancelled {
            do {
                if server == nil {
                    server = try await VKAPIClient.shared.getLongPollServer()
                    ts = server?.ts ?? 0
                }
                guard let srv = server else {
                    try await Task.sleep(nanoseconds: 2_000_000_000); continue
                }

                let events = try await VKAPIClient.shared.pollLongPoll(server: srv, ts: ts)
                ts = events.ts

                let s = SettingsStore.shared
                guard s.typePush else {
                    try await Task.sleep(nanoseconds: 1_000_000_000); continue
                }

                for update in events.updates {
                    guard let code = update.first as? Int else { continue }
                    // code 61 = user typing in DM
                    // code 62 = user typing in group chat
                    guard code == 61 || code == 62 else { continue }

                    guard let userId = (update.count > 1 ? update[1] : nil) as? Int,
                          userId > 0 else { continue }

                    // peerId: for code 62 it's in update[3], for 61 it equals userId
                    let peerId = (code == 62 && update.count > 3)
                        ? (update[3] as? Int ?? userId)
                        : userId

                    // Apply filters
                    if await shouldFilter(code: code, userId: userId, peerId: peerId, settings: s) {
                        continue
                    }

                    await handleTyping(userId: userId, peerId: peerId, isGroup: code == 62)
                }

            } catch {
                // Reset server so it gets re-fetched on next iteration
                server = nil
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // MARK: - Filter logic (Пункт 6)
    private func shouldFilter(code: Int, userId: Int, peerId: Int, settings s: SettingsStore) async -> Bool {

        // ── 1. Only DMs mode — block all group typing events ──────────
        if s.predictOnlyDMs && code == 62 {
            return true
        }

        // ── 2. Favorites only — block non-favorites ───────────────────
        if s.predictFavoritesOnly {
            if !s.predictFavoriteIds.contains(userId) {
                return true // NOT in favorites → filter out
            }
        }

        // ── 3. Group size filter ───────────────────────────────────────
        if s.predictFilterGroups && code == 62 {
            let memberCount = await getGroupMemberCount(peerId: peerId)
            if memberCount >= s.predictMinGroupSize {
                return true // group too large — filter it
            }
        }

        // ── 4. Self filter — never notify about own typing ────────────
        let myId = TokenStorage.shared.cachedUserId ?? 0
        if userId == myId { return true }

        return false
    }

    // MARK: - Handle typing event
    private func handleTyping(userId: Int, peerId: Int, isGroup: Bool) async {
        let cooldown: TimeInterval = isGroup ? 30 : 10
        if let last = lastNotif[userId],
           Date().timeIntervalSince(last) < cooldown { return }
        lastNotif[userId] = Date()

        // Resolve name
        let name: String
        if let user = try? await VKAPIClient.shared.getUserById("\(userId)") {
            name = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
        } else {
            name = "Пользователь"
        }

        await fireNotification(name: name, userId: userId, peerId: peerId, isGroup: isGroup)
    }

    // MARK: - Group member count (cached)
    private func getGroupMemberCount(peerId: Int) async -> Int {
        if let cached = memberCountCache[peerId] { return cached }
        // peerId for group chats is > 2_000_000_000
        // For group chat: use messages.getConversationsById
        let _ = peerId > 2_000_000_000 ? peerId - 2_000_000_000 : peerId
        let json = try? await VKAPIClient.shared.rawCall("messages.getConversationsById",
            params: ["peer_ids": "\(peerId)", "extended": "0"])
        let items = (json?["response"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
        let count = (items.first?["chat_settings"] as? [String: Any])?["members_count"] as? Int ?? 0
        memberCountCache[peerId] = count
        return count
    }

    // MARK: - Fire notification
    @MainActor
    private func fireNotification(name: String, userId: Int, peerId: Int, isGroup: Bool) {
        let content = UNMutableNotificationContent()
        content.title  = "✍️ \(name)"
        content.body   = isGroup ? "Пишет в групповом чате" : "Начал(а) писать тебе сообщение"
        content.subtitle = "Predict Push System"
        content.sound  = .default
        content.threadIdentifier = "predict_\(userId)"
        content.userInfo = ["userId": userId, "peerId": peerId, "type": "predict_push"]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let req = UNNotificationRequest(
            identifier: "predict_\(userId)_\(Date().timeIntervalSince1970)",
            content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Foreground display
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound])
    }
}

// MARK: - LongPoll models
struct LongPollServer {
    let key: String; let server: String; let ts: Int
}

struct LongPollEvents {
    let ts: Int; let pts: Int?; let updates: [[Any]]
}

// MARK: - VKAPIClient LongPoll extension
extension VKAPIClient {
    func getLongPollServer() async throws -> LongPollServer {
        let json = try await rawCall("messages.getLongPollServer",
            params: ["lp_version": "3", "need_pts": "1"])
        guard let resp = json["response"] as? [String: Any],
              let key    = resp["key"]    as? String,
              let server = resp["server"] as? String
        else { throw VKError.noData }
        let ts: Int
        if let tsInt = resp["ts"] as? Int { ts = tsInt }
        else if let tsStr = resp["ts"] as? String, let tsInt = Int(tsStr) { ts = tsInt }
        else { throw VKError.noData }
        return LongPollServer(key: key, server: server, ts: ts)
    }

    func pollLongPoll(server srv: LongPollServer, ts: Int) async throws -> LongPollEvents {
        let urlStr = "https://\(srv.server)?act=a_check&key=\(srv.key)&ts=\(ts)&wait=25&mode=2&version=3"
        guard let url = URL(string: urlStr) else { throw VKError.noData }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VKError.noData
        }
        if let failed = json["failed"] as? Int {
            if failed == 1 {
                // ts outdated — use new ts
                let newTs = (json["ts"] as? Int) ?? ts
                return LongPollEvents(ts: newTs, pts: nil, updates: [])
            }
            if failed == 2 || failed == 3 {
                // key/ts expired — need new server
                throw VKError.api(failed, "LongPoll key expired")
            }
            throw VKError.api(failed, "LongPoll failed=\(failed)")
        }
        // VK sometimes returns ts as String, sometimes as Int
        let newTs: Int
        if let tsInt = json["ts"] as? Int { newTs = tsInt }
        else if let tsStr = json["ts"] as? String, let tsInt = Int(tsStr) { newTs = tsInt }
        else { newTs = ts }

        return LongPollEvents(
            ts:  newTs,
            pts: json["pts"] as? Int,
            updates: json["updates"] as? [[Any]] ?? []
        )
    }
}
