import SwiftUI

// MARK: - SplashView
struct SplashView: View {
    let onFinished: () -> Void
    var isAuthenticated: Bool = false

    // Split animation
    @State private var splitTop:    CGFloat = 0
    @State private var splitBot:    CGFloat = 0
    @State private var splitting    = false
    @State private var canvasPhase  = SplashPhase.drawing
    @State private var screenH:     CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()

                if !splitting {
                    // Full canvas animation
                    SplashCanvas(
                        phase: $canvasPhase,
                        onBySelfCodeShown: {
                            if isAuthenticated {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    startSplit(h: geo.size.height)
                                }
                            } else {
                                // Not authenticated — go to auth after short hold
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    onFinished()
                                }
                            }
                        }
                    )
                    .ignoresSafeArea()

                } else {
                    // Top half: clip to upper portion, slide up
                    SplashCanvas(phase: $canvasPhase, onBySelfCodeShown: {})
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .frame(width: geo.size.width, height: geo.size.height / 2, alignment: .top)
                        .clipped()
                        .offset(y: -splitTop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()

                    // Bottom half: clip to lower portion, slide down
                    SplashCanvas(phase: $canvasPhase, onBySelfCodeShown: {})
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: -geo.size.height / 2)
                        .frame(width: geo.size.width, height: geo.size.height / 2, alignment: .top)
                        .clipped()
                        .offset(y: geo.size.height / 2 + splitBot)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }
            }
            .onAppear { screenH = geo.size.height }
        }
    }

    private func startSplit(h: CGFloat) {
        splitting = true
        withAnimation(.easeIn(duration: 0.55).delay(0.05)) {
            splitTop = h / 2 + 80
            splitBot = h / 2 + 80
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onFinished()
        }
    }
}

// MARK: - Phase
enum SplashPhase: Equatable {
    case drawing, holding, bruteforce, done
}

// MARK: - SplashCanvas (TimelineView wrapper)
struct SplashCanvas: View {
    @Binding var phase: SplashPhase
    let onBySelfCodeShown: () -> Void

    @State private var startDate = Date()
    @State private var bySelfCodeFired = false

    // Bruteforce state
    @State private var bruteChars: [Character] = Array(repeating: " ", count: 14)
    @State private var bruteSolved: [Bool]     = Array(repeating: false, count: 14)
    @State private var bruteSolveAt: [Date]    = Array(repeating: Date(), count: 14)
    @State private var bruteStarted = false
    @State private var bruteFlashAt: [Date]    = Array(repeating: Date.distantPast, count: 14)

    private let target = Array("Welcome to VK+")
    private let glyphs = Array("/\\|!@#$%&*?^~<>_=+")

    // Timing constants (seconds)
    private let DRAW_DUR: Double  = 3.6
    private let HOLD_DUR: Double  = 0.9
    private let BRUTE_DELAY: Double = 1.5   // after bySelfCode fully visible
    private let LABEL_START: Double = 0.82  // fraction of DRAW_DUR

    var body: some View {
        TimelineView(.animation) { tl in
            let now = tl.date
            let el  = now.timeIntervalSince(startDate)
            let dp  = min(1.0, el / DRAW_DUR)

            Canvas { ctx, size in
                drawFrame(ctx: ctx, size: size, el: el, dp: dp, now: now)
            }
            .onChange(of: dp) { _, newVal in
                handlePhaseTransitions(el: el, dp: newVal, now: now)
            }
        }
        .background(Color(red: 0.02, green: 0.03, blue: 0.06))
        .onAppear { startDate = Date() }
    }

    // MARK: - Phase transitions
    private func handlePhaseTransitions(el: Double, dp: Double, now: Date) {
        // by SelfCode fully visible → fire callback
        if dp > 0.97 && !bySelfCodeFired {
            bySelfCodeFired = true
            onBySelfCodeShown()
        }
        // Start bruteforce after label shown + delay
        let bruteStartEl = DRAW_DUR * LABEL_START / 0.97 + HOLD_DUR + BRUTE_DELAY
        if el >= bruteStartEl && !bruteStarted {
            bruteStarted = true
            initBrute(now: now)
        }
        // Tick brute
        if bruteStarted { tickBrute(now: now) }
    }

