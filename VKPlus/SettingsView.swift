import SwiftUI

private let tabs = ["Приватность", "Движок", "Устройство", "Визуал", "Прокси"]
private let tabIcons = ["lock.shield.fill", "cpu.fill", "iphone", "paintbrush.fill", "network"]

struct SettingsView: View {
    @State private var selectedTab = 0
    @State private var appeared    = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                tabBar
                Divider().background(Color.divider)
                ScrollView(showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case 0: PrivacyTab()
                        case 1: EngineTab()
                        case 2: DeviceTab()
                        case 3: VisualTab()
                        default: ProxyTabView()
                        }
                    }
                    .padding(16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
            }
        }
        .navigationTitle("Настройки").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { withAnimation(.easeOut(duration: 0.3)) { appeared = true } }
        .onChange(of: selectedTab) { _, _ in
            appeared = false
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedTab = i }
                    } label: {
                        HStack(spacing: 5) {
                                Image(systemName: tabIcons[i])
                                    .font(.system(size: 12, weight: .semibold))
                                Text(tabs[i])
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(selectedTab == i ? Color.background : Color.onSurfaceMut)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                selectedTab == i
                                    ? AnyShapeStyle(LinearGradient.cyberGrad)
                                    : AnyShapeStyle(Color.surfaceVar)
                            )
                            .clipShape(Capsule())
                            .shadow(color: selectedTab == i ? Color.cyberBlue.opacity(0.35) : .clear, radius: 6)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}

// MARK: - Privacy Tab
private struct PrivacyTab: View {
    @ObservedObject private var s = SettingsStore.shared
    var body: some View {
        VStack(spacing: 14) {
            SettingsSectionCard(title: "🛡 Режим невидимки",
                                subtitle: "Управление видимостью активности",
                                icon: "eye.slash.fill", iconColor: Color.cyberBlue) {
                SettingsToggle("Не отмечать прочитанным",  icon: "envelope.badge.shield.half.filled",  subtitle: "Входящие остаются непрочитанными",        val: $s.ghostMode)
                SettingsToggle("Anti-Typing (UnType)",     icon: "keyboard.badge.eye",    subtitle: "Собеседник не видит что ты печатаешь",       val: $s.antiTyping)
                SettingsToggle("Force Offline",            icon: "wifi.exclamationmark",  subtitle: "Всегда показываться офлайн",        val: $s.forceOffline)
                SettingsToggle("Ghost Online",             icon: "moon.stars.fill",       subtitle: "Скрыть онлайн-статус",          val: $s.ghostOnline)
                SettingsToggle("Ghost Story",              icon: "circle.dashed",         subtitle: "Смотреть истории анонимно",       val: $s.ghostStory)
            }
            SettingsSectionCard(title: "🕶 Локальная Приватность",
                                subtitle: "Приватность в интерфейсе приложения",
                                icon: "lock.shield.fill", iconColor: Color(r:0x8B,g:0x5C,b:0xF6)) {
                SettingsToggle("Скрыть отправителя",
                               icon: "person.fill.xmark",
                               subtitle: "Аватар и имя заменяются на «Пользователь скрыт»",
                               val: $s.hideSender)
                SettingsToggle("Blur Screen",
                               icon: "eye.trianglebadge.exclamationmark",
                               subtitle: "Размывает контент при скриншоте",
                               val: $s.blurScreen)
            }
            SettingsSectionCard(title: "📅 Дата регистрации",
                                subtitle: "Узнать дату регистрации аккаунта",
                                icon: "calendar.badge.clock", iconColor: Color(r:0xFF,g:0x6B,b:0x35)) {
                RegDateCheckerView()
            }
            SettingsSectionCard(title: "🕵️ Deep Privacy",
                                subtitle: "Защита персональных данных устройства",
                                icon: "shield.lefthalf.filled", iconColor: Color(r:0xFF,g:0x45,b:0x45)) {
                SettingsToggle("Spoof Ads ID",
                               icon: "qrcode",
                               subtitle: "Скрыть рекламный идентификатор устройства",
                               val: $s.spoofAdId)
                SettingsToggle("Block Wi-Fi Scan",
                               icon: "wifi.slash",
                               subtitle: "Запретить отправку данных о Wi-Fi окружении",
                               val: $s.blockWifi)
                SettingsToggle("Spoof Carrier",
                               icon: "simcard.2",
                               subtitle: "Скрывает название оператора связи",
                               val: $s.spoofCarrier)
            }
            SettingsSectionCard(title: "📡 Антислежка",
                                subtitle: "Защита от слежки и сбора данных",
                                icon: "antenna.radiowaves.left.and.right", iconColor: Color(r:0xFF,g:0xAB,b:0x40)) {
                SettingsToggle("Anti-Telemetry",   icon: "antenna.radiowaves.left.and.right", subtitle: "Блокировка аналитических трекеров", val: $s.antiTelemetry)
                SettingsToggle("Anti-Screen",      icon: "camera.viewfinder",                 subtitle: "Защита экрана от захвата",       val: $s.antiScreen)
                SettingsToggle("Bypass Links",     icon: "link.badge.plus",                   subtitle: "Переходить по ссылкам напрямую", val: $s.bypassLinks)
                SettingsToggle("Bypass Short URL", icon: "arrow.uturn.right.circle",          subtitle: "Разворачивать укороченные ссылки", val: $s.bypassShortUrl)
            }
            SettingsSectionCard(title: "🔔 Уведомления",
                                subtitle: "Уведомления о действиях собеседников",
                                icon: "bell.badge.fill", iconColor: Color(r:0xFF,g:0x6B,b:0x35)) {
                SettingsToggle("Type You Push", icon: "bell.and.waves.left.and.right", subtitle: "Уведомление когда тебе начинают писать", val: $s.typePush)
            }
            NavigationLink(destination: ExploitsView()) {
                exploitsBanner
            }
        }
    }

