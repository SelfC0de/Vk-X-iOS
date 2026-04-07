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
        }
    }
}

// MARK: - PIN Entry Screen
struct AppLockView: View {
    let onUnlock: () -> Void
    @ObservedObject private var s = SettingsStore.shared
    @State private var entered    = ""
    @State private var shake      = false
    @State private var showError  = false
    @State private var bioError   = ""   // human-readable biometric error

    private let digits = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["⌫","0","✓"]
    ]

    // ── biometric helpers ──────────────────────────────────────────────────
    private var ctx: LAContext { LAContext() }

    private var biometricAvailable: Bool {
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    private var biometricType: LABiometryType { ctx.biometryType }

    private var biometricIcon: String {
        biometricType == .faceID ? "faceid" : "touchid"
    }
    private var biometricLabel: String {
        biometricType == .faceID ? "Face ID" : "Touch ID"
    }

    // ──────────────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            Color(red:0.04,green:0.04,blue:0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.cyberBlue, Color(r:0x63,g:0x66,b:0xF1)],
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

                Spacer().frame(height: 36)

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

                Spacer().frame(height: 14)

                // Error text
                ZStack {
                    if showError {
                        Text("Неверный PIN")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.errorRed)
                            .transition(.opacity)
                    } else if !bioError.isEmpty {
                        Text(bioError)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.onSurfaceMut)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .frame(height: 20)
                .animation(.easeInOut(duration: 0.2), value: showError)
                .animation(.easeInOut(duration: 0.2), value: bioError)

                Spacer().frame(height: 24)

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

                Spacer().frame(height: 24)

                // Biometric button — show if enabled AND available
                if s.appLockBiometric && biometricAvailable {
                    Button { tryBiometric() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 32))
                                .foregroundStyle(Color.cyberBlue)
                            Text(biometricLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.cyberBlue)
                        }
                        .frame(width: 72, height: 72)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Placeholder to keep layout stable
                    Color.clear.frame(width: 72, height: 72)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            // Auto-trigger biometric on appear
            if s.appLockBiometric { tryBiometric() }
        }
    }

    // ── actions ────────────────────────────────────────────────────────────
    private func tap(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { showError = false; bioError = "" }
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
            withAnimation { shake = true; showError = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false; entered = ""
            }
        }
    }

    func tryBiometric() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let e = error {
                DispatchQueue.main.async {
                    switch LAError.Code(rawValue: e.code) {
                    case .biometryNotEnrolled:
                        bioError = "Face ID не настроен в настройках телефона"
                    case .biometryNotAvailable:
                        bioError = "Face ID недоступен на этом устройстве"
                    default:
                        bioError = ""
                    }
                }
            }
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Войдите в VK+"
        ) { success, evalError in
            DispatchQueue.main.async {
                if success {
                    onUnlock()
                } else if let e = evalError as? LAError {
                    switch e.code {
                    case .userFallback:
                        // User tapped "Enter password" — just show PIN
                        bioError = ""
                    case .userCancel, .systemCancel, .appCancel:
                        bioError = ""
                    case .biometryLockout:
                        bioError = "Face ID заблокирован. Введите PIN"
                    default:
                        bioError = ""
                    }
                }
            }
        }
    }
}

// MARK: - PIN Setup View (in Settings)
struct PinSetupView: View {
    @ObservedObject private var s = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var step    = 0
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
