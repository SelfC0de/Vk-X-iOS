import SwiftUI

// MARK: - SplashView
struct SplashView: View {
    let onFinished: () -> Void
    var isAuthenticated: Bool = false

    @State private var splitTop: CGFloat = 0
    @State private var splitBot: CGFloat = 0
    @State private var splitting = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red:0.02, green:0.03, blue:0.06).ignoresSafeArea()
                if !splitting {
                    SplashCanvas(
                        isAuthenticated: isAuthenticated,
                        onReadyToTransition: {
                            if isAuthenticated { startSplit(h: geo.size.height) }
                            else { DispatchQueue.main.asyncAfter(deadline: .now()+0.4) { onFinished() } }
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    // Split halves
                    SplashCanvas(isAuthenticated: isAuthenticated, onReadyToTransition: {})
                        .frame(width: geo.size.width, height: geo.size.height)
                        .frame(width: geo.size.width, height: geo.size.height/2, alignment: .top)
                        .clipped()
                        .offset(y: -splitTop)
                        .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top)
                        .ignoresSafeArea()

                    SplashCanvas(isAuthenticated: isAuthenticated, onReadyToTransition: {})
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: -geo.size.height/2)
                        .frame(width: geo.size.width, height: geo.size.height/2, alignment: .top)
                        .clipped()
                        .offset(y: geo.size.height/2 + splitBot)
                        .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top)
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
    }

    private func startSplit(h: CGFloat) {
        splitting = true
        withAnimation(.easeIn(duration: 0.55).delay(0.05)) {
            splitTop = h/2 + 100
            splitBot = h/2 + 100
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.65) { onFinished() }
    }
}

// MARK: - SplashCanvas
struct SplashCanvas: View {
    var isAuthenticated: Bool = false
    var onReadyToTransition: () -> Void = {}

    private let T_DRAW: Double = 3.8
    private let T_DONE: Double = 4.6

