import SwiftUI
import PhotosUI

// MARK: - Visual Tab
struct VisualTab: View {
    @ObservedObject private var s = SettingsStore.shared

    private var weatherSubtitle: String {
        let parts = [s.weatherGarland ? "Гирлянда" : nil,
                     s.weatherRain    ? "Дождь"    : nil,
                     s.weatherSnow    ? "Снег"     : nil,
                     s.weatherFog     ? "Туман"    : nil,
                     s.weatherLeaves  ? "Листопад" : nil,
                     s.weatherSakura  ? "Сакура"   : nil,
                     s.weatherAurora  ? "Сияние"   : nil,
                     s.weatherBubbles ? "Пузыри"   : nil,
                     s.weatherStars   ? "Звёзды"   : nil,
                     s.weatherFire    ? "Огни"     : nil,
                     s.weatherPixels  ? "Пиксели"  : nil].compactMap { $0 }
        return parts.isEmpty ? "Выключено" : parts.joined(separator: ", ")
    }

    @State private var showMyColorPicker     = false
    @State private var showTheirColorPicker = false
    @State private var showClockColorPicker  = false
    @State private var bgPickerItem:        PhotosPickerItem? = nil
    @State private var bgImage:            UIImage? = nil
    @State private var feedBgPickerItem:    PhotosPickerItem? = nil
    @State private var profileBgPickerItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 14) {
            petCard
            weatherCard
            clockCard
            liquidGlassCard
            themeCard
            bubbleCard
            bgCard
            feedBgCard
            profileBgCard
        }
        .onAppear { applyTheme(s.appTheme) }
    }

    // MARK: - Pet card
    private var petSubtitle: String { s.showPet ? (PetSpecies(rawValue: s.petType)?.label ?? "Кот") : "Выключен" }

    @ViewBuilder private var petCard: some View {
            // ── Аватар ──────────────────────────────────────────────────
            SettingsSectionCard(title: "Аватар",
                                subtitle: "Форма и эффекты аватара",
                                icon: "person.crop.circle.fill",
                                iconColor: Color(r:0x8B,g:0x5C,b:0xF6)) {
                AvatarShapeCard()
            }

        SettingsSectionCard(title: "Питомец",
                                subtitle: petSubtitle,
                                icon: "pawprint.fill",
                                iconColor: Color(r:0xFF,g:0xAB,b:0x40)) {
                VStack(spacing: 0) {
                    SettingsToggle("Показывать питомца", icon: "pawprint",
                                   subtitle: "Животное бегает по шапке приложения",
                                   val: $s.showPet)
                    if s.showPet {
                        Divider().background(Color.divider).padding(.leading, 14)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Выбрать питомца")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.onSurfaceMut)
                                .padding(.horizontal, 14).padding(.top, 12)
                            PetGridView()
                            .padding(.horizontal, 14).padding(.bottom, 12)
                        }
                    }
                }
            }
    }

    // MARK: - Weather card
    @ViewBuilder private var weatherCard: some View {
        SettingsSectionCard(title: "Погода",
                                subtitle: weatherSubtitle,
                                icon: "cloud.rain.fill",
                                iconColor: Color(r:0x4D,g:0xA6,b:0xFF)) {
                VStack(spacing: 0) {
                    SettingsToggle("Garland Lights", icon: "light.ribbon.fill",
                                   subtitle: "Новогодняя гирлянда в шапке",
                                   val: $s.weatherGarland)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Дождь", icon: "cloud.rain",
                                   subtitle: "Капли дождя на экране",
                                   val: $s.weatherRain)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Снег", icon: "snowflake",
                                   subtitle: "Снежинки падают по экрану",
                                   val: $s.weatherSnow)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Туман", icon: "cloud.fog",
                                   subtitle: "Лёгкая дымка поверх интерфейса",
                                   val: $s.weatherFog)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Листопад", icon: "leaf.fill",
                                   subtitle: "Осенние листья падают по экрану",
                                   val: $s.weatherLeaves)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Сакура", icon: "leaf",
                                   subtitle: "Розовые лепестки кружатся",
                                   val: $s.weatherSakura)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Северное сияние", icon: "rays",
                                   subtitle: "Волны полярного сияния",
                                   val: $s.weatherAurora)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Пузыри", icon: "bubbles.and.sparkles",
                                   subtitle: "Пузыри всплывают снизу",
                                   val: $s.weatherBubbles)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Звёздный дождь", icon: "sparkles",
                                   subtitle: "Метеориты со следом",
                                   val: $s.weatherStars)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Огни", icon: "flame.fill",
                                   subtitle: "Искры поднимаются снизу",
                                   val: $s.weatherFire)
                    Divider().background(Color.divider).padding(.leading, 50)
                    SettingsToggle("Пиксели", icon: "squareshape.split.2x2",
                                   subtitle: "Цветные пиксели рассыпаются",
                                   val: $s.weatherPixels)
                }
            }
    }

    // MARK: - Clock card
    @ViewBuilder private var clockCard: some View {
        SettingsSectionCard(title: "Часы",
                                subtitle: s.showClock ? (s.clockSeconds ? "С секундами" : "Без секунд") : "Выключены",
                                icon: "clock.fill",
                                iconColor: Color(r:0xFF,g:0xAB,b:0x40)) {
                VStack(spacing: 0) {
                    // Main toggle
                    SettingsToggle("Показывать часы", icon: "clock",
                                   subtitle: "Отображать время в шапке всех вкладок",
                                   val: $s.showClock)

                    if s.showClock {
                        Divider().background(Color.divider).padding(.leading, 50)

                        // Style picker
                        ClockStylePicker(selected: $s.clockStyle, ampm: s.clockAmPm, sec: s.clockSeconds, colorHex: s.clockColorHex)

                        Divider().background(Color.divider).padding(.leading, 14)

                        // AM/PM toggle
                        SettingsToggle("Формат AM/PM", icon: "clock.badge",
                                       subtitle: s.clockAmPm ? "12-часовой формат" : "24-часовой формат",
                                       val: $s.clockAmPm)

                        Divider().background(Color.divider).padding(.leading, 50)

                        // Seconds toggle
                        SettingsToggle("Отображать секунды", icon: "stopwatch",
                                       subtitle: s.clockSeconds ? "Формат чч:мм:сс" : "Формат чч:мм",
                                       val: $s.clockSeconds)

                        Divider().background(Color.divider).padding(.leading, 50)

                        // Color picker — same style as bubble colors
                        let clockHex = s.clockColorHex == "auto" ? "Авто" : s.clockColorHex
                        Button { showClockColorPicker = true } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    if s.clockColorHex == "auto" {
                                        Circle()
                                            .fill(AngularGradient(colors: [.red,.orange,.yellow,.green,.blue,.purple,.red], center: .center))
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Circle()
                                            .fill(Color(hex: s.clockColorHex))
                                            .frame(width: 32, height: 32)
                                    }
                                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        .frame(width: 32, height: 32)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Цвет часов").font(.system(size: 14)).foregroundStyle(Color.onSurface)
                                    Text(clockHex).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.onSurfaceMut)
                                }
                                Spacer()
                                Image(systemName: "eyedropper").foregroundStyle(Color.cyberBlue).font(.system(size: 16))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showClockColorPicker) {
                            ClockColorPickerSheet(hex: $s.clockColorHex)
                                .onDisappear { ToastManager.shared.show("Цвет применён", icon: "checkmark.circle.fill", style: .success) }
                        }
                    }
                }
            }
    }

    // MARK: - Liquid Glass card
    @ViewBuilder private var liquidGlassCard: some View {
        SettingsSectionCard(title: "Liquid Glass",
                                subtitle: "Эффект стекла в нижнем меню",
                                icon: "bubbles.and.sparkles.fill",
                                iconColor: Color(r:0x64,g:0xD2,b:0xFF)) {
                SettingsToggle("Liquid Glass", icon: "rectangle.bottomthird.inset.filled",
                               subtitle: "Размытое стекло таб-бара — iOS 26+",
                               val: Binding(
                                   get: { s.liquidGlass },
                                   set: { v in
                                       s.liquidGlass = v
                                       ToastManager.shared.show(v ? "Liquid Glass вкл" : "Liquid Glass выкл",
                                                                icon: "bubbles.and.sparkles.fill",
                                                                style: v ? .cyber : .info)
                                   }))
            }
    }

    // MARK: - Theme card
    @ViewBuilder private var themeCard: some View {
            // ── Status Changer ──────────────────────────────────────
            SettingsSectionCard(title: "Status Changer",
                                subtitle: "Изменение статуса ВКонтакте",
                                icon: "text.bubble.fill",
                                iconColor: Color(r:0x34,g:0xC7,b:0x59)) {
                StatusChangerCard()
            }

        SettingsSectionCard(title: "Тема",
                                subtitle: "Цветовая схема приложения",
                                icon: "circle.lefthalf.filled",
                                iconColor: Color(r:0xAA,g:0x88,b:0xFF)) {
                HStack(spacing: 10) {
                    ForEach(["dark", "light", "system"], id: \.self) { t in
                        let label = t == "dark" ? "Тёмная" : t == "light" ? "Светлая" : "Авто"
                        let icon  = t == "dark" ? "moon.fill" : t == "light" ? "sun.max.fill" : "circle.lefthalf.filled"
                        Button {
                            s.appTheme = t
                            applyTheme(t)
                            ToastManager.shared.show("Тема: \(label)", icon: icon, style: .info)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: icon).font(.system(size: 18))
                                Text(label).font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(s.appTheme == t ? Color.background : Color.onSurface)
                            .background(s.appTheme == t ? Color.cyberBlue : Color.surfaceVar)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)

                // Reset theme
                Button {
                    s.appTheme = "dark"
                    applyTheme("dark")
                    s.myBubbleHex    = "#122846"
                    s.theirBubbleHex = "#1A1E2E"
                    s.chatBgImageData = nil
                    ToastManager.shared.show("Визуал сброшен", icon: "arrow.counterclockwise", style: .info)
                } label: {
                    HStack {
                        Spacer()
                        Label("Сбросить настройки визуала", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 13)).foregroundStyle(Color.onSurfaceMut)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
    }

    // MARK: - Bubble card
    @ViewBuilder private var bubbleCard: some View {
        SettingsSectionCard(title: "Цвета пузырей",
                                subtitle: "Цвет сообщений в чате",
                                icon: "bubble.left.and.bubble.right.fill",
                                iconColor: Color(r:0x00,g:0xB4,b:0xFF)) {
                VStack(spacing: 0) {
                    // My color
                    Button { showMyColorPicker = true } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: s.myBubbleHex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Мои сообщения").font(.system(size: 14)).foregroundStyle(Color.onSurface)
                                Text(s.myBubbleHex).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.onSurfaceMut)
                            }
                            Spacer()
                            Image(systemName: "eyedropper").foregroundStyle(Color.cyberBlue).font(.system(size: 16))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showMyColorPicker) {
                        ColorPickerSheet(hex: $s.myBubbleHex, title: "Мои сообщения")
                            .onDisappear { ToastManager.shared.show("Цвет применён", icon: "checkmark.circle.fill", style: .success) }
                    }

                    Divider().background(Color.divider).padding(.leading, 58)

                    // Their color
                    Button { showTheirColorPicker = true } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: s.theirBubbleHex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Собеседник").font(.system(size: 14)).foregroundStyle(Color.onSurface)
                                Text(s.theirBubbleHex).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.onSurfaceMut)
                            }
                            Spacer()
                            Image(systemName: "eyedropper").foregroundStyle(Color.cyberBlue).font(.system(size: 16))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showTheirColorPicker) {
                        ColorPickerSheet(hex: $s.theirBubbleHex, title: "Собеседник")
                            .onDisappear { ToastManager.shared.show("Цвет применён", icon: "checkmark.circle.fill", style: .success) }
                    }

                    // Reset
                    Button {
                        s.myBubbleHex    = "#122846"
                        s.theirBubbleHex = "#1A1E2E"
                        ToastManager.shared.show("Цвета сброшены", icon: "arrow.counterclockwise", style: .info)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Сбросить").font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
    }

    // MARK: - Background card
    @ViewBuilder private var bgCard: some View { BgCardView(bgPickerItem: $bgPickerItem) }
    @ViewBuilder private var feedBgCard: some View {
        ExtraBgCardView(title: "Фон ленты", subtitle: "Картинка за постами",
                        icon: "newspaper.fill", iconColor: Color(r:0x21,g:0x96,b:0xF3),
                        pickerItem: $feedBgPickerItem,
                        dataKeyPath: \.feedBgImageData)
    }
    @ViewBuilder private var profileBgCard: some View {
        ExtraBgCardView(title: "Фон профиля", subtitle: "Картинка за профилем",
                        icon: "person.crop.rectangle.fill", iconColor: Color(r:0xFF,g:0x6B,b:0x35),
                        pickerItem: $profileBgPickerItem,
                        dataKeyPath: \.profileBgImageData)
    }

    private func applyTheme(_ t: String) {
        // preferredColorScheme is driven by SettingsStore.appTheme via VKPlusApp
        // Nothing extra needed — store.appTheme = t triggers the change
    }
}



