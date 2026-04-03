import Foundation

// MARK: - Privacy Engine
// iOS equivalent of Android PrivacyInterceptor
// Intercepts VK API calls at URLSession level via URLProtocol

private let TELEMETRY_DOMAINS  = ["stats.vk-portal.net","tns-counter.ru","counter.yadro.ru","mc.yandex.ru"]
private let TELEMETRY_METHODS  = ["stats.trackEvents","stats.addPost","auth.saveMetrics"]

// iOS client IDs for Anti-Ban rotation
private let CLIENT_IDS = [3140623, 2274003, 2685278]  // VK iPhone, VK Android, Kate Mobile
private var clientIdIndex = 0
private var requestCount  = 0

final class PrivacyURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else { return false }
        // Only intercept VK API requests
        return url.contains("api.vk.com/method") || TELEMETRY_DOMAINS.contains(where: { url.contains($0) })
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url?.absoluteString else { client?.urlProtocolDidFinishLoading(self); return }
        let s = SettingsStore.shared

        // Block telemetry domains entirely
        if TELEMETRY_DOMAINS.contains(where: { url.contains($0) }) {
            if s.antiTelemetry { fakeOK("{\"response\":1}"); return }
        }

        let method = url.components(separatedBy: "/method/").last?.components(separatedBy: "?").first ?? ""
        let path   = URL(string: url)?.query ?? ""

        // Ghost Mode — block markAsRead
        if s.ghostMode && method == "messages.markAsRead" {
            fakeOK("{\"response\":1}"); return
        }
        // Silent VM — block markAsListened
        if s.silentVm && method == "messages.markAsListened" {
            fakeOK("{\"response\":1}"); return
        }
        // Ghost Story — block markAsViewed
        if s.ghostStory && method == "stories.markAsViewed" {
            fakeOK("{\"response\":1}"); return
        }
        // Ghost Online — block setOnline
        if s.ghostOnline && method == "account.setOnline" {
            fakeOK("{\"response\":1}"); return
        }
        // Anti-Typing — block typing activity
        if s.antiTyping && method == "messages.setActivity" && path.contains("type=typing") {
            fakeOK("{\"response\":1}"); return
        }
        // Anti-Telemetry methods
        if s.antiTelemetry && TELEMETRY_METHODS.contains(method) {
            fakeOK("{\"response\":1}"); return
        }

        // Build modified request
        var newRequest = request
        newRequest.url = buildModifiedURL(original: request.url!, method: method, antiBan: s.antiBan)

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: newRequest) { [weak self] data, response, error in
            guard let self else { return }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }

    override func stopLoading() {}

    private func fakeOK(_ json: String) {
        let data = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func buildModifiedURL(original: URL, method: String, antiBan: Bool) -> URL {
        guard antiBan, !method.isEmpty else { return original }
        var comps = URLComponents(url: original, resolvingAgainstBaseURL: false) ?? URLComponents()
        requestCount += 1
        if requestCount % 50 == 0 {
            clientIdIndex = (clientIdIndex + 1) % CLIENT_IDS.count
        }
        var items = comps.queryItems ?? []
        items.removeAll { $0.name == "client_id" }
        items.append(URLQueryItem(name: "client_id", value: "\(CLIENT_IDS[clientIdIndex])"))
        comps.queryItems = items
        return comps.url ?? original
    }
}

// MARK: - Force Offline timer
final class ForceOfflineManager {
    static let shared = ForceOfflineManager()
    private var timer: Timer?
    private init() {}

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.sendOffline()
        }
        sendOffline()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sendOffline() {
        Task {
            _ = try? await VKAPIClient.shared.setOffline()
        }
    }
}
