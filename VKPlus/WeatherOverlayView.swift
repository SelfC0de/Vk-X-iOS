import SwiftUI

// MARK: - Particle
private struct Particle: Identifiable {
    let id = UUID()
    var x, y, speed, drift, opacity, size, rotation, rotSpeed: CGFloat
    var vx: CGFloat = 0  // extra velocity X
    var vy: CGFloat = 0  // extra velocity Y
    var life: CGFloat = 1.0  // 0..1 lifespan (for fire/pixels)
    var hue: CGFloat = 0     // for aurora/pixels
    var phase: CGFloat = 0   // for bubbles/aurora
}

// MARK: - Weather Overlay
struct WeatherOverlayView: View {
    @ObservedObject private var s = SettingsStore.shared

    @State private var rain:    [Particle] = []
    @State private var snow:    [Particle] = []
    @State private var leaves:  [Particle] = []
    @State private var sakura:  [Particle] = []
    @State private var bubbles: [Particle] = []
    @State private var stars:   [Particle] = []
    @State private var fire:    [Particle] = []
    @State private var pixels:  [Particle] = []
    @State private var ticker:  CGFloat    = 0
    @State private var W: CGFloat = UIScreen.main.bounds.width
    @State private var H: CGFloat = UIScreen.main.bounds.height