// MARK: - Background card view
private struct BgCardView: View {
    @ObservedObject private var s = SettingsStore.shared
    @Binding var bgPickerItem: PhotosPickerItem?

    var body: some View {
        SettingsSectionCard(title: "Фон диалогов",
                            subtitle: "Картинка для фона чата",
                            icon: "photo.fill",
                            iconColor: Color(r:0x4C,g:0xAF,b:0x50)) {
            VStack(spacing: 0) {
                if let data = s.chatBgImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 14).padding(.top, 12)
                }
                PhotosPicker(selection: $bgPickerItem, matching: .images) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus").foregroundStyle(Color.cyberBlue)
                        Text(s.chatBgImageData == nil ? "Выбрать фото" : "Сменить фото")
                            .font(.system(size: 14)).foregroundStyle(Color.onSurface)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                if s.chatBgImageData != nil {
                    Divider().background(Color.divider).padding(.leading, 14)
                    Button {
                        s.chatBgImageData = nil
                        ToastManager.shared.show("Фон удалён", icon: "trash", style: .info)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash").foregroundStyle(Color.errorRed)
                            Text("Удалить фон").font(.system(size: 14)).foregroundStyle(Color.errorRed)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: bgPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    s.chatBgImageData = data
                    ToastManager.shared.show("Фон установлен", icon: "photo.fill", style: .success)
                }
                bgPickerItem = nil
            }
        }
    }
}