    private var exploitsBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(r:0xFF,g:0xB8,b:0x00).opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "bolt.fill").font(.system(size: 17)).foregroundStyle(Color(r:0xFF,g:0xB8,b:0x00))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Эксплойты (7)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.onSurface)
                Text("Stickers, Execute, Platform, Groups...").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
            }
            Spacer()
            Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color(r:0xFF,g:0xB8,b:0x00).opacity(0.7)).font(.system(size: 18))
        }
        .padding(14).background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(r:0xFF,g:0xB8,b:0x00).opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Engine Tab
private struct EngineTab: View {
    @ObservedObject private var s = SettingsStore.shared
    var body: some View {
        VStack(spacing: 14) {
            SettingsSectionCard(title: "🎙 Silent VM Listener",
                                subtitle: "Анонимное прослушивание голосовых",
                                icon: "mic.slash.fill", iconColor: Color(r:0xE9,g:0x3E,b:0xFF)) {
                SettingsToggle("Silent VM Listener", icon: "mic.slash.fill",
                               subtitle: "Прослушивать голосовые анонимно",
                               val: $s.silentVm)
            }
            SettingsSectionCard(title: "🔄 Anti-Ban Engine",
                                subtitle: "Защита от блокировок и ограничений",
                                icon: "shield.lefthalf.filled", iconColor: Color(r:0x4C,g:0xAF,b:0x50)) {
                SettingsToggle("Anti-Ban Engine", icon: "shield.fill",
                               subtitle: "Защита от блокировок и ограничений",
                               val: $s.antiBan)
                SettingsToggle("Offline Post", icon: "tray.and.arrow.up.fill",
                               subtitle: "Отправлять контент без обновления онлайна",
                               val: $s.offlinePost)
            }
            SettingsSectionCard(title: "✅ Верификация",
                                subtitle: "Значки подтверждения личности",
                                icon: "checkmark.seal.fill", iconColor: Color(r:0x1D,g:0xA1,b:0xF2)) {
                SettingsToggle("Verify Checker", icon: "checkmark.seal.fill",
                               subtitle: "Значки Госуслуги, Сбер, Альфа рядом с именем",
                               val: $s.verifyChecker)
                SettingsToggle("Fake Verification", icon: "checkmark.seal.fill",
                               subtitle: "Показывать синюю галочку в своём профиле",
                               val: $s.fakeVerification)
            }
            SettingsSectionCard(title: "🕵️ Activity Bypass",
                                subtitle: "Скрытый режим чтения сообщений",
                                icon: "figure.walk", iconColor: Color(r:0x21,g:0x96,b:0xF3)) {
                SettingsToggle("Bypass Activity Status", icon: "eye.slash",
                               subtitle: "Читать сообщения без обновления статуса",
                               val: $s.bypassActivity)
                SettingsToggle("LongPoll Only Mode", icon: "wifi.router",
                               subtitle: "Оставаться офлайн при получении сообщений",
                               val: $s.longPollOnly)
            }
            typeStatusSection
            NavigationLink(destination: ToolsView()) {
                toolsBanner
            }
        }
    }

