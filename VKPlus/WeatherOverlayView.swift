import SwiftUI

// MARK: - Single particle
private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var drift: CGFloat   // horizontal drift
    var opacity: Double
    var size: CGFloat
    var rotation: Double // for snowflakes
    var rotSpeed: Double
}

// MARK: - Weather Overlay
struct WeatherOverlayView: View {
    @ObservedObject private var s = SettingsStore.shared
    @State private var rainDrops: [Particle] = []
    @State private var snowFlakes: [Particle] = []
    @State private var ticker: Int = 0
    @State private var screenW: CGFloat = UIScreen.main.bounds.width
    @State private var screenH: CGFloat = UIScreen.main.bounds.height

    private let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fog
                if s.weatherFog {
                    fogLayer
                }
                // Rain
                if s.weatherRain {
                    ForEach(rainDrops) { p in
                        RainDrop()
                            .stroke(Color(red:0.6,green:0.75,blue:0.95).opacity(p.opacity), lineWidth: 1)
                            .frame(width: 2, height: p.size)
                            .position(x: p.x, y: p.y)
                    }
                }
                // Snow
                if s.weatherSnow {
                    ForEach(snowFlakes) { p in
                        Text("❄")
                            .font(.system(size: p.size))
                            .opacity(p.opacity)
                            .rotationEffect(.degrees(p.rotation))
                            .position(x: p.x, y: p.y)
                    }
                }
            }
            .onAppear {
                screenW = geo.size.width
                screenH = geo.size.height
                spawnInitial()
            }
            .onReceive(timer) { _ in
                ticker += 1
                update(w: geo.size.width, h: geo.size.height)
            }
            .onChange(of: s.weatherRain) { _, on in if on { spawnRain(w: geo.size.width, h: geo.size.height) } else { rainDrops.removeAll() } }
            .onChange(of: s.weatherSnow) { _, on in if on { spawnSnow(w: geo.size.width, h: geo.size.height) } else { snowFlakes.removeAll() } }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Fog — full-screen multi-layer
    private var fogLayer: some View {
        ZStack {
            // 5 layers at different depths/speeds for parallax feel
            FogLayer(index: 0, speed: 22, yFrac: 0.15, opacity: 0.13, widthFrac: 1.4, height: 160)
            FogLayer(index: 1, speed: 31, yFrac: 0.38, opacity: 0.11, widthFrac: 1.2, height: 140)
            FogLayer(index: 2, speed: 18, yFrac: 0.58, opacity: 0.14, widthFrac: 1.6, height: 180)
            FogLayer(index: 3, speed: 26, yFrac: 0.75, opacity: 0.10, widthFrac: 1.3, height: 150)
            FogLayer(index: 4, speed: 20, yFrac: 0.92, opacity: 0.12, widthFrac: 1.5, height: 170)
            // Ambient base fill — very subtle grey tint over entire screen
            Color.white.opacity(0.04).ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Spawn
    private func spawnInitial() {
        if s.weatherRain { spawnRain(w: screenW, h: screenH) }
        if s.weatherSnow { spawnSnow(w: screenW, h: screenH) }
    }

    private func spawnRain(w: CGFloat, h: CGFloat) {
        rainDrops = (0..<60).map { _ in
            Particle(x: CGFloat.random(in: 0...w),
                     y: CGFloat.random(in: -h...h),
                     speed: CGFloat.random(in: 14...22),
                     drift: CGFloat.random(in: 1.5...4),
                     opacity: Double.random(in: 0.4...0.8),
                     size: CGFloat.random(in: 12...22),
                     rotation: 0, rotSpeed: 0)
        }
    }

    private func spawnSnow(w: CGFloat, h: CGFloat) {
        snowFlakes = (0..<40).map { _ in
            Particle(x: CGFloat.random(in: 0...w),
                     y: CGFloat.random(in: -h...h),
                     speed: CGFloat.random(in: 1.5...4.0),
                     drift: CGFloat.random(in: -1.5...1.5),
                     opacity: Double.random(in: 0.5...0.9),
                     size: CGFloat.random(in: 8...18),
                     rotation: Double.random(in: 0...360),
                     rotSpeed: Double.random(in: -2...2))
        }
    }

    // MARK: Update
    private func update(w: CGFloat, h: CGFloat) {
        // Rain
        if s.weatherRain {
            for i in rainDrops.indices {
                rainDrops[i].y += rainDrops[i].speed
                rainDrops[i].x += rainDrops[i].drift
                if rainDrops[i].y > h + 30 {
                    rainDrops[i].y = CGFloat.random(in: -40 ... -10)
                    rainDrops[i].x = CGFloat.random(in: -20...w+20)
                }
            }
            // Spawn extra drop occasionally
            if ticker % 4 == 0 && rainDrops.count < 80 {
                rainDrops.append(Particle(x: CGFloat.random(in: 0...w),
                                          y: -20, speed: CGFloat.random(in: 14...22),
                                          drift: CGFloat.random(in: 1.5...4),
                                          opacity: Double.random(in: 0.4...0.8),
                                          size: CGFloat.random(in: 12...22),
                                          rotation: 0, rotSpeed: 0))
            }
        }
        // Snow
        if s.weatherSnow {
            for i in snowFlakes.indices {
                snowFlakes[i].y += snowFlakes[i].speed
                // Gentle sway
                snowFlakes[i].x += snowFlakes[i].drift + sin(Double(ticker) * 0.05 + Double(i)) * 0.4
                snowFlakes[i].rotation += snowFlakes[i].rotSpeed
                if snowFlakes[i].y > h + 20 {
                    snowFlakes[i].y = CGFloat.random(in: -20 ... -5)
                    snowFlakes[i].x = CGFloat.random(in: 0...w)
                }
            }
        }
    }
}

// MARK: - Rain drop shape
private struct RainDrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// MARK: - Fog cloud
private struct FogLayer: View {
    let index:     Int
    let speed:     Double    // animation duration
    let yFrac:     Double    // vertical position 0..1
    let opacity:   Double
    let widthFrac: Double    // width multiplier vs screen
    let height:    CGFloat

    @State private var offsetX: CGFloat = 0
    @State private var scale:   CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let layerW = w * widthFrac
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(opacity), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: layerW * 0.5
                    )
                )
                .frame(width: layerW, height: height)
                .blur(radius: 28)
                .scaleEffect(x: scale, y: 1)
                .position(x: w / 2 + offsetX, y: h * yFrac)
                .onAppear {
                    let startX = CGFloat.random(in: -w * 0.3 ... w * 0.3)
                    offsetX = startX
                    scale   = CGFloat.random(in: 0.85...1.15)
                    let dur = speed + Double(index) * 3.7
                    let targetX = startX + CGFloat.random(in: -w * 0.25 ... w * 0.25)
                    withAnimation(
                        .easeInOut(duration: dur).repeatForever(autoreverses: true)
                    ) {
                        offsetX = targetX
                        scale   = CGFloat.random(in: 0.9...1.2)
                    }
                }
        }
        .ignoresSafeArea()
    }
}
