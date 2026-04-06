import SwiftUI

private let tabs = ["Приватность", "Движок", "Устройство", "Визуал", "Интерфейс", "Прокси", "О нас"]
private let tabIcons = ["lock.shield.fill", "cpu.fill", "iphone", "paintbrush.fill", "square.3.layers.3d", "network", "info.circle.fill"]

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
                        case 4: InterfaceTab()
                        case 5: ProxyTabView()
                        default: AboutInlineView()
                        }
                    }
                    .padding(16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                ZStack(alignment: .leading) {
                    GarlandView()
                        .frame(width: UIScreen.main.bounds.width)
                        .allowsHitTesting(false)
                    PetView()
                        .frame(width: UIScreen.main.bounds.width)
                        .allowsHitTesting(false)
                    ClockView()
                        .padding(.leading, 6)
                }
            } }
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
                        HStack(spacing: 6) {
                            SettingsTabIcon(tab: i, isSelected: selectedTab == i, size: 18)
                            Text(tabs[i])
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selectedTab == i ? Color.background : Color.onSurfaceMut)
                        .padding(.horizontal, 12).padding(.vertical, 8)
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
            SettingsSectionCard(title: "Режим невидимки",
                                subtitle: "Управление видимостью активности",
                                icon: "eye.slash.fill", iconColor: Color.cyberBlue) {
                SettingsToggle("Не отмечать прочитанным",  icon: "envelope.badge.shield.half.filled",  subtitle: "Входящие остаются непрочитанными",        val: $s.ghostMode)
                SettingsToggle("Anti-Typing (UnType)",     icon: "keyboard.badge.eye",    subtitle: "Собеседник не видит что ты печатаешь",       val: $s.antiTyping)
                SettingsToggle("Force Offline",            icon: "wifi.exclamationmark",  subtitle: "Всегда показываться офлайн",        val: $s.forceOffline)
                SettingsToggle("Ghost Online",             icon: "moon.stars.fill",       subtitle: "Скрыть онлайн-статус",          val: $s.ghostOnline)
                SettingsToggle("Ghost Story",              icon: "circle.dashed",         subtitle: "Смотреть истории анонимно",       val: $s.ghostStory)
            }
            SettingsSectionCard(title: "Локальная Приватность",
                                subtitle: "Приватность в интерфейсе приложения",
                                icon: "lock.shield.fill", iconColor: Color(r:0x8B,g:0x5C,b:0xF6)) {
                SettingsToggle("Скрыть отправителя",
                               icon: "person.fill.xmark",
                               subtitle: "Аватар и имя заменяются на «Пользователь скрыт»",
                               val: $s.hideSender)
            }
            SettingsSectionCard(title: "Дата регистрации",
                                subtitle: "Узнать дату регистрации аккаунта",
                                icon: "calendar.badge.clock", iconColor: Color(r:0xFF,g:0x6B,b:0x35)) {
                RegDateCheckerView()
            }
            SettingsSectionCard(title: "Deep Privacy",
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
            SettingsSectionCard(title: "Антислежка",
                                subtitle: "Защита от слежки и сбора данных",
                                icon: "antenna.radiowaves.left.and.right", iconColor: Color(r:0xFF,g:0xAB,b:0x40)) {
                SettingsToggle("Anti-Telemetry",   icon: "antenna.radiowaves.left.and.right", subtitle: "Блокировка аналитических трекеров", val: $s.antiTelemetry)
                SettingsToggle("Anti-Screen",      icon: "camera.viewfinder",                 subtitle: "Защита экрана от захвата",       val: $s.antiScreen)
                SettingsToggle("Bypass Links",     icon: "link.badge.plus",                   subtitle: "Переходить по ссылкам напрямую", val: $s.bypassLinks)
                SettingsToggle("Bypass Short URL", icon: "arrow.uturn.right.circle",          subtitle: "Разворачивать укороченные ссылки", val: $s.bypassShortUrl)
            }
            SettingsSectionCard(title: "Уведомления",
                                subtitle: "Уведомления о действиях собеседников",
                                icon: "bell.badge.fill", iconColor: Color(r:0xFF,g:0x6B,b:0x35)) {
                SettingsToggle("Predict Push System", icon: "bell.and.waves.left.and.right",
                               subtitle: "Уведомление когда тебе начинают писать", val: $s.typePush)

                Divider().background(Color.divider).padding(.leading, 50)

                // Notify style selector (always visible)
                NotifyStylePicker()

                if s.typePush {
                    Divider().background(Color.divider).padding(.leading, 50)
                    PredictPushFilterCard()
                }
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
            SettingsSectionCard(title: "Silent VM Listener",
                                subtitle: "Анонимное прослушивание голосовых",
                                icon: "mic.slash.fill", iconColor: Color(r:0xE9,g:0x3E,b:0xFF)) {
                SettingsToggle("Silent VM Listener", icon: "mic.slash.fill",
                               subtitle: "Прослушивать голосовые анонимно",
                               val: $s.silentVm)
            }
            SettingsSectionCard(title: "Anti-Ban Engine",
                                subtitle: "Защита от блокировок и ограничений",
                                icon: "shield.lefthalf.filled", iconColor: Color(r:0x4C,g:0xAF,b:0x50)) {
                SettingsToggle("Anti-Ban Engine", icon: "shield.fill",
                               subtitle: "Защита от блокировок и ограничений",
                               val: $s.antiBan)
                SettingsToggle("Offline Post", icon: "tray.and.arrow.up.fill",
                               subtitle: "Отправлять контент без обновления онлайна",
                               val: $s.offlinePost)
            }
            SettingsSectionCard(title: "Верификация",
                                subtitle: "Значки подтверждения личности",
                                icon: "checkmark.seal.fill", iconColor: Color(r:0x1D,g:0xA1,b:0xF2)) {
                SettingsToggle("Verify Checker", icon: "checkmark.seal.fill",
                               subtitle: "Значки Госуслуги, Сбер, Альфа рядом с именем",
                               val: $s.verifyChecker)
                SettingsToggle("Fake Verification", icon: "checkmark.seal.fill",
                               subtitle: "Показывать синюю галочку в своём профиле",
                               val: $s.fakeVerification)
            }
            SettingsSectionCard(title: "Activity Bypass",
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
                title: "Type Status",
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
            SettingsSectionCard(title: "Hardware Spoof",
                                subtitle: "Маскировка параметров устройства",
                                icon: "iphone.badge.play", iconColor: Color(r:0xFF,g:0x6B,b:0x35)) {
                SettingsToggle("Hardware Spoof", icon: "dice.fill",
                               subtitle: "Случайная модель устройства при каждом сеансе",
                               val: $s.hardwareSpoof)
            }

            // Device Profile selector
            deviceProfileSectionCard

            // Bypass copy
            SettingsSectionCard(title: "Bypass Copy",
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
            title: "Device Spoofer",
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
                        RoundedRectangle(cornerRadius: 9).fill(iconColor.opacity(0.18)).frame(width: 36, height: 36)
                        SFAnimIcon(name: icon, color: iconColor, size: 22, isOn: expanded)
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
                SFAnimIcon(name: icon, color: Color.cyberBlue, size: 20, isOn: val).frame(width: 22)
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
                SFAnimIcon(name: icon, color: Color.cyberBlue, size: 20, isOn: false).frame(width: 22)
                Text(title).foregroundStyle(Color.onSurface).font(.system(size: 14))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.onSurfaceMut).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
    }
}

// MARK: - Predict Push Filter Card
struct PredictPushFilterCard: View {
    @ObservedObject private var s = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {

            // ── Filter groups toggle ───────────────────────────────────
            HStack(spacing: 12) {
                SFAnimIcon(name: "bubble.left.and.bubble.right", color: Color(r:0xFF,g:0x6B,b:0x35), size: 18, isOn: s.predictFilterGroups)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Фильтр групповых чатов")
                        .font(.system(size: 14)).foregroundStyle(Color.onSurface)
                    Text("Игнорировать typing из групп")
                        .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Toggle("", isOn: $s.predictFilterGroups).tint(Color(r:0xFF,g:0x6B,b:0x35)).labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            // ── Min group size slider (when group filter is on) ────────
            if s.predictFilterGroups {
                Divider().background(Color.divider).padding(.leading, 50)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                            .frame(width: 22)
                        Text("Мин. участников в группе: \(s.predictMinGroupSize)+")
                            .font(.system(size: 13)).foregroundStyle(Color.onSurface)
                    }
                    .padding(.horizontal, 14)
                    HStack(spacing: 10) {
                        Text("2").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                        Slider(value: Binding(
                            get: { Double(s.predictMinGroupSize) },
                            set: { s.predictMinGroupSize = Int($0) }
                        ), in: 2...50, step: 1)
                        .tint(Color(r:0xFF,g:0x6B,b:0x35))
                        Text("50").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                    .padding(.horizontal, 14).padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: s.predictFilterGroups)
            }

            Divider().background(Color.divider).padding(.leading, 50)

            // ── Only DMs toggle ────────────────────────────────────────
            HStack(spacing: 12) {
                SFAnimIcon(name: "person.fill", color: Color.cyberBlue, size: 18, isOn: s.predictOnlyDMs)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Только личные сообщения")
                        .font(.system(size: 14)).foregroundStyle(Color.onSurface)
                    Text("Игнорировать все групповые чаты")
                        .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Toggle("", isOn: $s.predictOnlyDMs).tint(.cyberBlue).labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider().background(Color.divider).padding(.leading, 50)

            // ── Favorites only toggle ──────────────────────────────────
            HStack(spacing: 12) {
                SFAnimIcon(name: "star.fill", color: Color(r:0xFF,g:0xD7,b:0x00), size: 18, isOn: s.predictFavoritesOnly)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Только избранные")
                        .font(.system(size: 14)).foregroundStyle(Color.onSurface)
                    Text("Уведомления только от нужных людей")
                        .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Toggle("", isOn: $s.predictFavoritesOnly).tint(Color(r:0xFF,g:0xD7,b:0x00)).labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            // ── Favorites list ─────────────────────────────────────────
            if s.predictFavoritesOnly {
                Divider().background(Color.divider).padding(.leading, 50)
                PredictFavoritesEditor()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: s.predictFavoritesOnly)
            }
        }
        .background(Color(red:0.06,green:0.07,blue:0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 14).padding(.vertical, 6)
    }
}

// MARK: - Favorites Editor (add/remove VK IDs)
private struct PredictFavoritesEditor: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var inputText = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Избранные контакты")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.onSurfaceMut)
                .padding(.horizontal, 14).padding(.top, 10)

            // Add by ID or URL
            HStack(spacing: 8) {
                TextField("vk.com/id или числовой ID", text: $inputText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.onSurface)
                    .keyboardType(.default)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(red:0.08,green:0.09,blue:0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    Task { await addFavorite() }
                } label: {
                    if isLoading {
                        ProgressView().tint(.cyberBlue).frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(inputText.isEmpty ? Color.onSurfaceMut : Color.cyberBlue)
                    }
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(.horizontal, 14)

            // Favorites list
            if s.predictFavoriteIds.isEmpty {
                Text("Список пуст — уведомления отключены для всех")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.onSurfaceMut)
                    .padding(.horizontal, 14).padding(.bottom, 10)
            } else {
                ForEach(s.predictFavoriteIds, id: \.self) { uid in
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cyberBlue)
                            .frame(width: 22)
                        Text("ID: \(uid)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.onSurface)
                        Spacer()
                        Button {
                            s.predictFavoriteIds.removeAll { $0 == uid }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.onSurfaceMut)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    Divider().background(Color.divider).padding(.leading, 50)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func addFavorite() async {
        isLoading = true
        // Parse input: could be "123456", "vk.com/id123456", "id123456"
        var idStr = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        idStr = idStr.replacingOccurrences(of: "https://", with: "")
        idStr = idStr.replacingOccurrences(of: "vk.com/", with: "")
        if idStr.hasPrefix("id") { idStr = String(idStr.dropFirst(2)) }

        if let uid = Int(idStr), uid > 0 {
            if !s.predictFavoriteIds.contains(uid) {
                s.predictFavoriteIds.append(uid)
                ToastManager.shared.show("Добавлен ID \(uid)", icon: "star.fill", style: .success)
            }
            inputText = ""
        } else {
            // Try to resolve screen name
            if let user = try? await VKAPIClient.shared.getUserById(idStr) {
                if !s.predictFavoriteIds.contains(user.id) {
                    s.predictFavoriteIds.append(user.id)
                    ToastManager.shared.show("\(user.firstName) добавлен", icon: "star.fill", style: .success)
                }
                inputText = ""
            } else {
                ToastManager.shared.show("Пользователь не найден", icon: "exclamationmark.triangle.fill", style: .warning)
            }
        }
        isLoading = false
    }
}

// MARK: - Notify Style Picker
struct NotifyStylePicker: View {
    @ObservedObject private var s = SettingsStore.shared

    private let styles: [(id: String, label: String, icon: String, desc: String)] = [
        ("default", "Default",       "bell.fill",               "Стандартный тост сверху"),
        ("center",  "Notify Center", "square.filled.on.square", "Карточка в центре экрана"),
        ("slide",   "Slide-Fade",    "arrow.right.to.line",     "Выезжает справа"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Стиль уведомления")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.onSurfaceMut)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(styles, id: \.id) { style in
                    Button {
                        withAnimation(.spring(response: 0.28)) {
                            s.notifyStyle = style.id
                        }
                        // Demo toast
                        ToastManager.shared.show(
                            style.label,
                            icon: style.icon,
                            style: .info,
                            duration: 2.0
                        )
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: style.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(s.notifyStyle == style.id
                                    ? Color(r:0xFF,g:0x6B,b:0x35)
                                    : Color.onSurfaceMut)
                            Text(style.label)
                                .font(.system(size: 11, weight: s.notifyStyle == style.id ? .semibold : .regular))
                                .foregroundStyle(s.notifyStyle == style.id
                                    ? Color(r:0xFF,g:0x6B,b:0x35)
                                    : Color.onSurface)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(style.desc)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.onSurfaceMut)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10).padding(.horizontal, 4)
                        .background(s.notifyStyle == style.id
                            ? Color(r:0xFF,g:0x6B,b:0x35).opacity(0.10)
                            : Color(red:0.07,green:0.08,blue:0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(s.notifyStyle == style.id
                                ? Color(r:0xFF,g:0x6B,b:0x35).opacity(0.45)
                                : Color.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 10)
        }
    }
}

// MARK: - Interface Tab
struct InterfaceTab: View {
    var body: some View {
        VStack(spacing: 14) {
            SettingsSectionCard(title: "Меню навигации",
                                subtitle: "Стиль нижней панели",
                                icon: "square.3.layers.3d",
                                iconColor: Color(r:0x9C,g:0x27,b:0xB0)) {
                TabBarStylePicker()
            }
        }
    }
}

// MARK: - TabBar Style Picker
struct TabBarStylePicker: View {
    @ObservedObject private var s = SettingsStore.shared

    private let styles: [(id: String, label: String, icon: String, desc: String)] = [
        ("default", "Default",        "rectangle.bottomthird.inset.filled", "Текущий стиль с bracket"),
        ("liquid",  "Liquid Morphing","drop.fill",                          "Жидкий blob скользит между иконками"),
        ("island",  "Floating Island","oval.fill",                          "Капсула парит над контентом"),
        ("neon",    "Neon Glow",      "sun.max.fill",                       "Светящаяся линия под иконкой"),
        ("ticker",  "Ticker Label",   "textformat",                         "Название печатается побуквенно"),
        ("gravity", "Gravity Drop",   "arrow.down.circle.fill",             "Иконка падает и отскакивает"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(styles, id: \.id) { style in
                Button {
                    withAnimation(.spring(response: 0.28)) {
                        s.tabBarStyle = style.id
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(s.tabBarStyle == style.id
                                    ? Color(r:0x9C,g:0x27,b:0xB0).opacity(0.18)
                                    : Color(red:0.08,green:0.09,blue:0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: style.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(s.tabBarStyle == style.id
                                    ? Color(r:0x9C,g:0x27,b:0xB0)
                                    : Color.onSurfaceMut)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.label)
                                .font(.system(size: 14, weight: s.tabBarStyle == style.id ? .semibold : .regular))
                                .foregroundStyle(s.tabBarStyle == style.id
                                    ? Color(r:0x9C,g:0x27,b:0xB0)
                                    : Color.onSurface)
                            Text(style.desc)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.onSurfaceMut)
                        }
                        Spacer()
                        if s.tabBarStyle == style.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(r:0x9C,g:0x27,b:0xB0))
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(s.tabBarStyle == style.id
                        ? Color(r:0x9C,g:0x27,b:0xB0).opacity(0.06)
                        : Color.clear)
                }
                .buttonStyle(.plain)
                if style.id != styles.last?.id {
                    Divider().background(Color.divider).padding(.leading, 62)
                }
            }
        }
    }
}
