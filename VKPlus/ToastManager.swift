import SwiftUI

// MARK: - Toast Model
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let icon: String
    let style: ToastStyle
    var duration: Double = 2.8

    enum ToastStyle {
        case success, info, warning, cyber
        var color: Color {
            switch self {
            case .success: return Color(red: 0.10, green: 0.85, blue: 0.45)
            case .info:    return Color(red: 0.00, green: 0.71, blue: 1.00)
            case .warning: return Color(red: 1.00, green: 0.72, blue: 0.00)
            case .cyber:   return Color(red: 0.00, green: 0.93, blue: 1.00)
            }
        }
        var bgColor: Color {
            switch self {
            case .success: return Color(red: 0.04, green: 0.14, blue: 0.08)
            case .info:    return Color(red: 0.03, green: 0.10, blue: 0.18)
            case .warning: return Color(red: 0.14, green: 0.11, blue: 0.03)
            case .cyber:   return Color(red: 0.02, green: 0.12, blue: 0.16)
            }
        }
    }
}

// MARK: - ToastManager
@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var toasts: [Toast] = []

    private init() {}

    func show(_ message: String, icon: String = "checkmark.circle.fill", style: Toast.ToastStyle = .info, duration: Double = 2.8) {
        let toast = Toast(message: message, icon: icon, style: style, duration: duration)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            toasts.append(toast)
        }
        UIImpactFeedbackGenerator(style: style == .warning ? .heavy : .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.toasts.removeAll { $0.id == toast.id }
            }
        }
    }
}

// MARK: - ToastView
struct ToastView: View {
    let toast: Toast
    @State private var appear = false
    @State private var iconBounce = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toast.style.color)
                .scaleEffect(iconBounce ? 1.25 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: iconBounce)

            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.onSurface)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                toast.style.bgColor
                RoundedRectangle(cornerRadius: 14)
                    .stroke(toast.style.color.opacity(0.4), lineWidth: 0.8)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: toast.style.color.opacity(0.2), radius: 12, y: 4)
        .scaleEffect(appear ? 1 : 0.85)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : -12)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { iconBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { iconBounce = false }
        }
    }
}

// MARK: - ToastOverlay modifier
struct ToastOverlay: ViewModifier {
    @ObservedObject var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            VStack(spacing: 8) {
                ForEach(manager.toasts) { toast in
                    ToastView(toast: toast)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .padding(.top, 56)
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.toasts.map(\.id))
        }
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