    private func initBrute(now: Date) {
        for i in 0..<14 {
            bruteSolveAt[i] = now.addingTimeInterval(Double(i) * 0.062 + Double.random(in: 0...0.028))
            bruteSolved[i]  = false
            bruteChars[i]   = glyphs[Int.random(in: 0..<glyphs.count)]
        }
    }

    private func tickBrute(now: Date) {
        for i in 0..<14 {
            if bruteSolved[i] { continue }
            if now >= bruteSolveAt[i] {
                if !bruteSolved[i] { bruteFlashAt[i] = now }
                bruteSolved[i] = true
                bruteChars[i]  = target[i]
            } else {
                bruteChars[i] = glyphs[Int.random(in: 0..<glyphs.count)]
            }
        }
    }

    // MARK: - Draw
    private func drawFrame(ctx: GraphicsContext, size: CGSize, el: Double, dp: Double, now: Date) {
        let W = size.width, H = size.height
        let cx = W / 2
        // VK+ logo positioned at 45% height
        let cy = H * 0.45

        // ── helpers ──────────────────────────────────────────────────
        let BLUE = Color(red: 0, green: 0.706, blue: 1)
        let ACC  = Color(red: 0, green: 0.933, blue: 1)

        func pLen(_ pts: [CGPoint]) -> CGFloat {
            var l: CGFloat = 0
            for i in 1..<pts.count {
                let dx = pts[i].x - pts[i-1].x, dy = pts[i].y - pts[i-1].y
                l += sqrt(dx*dx + dy*dy)
            }
            return l
        }

        func endPoint(_ pts: [CGPoint], _ prog: Double) -> CGPoint {
            let total = pLen(pts); var draw = CGFloat(prog) * total
            var ex = pts[0].x, ey = pts[0].y
            for i in 1..<pts.count {
                let dx = pts[i].x - pts[i-1].x, dy = pts[i].y - pts[i-1].y
                let sl = sqrt(dx*dx + dy*dy); if draw <= 0 { break }
                let tk = min(sl, draw)
                ex = pts[i-1].x + dx*(tk/sl); ey = pts[i-1].y + dy*(tk/sl)
                draw -= tk
            }
            return CGPoint(x: ex, y: ey)
        }

        func drawTrace(_ pts: [CGPoint], _ prog: Double, _ color: Color, _ lw: CGFloat) {
            guard prog > 0, pts.count >= 2 else { return }
            let total = pLen(pts); var draw = CGFloat(prog) * total
            var path = Path(); path.move(to: pts[0])
            var ex = pts[0].x, ey = pts[0].y
            for i in 1..<pts.count {
                let dx = pts[i].x-pts[i-1].x, dy = pts[i].y-pts[i-1].y
                let sl = sqrt(dx*dx+dy*dy); if draw <= 0 { break }
                let tk = min(sl, draw)
                ex = pts[i-1].x+dx*(tk/sl); ey = pts[i-1].y+dy*(tk/sl)
                path.addLine(to: CGPoint(x: ex, y: ey)); draw -= tk
            }
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            // endpoint dot
            ctx.fill(Path(ellipseIn: CGRect(x: ex-lw*1.8, y: ey-lw*1.8, width: lw*3.6, height: lw*3.6)), with: .color(ACC))
        }

        // ── geometry anchors ──────────────────────────────────────────
        // VK+ text approx bounds at font size 42
        let FS: CGFloat = 42
        let tw: CGFloat = 78  // approx width of "VK+" at 42px bold
        let th: CGFloat = FS * 0.72
        let lL = cx-tw/2, lR = cx+tw/2, lT = cy-th/2, lB = cy+th/2

        let bx1 = cx-112, by1 = cy-98, bx2 = cx+112, by2 = cy+98
        let br: CGFloat = 18

        let traces: [[CGPoint]] = [
            [.init(x:lL,y:lT),.init(x:lL-20,y:lT),.init(x:lL-20,y:lT-24),.init(x:lL+10,y:lT-24)],
            [.init(x:cx-8,y:lT),.init(x:cx-8,y:lT-36),.init(x:cx+20,y:lT-36)],
            [.init(x:lR-12,y:lT),.init(x:lR-12,y:lT-20),.init(x:lR+14,y:lT-20),.init(x:lR+14,y:lT-44)],
            [.init(x:lR,y:cy),.init(x:lR+20,y:cy),.init(x:lR+20,y:cy-18),.init(x:lR+44,y:cy-18)],
            [.init(x:lR,y:cy+8),.init(x:lR+30,y:cy+8)],
            [.init(x:lR-8,y:lB),.init(x:lR-8,y:lB+22),.init(x:lR+24,y:lB+22),.init(x:lR+24,y:lB+40)],
            [.init(x:cx+10,y:lB),.init(x:cx+10,y:lB+30),.init(x:cx-16,y:lB+30)],
            [.init(x:lL+4,y:lB),.init(x:lL+4,y:lB+20),.init(x:lL-18,y:lB+20),.init(x:lL-18,y:lB+40)],
            [.init(x:lL,y:cy-8),.init(x:lL-22,y:cy-8),.init(x:lL-22,y:cy-32),.init(x:lL-44,y:cy-32)],
            [.init(x:lL,y:cy+8),.init(x:lL-34,y:cy+8)],
            [.init(x:lL,y:cy+18),.init(x:lL-22,y:cy+18),.init(x:lL-22,y:cy+38)],
            [.init(x:cx-4,y:lT-24),.init(x:cx-4,y:lT-48)],
            [.init(x:cx+6,y:lB+30),.init(x:cx+6,y:lB+52),.init(x:cx-14,y:lB+52)],
        ]

        let borderPaths: [[CGPoint]] = [
            [.init(x:bx1+br,y:by1),.init(x:bx1,y:by1),.init(x:bx1,y:by1+br)],
            [.init(x:bx2-br,y:by1),.init(x:bx2,y:by1),.init(x:bx2,y:by1+br)],
            [.init(x:bx1,y:by2-br),.init(x:bx1,y:by2),.init(x:bx1+br,y:by2)],
            [.init(x:bx2,y:by2-br),.init(x:bx2,y:by2),.init(x:bx2-br,y:by2)],
            [.init(x:bx1+br+4,y:by1),.init(x:cx-16,y:by1)],
            [.init(x:cx+16,y:by1),.init(x:bx2-br-4,y:by1)],
            [.init(x:bx1+br+4,y:by2),.init(x:cx-16,y:by2)],
            [.init(x:cx+16,y:by2),.init(x:bx2-br-4,y:by2)],
            [.init(x:bx1,y:by1+br+4),.init(x:bx1,y:by2-br-4)],
            [.init(x:bx2,y:by1+br+4),.init(x:bx2,y:by2-br-4)],
        ]

        let vias: [CGPoint] = [
            .init(x:bx1,y:by1),.init(x:bx2,y:by1),.init(x:bx1,y:by2),.init(x:bx2,y:by2),
            .init(x:lL+10,y:lT-24),.init(x:cx+20,y:lT-36),
            .init(x:lR+14,y:lT-44),.init(x:lR+24,y:lB+40),
            .init(x:lL-18,y:lB+40),.init(x:lL-44,y:cy-32),
            .init(x:lL-22,y:cy+38),.init(x:cx-14,y:lB+52),
            .init(x:cx+6,y:lT-48),.init(x:lR+44,y:cy-18),
        ]

        let labelY  = by2 + 52
        let welcomeY = by2 + 100

        // ── draw borders ───────────────────────────────────────────────
        for (i, bp) in borderPaths.enumerated() {
            let delay = Double(i) * 0.03
            let p = min(1.0, max(0, (dp - delay) / (1 - delay)) * 1.1)
            drawTrace(bp, p, BLUE.opacity(0.3), 0.9)
        }

        // ── draw traces ────────────────────────────────────────────────
        for (i, tr) in traces.enumerated() {
            let delay = 0.05 + Double(i) * 0.05
            let p = min(1.0, max(0, (dp - delay) / (1 - delay)))
            drawTrace(tr, p, BLUE.opacity(0.6), 1.1)
        }

        // ── vias ───────────────────────────────────────────────────────
        if dp > 0.35 {
            let va = min(1.0, (dp - 0.35) / 0.3)
            for v in vias {
                ctx.fill(Path(ellipseIn: CGRect(x: v.x-3, y: v.y-3, width: 6, height: 6)),
                         with: .color(ACC.opacity(va * 0.85)))
                ctx.stroke(Path(ellipseIn: CGRect(x: v.x-6, y: v.y-6, width: 12, height: 12)),
                           with: .color(BLUE.opacity(va * 0.2)), lineWidth: 0.5)
            }
        }

        // ── VK+ text ───────────────────────────────────────────────────
        if dp > 0.55 {
            let ta = min(1.0, (dp - 0.55) / 0.28)
            var txt = AttributedString("VK+")
            txt.font = .systemFont(ofSize: FS, weight: .black)
            txt.foregroundColor = UIColor(red: 0, green: 0.706, blue: 1, alpha: CGFloat(ta))
            let r = ctx.resolve(Text(txt))
            ctx.draw(r, at: CGPoint(x: cx, y: cy), anchor: .center)
        }

        // ── by SelfCode ────────────────────────────────────────────────
        let bsStart = LABEL_START, bsEnd = 0.97
        if dp > bsStart {
            let la  = min(1.0, (dp - bsStart) / (bsEnd - bsStart))
            let ease = 1.0 - pow(1.0 - la, 3.0)
            let offY = CGFloat((1 - ease) * 18)
            var txt = AttributedString("by SelfCode")
            txt.font = .systemFont(ofSize: 15, weight: .semibold)
            txt.foregroundColor = UIColor(red: 0.71, green: 0.75, blue: 0.82, alpha: CGFloat(ease))
            let r = ctx.resolve(Text(txt))
            ctx.draw(r, at: CGPoint(x: cx, y: labelY + offY), anchor: .center)
        }

        // ── bruteforce ─────────────────────────────────────────────────
        if bruteStarted {
            let solvedN  = bruteSolved.filter { $0 }.count
            let ratio    = Double(solvedN) / 14.0

            // divider lines grow from center
            if ratio > 0.1 {
                let lAlpha = min(1.0, (ratio - 0.1) / 0.5) * 0.45
                let lLen   = CGFloat(min(1.0, (ratio - 0.1) / 0.6) * 110)
                var lp = Path()
                lp.move(to: .init(x: cx-lLen, y: welcomeY-18))
                lp.addLine(to: .init(x: cx+lLen, y: welcomeY-18))
                ctx.stroke(lp, with: .color(BLUE.opacity(lAlpha)), lineWidth: 0.5)
                var lp2 = Path()
                lp2.move(to: .init(x: cx-lLen, y: welcomeY+18))
                lp2.addLine(to: .init(x: cx+lLen, y: welcomeY+18))
                ctx.stroke(lp2, with: .color(BLUE.opacity(lAlpha)), lineWidth: 0.5)
            }

            // render each char
            let CW: CGFloat = 13.8
            let ox  = cx - CGFloat(14) * CW / 2 + CW / 2
            for i in 0..<14 {
                let x = ox + CGFloat(i) * CW
                let ch = String(bruteChars[i])
                if bruteSolved[i] {
                    // flash burst
                    let age = now.timeIntervalSince(bruteFlashAt[i])
                    if age < 0.18 {
                        let fl = 1.0 - age / 0.18
                        var ft = AttributedString(ch)
                        ft.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
                        ft.foregroundColor = UIColor(red: 0, green: 0.933, blue: 1, alpha: CGFloat(fl * 0.9))
                        ctx.draw(Text(ft), at: .init(x: x, y: welcomeY), anchor: .center)
                    }
                    // solid
                    var st = AttributedString(ch)
                    st.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
                    st.foregroundColor = UIColor(red: 0, green: 0.882, blue: 1, alpha: 1)
                    ctx.draw(Text(st), at: .init(x: x, y: welcomeY), anchor: .center)
                } else {
                    var dt = AttributedString(ch)
                    dt.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
                    dt.foregroundColor = UIColor(red: 0, green: 0.706, blue: 1, alpha: 0.28)
                    ctx.draw(Text(dt), at: .init(x: x, y: welcomeY), anchor: .center)
                }
            }

            // all solved — pulse glow
            if bruteSolved.allSatisfy({ $0 }) {
                let age  = now.timeIntervalSince(bruteSolveAt[13])
                let pulse = 0.12 + sin(age / 0.55) * 0.12
                for i in 0..<14 {
                    let x = ox + CGFloat(i) * CW
                    var gt = AttributedString(String(target[i]))
                    gt.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
                    gt.foregroundColor = UIColor(red: 0, green: 0.706, blue: 1, alpha: CGFloat(max(0, pulse)))
                    ctx.draw(Text(gt), at: .init(x: x, y: welcomeY), anchor: .center)
                }
            }
        }
    }
}