    private var typeStatusSection: some View {
        TypeStatusCard()
    }

    // Separate view so @ObservedObject works correctly
    private struct TypeStatusCard: View {
        @ObservedObject private var s = SettingsStore.shared
        var body: some View {
            SettingsSectionCard(
                title: "⌨️ Type Status",
                subtitle: "Сейчас: \(s.currentTypeStatus.label)",
                icon: "keyboard.fill",
                iconColor: Color.cyberBlue
            ) {
            VStack(spacing: 0) {
                ForEach(TypeStatus.allCases, id: \.self) { status in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            s.typeStatus = status.rawValue
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(status.emoji).font(.system(size: 18)).frame(width: 26)
                            Text(status.label).font(.system(size: 14))
                                .foregroundStyle(s.currentTypeStatus == status ? Color.cyberBlue : Color.onSurface)
                            Spacer()
                            ZStack {
                                Circle().stroke(s.currentTypeStatus == status ? Color.cyberBlue : Color.divider, lineWidth: 2).frame(width: 20, height: 20)
                                if s.currentTypeStatus == status {
                                    Circle().fill(Color.cyberBlue).frame(width: 10, height: 10)
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if status != TypeStatus.allCases.last {
                        Divider().background(Color.divider).padding(.leading, 50)
                    }
                }
            }
        }
        } // end body
    } // end TypeStatusCard

    private var toolsBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.cyberBlue.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 17)).foregroundStyle(Color.cyberBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Инструменты").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.onSurface)
                Text("Дополнительные инструменты аккаунта").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
            }
            Spacer()
            Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.cyberBlue.opacity(0.6)).font(.system(size: 18))
        }
        .padding(14).background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyberBlue.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Device Tab
