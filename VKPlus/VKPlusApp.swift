import SwiftUI
import UIKit

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
                    ScreenProtector.shared.apply(enabled: store.blurScreen)
                }
                .onChange(of: store.forceOffline) { _, val in
                    if val { ForceOfflineManager.shared.start() }
                    else   { ForceOfflineManager.shared.stop()  }
                }
                .onChange(of: store.blurScreen) { _, val in
                    ScreenProtector.shared.apply(enabled: val)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
                    ScreenProtector.shared.apply(enabled: store.blurScreen)
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
}

// MARK: - Screen Protector
// Uses UITextField.isSecureTextEntry trick:
// iOS automatically blurs secure text field content in screenshots and recordings at OS level.
// We take the private UIView subview of UITextField (which renders the secure canvas)
// and stretch it over the full window — content inside shows normally,
// but any screenshot/recording captures only blur.
final class ScreenProtector {
    static let shared = ScreenProtector()
    private var secureContainer: UIView?
    private init() {}

    func apply(enabled: Bool) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return }

        if enabled {
            if secureContainer == nil {
                // Build the secure view via UITextField trick
                let field = UITextField()
                field.isSecureTextEntry = true
                // The first subview of a secure UITextField is the private
                // _UITextLayoutCanvasView or similar which iOS automatically
                // excludes from screenshots/screen recordings
                let secure = UIView()
                secure.translatesAutoresizingMaskIntoConstraints = false
                secure.backgroundColor = .clear
                secure.isUserInteractionEnabled = false
                if let privateLayer = field.subviews.first {
                    privateLayer.translatesAutoresizingMaskIntoConstraints = false
                    privateLayer.isUserInteractionEnabled = false
                    privateLayer.backgroundColor = .clear
                    secure.addSubview(privateLayer)
                    NSLayoutConstraint.activate([
                        privateLayer.leadingAnchor.constraint(equalTo: secure.leadingAnchor),
                        privateLayer.trailingAnchor.constraint(equalTo: secure.trailingAnchor),
                        privateLayer.topAnchor.constraint(equalTo: secure.topAnchor),
                        privateLayer.bottomAnchor.constraint(equalTo: secure.bottomAnchor),
                    ])
                }
                secure.tag = 88881
                window.addSubview(secure)
                NSLayoutConstraint.activate([
                    secure.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                    secure.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                    secure.topAnchor.constraint(equalTo: window.topAnchor),
                    secure.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                ])
                secureContainer = secure
            }
        } else {
            secureContainer?.removeFromSuperview()
            secureContainer = nil
            window.viewWithTag(88881)?.removeFromSuperview()
        }
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