// MARK: - Pet Grid
private struct PetGridView: View {
    @ObservedObject private var s = SettingsStore.shared
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(allPets, id: \.rawValue) { pet in
                let selected = s.petType == pet.rawValue
                Button { withAnimation(.easeInOut(duration: 0.15)) { s.petType = pet.rawValue } } label: {
                    VStack(spacing: 4) {
                        Text(String(pet.label.split(separator: " ").first ?? "")).font(.system(size: 28))
                        Text(String(pet.label.split(separator: " ").last ?? ""))
                            .font(.system(size: 10))
                            .foregroundStyle(selected ? Color.cyberBlue : Color.onSurfaceMut)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? Color.cyberBlue.opacity(0.12) : Color(red:0.07,green:0.08,blue:0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                        selected ? Color.cyberBlue.opacity(0.5) : Color.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Color Picker Sheet
struct ColorPickerSheet: View {
    @Binding var hex: String
    let title: String
    @Environment(\.dismiss) var dismiss
    @State private var picked = Color.black

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ColorPicker("Цвет пузыря", selection: $picked, supportsOpacity: false)
                    .padding(.horizontal)

                // Preview bubble
                HStack {
                    Spacer(minLength: 60)
                    Text("Пример сообщения")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(picked)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 18, bottomLeadingRadius: 18,
                            bottomTrailingRadius: 4, topTrailingRadius: 18))
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        hex = picked.toHex() ?? hex
                        dismiss()
                    }
                    .foregroundStyle(Color.cyberBlue)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .background(Color.background)
            .preferredColorScheme(.dark)
        }
        .onAppear { picked = Color(hex: hex) }
    }
}


// MARK: - Clock Color Picker Sheet
struct ClockColorPickerSheet: View {
    @Binding var hex: String
    @Environment(\.dismiss) var dismiss
    @State private var picked = Color.white
    @State private var isAuto = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Auto toggle
                Toggle(isOn: $isAuto) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(AngularGradient(colors: [.red,.orange,.yellow,.green,.blue,.purple,.red], center: .center))
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Авто").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.onSurface)
                            Text("Белый на тёмной / чёрный на светлой")
                                .font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                        }
                    }
                }
                .tint(Color.cyberBlue)
                .padding(.horizontal)
                .padding(.top, 8)

                if !isAuto {
                    Divider().padding(.horizontal)
                    ColorPicker("Цвет часов", selection: $picked, supportsOpacity: false)
                        .padding(.horizontal)

                    // Preview
                    HStack {
                        Spacer()
                        Text("12:34")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(picked)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Цвет часов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if isAuto {
                            hex = "auto"
                        } else {
                            hex = picked.toHex() ?? hex
                        }
                        dismiss()
                    }
                    .foregroundStyle(Color.cyberBlue)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .background(Color.background)
            .preferredColorScheme(.dark)
        }
        .onAppear {
            isAuto = (hex == "auto")
            if hex != "auto" { picked = Color(hex: hex) }
        }
    }
}