private struct DeviceTab: View {
    @ObservedObject private var s = SettingsStore.shared
    var body: some View {
        VStack(spacing: 14) {
            // Hardware Spoof toggle
            SettingsSectionCard(title: "🔄 Hardware Spoof",
                                subtitle: "Маскировка параметров устройства",
                                icon: "iphone.badge.play", iconColor: Color(r:0xFF,g:0x6B,b:0x35)) {
                SettingsToggle("Hardware Spoof", icon: "dice.fill",
                               subtitle: "Случайная модель устройства при каждом сеансе",
                               val: $s.hardwareSpoof)
            }

            // Device Profile selector
            deviceProfileSectionCard

            // Bypass copy
            SettingsSectionCard(title: "📋 Bypass Copy",
                                subtitle: "Снятие ограничений на копирование",
                                icon: "doc.on.doc.fill", iconColor: Color(r:0x4C,g:0xAF,b:0x50)) {
                SettingsToggle("Bypass Copy + Reposts", icon: "doc.on.doc.fill",
                               subtitle: "Копировать и репостить любой контент",
                               val: $s.bypassCopy)
            }

            // Current spoof preview (if active)
            if s.hardwareSpoof {
                spoofPreview
            }

            // Footer
            HStack {
                Spacer()
                Text("VK+ by SelfCode").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut.opacity(0.5))
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    private var deviceProfileSectionCard: some View {
        SettingsSectionCard(
            title: "📱 Device Spoofer",
            subtitle: s.deviceUa.isEmpty ? "Выбрать профиль" : s.currentDeviceProfile.label,
            icon: "iphone",
            iconColor: Color.cyberBlue
        ) {
            VStack(spacing: 0) {
                ForEach(DeviceProfile.allCases, id: \.self) { profile in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            SettingsStore.shared.deviceUa = profile.ua
                        }
                    } label: {
                        HStack(spacing: 12) {
                            let selected = s.currentDeviceProfile == profile
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.label)
                                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Color.cyberBlue : Color.onSurface)
                                Text(profile.uaPreview)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.onSurfaceMut)
                                    .lineLimit(1)
                            }
                            Spacer()
                            ZStack {
                                Circle().stroke(selected ? Color.cyberBlue : Color.divider, lineWidth: 2).frame(width: 20, height: 20)
                                if selected { Circle().fill(Color.cyberBlue).frame(width: 10, height: 10) }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if profile != DeviceProfile.allCases.last {
                        Divider().background(Color.divider).padding(.leading, 14)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").foregroundStyle(Color.onSurfaceMut).font(.system(size: 11))
                    Text("Выбранный профиль применяется ко всем сетевым запросам.")
                        .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
    }

    private var spoofPreview: some View {
        let device = HardwareSpoofing.generate()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark").foregroundStyle(Color(r:0xFF,g:0x6B,b:0x35))
                Text("Пример сгенерированного отпечатка").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.onSurface)
            }
            spoofRow("📱 Модель",       device.model)
            spoofRow("🤖 Android",      device.androidVersion)
            spoofRow("🖥 Разрешение",   "\(device.screenWidth)×\(device.screenHeight)")
            spoofRow("🔋 Заряд",        "\(device.batteryLevel)%")
        }
        .padding(14)
        .background(Color(r:0xFF,g:0x6B,b:0x35).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(r:0xFF,g:0x6B,b:0x35).opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private func spoofRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
            Spacer()
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.onSurface)
        }
    }
}

// MARK: - Proxy Tab
private struct ProxyTabView: View {
    var body: some View {
        NavigationLink(destination: ProxyView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.cyberBlue.opacity(0.15)).frame(width: 48, height: 48)
                    Image(systemName: "network").font(.system(size: 20)).foregroundStyle(Color.cyberBlue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Управление прокси").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.onSurface)
                    Text("Настройка и управление подключениями")
                        .font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.cyberBlue.opacity(0.6)).font(.system(size: 20))
            }
            .padding(16).background(Color.surface).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyberBlue.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - Reusable components
struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { expanded.toggle() } } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.15)).frame(width: 34, height: 34)
                        Image(systemName: icon).font(.system(size: 16)).foregroundStyle(iconColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.onSurface)
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.onSurfaceMut)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if expanded {
                Divider().background(Color.divider)
                content
            }
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.divider, lineWidth: 0.5))
        .animation(.spring(response: 0.35), value: expanded)
    }
}

struct SettingsToggle: View {
    let title: String; let icon: String; let subtitle: String; @Binding var val: Bool
    init(_ title: String, icon: String, subtitle: String = "", val: Binding<Bool>) {
        self.title = title; self.icon = icon; self.subtitle = subtitle; self._val = val
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Color.onSurface).font(.system(size: 14))
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                }
                Spacer()
                Toggle("", isOn: $val).tint(.cyberBlue).labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, subtitle.isEmpty ? 13 : 10)
            Divider().background(Color.divider).padding(.leading, 48)
        }
    }
}

struct SettingsNavRow<Dest: View>: View {
    let title: String; let icon: String; @ViewBuilder let destination: () -> Dest
    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color.cyberBlue).frame(width: 22)
                Text(title).foregroundStyle(Color.onSurface).font(.system(size: 14))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.onSurfaceMut).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
    }
}
