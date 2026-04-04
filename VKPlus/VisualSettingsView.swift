import SwiftUI
import PhotosUI

// MARK: - Visual Tab
struct VisualTab: View {
    @ObservedObject private var s = SettingsStore.shared

    private var weatherSubtitle: String {
        let parts = [s.weatherGarland ? "Гирлянда" : nil,
                     s.weatherRain    ? "Дождь"    : nil,
                     s.weatherSnow    ? "Снег"     : nil,
                     s.weatherFog     ? "Туман"    : nil].compactMap { $0 }
        return parts.isEmpty ? "Выключено" : parts.joined(separator: ", ")
    }

    @State private var showMyColorPicker    = false
    @State private var showTheirColorPicker = false
    @State private var bgPickerItem: PhotosPickerItem? = nil
    @State private var bgImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 14) {
            petCard
            weatherCard
            clockCard
            liquidGlassCard
            themeCard
            bubbleCard
            bgCard
        }
    }

    // MARK: - Pet card
    @ViewBuilder private var petCard: some View {
        SettingsSectionCard(title: "🐾 Питомец",
                                subtitle: s.showPet ? (allPets.first { $0.id == s.petType }?.label ?? "Кот") : "Выключен",
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
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(allPets, id: \.id) { pet in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) { s.petType = pet.id }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(pet.frames[0])
                                                .font(.system(size: 28))
                                            Text(String(pet.label.split(separator: " ").last ?? ""))
                                                .font(.system(size: 10))
                                                .foregroundStyle(s.petType == pet.id ? Color.cyberBlue : Color.onSurfaceMut)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(s.petType == pet.id ? Color.cyberBlue.opacity(0.12) : Color(red:0.07,green:0.08,blue:0.13))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                            s.petType == pet.id ? Color.cyberBlue.opacity(0.5) : Color.divider, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14).padding(.bottom, 12)
                        }
                    }
                }
            }
    }

    // MARK: - Weather card
    @ViewBuilder private var weatherCard: some View {
        SettingsSectionCard(title: "🌧 Погода",
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
                }
            }
    }

    // MARK: - Clock card
    @ViewBuilder private var clockCard: some View {
        SettingsSectionCard(title: "🕐 Часы",
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Стиль")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.onSurfaceMut)
                                .padding(.horizontal, 14)
                                .padding(.top, 12)
                            HStack(spacing: 8) {
                                ForEach([("digital", "Цифровой", "display"), ("minimal", "Минимальный", "minus.circle"), ("bold", "Жирный", "bold")], id: \.0) { id, label, icon in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) { s.clockStyle = id }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(s.clockStyle == id ? Color.cyberBlue : Color.onSurfaceMut)
                                            Text(label)
                                                .font(.system(size: 11))
                                                .foregroundStyle(s.clockStyle == id ? Color.cyberBlue : Color.onSurfaceMut)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(s.clockStyle == id ? Color.cyberBlue.opacity(0.12) : Color(red:0.07,green:0.08,blue:0.13))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                            s.clockStyle == id ? Color.cyberBlue.opacity(0.4) : Color.divider, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14).padding(.bottom, 12)
                        }

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

                        Divider().background(Color.divider).padding(.leading, 14)

                        // Color picker
                        ClockColorRow()
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
    @ViewBuilder private var bgCard: some View {
        SettingsSectionCard(title: "Фон диалогов",
                                subtitle: "Картинка для фона чата",
                                icon: "photo.fill",
                                iconColor: Color(r:0x4C,g:0xAF,b:0x50)) {
                VStack(spacing: 0) {
                    // Preview
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
        }
        .onChange(of: bgPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    SettingsStore.shared.chatBgImageData = data
                    ToastManager.shared.show("Фон установлен", icon: "photo.fill", style: .success)
                }
                bgPickerItem = nil
            }
        }
        .onAppear { applyTheme(s.appTheme) }
    }

    private func applyTheme(_ t: String) {
        // preferredColorScheme is driven by SettingsStore.appTheme via VKPlusApp
        // Nothing extra needed — store.appTheme = t triggers the change
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

// MARK: - Clock Color Row
private struct ClockColorRow: View {
    @ObservedObject private var s = SettingsStore.shared

    // preset palette: "auto" + 8 fixed colors
    private let presets: [(String, String)] = [
        ("auto",     "Авто"),
        ("FFFFFF",   "Белый"),
        ("000000",   "Чёрный"),
        ("4DA6FF",   "Синий"),
        ("52C41A",   "Зелёный"),
        ("FF6B35",   "Оранжевый"),
        ("FF4545",   "Красный"),
        ("FFD700",   "Золотой"),
        ("C875FF",   "Фиолетовый"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.cyberBlue)
                    .frame(width: 22)
                Text("Цвет часов")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.onSurface)
            }
            .padding(.horizontal, 14).padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { hex, label in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { s.clockColorHex = hex }
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle()
                                        .fill(hex == "auto"
                                              ? AnyShapeStyle(AngularGradient(colors: [.red,.orange,.yellow,.green,.blue,.purple,.red], center: .center))
                                              : AnyShapeStyle(Color(hex: hex)))
                                        .frame(width: 34, height: 34)
                                    if s.clockColorHex == hex {
                                        Circle()
                                            .stroke(Color.cyberBlue, lineWidth: 2.5)
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(hex == "000000" ? .white : .black)
                                    }
                                }
                                Text(label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(s.clockColorHex == hex ? Color.cyberBlue : Color.onSurfaceMut)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 50)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 12)
        }
    }
}
