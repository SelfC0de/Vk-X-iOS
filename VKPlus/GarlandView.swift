import SwiftUI

// MARK: - Garland bulb
private struct Bulb: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat          // hanging offset from wire
    var color: Color
    var isOn: Bool = true
    var brightness: Double  // 0.0 ... 1.0
    var phase: Double       // random phase for flicker
    var size: CGFloat
}

// MARK: - Garland View
struct GarlandView: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var bulbs: [Bulb] = []
    @State private var tick: Double = 0
    @State private var screenW: CGFloat = UIScreen.main.bounds.width

    private let colors: [Color] = [
        Color(red:1.0, green:0.15, blue:0.15),   // red
        Color(red:1.0, green:0.85, blue:0.1),    // yellow
        Color(red:0.2, green:0.85, blue:0.2),    // green
        Color(red:0.2, green:0.5,  blue:1.0),    // blue
        Color(red:1.0, green:0.4,  blue:0.9),    // pink
        Color(red:1.0, green:0.55, blue:0.1),    // orange
    ]

    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        if s.weatherGarland {
            GeometryReader { geo in
                ZStack {
                    // Wire — catenary curve
                    WireShape(width: geo.size.width, sag: 10)
                        .stroke(Color(red:0.25, green:0.25, blue:0.25), lineWidth: 1.2)

                    // Bulbs
                    ForEach(Array(bulbs.enumerated()), id: \.element.id) { idx, bulb in
                        ZStack {
                            // Glow halo
                            Circle()
                                .fill(bulb.color.opacity(bulb.isOn ? bulb.brightness * 0.35 : 0))
                                .frame(width: bulb.size * 2.8, height: bulb.size * 2.8)
                                .blur(radius: 4)

                            // Cap (small grey rectangle)
                            Rectangle()
                                .fill(Color(red:0.4, green:0.4, blue:0.4))
                                .frame(width: 3, height: 4)
                                .offset(y: -bulb.size * 0.6)

                            // Bulb body
                            BulbShape()
                                .fill(bulb.isOn
                                      ? bulb.color.opacity(0.3 + bulb.brightness * 0.7)
                                      : Color(red:0.25, green:0.25, blue:0.25))
                                .overlay(
                                    BulbShape()
                                        .fill(LinearGradient(
                                            colors: [.white.opacity(bulb.isOn ? 0.6 : 0.1), .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                )
                                .frame(width: bulb.size, height: bulb.size * 1.3)
                        }
                        .position(x: bulb.x, y: bulb.y + catenaryY(x: bulb.x, w: geo.size.width, sag: 10))
                    }
                }
                .onAppear {
                    screenW = geo.size.width
                    setupBulbs(w: geo.size.width)
                }
            }
            .frame(height: 40)
            .clipped()
            .onReceive(timer) { _ in
                guard s.weatherGarland else { return }
                tick += 0.08
                updateBulbs()
            }
        }
    }

    // MARK: - Catenary Y offset
    private func catenaryY(x: CGFloat, w: CGFloat, sag: CGFloat) -> CGFloat {
        // Parabola approximation: y = sag * 4 * (x/w) * (1 - x/w)
        let t = x / max(w, 1)
        return sag * 4 * t * (1 - t)
    }

    // MARK: - Setup
    private func setupBulbs(w: CGFloat) {
        let count = Int(w / 28)
        bulbs = (0..<count).map { i in
            let x = CGFloat(i + 1) * (w / CGFloat(count + 1))
            let color = colors[i % colors.count]
            return Bulb(x: x,
                        y: 12,
                        color: color,
                        brightness: Double.random(in: 0.7...1.0),
                        phase: Double.random(in: 0...Double.pi * 2),
                        size: CGFloat.random(in: 7...10))
        }
    }

    // MARK: - Update flicker
    private func updateBulbs() {
        for i in bulbs.indices {
            let p = bulbs[i].phase
            // Each bulb flickers independently via its phase offset
            let signal = sin(tick * 3.5 + p) * 0.5 + sin(tick * 7.1 + p * 1.7) * 0.3
            let b = max(0.0, min(1.0, 0.7 + signal * 0.4))
            bulbs[i].brightness = b
            // Random off event
            if Int.random(in: 0...180) == 0 {
                bulbs[i].isOn = false
                let idx = i
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.5)) {
                    if idx < bulbs.count { bulbs[idx].isOn = true }
                }
            }
        }
    }
}

// MARK: - Wire catenary shape
private struct WireShape: Shape {
    let width: CGFloat
    let sag: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 100
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = t * width
            let y = sag * 4 * t * (1 - t) + 10
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else       { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

// MARK: - Bulb shape (rounded teardrop)
private struct BulbShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Top flat part
        p.move(to: CGPoint(x: w * 0.3, y: 0))
        p.addLine(to: CGPoint(x: w * 0.7, y: 0))
        // Rounded bottom
        p.addCurve(to:     CGPoint(x: w * 0.7, y: h),
                   control1: CGPoint(x: w,     y: h * 0.3),
                   control2: CGPoint(x: w,     y: h))
        p.addCurve(to:     CGPoint(x: w * 0.3, y: h),
                   control1: CGPoint(x: w * 0.5, y: h * 1.1),
                   control2: CGPoint(x: w * 0.5, y: h * 1.1))
        p.addCurve(to:     CGPoint(x: w * 0.3, y: 0),
                   control1: CGPoint(x: 0,     y: h),
                   control2: CGPoint(x: 0,     y: h * 0.3))
        p.closeSubpath()
        return p
    }
}
