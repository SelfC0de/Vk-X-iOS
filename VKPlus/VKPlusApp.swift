import SwiftUI

@main
struct VKPlusApp: App {
    @ObservedObject private var store = SettingsStore.shared

    init() {
        URLProtocol.registerClass(PrivacyURLProtocol.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    if store.forceOffline { ForceOfflineManager.shared.start() }
                    else { ForceOfflineManager.shared.stop() }
                }
                .onChange(of: store.forceOffline) { _, val in
                    if val { ForceOfflineManager.shared.start() }
                    else   { ForceOfflineManager.shared.stop()  }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil  // system
        }
    }
}
