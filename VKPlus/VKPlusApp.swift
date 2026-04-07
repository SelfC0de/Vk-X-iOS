import SwiftUI
import UIKit

@main
struct VKPlusApp: App {
    @ObservedObject private var store = SettingsStore.shared

    init() {
        URLProtocol.registerClass(PrivacyURLProtocol.self)
        Self.setupMediaDirectories()
        // Start offline manager immediately on launch if enabled
        let s = SettingsStore.shared
        if s.forceOffline || s.ghostOnline {
            ForceOfflineManager.shared.start()
        }
        if s.typePush {
            TypingPushManager.shared.start()
        }
    }

    // Create Documents/Аудио and Documents/Голосовые on first launch
    private static func setupMediaDirectories() {
        let fm   = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for folder in ["Аудио", "Голосовые"] {
            let dir = docs.appendingPathComponent(folder)
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                // Create a .nomedia placeholder so folder is visible in Files immediately
                let placeholder = dir.appendingPathComponent(".readme.txt")
                let text = folder == "Аудио"
                    ? "Здесь хранятся скачанные аудиозаписи из VK+"
                    : "Здесь хранятся скачанные голосовые сообщения из VK+"
                try? text.write(to: placeholder, atomically: true, encoding: .utf8)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    let needOffline = store.forceOffline || store.ghostOnline
                    if needOffline {
                        ForceOfflineManager.shared.start()
                        // Immediately set offline — don't wait for timer
                        Task { try? await VKAPIClient.shared.setOffline() }
                    } else {
                        ForceOfflineManager.shared.stop()
                    }
                    ScreenProtector.shared.apply(enabled: store.blurScreen)
                    // TypingPushManager auto-resumes via onChange(typePush)
                }
                .onChange(of: store.forceOffline) { _, val in
                    let needOffline = val || store.ghostOnline
                    if needOffline {
                        ForceOfflineManager.shared.start()
                        Task { try? await VKAPIClient.shared.setOffline() }
                    } else {
                        ForceOfflineManager.shared.stop()
                    }
                }
                .onChange(of: store.ghostOnline) { _, val in
                    if val {
                        ForceOfflineManager.shared.start()
                        Task { try? await VKAPIClient.shared.setOffline() }
                    } else if !store.forceOffline {
                        ForceOfflineManager.shared.stop()
                    }
                }
                .onChange(of: store.typePush) { _, val in
                    if val {
                        TypingPushManager.shared.requestPermission()
                        TypingPushManager.shared.start()
                    } else {
                        TypingPushManager.shared.stop()
                    }
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


