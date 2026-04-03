import Foundation

final class TokenStorage {
    static let shared = TokenStorage()
    private let key   = "vkplus_access_token"
    private init() {}

    var token: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let v = newValue, !v.isEmpty {
                UserDefaults.standard.set(v, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    var hasToken: Bool { !(token?.isEmpty ?? true) }

    func clear() { token = nil }
}
