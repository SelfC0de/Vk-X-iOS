import SwiftUI

// MARK: - Clock styles registry
// id / display name / description
let clockStyles: [(id: String, name: String, desc: String)] = [
    ("digital",   "Digital",   "00:00"),
    ("minimal",   "Minimal",   "0·00"),
    ("bold",      "Bold",      "00:00"),
    ("neon",      "Neon",      "00:00"),
    ("retro",     "Retro",     "00·00"),
    ("pill",      "Pill",      "[ 00:00 ]"),
    ("dots",      "Dots",      "00 • 00"),
    ("serif",     "Serif",     "00:00"),
    ("cyber",     "Cyber",     "〈00:00〉"),
]

// MARK: - ClockView (used in tab bar / header)
struct ClockView: View {
    @ObservedObject private var s = SettingsStore.shared
    @Environment(\.colorScheme) private var cs
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if s.showClock {
            clockContent(style: s.clockStyle, now: now, ampm: s.clockAmPm, sec: s.clockSeconds, colorHex: s.clockColorHex, cs: cs)
                .onReceive(timer) { now = $0 }
                .animation(.none, value: now)
        }
    }
}

// MARK: - Clock renderer (reused in ClockStylePicker preview)
@ViewBuilder
func clockContent(style: String, now: Date, ampm: Bool, sec: Bool, colorHex: String, cs: ColorScheme) -> some View {
    let color: Color = colorHex == "auto"
        ? (cs == .dark ? .white.opacity(0.85) : .black.opacity(0.75))
        : Color(hex: colorHex)
    let t = timeComponents(now: now, ampm: ampm, sec: sec)

    switch style {

    // ── Digital ─ monospaced, medium weight
    case "digital":
        Text(t.full)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .monospacedDigit()

    // ── Minimal ─ light, dots separator
    case "minimal":
        Text(t.full.replacingOccurrences(of: ":", with: "·"))
            .font(.system(size: 13, weight: .light, design: .rounded))
            .foregroundStyle(color.opacity(0.75))
            .monospacedDigit()

    // ── Bold ─ heavy weight
    case "bold":
        Text(t.full)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()

    // ── Neon ─ cyan glow effect
    case "neon":
        Text(t.full)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.cyan)
            .monospacedDigit()
            .shadow(color: Color.cyan.opacity(0.9), radius: 4, x: 0, y: 0)
            .shadow(color: Color.cyan.opacity(0.5), radius: 8, x: 0, y: 0)

    // ── Retro ─ orange, serif-ish, bullet separator
    case "retro":
        Text(t.full.replacingOccurrences(of: ":", with: "·"))
            .font(.system(size: 13, weight: .semibold, design: .serif))
            .foregroundStyle(Color(r:0xFF,g:0x8C,b:0x00))
            .monospacedDigit()

    // ── Pill ─ bracketed, background capsule
    case "pill":
        Text("[\(t.full)]")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .monospacedDigit()
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())

    // ── Dots ─ bullet separator, spaced
    case "dots":
        Text(t.full.replacingOccurrences(of: ":", with: " • "))
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(color.opacity(0.9))
            .monospacedDigit()

    // ── Serif ─ elegant thin serif
    case "serif":
        Text(t.full)
            .font(.system(size: 14, weight: .thin, design: .serif))
            .foregroundStyle(color)
            .monospacedDigit()
            .tracking(1.5)

    // ── Cyber ─ angle brackets, purple gradient
    case "cyber":
        HStack(spacing: 2) {
            Text("〈")
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color(r:0x8B,g:0x5C,b:0xF6).opacity(0.7))
            Text(t.full)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(colors: [Color(r:0xC0,g:0x7A,b:0xFF), Color(r:0x8B,g:0x5C,b:0xF6)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .monospacedDigit()
            Text("〉")
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color(r:0x8B,g:0x5C,b:0xF6).opacity(0.7))
        }

    default:
        Text(t.full)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

// MARK: - Time components helper
struct ClockTime {
    let full: String
}

func timeComponents(now: Date, ampm: Bool, sec: Bool) -> ClockTime {
    let cal = Calendar.current
    let h   = cal.component(.hour,   from: now)
    let m   = cal.component(.minute, from: now)
    let s   = cal.component(.second, from: now)
    var str: String
    if ampm {
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        let sfx = h < 12 ? "AM" : "PM"
        str = sec ? String(format: "%d:%02d:%02d %@", h12, m, s, sfx)
                  : String(format: "%d:%02d %@", h12, m, sfx)
    } else {
        str = sec ? String(format: "%02d:%02d:%02d", h, m, s)
                  : String(format: "%02d:%02d", h, m)
    }
    return ClockTime(full: str)
}

// MARK: - Clock Style Picker (used in VisualSettingsView)
struct ClockStylePicker: View {
    @Binding var selected: String
    let ampm: Bool; let sec: Bool; let colorHex: String
    @Environment(\.colorScheme) private var cs
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Стиль")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.onSurfaceMut)
                .padding(.horizontal, 14)
                .padding(.top, 12)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(clockStyles, id: \.id) { style in
                    Button {
                        withAnimation(.spring(response: 0.25)) { selected = style.id }
                    } label: {
                        VStack(spacing: 6) {
                            // Live preview
                            clockContent(style: style.id, now: now, ampm: ampm, sec: false, colorHex: colorHex, cs: cs)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(height: 22)
                            Text(style.name)
                                .font(.system(size: 10, weight: selected == style.id ? .semibold : .regular))
                                .foregroundStyle(selected == style.id ? Color.cyberBlue : Color.onSurfaceMut)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10).padding(.horizontal, 4)
                        .background(selected == style.id ? Color.cyberBlue.opacity(0.10) : Color(red:0.07,green:0.08,blue:0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            selected == style.id ? Color.cyberBlue.opacity(0.45) : Color.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
        .onReceive(timer) { now = $0 }
    }
}
