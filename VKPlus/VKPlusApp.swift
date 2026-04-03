import SwiftUI

@main
struct VKPlusApp: App {
    init() {
        // Register privacy interceptor URLProtocol
        URLProtocol.registerClass(PrivacyURLProtocol.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    if SettingsStore.shared.forceOffline { ForceOfflineManager.shared.start() }
                    else { ForceOfflineManager.shared.stop() }
                }
                .onChange(of: SettingsStore.shared.forceOffline) { _, val in
                    if val { ForceOfflineManager.shared.start() }
                    else   { ForceOfflineManager.shared.stop()  }
                }
        }
    }
}