    private let fps = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if s.weatherFog    { fogLayer }
                if s.weatherAurora { AuroraView(ticker: ticker) }
                layer1
                layer2
            }
            .onAppear {
                W = geo.size.width; H = geo.size.height
                spawnAll()
            }
            .onReceive(fps) { _ in
                ticker += 1
                updateAll(w: geo.size.width, h: geo.size.height)
            }
            .onChange(of: s.weatherRain)    { _, on in on ? spawn(&rain,    makeRain)    : rain.removeAll()    }
            .onChange(of: s.weatherSnow)    { _, on in on ? spawn(&snow,    makeSnow)    : snow.removeAll()    }
            .onChange(of: s.weatherLeaves)  { _, on in on ? spawn(&leaves,  makeLeaf)    : leaves.removeAll()  }
            .onChange(of: s.weatherSakura)  { _, on in on ? spawn(&sakura,  makeSakura)  : sakura.removeAll()  }
            .onChange(of: s.weatherBubbles) { _, on in on ? spawn(&bubbles, makeBubble)  : bubbles.removeAll() }
            .onChange(of: s.weatherStars)   { _, on in on ? spawn(&stars,   makeStar)    : stars.removeAll()   }
            .onChange(of: s.weatherFire)    { _, on in on ? spawn(&fire,    makeFire)    : fire.removeAll()    }
            .onChange(of: s.weatherPixels)  { _, on in on ? spawn(&pixels,  makePixel)   : pixels.removeAll()  }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // ── Fog ──────────────────────────────────────────────────────────
    private var fogLayer: some View {
        ZStack {
            FogLayer(index:0, speed:22, yFrac:0.15, opacity:0.13, widthFrac:1.4, height:160)
            FogLayer(index:1, speed:31, yFrac:0.38, opacity:0.11, widthFrac:1.2, height:140)
            FogLayer(index:2, speed:18, yFrac:0.58, opacity:0.14, widthFrac:1.6, height:180)
            FogLayer(index:3, speed:26, yFrac:0.75, opacity:0.10, widthFrac:1.3, height:150)
            FogLayer(index:4, speed:20, yFrac:0.92, opacity:0.12, widthFrac:1.5, height:170)
            Color.white.opacity(0.04).ignoresSafeArea()
        }.ignoresSafeArea().allowsHitTesting(false)
    }


    // Split rendering into layers to avoid type-checker timeout
    @ViewBuilder private var layer1: some View {
        ZStack {
            if s.weatherRain {
                ForEach(rain) { p in
                    RainDrop().stroke(Color(red:0.6,green:0.75,blue:0.95).opacity(Double(p.opacity)), lineWidth:1.2)
                        .frame(width:2, height:p.size).position(x:p.x, y:p.y)
                }
            }
            if s.weatherSnow {
                ForEach(snow) { p in
                    Text("❄").font(.system(size:p.size)).opacity(Double(p.opacity))
                        .rotationEffect(.degrees(Double(p.rotation))).position(x:p.x, y:p.y)
                }
            }
            if s.weatherLeaves {
                ForEach(leaves) { p in
                    LeafShape().fill(Color(hue:Double(p.hue), saturation:0.85, brightness:0.75))
                        .frame(width:p.size, height:p.size*0.7).opacity(Double(p.opacity))
                        .rotationEffect(.degrees(Double(p.rotation))).position(x:p.x, y:p.y)
                }
            }
            if s.weatherSakura {
                ForEach(sakura) { p in
                    PetalShape().fill(Color(hue:0.94, saturation:0.35+Double(p.hue)*0.2, brightness:0.97))
                        .frame(width:p.size, height:p.size*0.6).opacity(Double(p.opacity))
                        .rotationEffect(.degrees(Double(p.rotation))).position(x:p.x, y:p.y)
                }
            }
        }
    }

    @ViewBuilder private var layer2: some View {
        ZStack {
            if s.weatherBubbles {
                ForEach(bubbles) { p in
                    Circle()
                        .stroke(LinearGradient(colors:[Color(hue:Double(p.hue),saturation:0.6,brightness:1).opacity(0.7),Color.white.opacity(0.2)],startPoint:.topLeading,endPoint:.bottomTrailing), lineWidth:1.5)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .frame(width:p.size, height:p.size).opacity(Double(p.opacity)).position(x:p.x, y:p.y)
                }
            }
            if s.weatherStars {
                ForEach(stars) { p in
                    MeteorShape()
                        .stroke(LinearGradient(colors:[Color.white.opacity(Double(p.opacity)),Color.white.opacity(0)],startPoint:.leading,endPoint:.trailing), lineWidth:1.5)
                        .frame(width:p.size*4, height:2).opacity(Double(p.opacity))
                        .rotationEffect(.degrees(Double(p.rotation))).position(x:p.x, y:p.y)
                }
            }
            if s.weatherFire {
                ForEach(fire) { p in
                    Circle().fill(Color(hue:Double(p.hue)*0.08, saturation:1, brightness:1))
                        .frame(width:p.size, height:p.size).opacity(Double(p.opacity*p.life))
                        .blur(radius:p.size*0.3).position(x:p.x, y:p.y)
                }
            }
            if s.weatherPixels {
                ForEach(pixels) { p in
                    RoundedRectangle(cornerRadius:2).fill(Color(hue:Double(p.hue), saturation:0.9, brightness:0.95))
                        .frame(width:p.size, height:p.size).opacity(Double(p.opacity*p.life))
                        .rotationEffect(.degrees(Double(p.rotation))).position(x:p.x, y:p.y)
                }
            }
        }
    }

    // ── Spawn all active ─────────────────────────────────────────────
    private func spawnAll() {
        if s.weatherRain    { spawn(&rain,    makeRain)    }
        if s.weatherSnow    { spawn(&snow,    makeSnow)    }
        if s.weatherLeaves  { spawn(&leaves,  makeLeaf)    }
        if s.weatherSakura  { spawn(&sakura,  makeSakura)  }
        if s.weatherBubbles { spawn(&bubbles, makeBubble)  }
        if s.weatherStars   { spawn(&stars,   makeStar)    }
        if s.weatherFire    { spawn(&fire,    makeFire)    }
        if s.weatherPixels  { spawn(&pixels,  makePixel)   }
    }

    private func spawn(_ arr: inout [Particle], _ factory: (CGFloat, CGFloat) -> Particle) {
        arr = (0..<count(factory)).map { _ in factory(W, H) }
    }

    private func count(_ f: (CGFloat,CGFloat)->Particle) -> Int {
        // Different counts per type
        if f(1,1).size > 20 { return 20 } // stars/leaves bigger
        return 35
    }

    // ── Factories ────────────────────────────────────────────────────
    private func makeRain(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: .random(in:-h...h),
                 speed: .random(in:14...22), drift: .random(in:1.5...4),
                 opacity: .random(in:0.4...0.8), size: .random(in:12...22),
                 rotation: 0, rotSpeed: 0)
    }
    private func makeSnow(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: .random(in:-h...h),
                 speed: .random(in:1.5...4), drift: .random(in:-1.5...1.5),
                 opacity: .random(in:0.5...0.9), size: .random(in:8...18),
                 rotation: .random(in:0...360), rotSpeed: .random(in:-2...2))
    }
    private func makeLeaf(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: .random(in:-h...h),
                 speed: .random(in:1.2...3.5), drift: .random(in:-2...2),
                 opacity: .random(in:0.6...0.9), size: .random(in:14...28),
                 rotation: .random(in:0...360), rotSpeed: .random(in:-3...3),
                 hue: .random(in:0.04...0.11)) // orange/red/brown
    }
    private func makeSakura(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: .random(in:-h...h),
                 speed: .random(in:0.8...2.5), drift: .random(in:-2.5...2.5),
                 opacity: .random(in:0.5...0.9), size: .random(in:8...18),
                 rotation: .random(in:0...360), rotSpeed: .random(in:-4...4),
                 hue: .random(in:0...0.05)) // pink tint variation
    }
    private func makeBubble(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in: w*0.1...w*0.9), y: h + .random(in:10...60),
                 speed: .random(in:0.8...2.5), drift: .random(in:-0.8...0.8),
                 opacity: .random(in:0.4...0.8), size: .random(in:12...40),
                 rotation: 0, rotSpeed: 0,
                 hue: .random(in:0...1),
                 phase: .random(in:0...6.28))
    }
    private func makeStar(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: .random(in:0...h*0.5),
                 speed: .random(in:8...18), drift: .random(in:6...14),
                 opacity: .random(in:0.6...1.0), size: .random(in:20...50),
                 rotation: .random(in:20...40), rotSpeed: 0)
    }
    private func makeFire(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: h + .random(in:0...20),
                 speed: .random(in:2...6), drift: .random(in:-1.5...1.5),
                 opacity: .random(in:0.6...1.0), size: .random(in:3...9),
                 rotation: 0, rotSpeed: 0,
                 life: .random(in:0.5...1.0),
                 hue: .random(in:0...1))
    }
    private func makePixel(_ w: CGFloat, _ h: CGFloat) -> Particle {
        Particle(x: .random(in:0...w), y: .random(in:0...h),
                 speed: .random(in:-1...1), drift: .random(in:-1...1),
                 opacity: .random(in:0.5...1.0), size: .random(in:4...10),
                 rotation: .random(in:0...45), rotSpeed: .random(in:-1...1),
                 life: .random(in:0.3...1.0),
                 hue: .random(in:0...1))
    }

    // ── Update all ───────────────────────────────────────────────────
    private func updateAll(w: CGFloat, h: CGFloat) {
        let dt = ticker

        if s.weatherRain {
            for i in rain.indices {
                rain[i].y += rain[i].speed; rain[i].x += rain[i].drift
                if rain[i].y > h+30 { rain[i].y = .random(in:-40 ... -10); rain[i].x = .random(in:-20...w+20) }
            }
        }

        if s.weatherSnow {
            for i in snow.indices {
                snow[i].y += snow[i].speed
                snow[i].x += snow[i].drift + sin(Double(dt)*0.05 + Double(i))*0.4
                snow[i].rotation += snow[i].rotSpeed
                if snow[i].y > h+20 { snow[i].y = .random(in:-20 ... -5); snow[i].x = .random(in:0...w) }
            }
        }

        if s.weatherLeaves {
            for i in leaves.indices {
                leaves[i].y += leaves[i].speed
                leaves[i].x += leaves[i].drift + sin(Double(dt)*0.04 + Double(i)*0.7) * 1.2
                leaves[i].rotation += leaves[i].rotSpeed
                if leaves[i].y > h+30 {
                    leaves[i].y = .random(in:-30 ... -10)
                    leaves[i].x = .random(in:0...w)
                    leaves[i].hue = .random(in:0.04...0.11)
                }
            }
        }

        if s.weatherSakura {
            for i in sakura.indices {
                sakura[i].y += sakura[i].speed
                sakura[i].x += sakura[i].drift + sin(Double(dt)*0.03 + Double(i)*0.5) * 1.5
                sakura[i].rotation += sakura[i].rotSpeed
                if sakura[i].y > h+20 {
                    sakura[i].y = .random(in:-20 ... -5)
                    sakura[i].x = .random(in:0...w)
                }
            }
        }

        if s.weatherBubbles {
            for i in bubbles.indices {
                bubbles[i].y -= bubbles[i].speed
                bubbles[i].x += sin(Double(dt)*0.05 + Double(bubbles[i].phase)) * 0.6
                // Fade in at bottom, fade out near top
                let progress = 1.0 - (bubbles[i].y / h)
                bubbles[i].opacity = min(1.0, progress * 2) * 0.75
                if bubbles[i].y < -bubbles[i].size {
                    bubbles[i].y = h + .random(in:10...60)
                    bubbles[i].x = .random(in: w*0.1...w*0.9)
                    bubbles[i].hue = .random(in:0...1)
                    bubbles[i].size = .random(in:12...40)
                    bubbles[i].speed = .random(in:0.8...2.5)
                }
            }
        }

        if s.weatherStars {
            for i in stars.indices {
                stars[i].x += stars[i].drift
                stars[i].y += stars[i].speed
                stars[i].opacity -= 0.018
                if stars[i].opacity <= 0 || stars[i].y > h*0.8 {
                    stars[i] = makeStar(w, h)
                    stars[i].opacity = 0
                    // Stagger re-entry opacity
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...2)) {
                        if i < self.stars.count { self.stars[i].opacity = .random(in:0.6...1.0) }
                    }
                }
            }
        }

        if s.weatherFire {
            for i in fire.indices {
                fire[i].y -= fire[i].speed
                fire[i].x += fire[i].drift + sin(Double(dt)*0.1 + Double(i)*0.3) * 0.4
                fire[i].life -= 0.015
                fire[i].opacity = fire[i].life
                fire[i].size *= 0.99
                if fire[i].life <= 0 {
                    fire[i] = makeFire(w, h)
                }
            }
            // Spawn new sparks from random bottom positions
            if Int(dt) % 3 == 0 && fire.count < 60 {
                fire.append(makeFire(w, h))
            }
        }

        if s.weatherPixels {
            for i in pixels.indices {
                pixels[i].x += pixels[i].drift + sin(Double(dt)*0.07 + Double(i)) * 0.5
                pixels[i].y += pixels[i].speed
                pixels[i].rotation += pixels[i].rotSpeed
                pixels[i].life -= 0.008
                pixels[i].opacity = pixels[i].life
                if pixels[i].life <= 0 {
                    pixels[i] = makePixel(w, h)
                }
            }
        }
    }
}

