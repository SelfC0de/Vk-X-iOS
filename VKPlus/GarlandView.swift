import SwiftUI

// MARK: - Bulb data
private struct Bulb: Identifiable {
    let id       = UUID()
    let x:        CGFloat   // position along wire
    let color:    Color
    var isOn:     Bool   = true
    var bright:   Double = 1.0
    let phase:    Double  // flicker phase offset
    let size:     CGFloat
    let dropY:    CGFloat // vertical drop from wire
}

// MARK: - GarlandView
// Renders along bottom edge of navigation bar — wire + small round bulbs hanging down
struct GarlandView: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var bulbs: [Bulb] = []
    @State private var tick: Double  = 0

    private let colors: [Color] = [
        Color(red:1.00, green:0.22, blue:0.22),  // red
        Color(red:1.00, green:0.85, blue:0.10),  // yellow
        Color(red:0.22, green:0.85, blue:0.22),  // green
        Color(red:0.25, green:0.55, blue:1.00),  // blue
        Color(red:1.00, green:0.40, blue:0.90),  // pink
        Color(red:1.00, green:0.55, blue:0.10),  // orange
        Color(red:0.70, green:0.30, blue:1.00),  // purple
    ]

    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        if s.weatherGarland {
            GeometryReader { geo in
                let w = geo.size.width
                Canvas { ctx, size in
                    drawGarland(ctx: ctx, w: w, h: size.height)
                }
                .onAppear { setupBulbs(w: w) }
            }
            .frame(height: 18)
            .onReceive(timer) { _ in
                guard s.weatherGarland else { return }
                tick += 0.08
                flicker()
            }
        }
    }

    // MARK: - Canvas draw
    private func drawGarland(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let wireY: CGFloat = 2  // wire sits at very top of the 18pt frame

        // 1. Wire — single horizontal line across full width
        var wirePath = Path()
        wirePath.move(to: CGPoint(x: 0, y: wireY))
        wirePath.addLine(to: CGPoint(x: w, y: wireY))
        ctx.stroke(wirePath,
                   with: .color(Color(red:0.55, green:0.55, blue:0.55).opacity(0.8)),
                   lineWidth: 1.0)

        // 2. Bulbs
        for bulb in bulbs {
            guard bulb.x <= w else { continue }

            // Short wire drop from main wire to bulb cap
            let capY = wireY + bulb.dropY - bulb.size * 0.6
            var dropPath = Path()
            dropPath.move(to: CGPoint(x: bulb.x, y: wireY))
            dropPath.addLine(to: CGPoint(x: bulb.x, y: capY))
            ctx.stroke(dropPath,
                       with: .color(Color(red:0.55, green:0.55, blue:0.55).opacity(0.7)),
                       lineWidth: 0.8)

            if !bulb.isOn { continue }

            let bulbCenter = CGPoint(x: bulb.x, y: wireY + bulb.dropY)
            let r = bulb.size / 2

            // Glow
            let glowR = r * 2.2
            let glowRect = CGRect(x: bulbCenter.x - glowR, y: bulbCenter.y - glowR,
                                  width: glowR * 2, height: glowR * 2)
            ctx.fill(Path(ellipseIn: glowRect),
                     with: .color(bulb.color.opacity(bulb.bright * 0.25)))

            // Bulb body
            let bulbRect = CGRect(x: bulbCenter.x - r, y: bulbCenter.y - r,
                                  width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: bulbRect),
                     with: .color(bulb.color.opacity(0.25 + bulb.bright * 0.65)))

            // Highlight
            let hlR = r * 0.35
            let hlRect = CGRect(x: bulbCenter.x - hlR * 0.7, y: bulbCenter.y - r * 0.55,
                                width: hlR * 1.4, height: hlR * 1.4)
            ctx.fill(Path(ellipseIn: hlRect),
                     with: .color(Color.white.opacity(bulb.bright * 0.55)))
        }
    }

    // MARK: - Setup
    private func setupBulbs(w: CGFloat) {
        let spacing: CGFloat = 24
        let count = Int(w / spacing) + 1
        bulbs = (0..<count).map { i in
            let x = CGFloat(i) * spacing + spacing / 2
            let color = colors[i % colors.count]
            // Alternate drop heights for natural look
            let drop: CGFloat = i % 2 == 0 ? 10 : 13
            return Bulb(x: x, color: color,
                        phase: Double.random(in: 0...Double.pi * 2),
                        size: CGFloat.random(in: 6...9),
                        dropY: drop)
        }
    }

    // MARK: - Flicker
    private func flicker() {
        for i in bulbs.indices {
            let p = bulbs[i].phase
            let sig = sin(tick * 3.2 + p) * 0.4 + sin(tick * 7.8 + p * 1.6) * 0.25
            bulbs[i].bright = max(0.4, min(1.0, 0.8 + sig))

            // Random off event ~1 per 12 seconds per bulb
            if Int.random(in: 0...150) == 0 {
                bulbs[i].isOn = false
                let idx = i
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.6)) {
                    if idx < bulbs.count { bulbs[idx].isOn = true }
                }
            }
        }
    }
}

// MARK: - GarlandNavBar
// Full-width transparent overlay that sits at top of screen, garland on bottom edge of navbar
struct GarlandNavBar: View {
    @ObservedObject private var s = SettingsStore.shared

    var body: some View {
        if s.weatherGarland {
            GarlandView()
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .background(Color.clear)
                .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }
}
