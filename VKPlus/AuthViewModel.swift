import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading       = false
    @Published var error: String?  = nil

    init() {
        isAuthenticated = TokenStorage.shared.hasToken
        if let t = TokenStorage.shared.token, !t.isEmpty {
            VKAPIClient.shared.configure(token: t)
        }
    }

    func login(token: String) async {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { error = "Введите токен"; return }
        isLoading = true
        error     = nil
        do {
            let me = try await VKAPIClient.shared.getMe(token: t)
            TokenStorage.shared.token = t
            TokenStorage.shared.cachedUserId = me.id
            VKAPIClient.shared.configure(token: t)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        TokenStorage.shared.clear()
        VKAPIClient.shared.reset()
        isAuthenticated = false
    }
}
