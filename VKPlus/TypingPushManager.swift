import Foundation
import UserNotifications

// MARK: - TypingPushManager
// Monitors VK LongPoll for typing events and fires local push notifications
// when ghostMode is off and typePush is on.

final class TypingPushManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TypingPushManager()
    private override init() { super.init() }

    private var pollTask:    Task<Void, Never>? = nil
    private var server:      LongPollServer?    = nil
    private var ts:          Int = 0
    private var pts:         Int = 0

    // Track who is currently typing to avoid spam
    private var lastTypingNotif: [Int: Date] = [:]
    private let cooldown: TimeInterval = 15  // seconds between notifs per user

    // MARK: - Permission request
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
        pollTask = Task { [weak self] in
            await self?.runLoop()
        }
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
                // Get/refresh server
                if server == nil {
                    server = try await VKAPIClient.shared.getLongPollServer()
                    ts = server?.ts ?? 0
                }
                guard let srv = server else { try await Task.sleep(nanoseconds: 2_000_000_000); continue }

                // Poll for events
                let events = try await VKAPIClient.shared.pollLongPoll(server: srv, ts: ts)
                ts = events.ts
                // Update pts if present
                if let newPts = events.pts { pts = newPts }

                let s = SettingsStore.shared
                guard s.typePush else { try await Task.sleep(nanoseconds: 1_000_000_000); continue }

                // Process typing events (code 61 = user typing, code 62 = user typing in chat)
                for update in events.updates {
                    guard let code = update.first as? Int else { continue }
                    if code == 61 || code == 62 {
                        // update[1] = userId, update[3] = flags
                        if let userId = (update.count > 1 ? update[1] : nil) as? Int, userId > 0 {
                            await handleTyping(userId: userId)
                        }
                    }
                }
            } catch {
                // On error: reset server and retry after delay
                server = nil
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func handleTyping(userId: Int) async {
        // Cooldown — don't spam
        if let last = lastTypingNotif[userId], Date().timeIntervalSince(last) < cooldown { return }
        lastTypingNotif[userId] = Date()

        // Get user name for notification
        let name: String
        if let user = try? await VKAPIClient.shared.getUserById("\(userId)") {
            name = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
        } else {
            name = "Пользователь"
        }

        await fireTypingNotification(name: name, userId: userId)
    }

    // MARK: - Fire notification
    @MainActor
    private func fireTypingNotification(name: String, userId: Int) {
        let content = UNMutableNotificationContent()
        content.title = "✍️ \(name)"
        content.body = "Начал(а) писать тебе сообщение"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("typing_ping.caf"))
        content.badge = nil
        // Custom thread for grouping per-user
        content.threadIdentifier = "typing_\(userId)"
        content.categoryIdentifier = "TYPING"
        // Rich subtitle
        content.subtitle = "VK+"

        // Subtle visual customization via userInfo
        content.userInfo = ["userId": userId, "type": "typing"]

        // Interruption level — time sensitive (shows even in focus mode)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let req = UNNotificationRequest(
            identifier: "typing_\(userId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Foreground display
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner + sound even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

// MARK: - LongPoll models
struct LongPollServer {
    let key:    String
    let server: String
    let ts:     Int
}

struct LongPollEvents {
    let ts:      Int
    let pts:     Int?
    let updates: [[Any]]
}

// MARK: - VKAPIClient LongPoll extension
extension VKAPIClient {
    func getLongPollServer() async throws -> LongPollServer {
        let json = try await rawCall("messages.getLongPollServer", params: [
            "lp_version": "3", "need_pts": "1"
        ])
        guard let resp = json["response"] as? [String: Any],
              let key = resp["key"] as? String,
              let server = resp["server"] as? String,
              let ts = resp["ts"] as? Int
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
        // Handle failed / outdated errors
        if let failed = json["failed"] as? Int {
            if failed == 1, let newTs = json["ts"] as? Int {
                return LongPollEvents(ts: newTs, pts: nil, updates: [])
            }
            throw VKError.api(failed, "LongPoll failed=\(failed)")
        }
        let ts2   = json["ts"] as? Int ?? ts
        let pts2  = json["pts"] as? Int
        let upd   = json["updates"] as? [[Any]] ?? []
        return LongPollEvents(ts: ts2, pts: pts2, updates: upd)
    }
}
