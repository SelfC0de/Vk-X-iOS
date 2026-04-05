import SwiftUI

// MARK: - Toast Model
struct Toast: Identifiable, Equatable {
    let id      = UUID()
    let message: String
    let icon:    String
    let style:   ToastStyle
    var duration: Double = 2.8

    enum ToastStyle {
        case success, info, warning, cyber
        var color: Color {
            switch self {
            case .success: return Color(red:0.10,green:0.85,blue:0.45)
            case .info:    return Color(red:0.00,green:0.71,blue:1.00)
            case .warning: return Color(red:1.00,green:0.72,blue:0.00)
            case .cyber:   return Color(red:0.00,green:0.93,blue:1.00)
            }
        }
        var bgColor: Color {
            switch self {
            case .success: return Color(red:0.04,green:0.14,blue:0.08)
            case .info:    return Color(red:0.03,green:0.10,blue:0.18)
            case .warning: return Color(red:0.14,green:0.11,blue:0.03)
            case .cyber:   return Color(red:0.02,green:0.12,blue:0.16)
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

    func show(_ message: String,
              icon: String = "checkmark.circle.fill",
              style: Toast.ToastStyle = .info,
              duration: Double = 2.8) {
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

// MARK: - ToastOverlay modifier (routes to correct style)
struct ToastOverlay: ViewModifier {
    @ObservedObject var manager = ToastManager.shared
    @ObservedObject var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        let style = settings.notifyStyle
        switch style {
        case "center":
            content.overlay(NotifyCenterOverlay(manager: manager))
        case "slide":
            content.overlay(SlideFadeOverlay(manager: manager))
        default:
            content.overlay(alignment: .top) {
                VStack(spacing: 8) {
                    ForEach(manager.toasts) { toast in
                        DefaultToastView(toast: toast)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.top, 56).padding(.horizontal, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.toasts.map(\.id))
            }
        }
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Style 1: Default (original top toast)
// ─────────────────────────────────────────────────────────────
struct DefaultToastView: View {
    let toast: Toast
    @State private var appear    = false
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
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(ZStack {
            toast.style.bgColor
            RoundedRectangle(cornerRadius: 14).stroke(toast.style.color.opacity(0.4), lineWidth: 0.8)
        })
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

// Also expose as ToastView for legacy compatibility
typealias ToastView = DefaultToastView

// ─────────────────────────────────────────────────────────────
// MARK: - Style 2: Notify Center (large card in screen center)
// ─────────────────────────────────────────────────────────────
struct NotifyCenterOverlay: View {
    @ObservedObject var manager: ToastManager

    var body: some View {
        ZStack {
            if let toast = manager.toasts.last {
                NotifyCenterCard(toast: toast)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal:   .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .id(toast.id)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: manager.toasts.last?.id)
    }
}

private struct NotifyCenterCard: View {
    let toast: Toast
    @State private var appear    = false
    @State private var pulse     = false
    @State private var iconScale = false

    var body: some View {
        VStack(spacing: 20) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(toast.style.color.opacity(0.15))
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .stroke(toast.style.color.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 72, height: 72)

                Image(systemName: toast.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(toast.style.color)
                    .scaleEffect(iconScale ? 1.0 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: iconScale)
            }

            // Message
            VStack(spacing: 6) {
                Text(toast.message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.onSurface)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                // Thin progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(toast.style.color.opacity(0.2))
                            .frame(height: 3)
                        ProgressBarFill(color: toast.style.color, duration: toast.duration)
                            .frame(height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(28)
        .frame(width: 260)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(toast.style.bgColor.opacity(0.85))
                RoundedRectangle(cornerRadius: 24)
                    .stroke(toast.style.color.opacity(0.25), lineWidth: 1)
            }
        )
        .shadow(color: toast.style.color.opacity(0.3), radius: 30, y: 10)
        .scaleEffect(appear ? 1 : 0.6)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pulse = true; iconScale = true }
        }
    }
}

// Animated progress bar fill
private struct ProgressBarFill: View {
    let color: Color
    let duration: Double
    @State private var progress: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: geo.size.width * progress, height: 3)
                .animation(.linear(duration: duration).delay(0.3), value: progress)
        }
        .onAppear { progress = 0 }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Style 3: Slide-Fade (H2 Tuner style, right edge)
// ─────────────────────────────────────────────────────────────
struct SlideFadeOverlay: View {
    @ObservedObject var manager: ToastManager

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()
                ForEach(manager.toasts) { toast in
                    SlideFadeToast(toast: toast)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                Spacer().frame(height: UIScreen.main.bounds.height * 0.18)
            }
        }
        .padding(.trailing, 0)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: manager.toasts.map(\.id))
        .allowsHitTesting(false)
    }
}

private struct SlideFadeToast: View {
    let toast: Toast
    @State private var appear   = false
    @State private var iconBounce = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(toast.style.color)
                .scaleEffect(iconBounce ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: iconBounce)
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.onSurface)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: 230, alignment: .leading)
        .background(
            ZStack {
                toast.style.bgColor.opacity(0.95)
                // Left accent bar
                HStack {
                    Rectangle()
                        .fill(toast.style.color)
                        .frame(width: 3)
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 12)
                    .stroke(toast.style.color.opacity(0.35), lineWidth: 0.8)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: toast.style.color.opacity(0.25), radius: 10, x: -4, y: 4)
        // Slide from right
        .offset(x: appear ? 0 : 260)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { iconBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { iconBounce = false }
        }
    }
}
