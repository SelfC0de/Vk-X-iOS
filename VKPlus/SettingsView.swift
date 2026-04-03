import SwiftUI

private let tabs = ["Приватность", "Инструменты", "Эксплойты", "Прокси"]

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                tabBar
                Divider().background(Color.divider)
                ScrollView {
                    Group {
                        switch selectedTab {
                        case 0: PrivacyTab()
                        case 1: ToolsTab()
                        case 2: ExploitsTab()
                        default: ProxyTab()
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = i }
                    } label: {
                        Text(tabs[i])
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedTab == i ? Color.background : Color.onSurface)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(selectedTab == i ? Color.cyberBlue : Color.surfaceVar)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}

// MARK: - Privacy
private struct PrivacyTab: View {
    @AppStorage("ghost_mode")       private var ghostMode      = false
    @AppStorage("anti_typing")      private var antiTyping     = false
    @AppStorage("force_offline")    private var forceOffline   = false
    @AppStorage("ghost_online")     private var ghostOnline    = false
    @AppStorage("anti_telemetry")   private var antiTelemetry  = false
    @AppStorage("anti_screen")      private var antiScreen     = false
    @AppStorage("ghost_story")      private var ghostStory     = false
    @AppStorage("silent_vm")        private var silentVm       = false
    @AppStorage("offline_post")     private var offlinePost    = false
    @AppStorage("anti_ban")         private var antiBan        = false
    @AppStorage("bypass_activity")  private var bypassActivity = false
    @AppStorage("bypass_links")     private var bypassLinks    = true
    @AppStorage("bypass_short_url") private var bypassShortUrl = false
    @AppStorage("hardware_spoof")   private var hardwareSpoof  = false
    @AppStorage("verify_checker")   private var verifyChecker  = true

    var body: some View {
        VStack(spacing: 12) {
            SettingsSection(title: "🛡 Режим невидимки") {
                SettingsToggle("Не отмечать прочитанным", icon: "eye.slash.fill",            val: $ghostMode)
                SettingsToggle("Anti-Typing",             icon: "keyboard.fill",              val: $antiTyping)
                SettingsToggle("Force Offline",           icon: "wifi.slash",                 val: $forceOffline)
                SettingsToggle("Ghost Online",            icon: "moon.fill",                  val: $ghostOnline)
                SettingsToggle("Ghost Story",             icon: "circle.dashed",              val: $ghostStory)
            }
            SettingsSection(title: "📡 Антислежка") {
                SettingsToggle("Anti-Telemetry",   icon: "antenna.radiowaves.left.and.right", val: $antiTelemetry)
                SettingsToggle("Anti-Screen",      icon: "camera.viewfinder",                 val: $antiScreen)
                SettingsToggle("Bypass Links",     icon: "link.badge.plus",                   val: $bypassLinks)
                SettingsToggle("Bypass Short URL", icon: "arrow.uturn.right.circle",          val: $bypassShortUrl)
            }
            SettingsSection(title: "🔄 Anti-Ban Engine") {
                SettingsToggle("Anti-Ban",         icon: "shield.fill",                       val: $antiBan)
                SettingsToggle("Bypass Activity",  icon: "figure.walk",                       val: $bypassActivity)
                SettingsToggle("Offline Post",     icon: "tray.and.arrow.up.fill",            val: $offlinePost)
            }
            SettingsSection(title: "🔇 Silent VM") {
                SettingsToggle("Silent VM Listener", icon: "mic.slash.fill",                  val: $silentVm)
            }
            SettingsSection(title: "🖥 Устройство") {
                SettingsToggle("Hardware Spoof",   icon: "iphone",                            val: $hardwareSpoof)
            }
            SettingsSection(title: "✅ Верификация") {
                SettingsToggle("Verify Checker",   icon: "checkmark.seal.fill",               val: $verifyChecker)
            }
        }
    }
}

// MARK: - Tools
private struct ToolsTab: View {
    var body: some View {
        VStack(spacing: 12) {
            SettingsSection(title: "🧹 Управление друзьями") {
                SettingsNavRow("Remove Banned Users", icon: "person.badge.minus") {
                    PlaceholderView(title: "Remove Banned")
                }
            }
            SettingsSection(title: "💱 Currency Exchange") {
                SettingsNavRow("Курсы валют", icon: "dollarsign.circle.fill") {
                    PlaceholderView(title: "Currency Exchange")
                }
            }
        }
    }
}

// MARK: - Exploits
private struct ExploitsTab: View {
    var body: some View {
        VStack(spacing: 12) {
            SettingsSection(title: "🎭 Profile Changer") {
                SettingsNavRow("Profile Changer", icon: "person.crop.circle.badge.questionmark.fill") {
                    PlaceholderView(title: "Profile Changer")
                }
            }
            SettingsSection(title: "✅ Fake Verification") {
                SettingsNavRow("Fake Verification", icon: "checkmark.seal.fill") {
                    PlaceholderView(title: "Fake Verification")
                }
            }
        }
    }
}

// MARK: - Proxy
private struct ProxyTab: View {
    var body: some View {
        VStack(spacing: 12) {
            SettingsSection(title: "🌍 Прокси") {
                SettingsNavRow("Управление прокси", icon: "network") { ProxyView() }
            }
        }
    }
}

// MARK: - Components
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.onSurfaceMut).padding(.horizontal, 4)
            VStack(spacing: 0) { content }.cyberCard()
        }
    }
}

struct SettingsToggle: View {
    let title: String; let icon: String
    @Binding var val: Bool
    init(_ title: String, icon: String, val: Binding<Bool>) {
        self.title = title; self.icon = icon; self._val = val
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 22)
                Text(title).foregroundStyle(Color.onSurface).font(.system(size: 14))
                Spacer()
                Toggle("", isOn: $val).tint(.cyberBlue).labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            Divider().background(Color.divider).padding(.leading, 50)
        }
    }
}

struct SettingsNavRow<Dest: View>: View {
    let title: String; let icon: String
    @ViewBuilder let destination: () -> Dest
    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 22)
                Text(title).foregroundStyle(Color.onSurface).font(.system(size: 14))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.onSurfaceMut).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
    }
}

struct PlaceholderView: View {
    let title: String
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 44)).foregroundStyle(Color.onSurfaceMut)
                Text(title).foregroundStyle(Color.onSurfaceMut)
                Text("В разработке").font(.system(size: 12))
                    .foregroundStyle(Color.onSurfaceMut.opacity(0.6))
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
