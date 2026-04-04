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
                    applyBlurScreen()
                }
                .onChange(of: store.forceOffline) { _, val in
                    if val { ForceOfflineManager.shared.start() }
                    else   { ForceOfflineManager.shared.stop()  }
                }
                .onChange(of: store.blurScreen) { _, _ in applyBlurScreen() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                    if store.blurScreen {
                        ToastManager.shared.show("Скриншот заблокирован", icon: "eye.slash.fill", style: .warning)
                    }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private func applyBlurScreen() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return }
        if store.blurScreen {
            if window.viewWithTag(9999) == nil {
                let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                blur.frame = window.bounds
                blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                blur.tag = 9999
                blur.alpha = 0
                window.addSubview(blur)
            }
            NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification,
                                                   object: nil, queue: .main) { _ in
                guard let b = window.viewWithTag(9999) else { return }
                UIView.animate(withDuration: 0.1) { b.alpha = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    UIView.animate(withDuration: 0.2) { b.alpha = 0 }
                }
            }
        } else {
            window.viewWithTag(9999)?.removeFromSuperview()
        }
    }
}
