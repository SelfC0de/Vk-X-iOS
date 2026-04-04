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

    // MARK: Fog
    private var fogLayer: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                FogCloud(offset: Double(i) * 0.33)
            }
        }
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
private struct FogCloud: View {
    let offset: Double
    @State private var x: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Ellipse()
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.0)
                    ], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: w * 0.7, height: 80)
                .blur(radius: 20)
                .offset(x: x, y: geo.size.height * (0.2 + offset * 0.3))
                .onAppear {
                    x = CGFloat.random(in: -w/2...w/2)
                    withAnimation(.linear(duration: Double.random(in: 18...30)).repeatForever(autoreverses: true)) {
                        x = CGFloat.random(in: -w/3...w/3)
                    }
                }
        }
    }
}
