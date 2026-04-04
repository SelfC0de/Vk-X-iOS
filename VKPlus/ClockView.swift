import SwiftUI

// MARK: - Live Clock Widget
struct ClockView: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if s.showClock {
            Text(timeString)
                .font(clockFont)
                .foregroundStyle(Color.onSurface.opacity(0.85))
                .monospacedDigit()
                .onReceive(timer) { now = $0 }
                .animation(.none, value: now)
        }
    }

    private var timeString: String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let sec = cal.component(.second, from: now)

        if s.clockAmPm {
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            let suffix = h < 12 ? "AM" : "PM"
            if s.clockSeconds {
                return String(format: "%d:%02d:%02d %@", h12, m, sec, suffix)
            } else {
                return String(format: "%d:%02d %@", h12, m, suffix)
            }
        } else {
            if s.clockSeconds {
                return String(format: "%02d:%02d:%02d", h, m, sec)
            } else {
                return String(format: "%02d:%02d", h, m)
            }
        }
    }

    private var clockFont: Font {
        switch s.clockStyle {
        case "minimal": return .system(size: 13, weight: .light, design: .rounded)
        case "bold":    return .system(size: 14, weight: .bold,  design: .rounded)
        default:        return .system(size: 13, weight: .medium, design: .monospaced)
        }
    }
}
