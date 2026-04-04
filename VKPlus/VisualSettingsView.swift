import SwiftUI
import PhotosUI

// MARK: - Visual Tab
struct VisualTab: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var showMyColorPicker    = false
    @State private var showTheirColorPicker = false
    @State private var bgPickerItem: PhotosPickerItem? = nil
    @State private var bgImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 14) {

            // Liquid Glass
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

            // Theme
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

            // Bubble colors
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

            // Chat background
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
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for window in ws.windows {
                switch t {
                case "light":  window.overrideUserInterfaceStyle = .light
                case "dark":   window.overrideUserInterfaceStyle = .dark
                default:       window.overrideUserInterfaceStyle = .unspecified
                }
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