// MARK: - Color helpers
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let c = UIColor(self).cgColor.components, c.count >= 3 else { return nil }
        let r = Int(c[0]*255), g = Int(c[1]*255), b = Int(c[2]*255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}


// MARK: - Status Changer Card
struct StatusChangerCard: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var isLoading  = false
    @State private var isFetching = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Text input ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Новый статус")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.onSurfaceMut)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                HStack(spacing: 8) {
                    TextField("Введите текст статуса...", text: $s.statusChangerText, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.onSurface)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color(red:0.07,green:0.08,blue:0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.divider, lineWidth: 1))

                    if !s.statusChangerText.isEmpty {
                        Button { s.statusChangerText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.onSurfaceMut)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 8)
            }

            Divider().background(Color.divider)

            // ── Mode selector ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Метод")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.onSurfaceMut)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    ForEach([("local", "Local", "iphone", "Только в приложении"),
                             ("server", "ServerSide", "server.rack", "Через VK API")], id: \.0) { id, label, icon, desc in
                        Button {
                            withAnimation(.spring(response: 0.25)) { s.statusChangerMode = id }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(s.statusChangerMode == id ? Color(r:0x34,g:0xC7,b:0x59) : Color.onSurfaceMut)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(s.statusChangerMode == id ? Color(r:0x34,g:0xC7,b:0x59) : Color.onSurface)
                                    Text(desc)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.onSurfaceMut)
                                }
                                Spacer()
                                if s.statusChangerMode == id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(r:0x34,g:0xC7,b:0x59))
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(s.statusChangerMode == id
                                ? Color(r:0x34,g:0xC7,b:0x59).opacity(0.10)
                                : Color(red:0.07,green:0.08,blue:0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(s.statusChangerMode == id
                                    ? Color(r:0x34,g:0xC7,b:0x59).opacity(0.4)
                                    : Color.divider, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 10)
            }

            Divider().background(Color.divider)

            // ── Current/previous status info ──────────────────────────
            if !s.statusChangerPrevious.isEmpty || s.statusChangerApplied {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.onSurfaceMut)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Предыдущий статус")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.onSurfaceMut)
                        Text(s.statusChangerPrevious.isEmpty ? "—" : s.statusChangerPrevious)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.onSurface)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                Divider().background(Color.divider)
            }

            // ── Action buttons ────────────────────────────────────────
            HStack(spacing: 10) {
                // Apply
                Button {
                    Task { await applyStatus() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Применить")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(s.statusChangerText.isEmpty
                        ? Color.onSurfaceMut.opacity(0.3)
                        : Color(r:0x34,g:0xC7,b:0x59))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(s.statusChangerText.isEmpty || isLoading)

                // Reset
                if s.statusChangerApplied && !s.statusChangerPrevious.isEmpty {
                    Button {
                        Task { await resetStatus() }
                    } label: {
                        HStack(spacing: 6) {
                            if isFetching {
                                ProgressView().tint(Color(r:0x34,g:0xC7,b:0x59)).scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            Text("Сбросить")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(r:0x34,g:0xC7,b:0x59))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(r:0x34,g:0xC7,b:0x59).opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(r:0x34,g:0xC7,b:0x59).opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetching)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    // ── Apply ──────────────────────────────────────────────────────────
    private func applyStatus() async {
        guard !s.statusChangerText.isEmpty else { return }
        isLoading = true

        if s.statusChangerMode == "server" {
            do {
                // Save current before overwriting
                if !s.statusChangerApplied {
                    let prev = (try? await VKAPIClient.shared.getStatus()) ?? ""
                    s.statusChangerPrevious = prev
                }
                try await VKAPIClient.shared.setStatus(s.statusChangerText)
                s.statusChangerApplied = true
                ToastManager.shared.show("Статус применён на сервере", icon: "checkmark.circle.fill", style: .success)
            } catch {
                ToastManager.shared.show("Ошибка: \(error.localizedDescription)", icon: "exclamationmark.triangle.fill", style: .warning)
            }
        } else {
            // Local only — save previous if first apply
            if !s.statusChangerApplied {
                s.statusChangerPrevious = "Локальный статус"
            }
            s.statusChangerApplied = true
            ToastManager.shared.show("Статус применён локально", icon: "iphone", style: .success)
        }

        isLoading = false
    }

    // ── Reset ──────────────────────────────────────────────────────────
    private func resetStatus() async {
        isFetching = true

        if s.statusChangerMode == "server" {
            do {
                try await VKAPIClient.shared.setStatus(s.statusChangerPrevious)
                s.statusChangerApplied = false
                s.statusChangerText = ""
                ToastManager.shared.show("Предыдущий статус восстановлен", icon: "arrow.counterclockwise", style: .info)
            } catch {
                ToastManager.shared.show("Ошибка: \(error.localizedDescription)", icon: "exclamationmark.triangle.fill", style: .warning)
            }
        } else {
            s.statusChangerApplied = false
            s.statusChangerText = ""
            ToastManager.shared.show("Локальный статус сброшен", icon: "arrow.counterclockwise", style: .info)
        }

        isFetching = false
    }

}

// MARK: - Generic extra bg card (feed / profile)
private struct ExtraBgCardView: View {
    let title:       String
    let subtitle:    String
    let icon:        String
    let iconColor:   Color
    @Binding var pickerItem: PhotosPickerItem?
    let dataKeyPath: ReferenceWritableKeyPath<SettingsStore, Data?>

    @ObservedObject private var s = SettingsStore.shared

    var currentData: Data? { s[keyPath: dataKeyPath] }

    var body: some View {
        SettingsSectionCard(title: title, subtitle: subtitle,
                            icon: icon, iconColor: iconColor) {
            VStack(spacing: 0) {
                if let data = currentData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 14).padding(.top, 12)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus").foregroundStyle(Color.cyberBlue)
                        Text(currentData == nil ? "Выбрать фото" : "Сменить фото")
                            .font(.system(size: 14)).foregroundStyle(Color.onSurface)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                if currentData != nil {
                    Divider().background(Color.divider).padding(.leading, 14)
                    Button {
                        s[keyPath: dataKeyPath] = nil
                        ToastManager.shared.show("Фон удалён", icon: "trash", style: .info)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash").foregroundStyle(Color.errorRed)
                            Text("Удалить фон").font(.system(size: 14)).foregroundStyle(Color.errorRed)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    s[keyPath: dataKeyPath] = data
                    ToastManager.shared.show("Фон установлен", icon: "photo.fill", style: .success)
                }
                pickerItem = nil
            }
        }
    }
}