    @State private var startDate = Date()
    @State private var doneFired = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let el  = max(0, tl.date.timeIntervalSince(startDate))
                let dp  = min(1.0, el / T_DRAW)
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size, dp: dp, el: el)
                }
            }
        }
        .background(Color(red:0.02, green:0.03, blue:0.06))
        .ignoresSafeArea()
        .onAppear { startDate = Date() }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(T_DONE * 1_000_000_000))
            if !doneFired { doneFired = true; onReadyToTransition() }
        }
    }

    // MARK: - Draw
    private func draw(ctx: GraphicsContext, size: CGSize, dp: Double, el: Double) {
        let W = size.width
        let H = size.height
        let cx = W / 2
        let cy = H / 2   // FULL screen center

        let BLUE = Color(red:0.00, green:0.71, blue:1.00)
        let ACC  = Color(red:0.00, green:0.93, blue:1.00)
        let DIM  = Color(red:0.00, green:0.50, blue:0.80)

        // ── Logo box around center ──
        let FS:  CGFloat = 52
        let bw:  CGFloat = 140   // half-box width
        let bh:  CGFloat = 110   // half-box height
        let bx1 = cx - bw,  by1 = cy - bh
        let bx2 = cx + bw,  by2 = cy + bh
        let br:  CGFloat = 20

        // ═══════════════════════════════════════════════
        // CIRCUIT TRACES — from all 4 screen edges inward
        // Each trace starts at a screen edge and routes to the logo box
        // ═══════════════════════════════════════════════
        let traces: [[CGPoint]] = [
            // ── TOP EDGE traces ──
            // Far-left top → logo top-left corner
            [.init(x:0,          y:H*0.12),
             .init(x:bx1-60,     y:H*0.12),
             .init(x:bx1-60,     y:by1-40),
             .init(x:bx1,        y:by1-40),
             .init(x:bx1,        y:by1)],

            // Left-center top → logo top
            [.init(x:W*0.22,     y:0),
             .init(x:W*0.22,     y:by1-55),
             .init(x:cx-30,      y:by1-55),
             .init(x:cx-30,      y:by1)],

            // Right-center top → logo top
            [.init(x:W*0.68,     y:0),
             .init(x:W*0.68,     y:by1-70),
             .init(x:cx+20,      y:by1-70),
             .init(x:cx+20,      y:by1)],

            // Far-right top → logo top-right corner
            [.init(x:W,          y:H*0.08),
             .init(x:bx2+55,     y:H*0.08),
             .init(x:bx2+55,     y:by1-30),
             .init(x:bx2,        y:by1-30),
             .init(x:bx2,        y:by1)],

            // ── BOTTOM EDGE traces ──
            // Far-left bottom → logo bottom-left
            [.init(x:0,          y:H*0.82),
             .init(x:bx1-70,     y:H*0.82),
             .init(x:bx1-70,     y:by2+45),
             .init(x:bx1,        y:by2+45),
             .init(x:bx1,        y:by2)],

            // Left-center bottom → logo bottom
            [.init(x:W*0.18,     y:H),
             .init(x:W*0.18,     y:by2+60),
             .init(x:cx-25,      y:by2+60),
             .init(x:cx-25,      y:by2)],

            // Right-center bottom → logo bottom
            [.init(x:W*0.72,     y:H),
             .init(x:W*0.72,     y:by2+50),
             .init(x:cx+35,      y:by2+50),
             .init(x:cx+35,      y:by2)],

            // Far-right bottom → logo bottom-right
            [.init(x:W,          y:H*0.78),
             .init(x:bx2+65,     y:H*0.78),
             .init(x:bx2+65,     y:by2+35),
             .init(x:bx2,        y:by2+35),
             .init(x:bx2,        y:by2)],

            // ── LEFT EDGE traces ──
            // Top-left side → logo left
            [.init(x:0,          y:H*0.30),
             .init(x:bx1-80,     y:H*0.30),
             .init(x:bx1-80,     y:cy-30),
             .init(x:bx1,        y:cy-30)],

            // Mid-left side → logo left-mid
            [.init(x:0,          y:H*0.50),
             .init(x:bx1-50,     y:H*0.50),
             .init(x:bx1-50,     y:cy+15),
             .init(x:bx1,        y:cy+15)],

            // Bottom-left side
            [.init(x:0,          y:H*0.68),
             .init(x:bx1-90,     y:H*0.68),
             .init(x:bx1-90,     y:by2+20),
             .init(x:bx1-20,     y:by2+20)],

            // ── RIGHT EDGE traces ──
            // Top-right side → logo right
            [.init(x:W,          y:H*0.32),
             .init(x:bx2+75,     y:H*0.32),
             .init(x:bx2+75,     y:cy-20),
             .init(x:bx2,        y:cy-20)],

            // Mid-right side → logo right-mid
            [.init(x:W,          y:H*0.52),
             .init(x:bx2+45,     y:H*0.52),
             .init(x:bx2+45,     y:cy+20),
             .init(x:bx2,        y:cy+20)],

            // Bottom-right side
            [.init(x:W,          y:H*0.70),
             .init(x:bx2+85,     y:H*0.70),
             .init(x:bx2+85,     y:by2+15),
             .init(x:bx2+20,     y:by2+15)],

            // ── EXTRA branching traces for density ──
            [.init(x:W*0.08,     y:0),
             .init(x:W*0.08,     y:by1-90),
             .init(x:cx-55,      y:by1-90),
             .init(x:cx-55,      y:by1-55)],

            [.init(x:W*0.88,     y:0),
             .init(x:W*0.88,     y:by1-80),
             .init(x:cx+50,      y:by1-80),
             .init(x:cx+50,      y:by1-50)],

            [.init(x:W*0.35,     y:H),
             .init(x:W*0.35,     y:by2+80),
             .init(x:bx1+20,     y:by2+80)],

            [.init(x:W*0.60,     y:H),
             .init(x:W*0.60,     y:by2+75),
             .init(x:bx2-20,     y:by2+75)],
        ]

        // Logo border segments
        let borders: [[CGPoint]] = [
            // Corners
            [.init(x:bx1+br, y:by1), .init(x:bx1, y:by1), .init(x:bx1, y:by1+br)],
            [.init(x:bx2-br, y:by1), .init(x:bx2, y:by1), .init(x:bx2, y:by1+br)],
            [.init(x:bx1, y:by2-br), .init(x:bx1, y:by2), .init(x:bx1+br, y:by2)],
            [.init(x:bx2, y:by2-br), .init(x:bx2, y:by2), .init(x:bx2-br, y:by2)],
            // Top edges
            [.init(x:bx1+br+4, y:by1), .init(x:cx-20, y:by1)],
            [.init(x:cx+20,    y:by1), .init(x:bx2-br-4, y:by1)],
            // Bottom edges
            [.init(x:bx1+br+4, y:by2), .init(x:cx-20, y:by2)],
            [.init(x:cx+20,    y:by2), .init(x:bx2-br-4, y:by2)],
            // Side edges
            [.init(x:bx1, y:by1+br+4), .init(x:bx1, y:by2-br-4)],
            [.init(x:bx2, y:by1+br+4), .init(x:bx2, y:by2-br-4)],
        ]

        // Via dots — endpoints and junctions
        let vias: [CGPoint] = [
            // Box corners
            .init(x:bx1, y:by1), .init(x:bx2, y:by1),
            .init(x:bx1, y:by2), .init(x:bx2, y:by2),
            // Trace endpoints at screen edges (dots)
            .init(x:bx1-60, y:by1-40), .init(x:cx-30, y:by1-55),
            .init(x:cx+20,  y:by1-70), .init(x:bx2+55, y:by1-30),
            .init(x:bx1-70, y:by2+45), .init(x:cx-25,  y:by2+60),
            .init(x:cx+35,  y:by2+50), .init(x:bx2+65, y:by2+35),
            .init(x:bx1-80, y:cy-30),  .init(x:bx1-50, y:cy+15),
            .init(x:bx2+75, y:cy-20),  .init(x:bx2+45, y:cy+20),
        ]

        // ─── Helper: path length ───
        func pLen(_ pts:[CGPoint]) -> CGFloat {
            var l: CGFloat = 0
            for i in 1..<pts.count {
                let dx = pts[i].x - pts[i-1].x
                let dy = pts[i].y - pts[i-1].y
                l += sqrt(dx*dx + dy*dy)
            }
            return max(l, 0.001)
        }

        // ─── Helper: draw animated trace ───
        func drawTrace(_ pts:[CGPoint], _ prog:Double, _ color:Color, _ lw:CGFloat) {
            guard prog > 0, pts.count >= 2 else { return }
            let tot = pLen(pts)
            var d = CGFloat(prog) * tot
            var path = Path()
            path.move(to: pts[0])
            var ex = pts[0].x, ey = pts[0].y
            for i in 1..<pts.count {
                let dx = pts[i].x - pts[i-1].x
                let dy = pts[i].y - pts[i-1].y
                let sl = sqrt(dx*dx + dy*dy)
                guard sl > 0, d > 0 else { break }
                let tk = min(sl, d)
                ex = pts[i-1].x + dx * (tk/sl)
                ey = pts[i-1].y + dy * (tk/sl)
                path.addLine(to: .init(x:ex, y:ey))
                d -= tk
            }
            ctx.stroke(path, with:.color(color),
                       style:StrokeStyle(lineWidth:lw, lineCap:.round, lineJoin:.round))
            // Glowing head dot
            ctx.fill(Path(ellipseIn:CGRect(x:ex-lw*2, y:ey-lw*2, width:lw*4, height:lw*4)),
                     with:.color(ACC.opacity(0.9)))
        }

        // ─── Draw background grid (very faint) ───
        let gridStep: CGFloat = 40
        var gridPath = Path()
        var gx: CGFloat = 0
        while gx <= W { gridPath.move(to:.init(x:gx,y:0)); gridPath.addLine(to:.init(x:gx,y:H)); gx += gridStep }
        var gy: CGFloat = 0
        while gy <= H { gridPath.move(to:.init(x:0,y:gy)); gridPath.addLine(to:.init(x:W,y:gy)); gy += gridStep }
        ctx.stroke(gridPath, with:.color(BLUE.opacity(0.04)), lineWidth:0.5)

        // ─── Draw traces ───
        let traceCount = Double(traces.count)
        for (i, tr) in traces.enumerated() {
            let stagger = Double(i) / traceCount * 0.45
            let p = min(1.0, max(0, (dp - stagger) / (0.7 - stagger * 0.3)))
            let isDim = i % 3 == 2
            drawTrace(tr, p, isDim ? DIM.opacity(0.5) : BLUE.opacity(0.65), isDim ? 0.9 : 1.2)
        }

        // ─── Draw logo border ───
        for (i, bp) in borders.enumerated() {
            let delay = 0.3 + Double(i) * 0.025
            let p = min(1.0, max(0, (dp - delay) / (0.65 - delay * 0.2)))
            drawTrace(bp, p, BLUE.opacity(0.45), 1.0)
        }

        // ─── Vias ───
        if dp > 0.4 {
            let va = min(1.0, (dp - 0.4) / 0.35)
            for v in vias {
                let r1: CGFloat = 3.5, r2: CGFloat = 7
                ctx.fill(Path(ellipseIn:CGRect(x:v.x-r1, y:v.y-r1, width:r1*2, height:r1*2)),
                         with:.color(ACC.opacity(va * 0.9)))
                ctx.stroke(Path(ellipseIn:CGRect(x:v.x-r2, y:v.y-r2, width:r2*2, height:r2*2)),
                           with:.color(BLUE.opacity(va * 0.25)), lineWidth:0.7)
            }
        }

        // ─── VK+ logo text ───
        if dp > 0.60 {
            let ta = min(1.0, (dp - 0.60) / 0.22)
            var t = AttributedString("VK+")
            t.font = .systemFont(ofSize: FS, weight: .black)
            t.foregroundColor = UIColor(red:0, green:0.706, blue:1, alpha:CGFloat(ta))
            ctx.draw(Text(t), at:.init(x:cx, y:cy), anchor:.center)
        }

        // ─── Pulse glow after fully drawn ───
        if dp >= 1.0 {
            let pulse = 0.10 + sin(el * 2.8) * 0.08
            var t = AttributedString("VK+")
            t.font = .systemFont(ofSize: FS, weight: .black)
            t.foregroundColor = UIColor(red:0, green:0.8, blue:1, alpha:CGFloat(max(0, pulse)))
            ctx.draw(Text(t), at:.init(x:cx, y:cy), anchor:.center)
        }

        // ─── "by SelfCode" subtitle ───
        if dp > 0.85 {
            let la   = min(1.0, (dp - 0.85) / 0.15)
            let ease = 1.0 - pow(1.0 - la, 3.0)
            var t = AttributedString("by SelfCode")
            t.font = .systemFont(ofSize: 14, weight: .semibold)
            t.foregroundColor = UIColor(red:0.71, green:0.75, blue:0.82, alpha:CGFloat(ease))
            ctx.draw(Text(t), at:.init(x:cx, y:cy + FS * 0.82 + CGFloat((1-ease)*14)),
                     anchor:.center)
        }
    }
}
