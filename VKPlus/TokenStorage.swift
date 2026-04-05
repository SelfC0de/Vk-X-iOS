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

    func clear() { token = nil; cachedUserId = nil }

    // Cached own user ID — set after successful auth/getProfile
    var cachedUserId: Int? {
        get {
            let v = UserDefaults.standard.integer(forKey: "vkplus_my_user_id")
            return v > 0 ? v : nil
        }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "vkplus_my_user_id") }
            else { UserDefaults.standard.removeObject(forKey: "vkplus_my_user_id") }
        }
    }
}
