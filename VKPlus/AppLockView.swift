import SwiftUI
import LocalAuthentication

// MARK: - App Lock Gate
struct AppLockGate<Content: View>: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var unlocked = false
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        if !s.appLockEnabled || unlocked {
            content
        } else {
            AppLockView(onUnlock: { unlocked = true })
                .onAppear { tryBiometric() }
        }
    }

    private func tryBiometric() {
        guard s.appLockBiometric else { return }
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Подтвердите вход в VK+") { ok, _ in
            if ok { DispatchQueue.main.async { unlocked = true } }
        }
    }
}

// MARK: - PIN Entry Screen
struct AppLockView: View {
    let onUnlock: () -> Void
    @ObservedObject private var s = SettingsStore.shared
    @State private var entered = ""
    @State private var shake   = false
    @State private var error   = false

    private let digits = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["⌫","0","✓"]
    ]

    var body: some View {
        ZStack {
            Color(red:0.04,green:0.04,blue:0.09).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo + title
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.cyberBlue, Color(r:0x63,g:0x66,b:0xF1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Text("VK+")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Введите PIN-код")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.onSurface)
                }

                // PIN dots
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < entered.count ? Color.cyberBlue : Color.divider)
                            .frame(width: 14, height: 14)
                            .scaleEffect(i < entered.count ? 1.15 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: entered.count)
                    }
                }
                .offset(x: shake ? -10 : 0)
                .animation(shake ? .easeInOut(duration: 0.06).repeatCount(5, autoreverses: true) : .default, value: shake)

                if error {
                    Text("Неверный PIN")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.errorRed)
                        .transition(.opacity)
                }

                // Numpad
                VStack(spacing: 14) {
                    ForEach(digits, id: \.self) { row in
                        HStack(spacing: 20) {
                            ForEach(row, id: \.self) { key in
                                PinButton(key: key) { tap(key) }
                            }
                        }
                    }
                }

                // Biometric button
                if s.appLockBiometric {
                    Button { tryBiometric() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 18))
                            Text(biometricLabel)
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(Color.cyberBlue)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private var biometricIcon: String {
        LAContext().biometryType == .faceID ? "faceid" : "touchid"
    }
    private var biometricLabel: String {
        LAContext().biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    private func tap(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { error = false }
        switch key {
        case "⌫": if !entered.isEmpty { entered.removeLast() }
        case "✓": verify()
        default:
            if entered.count < 4 { entered.append(key) }
            if entered.count == 4 { verify() }
        }
    }

    private func verify() {
        if entered == s.appLockPin {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onUnlock()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation { shake = true; error = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false; entered = ""
            }
        }
    }

    private func tryBiometric() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Подтвердите вход в VK+") { ok, _ in
            if ok { DispatchQueue.main.async { onUnlock() } }
        }
    }
}

// MARK: - PIN Setup View (in Settings)
struct PinSetupView: View {
    @ObservedObject private var s = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var step    = 0   // 0=enter, 1=confirm
    @State private var first   = ""
    @State private var entered = ""
    @State private var error   = ""

    private let digits = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["⌫","0","✓"]
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                VStack(spacing: 28) {
                    Text(step == 0 ? "Введите новый PIN" : "Повторите PIN")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.onSurface)
                        .padding(.top, 32)

                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i < entered.count ? Color.cyberBlue : Color.divider)
                                .frame(width: 14, height: 14)
                                .animation(.spring(response: 0.2), value: entered.count)
                        }
                    }

                    if !error.isEmpty {
                        Text(error).font(.system(size: 13)).foregroundStyle(Color.errorRed)
                    }

                    VStack(spacing: 14) {
                        ForEach(digits, id: \.self) { row in
                            HStack(spacing: 20) {
                                ForEach(row, id: \.self) { key in
                                    PinButton(key: key) { tap(key) }
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Установка PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private func tap(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        error = ""
        switch key {
        case "⌫": if !entered.isEmpty { entered.removeLast() }
        case "✓": confirm()
        default:
            if entered.count < 4 { entered.append(key) }
            if entered.count == 4 { confirm() }
        }
    }

    private func confirm() {
        if step == 0 {
            first = entered; entered = ""; step = 1
        } else {
            if entered == first {
                s.appLockPin = entered
                s.appLockEnabled = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                ToastManager.shared.show("PIN установлен", icon: "lock.fill", style: .success)
                dismiss()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                error = "PIN не совпадает, попробуйте снова"
                entered = ""; step = 0; first = ""
            }
        }
    }
}

// MARK: - PIN button
private struct PinButton: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.surface)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.divider, lineWidth: 0.5))
                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.onSurface)
                } else if key == "✓" {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.cyberBlue)
                } else {
                    Text(key)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.onSurface)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
