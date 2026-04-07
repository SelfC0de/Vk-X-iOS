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
// iPhone model pool for Spoof Device Model
private let IPHONE_MODELS: [(model: String, name: String)] = [
    ("iPhone14,2", "iPhone 13 Pro"),
    ("iPhone14,3", "iPhone 13 Pro Max"),
    ("iPhone15,2", "iPhone 14 Pro"),
    ("iPhone15,3", "iPhone 14 Pro Max"),
    ("iPhone16,1", "iPhone 15 Pro"),
    ("iPhone16,2", "iPhone 15 Pro Max"),
    ("iPhone17,1", "iPhone 16 Pro"),
    ("iPhone17,2", "iPhone 16 Pro Max"),
]
private let IOS_VERSIONS = ["17.0", "17.1", "17.2", "17.3", "17.4", "17.5", "18.0", "18.1", "18.2", "18.3"]

private var _spoofedModel: String = ""
private var _spoofedIos: String   = ""
private func getSpoofedModel() -> String {
    if _spoofedModel.isEmpty {
        _spoofedModel = IPHONE_MODELS.randomElement()?.model ?? "iPhone16,1"
        _spoofedIos   = IOS_VERSIONS.randomElement() ?? "17.5"
    }
    return _spoofedModel
}
private func getSpoofedIos() -> String {
    _ = getSpoofedModel(); return _spoofedIos
}



private let MODEL_FIELDS = ["device", "device_model", "device_id", "model", "hardware_model"]
private let IOS_FIELDS   = ["os_version", "system_version", "ios_version", "os"]

final class PrivacyURLProtocol: URLProtocol {
    // Reusable session — avoids creating a new session per request
    private static let passthrough: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.protocolClasses = cfg.protocolClasses?.filter { $0 != PrivacyURLProtocol.self }
        return URLSession(configuration: cfg)
    }()


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
        var req = request
        if s.blockWifi || s.spoofAdId || s.spoofCarrier {
            req = scrubRequest(req, s: s)
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

        // Anti-Link Preview
        if s.antiLinkPreview && (method == "messages.getLinkStats" || method == "links.getStats") {
            fakeOK("{\"response\":{\"stats\":[]}}"); return
        }
        // Ghost Forward
        if s.ghostForward && method == "messages.send" {
            req = stripForwardMeta(req)
        }
        // Spoof Device Model
        if s.spoofDeviceModel { req = spoofDevice(req) }
        // Language Spoof
        if s.languageSpoof    { req = spoofLanguage(req) }
        // Battery + Accelerometer Strip
        if s.batteryStrip     { req = stripBatterySensors(req) }
        // Network Type Spoof
        if s.networkTypeSpoof { req = spoofNetworkType(req) }

        req.url = buildModifiedURL(original: req.url ?? request.url!, method: method, antiBan: s.antiBan)

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: req) { [weak self] data, response, error in
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
        let pairs = str.components(separatedBy: "&").compactMap { pair -> String? in
            let kv = pair.components(separatedBy: "=")
            guard let key = kv.first?.removingPercentEncoding?.lowercased() else { return pair }
            if s.blockWifi,    WIFI_FIELDS.contains(key)    { return nil }
            if s.spoofAdId,    ADID_FIELDS.contains(key)    { return "\(kv[0])=\(getFakeAdId())" }
            if s.spoofCarrier, CARRIER_FIELDS.contains(key) { return "\(kv[0])=\(getFakeCarrier().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            return pair
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? data
    }



    // MARK: - Language Spoof
    private func spoofLanguage(_ req: URLRequest) -> URLRequest {
        let langs = ["en", "de", "fr", "es", "it", "nl", "pl", "sv"]
        let lang = langs[abs(getSpoofedModel().hashValue) % langs.count]
        var r = req
        if let url = r.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = comps.queryItems?.map { item in
                ["lang", "language", "locale"].contains(item.name)
                    ? URLQueryItem(name: item.name, value: lang) : item
            }
            r.url = comps.url
        }
        r.setValue(lang, forHTTPHeaderField: "Accept-Language")
        return r
    }

    // MARK: - Battery / Accelerometer Strip
    private let BATTERY_FIELDS = ["battery_level", "battery", "charging", "is_charging",
                                   "accelerometer", "gyroscope", "motion", "orientation"]
    private func stripBatterySensors(_ req: URLRequest) -> URLRequest {
        var r = req
        if let url = r.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = comps.queryItems?.filter { !BATTERY_FIELDS.contains($0.name) }
            r.url = comps.url
        }
        if let body = r.httpBody, let str = String(data: body, encoding: .utf8) {
            let cleaned = str.components(separatedBy: "&").filter {
                let key = $0.components(separatedBy: "=").first ?? ""
                return !BATTERY_FIELDS.contains(key)
            }.joined(separator: "&")
            r.httpBody = cleaned.data(using: .utf8)
        }
        return r
    }

    // MARK: - Network Type Spoof
    private let NETWORK_TYPES = ["wifi", "lte", "4g", "5g", "ethernet"]
    private func spoofNetworkType(_ req: URLRequest) -> URLRequest {
        let net = NETWORK_TYPES[abs(getSpoofedModel().hashValue) % NETWORK_TYPES.count]
        var r = req
        if let url = r.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = comps.queryItems?.map { item in
                ["connection_type", "network_type", "connection"].contains(item.name)
                    ? URLQueryItem(name: item.name, value: net) : item
            }
            r.url = comps.url
        }
        return r
    }

    // MARK: - Ghost Forward: strip forward_messages / reply_id metadata
    private func stripForwardMeta(_ req: URLRequest) -> URLRequest {
        var r = req
        if let url = r.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = comps.queryItems?.filter {
                !["forward_messages", "forward", "reply_to"].contains($0.name)
            }
            r.url = comps.url
        }
        if let body = r.httpBody, let str = String(data: body, encoding: .utf8) {
            let cleaned = str.components(separatedBy: "&").filter {
                let key = $0.components(separatedBy: "=").first ?? ""
                return !["forward_messages", "forward", "reply_to"].contains(key)
            }.joined(separator: "&")
            r.httpBody = cleaned.data(using: .utf8)
        }
        return r
    }

    // MARK: - Spoof Device Model: replace device/os fields
    private func spoofDevice(_ req: URLRequest) -> URLRequest {
        var r = req
        let model = getSpoofedModel()
        let ios   = getSpoofedIos()
        if let url = r.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = comps.queryItems?.map { item in
                if MODEL_FIELDS.contains(item.name) { return URLQueryItem(name: item.name, value: model) }
                if IOS_FIELDS.contains(item.name)   { return URLQueryItem(name: item.name, value: ios)   }
                return item
            }
            r.url = comps.url
        }
        if let body = r.httpBody, let str = String(data: body, encoding: .utf8) {
            let pairs = str.components(separatedBy: "&").map { pair -> String in
                let kv  = pair.components(separatedBy: "=")
                let key = kv.first ?? ""
                if MODEL_FIELDS.contains(key) { return "\(key)=\(model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model)" }
                if IOS_FIELDS.contains(key)   { return "\(key)=\(ios)" }
                return pair
            }
            r.httpBody = pairs.joined(separator: "&").data(using: .utf8)
        }
        return r
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
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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
