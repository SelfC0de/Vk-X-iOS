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

// Deep Privacy — fake advertising ID, rotated weekly
private var _fakeAdId: String = ""
private var _fakeAdIdDate: Date = .distantPast
private func getFakeAdId() -> String {
    let week: TimeInterval = 7 * 24 * 3600
    if _fakeAdId.isEmpty || Date().timeIntervalSince(_fakeAdIdDate) > week {
        _fakeAdId = UUID().uuidString
        _fakeAdIdDate = Date()
    }
    return _fakeAdId
}

// Carrier spoofing pool — plausible international carriers
private let FAKE_CARRIERS = ["T-Mobile", "Vodafone", "Orange", "O2", "Three", "Verizon", "AT&T"]
private func getFakeCarrier() -> String {
    FAKE_CARRIERS[abs(getFakeAdId().hashValue) % FAKE_CARRIERS.count]
}

// Wi-Fi / location fields to strip from query and body
private let WIFI_FIELDS  = ["wifi_list", "wifi_stealth", "bssid_list", "wifi_scan", "nearby_wifi"]
private let ADID_FIELDS  = ["ads_device_id", "advertising_id", "ad_id", "idfa", "device_id"]
private let CARRIER_FIELDS = ["carrier", "operator", "network_operator", "sim_operator"]

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

        // ── Deep Privacy interception ─────────────────────────────────────
        var newRequest2 = request
        if s.blockWifi || s.spoofAdId || s.spoofCarrier {
            newRequest2 = scrubRequest(newRequest2, s: s)
        }

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
        var newRequest = newRequest2
        newRequest.url = buildModifiedURL(original: newRequest2.url ?? request.url!, method: method, antiBan: s.antiBan)

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

    // MARK: - Deep Privacy scrubber
    private func scrubRequest(_ req: URLRequest, s: SettingsStore) -> URLRequest {
        var r = req
        // 1. Scrub URL query parameters
        if let url = r.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var items = comps.queryItems ?? []
            items = items.compactMap { item -> URLQueryItem? in
                if s.blockWifi,   WIFI_FIELDS.contains(item.name)    { return nil }
                if s.spoofAdId,   ADID_FIELDS.contains(item.name)    { return URLQueryItem(name: item.name, value: getFakeAdId()) }
                if s.spoofCarrier, CARRIER_FIELDS.contains(item.name) { return URLQueryItem(name: item.name, value: getFakeCarrier()) }
                return item
            }
            comps.queryItems = items
            r.url = comps.url
        }
        // 2. Scrub HTTP body (JSON or form-encoded)
        if let bodyData = r.httpBody {
            if let ct = r.value(forHTTPHeaderField: "Content-Type") {
                if ct.contains("application/json") {
                    r.httpBody = scrubJSON(bodyData, s: s)
                } else if ct.contains("application/x-www-form-urlencoded") {
                    r.httpBody = scrubForm(bodyData, s: s)
                }
            } else {
                // Try form-encoded as default for VK API
                r.httpBody = scrubForm(bodyData, s: s)
            }
        }
        return r
    }

    private func scrubJSON(_ data: Data, s: SettingsStore) -> Data {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        for key in json.keys {
            let lo = key.lowercased()
            if s.blockWifi,    WIFI_FIELDS.contains(lo)    { json[key] = [] }
            if s.spoofAdId,    ADID_FIELDS.contains(lo)    { json[key] = getFakeAdId() }
            if s.spoofCarrier, CARRIER_FIELDS.contains(lo) { json[key] = getFakeCarrier() }
        }
        return (try? JSONSerialization.data(withJSONObject: json)) ?? data
    }

    private func scrubForm(_ data: Data, s: SettingsStore) -> Data {
        guard let str = String(data: data, encoding: .utf8) else { return data }
        var pairs = str.components(separatedBy: "&").compactMap { pair -> String? in
            let kv = pair.components(separatedBy: "=")
            guard let key = kv.first?.removingPercentEncoding?.lowercased() else { return pair }
            if s.blockWifi,    WIFI_FIELDS.contains(key)    { return nil }
            if s.spoofAdId,    ADID_FIELDS.contains(key)    { return "\(kv[0])=\(getFakeAdId())" }
            if s.spoofCarrier, CARRIER_FIELDS.contains(key) { return "\(kv[0])=\(getFakeCarrier().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            return pair
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? data
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