// MARK: - Shapes
private struct RainDrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x:rect.midX,y:rect.minY)); p.addLine(to: CGPoint(x:rect.maxX,y:rect.maxY)); return p
    }
}
private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x:rect.midX, y:rect.minY))
        p.addQuadCurve(to: CGPoint(x:rect.maxX, y:rect.midY), control: CGPoint(x:rect.maxX, y:rect.minY))
        p.addQuadCurve(to: CGPoint(x:rect.midX, y:rect.maxY), control: CGPoint(x:rect.maxX, y:rect.maxY))
        p.addQuadCurve(to: CGPoint(x:rect.minX, y:rect.midY), control: CGPoint(x:rect.minX, y:rect.maxY))
        p.addQuadCurve(to: CGPoint(x:rect.midX, y:rect.minY), control: CGPoint(x:rect.minX, y:rect.minY))
        return p
    }
}
private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x:rect.midX, y:rect.minY))
        p.addQuadCurve(to: CGPoint(x:rect.maxX, y:rect.midY), control: CGPoint(x:rect.maxX*0.9, y:rect.minY))
        p.addQuadCurve(to: CGPoint(x:rect.midX, y:rect.maxY), control: CGPoint(x:rect.maxX, y:rect.maxY))
        p.addQuadCurve(to: CGPoint(x:rect.minX, y:rect.midY), control: CGPoint(x:rect.minX, y:rect.maxY))
        p.addQuadCurve(to: CGPoint(x:rect.midX, y:rect.minY), control: CGPoint(x:rect.minX*0.1, y:rect.minY))
        return p
    }
}
private struct MeteorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x:rect.minX,y:rect.midY)); p.addLine(to: CGPoint(x:rect.maxX,y:rect.midY)); return p
    }
}

