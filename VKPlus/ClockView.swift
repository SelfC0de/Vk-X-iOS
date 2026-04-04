import SwiftUI

// MARK: - Live Clock Widget
struct ClockView: View {
    @ObservedObject private var s = SettingsStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if s.showClock {
            Text(timeString)
                .font(clockFont)
                .foregroundStyle(clockColor)
                .monospacedDigit()
                .onReceive(timer) { now = $0 }
                .animation(.none, value: now)
        }
    }

    // MARK: - Color
    private var clockColor: Color {
        if s.clockColorHex == "auto" {
            // Adaptive: dark background → light text, light background → dark text
            return colorScheme == .dark
                ? Color.white.opacity(0.85)
                : Color.black.opacity(0.75)
        }
        return Color(hex: s.clockColorHex) ?? (colorScheme == .dark ? .white : .black)
    }

    // MARK: - Time string
    private var timeString: String {
        let cal = Calendar.current
        let h   = cal.component(.hour,   from: now)
        let m   = cal.component(.minute, from: now)
        let sec = cal.component(.second, from: now)

        if s.clockAmPm {
            let h12    = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            let suffix = h < 12 ? "AM" : "PM"
            return s.clockSeconds
                ? String(format: "%d:%02d:%02d %@", h12, m, sec, suffix)
                : String(format: "%d:%02d %@", h12, m, suffix)
        } else {
            return s.clockSeconds
                ? String(format: "%02d:%02d:%02d", h, m, sec)
                : String(format: "%02d:%02d", h, m)
        }
    }

    // MARK: - Font
    private var clockFont: Font {
        switch s.clockStyle {
        case "minimal": return .system(size: 13, weight: .light,  design: .rounded)
        case "bold":    return .system(size: 14, weight: .bold,   design: .rounded)
        default:        return .system(size: 13, weight: .medium, design: .monospaced)
        }
    }
}

// MARK: - Color hex init
extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
