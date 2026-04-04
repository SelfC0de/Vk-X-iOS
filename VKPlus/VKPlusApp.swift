import SwiftUI

@main
struct VKPlusApp: App {
    init() {
        URLProtocol.registerClass(PrivacyURLProtocol.self)
        // Apply saved theme
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first?.windows.first else { return }
            switch SettingsStore.shared.appTheme {
            case "light":  window.overrideUserInterfaceStyle = .light
            case "dark":   window.overrideUserInterfaceStyle = .dark
            default:       window.overrideUserInterfaceStyle = .unspecified
            }
        }
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