// MARK: - Aurora
private struct AuroraView: View {
    let ticker: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            // 4 aurora bands
            let bands: [(hue: Double, yFrac: Double, amp: Double, speed: Double)] = [
                (0.38, 0.08, 0.06, 0.008),  // green
                (0.75, 0.14, 0.05, 0.011),  // purple
                (0.50, 0.06, 0.04, 0.007),  // cyan
                (0.65, 0.18, 0.07, 0.009),  // violet
            ]
            for band in bands {
                var path = Path()
                path.move(to: CGPoint(x:0, y:h*band.yFrac))
                let steps = 40
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let x = t * w
                    let wave = sin(Double(t) * 4 * .pi + Double(ticker) * band.speed)
                    let y = h * (band.yFrac + band.amp * wave)
                    path.addLine(to: CGPoint(x:x, y:y))
                }
                // Make curtain by closing downward
                for i in stride(from: steps, through: 0, by: -1) {
                    let t = CGFloat(i) / CGFloat(steps)
                    let x = t * w
                    let wave = sin(Double(t) * 4 * .pi + Double(ticker) * band.speed + 0.5)
                    let y = h * (band.yFrac + band.amp * wave + 0.12)
                    path.addLine(to: CGPoint(x:x, y:y))
                }
                path.closeSubpath()
                ctx.fill(path, with: .color(Color(hue:band.hue, saturation:0.7, brightness:0.9).opacity(0.12)))
                ctx.stroke(path, with: .color(Color(hue:band.hue, saturation:0.8, brightness:1.0).opacity(0.18)), lineWidth: 1)
            }
        }
        .blur(radius: 12)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Fog Layer
private struct FogLayer: View {
    let index: Int; let speed: Double; let yFrac: Double
    let opacity: Double; let widthFrac: Double; let height: CGFloat
    @State private var offsetX: CGFloat = 0
    @State private var scale:   CGFloat = 1.0
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let lw = w * widthFrac
            Ellipse()
                .fill(RadialGradient(colors:[Color.white.opacity(opacity),Color.white.opacity(0)],
                                     center:.center, startRadius:0, endRadius:lw*0.5))
                .frame(width:lw, height:height)
                .blur(radius:28)
                .scaleEffect(x:scale, y:1)
                .position(x:w/2+offsetX, y:h*yFrac)
                .onAppear {
                    let sx = CGFloat.random(in:-w*0.3...w*0.3); offsetX = sx; scale = CGFloat.random(in:0.85...1.15)
                    let dur = speed + Double(index)*3.7
                    withAnimation(.easeInOut(duration:dur).repeatForever(autoreverses:true)) {
                        offsetX = sx + CGFloat.random(in:-w*0.25...w*0.25)
                        scale = CGFloat.random(in:0.9...1.2)
                    }
                }
        }.ignoresSafeArea()
    }
}
