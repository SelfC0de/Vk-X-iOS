import SwiftUI

// MARK: - Animated Tab Icon
// Each icon animates when isSelected=true
struct AnimatedTabIcon: View {
    let tab:        Int      // 0=feed,1=messages,2=friends,3=profile,4=settings,5=communities
    let isSelected: Bool
    let size:       CGFloat

    @State private var phase:   Double = 0
    @State private var timer:   Timer? = nil

    var body: some View {
        Canvas { ctx, sz in
            drawIcon(ctx: ctx, sz: sz, phase: phase)
        }
        .frame(width: size, height: size)
        .onChange(of: isSelected) { _, sel in
            if sel { startAnim() } else { stopAnim() }
        }
        .onAppear { if isSelected { startAnim() } }
        .onDisappear { stopAnim() }
    }

    private func startAnim() {
        stopAnim()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            phase = (phase + 0.07).truncatingRemainder(dividingBy: .pi * 2)
        }
    }
    private func stopAnim() {
        timer?.invalidate(); timer = nil
        phase = 0
    }

    private func drawIcon(ctx: GraphicsContext, sz: CGSize, phase: Double) {
        let w = sz.width, h = sz.height
        let sel = isSelected
        let blue  = Color(red:0.00, green:0.71, blue:1.00)
        let muted = Color(red:0.55, green:0.55, blue:0.65)
        let fg    = sel ? blue : muted

        switch tab {
        case 0: drawFeed     (ctx,w,h,fg,phase,sel)
        case 1: drawMessages (ctx,w,h,fg,phase,sel)
        case 2: drawFriends  (ctx,w,h,fg,phase,sel)
        case 3: drawProfile  (ctx,w,h,fg,phase,sel)
        case 4: drawSettings (ctx,w,h,fg,phase,sel)
        case 5: drawCommunity(ctx,w,h,fg,phase,sel)
        default: break
        }
    }

    // ── 0: Feed — animated lines scrolling ──
    private func drawFeed(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat,
                          _ fg: Color, _ phase: Double, _ sel: Bool) {
        let lw: CGFloat = sel ? 2.0 : 1.6
        let offsets: [CGFloat] = [0.18, 0.38, 0.56, 0.74, 0.90]
        for (i, yf) in offsets.enumerated() {
            let y = h * yf
            let wave: CGFloat = sel ? CGFloat(sin(phase + Double(i) * 0.6)) * 1.5 : 0
            let shortLine = i == 2 || i == 4
            var p = Path()
            p.move(to:    CGPoint(x: w*0.08, y: y + wave))
            p.addLine(to: CGPoint(x: shortLine ? w*0.62 : w*0.92, y: y + wave))
            let alpha = sel ? 0.6 + 0.4 * sin(phase + Double(i) * 0.9) : 1.0
            ctx.stroke(p, with: .color(fg.opacity(alpha)), lineWidth: lw)
        }
        // small square left (post avatar)
        let sq = CGRect(x: w*0.08, y: h*0.28, width: h*0.22, height: h*0.22)
        let sqPath = Path(roundedRect: sq, cornerRadius: 2)
        ctx.fill(sqPath, with: .color(fg.opacity(sel ? 0.85 : 0.7)))
    }

    // ── 1: Messages — bubble with typing dots ──
    private func drawMessages(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat,
                              _ fg: Color, _ phase: Double, _ sel: Bool) {
        // Bubble body
        let bubble = Path(roundedRect: CGRect(x:w*0.08,y:h*0.10,width:w*0.78,height:h*0.62), cornerRadius: h*0.18)
        ctx.fill(bubble, with: .color(fg.opacity(sel ? 0.15 : 0.12)))
        ctx.stroke(bubble, with: .color(fg.opacity(sel ? 0.9 : 0.6)), lineWidth: 1.6)
        // Tail
        var tail = Path()
        tail.move(to: CGPoint(x:w*0.22, y:h*0.72))
        tail.addLine(to: CGPoint(x:w*0.12, y:h*0.90))
        tail.addLine(to: CGPoint(x:w*0.38, y:h*0.72))
        tail.closeSubpath()
        ctx.fill(tail, with: .color(fg.opacity(sel ? 0.9 : 0.6)))
        // Typing dots
        let dotY = h * 0.41
        for i in 0..<3 {
            let dotX = w * (0.28 + Double(i) * 0.18)
            let bounce: CGFloat = sel ? CGFloat(sin(phase + Double(i) * 1.1)) * 3 : 0
            let r: CGFloat = sel ? 2.8 : 2.4
            ctx.fill(Path(ellipseIn: CGRect(x:dotX-r, y:dotY-r+bounce, width:r*2,height:r*2)),
                     with: .color(fg.opacity(sel ? 0.9 : 0.7)))
        }
    }

    // ── 2: Friends — two figures, one waves ──
    private func drawFriends(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat,
                             _ fg: Color, _ phase: Double, _ sel: Bool) {
        // Left figure
        drawStickFigure(ctx, cx: w*0.32, headY: h*0.18, h: h, fg: fg, armWave: 0, sel: sel)
        // Right figure (waves when selected)
        let wave = sel ? CGFloat(sin(phase)) * 14 : 0
        drawStickFigure(ctx, cx: w*0.68, headY: h*0.18, h: h, fg: fg, armWave: wave, sel: sel)
    }

    private func drawStickFigure(_ ctx: GraphicsContext, cx: CGFloat, headY: CGFloat,
                                  h: CGFloat, fg: Color, armWave: CGFloat, sel: Bool) {
        let alpha = sel ? 1.0 : 0.7
        let lw: CGFloat = sel ? 1.8 : 1.5
        // Head
        let hr: CGFloat = h * 0.12
        ctx.fill(Path(ellipseIn: CGRect(x:cx-hr,y:headY,width:hr*2,height:hr*2)),
                 with: .color(fg.opacity(alpha)))
        // Body
        var body = Path()
        body.move(to: CGPoint(x:cx, y:headY+hr*2))
        body.addLine(to: CGPoint(x:cx, y:headY+hr*2+h*0.28))
        ctx.stroke(body, with: .color(fg.opacity(alpha)), lineWidth: lw)
        // Arms
        let armY = headY+hr*2+h*0.10
        var arm = Path()
        arm.move(to: CGPoint(x:cx-h*0.13, y:armY+armWave))
        arm.addLine(to: CGPoint(x:cx, y:armY))
        arm.addLine(to: CGPoint(x:cx+h*0.13, y:armY-armWave))
        ctx.stroke(arm, with: .color(fg.opacity(alpha)), lineWidth: lw)
        // Legs
        let legTopY = headY+hr*2+h*0.28
        var legs = Path()
        legs.move(to: CGPoint(x:cx-h*0.10, y:legTopY+h*0.20))
        legs.addLine(to: CGPoint(x:cx, y:legTopY))
        legs.addLine(to: CGPoint(x:cx+h*0.10, y:legTopY+h*0.20))
        ctx.stroke(legs, with: .color(fg.opacity(alpha)), lineWidth: lw)
    }

    // ── 3: Profile — person silhouette, pulsing ring ──
    private func drawProfile(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat,
                             _ fg: Color, _ phase: Double, _ sel: Bool) {
        if sel {
            let ring = CGFloat(1.0 + 0.08 * sin(phase))
            let rr = h * 0.46 * ring
            ctx.stroke(Path(ellipseIn: CGRect(x:w/2-rr, y:h/2-rr, width:rr*2, height:rr*2)),
                       with: .color(fg.opacity(0.25 + 0.15 * sin(phase))), lineWidth: 1.5)
        }
        // Head
        let hr: CGFloat = h * 0.20
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-hr, y:h*0.10, width:hr*2, height:hr*2)),
                 with: .color(fg.opacity(sel ? 1.0 : 0.8)))
        // Shoulders arc
        var sh = Path()
        sh.move(to: CGPoint(x:w*0.08, y:h*0.95))
        sh.addQuadCurve(to: CGPoint(x:w*0.92, y:h*0.95), control: CGPoint(x:w/2, y:h*0.50))
        ctx.stroke(sh, with: .color(fg.opacity(sel ? 1.0 : 0.8)), lineWidth: 2.0)
    }

    // ── 4: Settings — spinning gear ──
    private func drawSettings(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat,
                              _ fg: Color, _ phase: Double, _ sel: Bool) {
        let cx = w/2, cy = h/2
        let outerR: CGFloat = h * 0.38
        let innerR: CGFloat = h * 0.22
        let teeth = 8
        // Rotate when selected
        var gearCtx = ctx
        if sel {
            gearCtx.translateBy(x: cx, y: cy)
            gearCtx.rotate(by: .radians(phase * 0.4))
            gearCtx.translateBy(x: -cx, y: -cy)
        }
        // Gear teeth path
        var gear = Path()
        for i in 0..<teeth {
            let a1 = Double(i) / Double(teeth) * .pi * 2 + (sel ? 0 : 0)
            let a2 = a1 + .pi / Double(teeth) * 0.6
            let a3 = a2 + .pi / Double(teeth) * 0.4
            let a4 = a3 + .pi / Double(teeth) * 0.6
            func pt(_ r: CGFloat, _ a: Double) -> CGPoint {
                CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a)))
            }
            if i == 0 { gear.move(to: pt(innerR, a1)) }
            gear.addLine(to: pt(innerR, a1))
            gear.addLine(to: pt(outerR, a2))
            gear.addLine(to: pt(outerR, a3))
            gear.addLine(to: pt(innerR, a4))
        }
        gear.closeSubpath()
        gearCtx.fill(gear, with: .color(fg.opacity(sel ? 0.25 : 0.18)))
        gearCtx.stroke(gear, with: .color(fg.opacity(sel ? 0.95 : 0.65)), lineWidth: 1.5)
        // Center hole
        let hole = CGRect(x:cx-innerR*0.5, y:cy-innerR*0.5, width:innerR, height:innerR)
        gearCtx.fill(Path(ellipseIn: hole), with: .color(fg.opacity(sel ? 0.9 : 0.6)))
    }

    // ── 5: Communities — building with windows that light up ──
    private func drawCommunity(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat,
                               _ fg: Color, _ phase: Double, _ sel: Bool) {
        // Building outline
        let bx = w*0.15, by = h*0.25, bw = w*0.70, bh = h*0.68
        let bldg = Path(roundedRect: CGRect(x:bx,y:by,width:bw,height:bh), cornerRadius: 2)
        ctx.fill(bldg, with: .color(fg.opacity(sel ? 0.15 : 0.10)))
        ctx.stroke(bldg, with: .color(fg.opacity(sel ? 0.9 : 0.6)), lineWidth: 1.6)
        // Roof triangle
        var roof = Path()
        roof.move(to: CGPoint(x:w*0.10, y:h*0.27))
        roof.addLine(to: CGPoint(x:w/2,   y:h*0.06))
        roof.addLine(to: CGPoint(x:w*0.90, y:h*0.27))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(fg.opacity(sel ? 0.20 : 0.12)))
        ctx.stroke(roof, with: .color(fg.opacity(sel ? 0.9 : 0.6)), lineWidth: 1.6)
        // Windows — 2×3 grid, light up sequentially
        let winW: CGFloat = bw*0.20, winH: CGFloat = bh*0.16
        let cols = 3, rows = 2
        for row in 0..<rows {
            for col in 0..<cols {
                let wx = bx + bw*(0.12 + CGFloat(col)*0.30)
                let wy = by + bh*(0.15 + CGFloat(row)*0.38)
                let winRect = CGRect(x:wx, y:wy, width:winW, height:winH)
                let idx = row * cols + col
                let lit = sel ? 0.4 + 0.6 * max(0, sin(phase - Double(idx)*0.5)) : 0.0
                ctx.fill(Path(roundedRect: winRect, cornerRadius: 1.5),
                         with: .color(Color(red:1,green:0.85,blue:0.3).opacity(sel ? lit : 0.0)))
                ctx.stroke(Path(roundedRect: winRect, cornerRadius: 1.5),
                           with: .color(fg.opacity(sel ? 0.7 : 0.5)), lineWidth: 1.0)
            }
        }
        // Door
        let dr = CGRect(x:w/2-winW*0.6, y:by+bh*0.68, width:winW*1.2, height:bh*0.32)
        ctx.fill(Path(roundedRect: dr, cornerRadius: 2),
                 with: .color(fg.opacity(sel ? 0.30 : 0.20)))
        ctx.stroke(Path(roundedRect: dr, cornerRadius: 2),
                   with: .color(fg.opacity(sel ? 0.8 : 0.5)), lineWidth: 1.0)
    }
}

// MARK: - Settings tab icons (animated)
struct SettingsTabIcon: View {
    let tab:        Int   // 0=privacy,1=engine,2=device,3=visual,4=proxy,5=about
    let isSelected: Bool
    let size:       CGFloat

    @State private var phase: Double = 0
    @State private var timer: Timer? = nil

    var body: some View {
        Canvas { ctx, sz in drawIcon(ctx:ctx, sz:sz, p:phase) }
            .frame(width: size, height: size)
            .onChange(of: isSelected) { _, s in s ? start() : stop() }
            .onAppear { if isSelected { start() } }
            .onDisappear { stop() }
    }

    private func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            phase = (phase + 0.06).truncatingRemainder(dividingBy: .pi * 2)
        }
    }
    private func stop() { timer?.invalidate(); timer = nil; phase = 0 }

    private func drawIcon(ctx: GraphicsContext, sz: CGSize, p: Double) {
        let w = sz.width, h = sz.height
        let sel = isSelected
        let accent = tabColor(tab)
        let fg = sel ? accent : Color(red:0.55,green:0.55,blue:0.65)
        switch tab {
        case 0: drawPrivacy (ctx,w,h,fg,p,sel)
        case 1: drawEngine  (ctx,w,h,fg,p,sel)
        case 2: drawDevice  (ctx,w,h,fg,p,sel)
        case 3: drawVisual  (ctx,w,h,fg,p,sel)
        case 4: drawProxy   (ctx,w,h,fg,p,sel)
        case 5: drawAbout   (ctx,w,h,fg,p,sel)
        default: break
        }
    }

    private func tabColor(_ t: Int) -> Color {
        switch t {
        case 0: return Color(red:1.00,green:0.35,blue:0.35) // red - privacy
        case 1: return Color(red:0.00,green:0.71,blue:1.00) // blue - engine
        case 2: return Color(red:0.50,green:0.85,blue:0.40) // green - device
        case 3: return Color(red:1.00,green:0.60,blue:0.10) // orange - visual
        case 4: return Color(red:0.65,green:0.40,blue:1.00) // purple - proxy
        case 5: return Color(red:0.00,green:0.71,blue:1.00) // blue - about
        default: return Color.white
        }
    }

    // Shield with lock — Privacy
    private func drawPrivacy(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,
                             _ fg: Color,_ p: Double,_ sel: Bool) {
        var shield = Path()
        shield.move(to: CGPoint(x:w/2, y:h*0.05))
        shield.addLine(to: CGPoint(x:w*0.88, y:h*0.25))
        shield.addLine(to: CGPoint(x:w*0.88, y:h*0.58))
        shield.addQuadCurve(to: CGPoint(x:w/2, y:h*0.95), control: CGPoint(x:w*0.88,y:h*0.85))
        shield.addQuadCurve(to: CGPoint(x:w*0.12, y:h*0.58), control: CGPoint(x:w*0.12,y:h*0.85))
        shield.addLine(to: CGPoint(x:w*0.12, y:h*0.25))
        shield.closeSubpath()
        ctx.fill(shield, with: .color(fg.opacity(sel ? 0.18 : 0.10)))
        ctx.stroke(shield, with: .color(fg.opacity(sel ? 0.95 : 0.6)), lineWidth: 1.8)
        // Lock
        let lw: CGFloat = w*0.18, lh: CGFloat = h*0.20
        let lx = w/2-lw/2, ly = h*0.48
        ctx.fill(Path(roundedRect: CGRect(x:lx,y:ly,width:lw,height:lh), cornerRadius: 3),
                 with: .color(fg.opacity(sel ? 0.9 : 0.6)))
        // Shackle
        var shackle = Path()
        shackle.move(to: CGPoint(x:lx+lw*0.25, y:ly))
        shackle.addLine(to: CGPoint(x:lx+lw*0.25, y:ly-lh*0.55))
        shackle.addArc(center: CGPoint(x:w/2,y:ly-lh*0.55),
                       radius: lw*0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        shackle.addLine(to: CGPoint(x:lx+lw*0.75, y:ly))
        let bounce: CGFloat = sel ? CGFloat(sin(p) * 2) : 0
        ctx.stroke(shackle.offsetBy(dx:0,dy:-bounce),
                   with: .color(fg.opacity(sel ? 0.9 : 0.6)), lineWidth: 1.8)
    }

    // CPU chip — Engine
    private func drawEngine(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,
                            _ fg: Color,_ p: Double,_ sel: Bool) {
        let chip = CGRect(x:w*0.25,y:h*0.25,width:w*0.50,height:h*0.50)
        ctx.fill(Path(roundedRect: chip, cornerRadius: 4), with: .color(fg.opacity(sel ? 0.20 : 0.12)))
        ctx.stroke(Path(roundedRect: chip, cornerRadius: 4), with: .color(fg.opacity(sel ? 0.9 : 0.6)), lineWidth: 1.6)
        // Pins
        let pins = 3
        for i in 0..<pins {
            let pf = CGFloat(i+1) / CGFloat(pins+1)
            // Top
            var p1 = Path(); p1.move(to: CGPoint(x:w*(0.25+pf*0.50), y:h*0.25))
            p1.addLine(to: CGPoint(x:w*(0.25+pf*0.50), y:h*0.10))
            // Bottom
            var p2 = Path(); p2.move(to: CGPoint(x:w*(0.25+pf*0.50), y:h*0.75))
            p2.addLine(to: CGPoint(x:w*(0.25+pf*0.50), y:h*0.90))
            // Left
            var p3 = Path(); p3.move(to: CGPoint(x:w*0.25, y:h*(0.25+pf*0.50)))
            p3.addLine(to: CGPoint(x:w*0.10, y:h*(0.25+pf*0.50)))
            // Right
            var p4 = Path(); p4.move(to: CGPoint(x:w*0.75, y:h*(0.25+pf*0.50)))
            p4.addLine(to: CGPoint(x:w*0.90, y:h*(0.25+pf*0.50)))
            let lw: CGFloat = sel ? 2.0 : 1.5
            let pulse = sel ? 0.5 + 0.5 * sin(p + Double(i)*1.0) : 0.6
            for path in [p1,p2,p3,p4] {
                ctx.stroke(path, with: .color(fg.opacity(pulse)), lineWidth: lw)
            }
        }
        // Core dot
        let r = h * (sel ? 0.08 + 0.03*CGFloat(sin(p)) : 0.08)
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-r,y:h/2-r,width:r*2,height:r*2)),
                 with: .color(fg.opacity(sel ? 1.0 : 0.7)))
    }

    // iPhone — Device
    private func drawDevice(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,
                            _ fg: Color,_ p: Double,_ sel: Bool) {
        let phone = CGRect(x:w*0.28,y:h*0.06,width:w*0.44,height:h*0.88)
        ctx.fill(Path(roundedRect: phone, cornerRadius: 6), with: .color(fg.opacity(sel ? 0.15:0.10)))
        ctx.stroke(Path(roundedRect: phone, cornerRadius: 6), with: .color(fg.opacity(sel ? 0.9:0.6)), lineWidth: 1.7)
        // Screen
        let screen = CGRect(x:w*0.32,y:h*0.14,width:w*0.36,height:h*0.65)
        ctx.fill(Path(roundedRect: screen, cornerRadius: 3),
                 with: .color(fg.opacity(sel ? 0.25 + 0.10*CGFloat(sin(p)) : 0.15)))
        // Notch
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-h*0.05,y:h*0.09,width:h*0.10,height:h*0.07)),
                 with: .color(fg.opacity(sel ? 0.9:0.6)))
        // Home indicator
        let ind = CGRect(x:w/2-w*0.10,y:h*0.86,width:w*0.20,height:h*0.03)
        ctx.fill(Path(roundedRect: ind, cornerRadius: 2), with: .color(fg.opacity(sel ? 0.9:0.6)))
    }

    // Paintbrush — Visual
    private func drawVisual(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,
                            _ fg: Color,_ p: Double,_ sel: Bool) {
        // Brush handle
        let angle: Double = -.pi/4 + (sel ? sin(p)*0.12 : 0)
        var gCtx = ctx
        gCtx.translateBy(x: w/2, y: h/2)
        gCtx.rotate(by: .radians(angle))
        gCtx.translateBy(x: -w/2, y: -h/2)
        var handle = Path()
        handle.move(to: CGPoint(x:w*0.65,y:h*0.08))
        handle.addLine(to: CGPoint(x:w*0.25,y:h*0.70))
        gCtx.stroke(handle, with: .color(fg.opacity(sel ? 0.85:0.6)), lineWidth: 3.5)
        // Bristles
        let bristleRect = CGRect(x:w*0.14,y:h*0.65,width:w*0.20,height:h*0.25)
        gCtx.fill(Path(roundedRect: bristleRect, cornerRadius: 3),
                  with: .color(fg.opacity(sel ? 0.9:0.6)))
        // Paint blobs
        if sel {
            let colors: [Color] = [Color(red:1,green:0.3,blue:0.3),
                                    Color(red:0.3,green:0.8,blue:0.3),
                                    Color(red:0.2,green:0.6,blue:1)]
            for (i,c) in colors.enumerated() {
                let bx = w*(0.48+CGFloat(i)*0.14)
                let by = h*(0.68+CGFloat(i)*0.06)
                let br: CGFloat = 5 + CGFloat(sin(p + Double(i)*1.2))*2
                ctx.fill(Path(ellipseIn: CGRect(x:bx-br,y:by-br,width:br*2,height:br*2)),
                         with: .color(c.opacity(0.7+0.3*sin(p+Double(i)))))
            }
        }
    }

    // Network nodes — Proxy
    private func drawProxy(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,
                           _ fg: Color,_ p: Double,_ sel: Bool) {
        let nodes: [(CGFloat,CGFloat)] = [(0.5,0.12),(0.15,0.70),(0.85,0.70),(0.5,0.92)]
        // Lines
        let conns = [(0,1),(0,2),(1,3),(2,3),(0,3)]
        for (a,b) in conns {
            var line = Path()
            line.move(to: CGPoint(x:w*nodes[a].0,y:h*nodes[a].1))
            line.addLine(to: CGPoint(x:w*nodes[b].0,y:h*nodes[b].1))
            let pulse = sel ? 0.3 + 0.5*sin(p + Double(a+b)*0.7) : 0.3
            ctx.stroke(line, with: .color(fg.opacity(pulse)), lineWidth: 1.2)
        }
        // Nodes
        for (i,(nx,ny)) in nodes.enumerated() {
            let r: CGFloat = sel ? 5 + CGFloat(sin(p + Double(i)*0.8))*1.5 : 4
            ctx.fill(Path(ellipseIn: CGRect(x:w*nx-r,y:h*ny-r,width:r*2,height:r*2)),
                     with: .color(fg.opacity(sel ? 0.9:0.6)))
        }
    }

    // Info circle — About
    private func drawAbout(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,
                           _ fg: Color,_ p: Double,_ sel: Bool) {
        let ring: CGFloat = sel ? 1.0 + 0.05*CGFloat(sin(p)) : 1.0
        let r = w*0.40*ring
        ctx.stroke(Path(ellipseIn: CGRect(x:w/2-r,y:h/2-r,width:r*2,height:r*2)),
                   with: .color(fg.opacity(sel ? 0.9:0.6)), lineWidth: 2.0)
        // "i" dot
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-2.5,y:h*0.28,width:5,height:5)),
                 with: .color(fg.opacity(sel ? 1.0:0.7)))
        // "i" stem
        var stem = Path()
        stem.move(to: CGPoint(x:w/2, y:h*0.42))
        stem.addLine(to: CGPoint(x:w/2, y:h*0.72))
        ctx.stroke(stem, with: .color(fg.opacity(sel ? 1.0:0.7)), lineWidth: 2.2)
    }
}

// MARK: - Settings Row Animated Icon
// Replaces static Image(systemName:) in SettingsToggle / SettingsSectionCard
// Maps SF symbol name → animated Canvas variant
struct SFAnimIcon: View {
    let name:  String
    let color: Color
    let size:  CGFloat
    let isOn:  Bool        // for toggles: drives animation state

    @State private var phase: Double = 0
    @State private var t: Timer? = nil

    var body: some View {
        Canvas { ctx, sz in draw(ctx: ctx, sz: sz, p: phase) }
            .frame(width: size, height: size)
            .onChange(of: isOn) { _, v in v ? start() : stop() }
            .onAppear { if isOn { start() } }
            .onDisappear { stop() }
    }

    private func start() {
        stop()
        t = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            phase = (phase + 0.07).truncatingRemainder(dividingBy: .pi * 2)
        }
    }
    private func stop() { t?.invalidate(); t = nil; phase = 0 }

    private func draw(ctx: GraphicsContext, sz: CGSize, p: Double) {
        let w = sz.width, h = sz.height
        let on = isOn
        let alpha: Double = on ? 1.0 : 0.65

        switch sfGroup(name) {
        // ── Eye / visibility ──────────────────────
        case "eye":
            drawEye(ctx, w, h, color, p, on, alpha, slashed: name.contains("slash"))
        // ── Lock / shield ─────────────────────────
        case "lock":
            drawLock(ctx, w, h, color, p, on, alpha)
        case "shield":
            drawShield(ctx, w, h, color, p, on, alpha)
        // ── Bell / notification ───────────────────
        case "bell":
            drawBell(ctx, w, h, color, p, on, alpha)
        // ── Keyboard ──────────────────────────────
        case "keyboard":
            drawKeyboard(ctx, w, h, color, p, on, alpha)
        // ── Wifi / antenna ────────────────────────
        case "wifi":
            drawWifi(ctx, w, h, color, p, on, alpha, slashed: name.contains("slash") || name.contains("exclamation"))
        // ── Mic ───────────────────────────────────
        case "mic":
            drawMic(ctx, w, h, color, p, on, alpha)
        // ── Phone / device ────────────────────────
        case "iphone", "device":
            drawPhone(ctx, w, h, color, p, on, alpha)
        // ── Doc / copy ────────────────────────────
        case "doc":
            drawDoc(ctx, w, h, color, p, on, alpha)
        // ── Checkmark ─────────────────────────────
        case "checkmark":
            drawCheck(ctx, w, h, color, p, on, alpha)
        // ── Link ──────────────────────────────────
        case "link":
            drawLink(ctx, w, h, color, p, on, alpha)
        // ── Moon / stars ──────────────────────────
        case "moon":
            drawMoon(ctx, w, h, color, p, on, alpha)
        // ── Bolt / lightning ──────────────────────
        case "bolt":
            drawBolt(ctx, w, h, color, p, on, alpha)
        // ── Person ────────────────────────────────
        case "person":
            drawPerson(ctx, w, h, color, p, on, alpha)
        // ── Dice / random ─────────────────────────
        case "dice":
            drawDice(ctx, w, h, color, p, on, alpha)
        // ── Tray / upload ─────────────────────────
        case "tray":
            drawTray(ctx, w, h, color, p, on, alpha)
        // ── Calendar ──────────────────────────────
        case "calendar":
            drawCalendar(ctx, w, h, color, p, on, alpha)
        // ── SIM / carrier ─────────────────────────
        case "sim", "simcard":
            drawSim(ctx, w, h, color, p, on, alpha)
        // ── QR code ───────────────────────────────
        case "qrcode":
            drawQR(ctx, w, h, color, p, on, alpha)
        // ── Walk / activity ───────────────────────
        case "figure":
            drawFigure(ctx, w, h, color, p, on, alpha)
        // ── Antenna / router ──────────────────────
        case "antenna", "router":
            drawAntenna(ctx, w, h, color, p, on, alpha)
        // ── Camera ────────────────────────────────
        case "camera":
            drawCamera(ctx, w, h, color, p, on, alpha)
        // ── Arrow ─────────────────────────────────
        case "arrow":
            drawArrow(ctx, w, h, color, p, on, alpha)
        // ── Wrench ────────────────────────────────
        case "wrench":
            drawWrench(ctx, w, h, color, p, on, alpha)
        // ── Envelope ─────────────────────────────
        case "envelope":
            drawEnvelope(ctx, w, h, color, p, on, alpha)
        // ── Network ──────────────────────────────
        case "network":
            drawNetwork(ctx, w, h, color, p, on, alpha)
        // ── Circle / dashed ──────────────────────
        case "circle":
            drawCircleDash(ctx, w, h, color, p, on, alpha)
        // ── Fallback: SF symbol placeholder dot ──
        default:
            fallbackDot(ctx, w, h, color, alpha)
        }
    }

    // Map SF symbol prefix to group
    private func sfGroup(_ name: String) -> String {
        let n = name.lowercased()
        if n.hasPrefix("eye") { return "eye" }
        if n.hasPrefix("lock") { return "lock" }
        if n.hasPrefix("shield") { return "shield" }
        if n.hasPrefix("bell") { return "bell" }
        if n.hasPrefix("keyboard") { return "keyboard" }
        if n.hasPrefix("wifi") || n.hasPrefix("antenna") { return n.hasPrefix("antenna") ? "antenna" : "wifi" }
        if n.hasPrefix("mic") { return "mic" }
        if n.hasPrefix("iphone") || n.hasPrefix("ipad") { return "iphone" }
        if n.hasPrefix("doc") { return "doc" }
        if n.hasPrefix("checkmark") { return "checkmark" }
        if n.hasPrefix("link") { return "link" }
        if n.hasPrefix("moon") { return "moon" }
        if n.hasPrefix("bolt") { return "bolt" }
        if n.hasPrefix("person") { return "person" }
        if n.hasPrefix("dice") { return "dice" }
        if n.hasPrefix("tray") { return "tray" }
        if n.hasPrefix("calendar") { return "calendar" }
        if n.hasPrefix("simcard") || n.hasPrefix("sim") { return "sim" }
        if n.hasPrefix("qrcode") { return "qrcode" }
        if n.hasPrefix("figure") { return "figure" }
        if n.hasPrefix("wifi.router") || n.hasPrefix("router") { return "router" }
        if n.hasPrefix("camera") { return "camera" }
        if n.hasPrefix("arrow") { return "arrow" }
        if n.hasPrefix("wrench") { return "wrench" }
        if n.hasPrefix("envelope") { return "envelope" }
        if n.hasPrefix("network") { return "network" }
        if n.hasPrefix("circle") { return "circle" }
        return "other"
    }

    // ── Draw implementations ──────────────────────────────────

    private func drawEye(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double, slashed: Bool) {
        let blink = on ? abs(CGFloat(sin(p * 0.8))) : 1.0
        let eyeH = h * 0.28 * blink
        var eye = Path()
        eye.addArc(center: CGPoint(x:w/2,y:h/2), radius: w*0.36, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        eye.addArc(center: CGPoint(x:w/2,y:h/2), radius: w*0.36, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        ctx.stroke(eye, with: .color(c.opacity(a)), lineWidth: 1.6)
        // Pupil
        let pr = w * 0.12 * blink
        if pr > 0.5 {
            ctx.fill(Path(ellipseIn: CGRect(x:w/2-pr,y:h/2-pr,width:pr*2,height:pr*2)), with: .color(c.opacity(a)))
        }
        if slashed {
            var sl = Path()
            sl.move(to: CGPoint(x:w*0.15, y:h*0.20))
            sl.addLine(to: CGPoint(x:w*0.85, y:h*0.80))
            ctx.stroke(sl, with: .color(c.opacity(a)), lineWidth: 1.8)
        }
    }

    private func drawLock(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let bounce: CGFloat = on ? CGFloat(abs(sin(p * 1.2))) * 2.5 : 0
        let body = CGRect(x:w*0.22, y:h*0.48-bounce*0.3, width:w*0.56, height:h*0.44)
        ctx.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(c.opacity(a*0.25)))
        ctx.stroke(Path(roundedRect: body, cornerRadius: 4), with: .color(c.opacity(a)), lineWidth: 1.7)
        var shackle = Path()
        shackle.move(to: CGPoint(x:w*0.33, y:h*0.48-bounce))
        shackle.addLine(to: CGPoint(x:w*0.33, y:h*0.26-bounce))
        shackle.addArc(center: CGPoint(x:w/2,y:h*0.26-bounce), radius: w*0.17, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        shackle.addLine(to: CGPoint(x:w*0.67, y:h*0.48-bounce))
        ctx.stroke(shackle, with: .color(c.opacity(a)), lineWidth: 1.7)
        let kr: CGFloat = 3.5
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-kr,y:h*0.62-bounce*0.2,width:kr*2,height:kr*2)), with: .color(c.opacity(a)))
    }

    private func drawShield(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let pulse: CGFloat = on ? 1.0 + 0.04*CGFloat(sin(p)) : 1.0
        var s = Path()
        s.move(to: CGPoint(x:w/2, y:h*0.06*pulse))
        s.addLine(to: CGPoint(x:w*0.88, y:h*0.26))
        s.addLine(to: CGPoint(x:w*0.88, y:h*0.58))
        s.addQuadCurve(to: CGPoint(x:w/2, y:h*0.94), control: CGPoint(x:w*0.88,y:h*0.84))
        s.addQuadCurve(to: CGPoint(x:w*0.12, y:h*0.58), control: CGPoint(x:w*0.12,y:h*0.84))
        s.addLine(to: CGPoint(x:w*0.12, y:h*0.26))
        s.closeSubpath()
        ctx.fill(s, with: .color(c.opacity(on ? 0.2 : 0.12)))
        ctx.stroke(s, with: .color(c.opacity(a)), lineWidth: 1.7)
        // Check inside
        var chk = Path()
        chk.move(to: CGPoint(x:w*0.32, y:h*0.52))
        chk.addLine(to: CGPoint(x:w*0.46, y:h*0.66))
        chk.addLine(to: CGPoint(x:w*0.70, y:h*0.38))
        ctx.stroke(chk, with: .color(c.opacity(a)), lineWidth: 1.8)
    }

    private func drawBell(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let swing: Double = on ? sin(p * 2.5) * 0.18 : 0
        var gCtx = ctx
        gCtx.translateBy(x: w/2, y: h*0.25)
        gCtx.rotate(by: .radians(swing))
        gCtx.translateBy(x: -w/2, y: -h*0.25)
        var bell = Path()
        bell.move(to: CGPoint(x:w/2, y:h*0.08))
        bell.addCurve(to: CGPoint(x:w*0.85,y:h*0.65),
                      control1: CGPoint(x:w*0.90,y:h*0.20),
                      control2: CGPoint(x:w*0.90,y:h*0.55))
        bell.addLine(to: CGPoint(x:w*0.15, y:h*0.65))
        bell.addCurve(to: CGPoint(x:w/2, y:h*0.08),
                      control1: CGPoint(x:w*0.10,y:h*0.55),
                      control2: CGPoint(x:w*0.10,y:h*0.20))
        gCtx.fill(bell, with: .color(c.opacity(on ? 0.22 : 0.15)))
        gCtx.stroke(bell, with: .color(c.opacity(a)), lineWidth: 1.6)
        // Clapper
        gCtx.fill(Path(ellipseIn: CGRect(x:w/2-4,y:h*0.66,width:8,height:8)), with: .color(c.opacity(a)))
        // Top stem
        var stem = Path(); stem.move(to: CGPoint(x:w*0.44,y:h*0.08)); stem.addLine(to: CGPoint(x:w*0.56,y:h*0.08))
        gCtx.stroke(stem, with: .color(c.opacity(a)), lineWidth: 2)
    }

    private func drawKeyboard(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let body = CGRect(x:w*0.06,y:h*0.24,width:w*0.88,height:h*0.52)
        ctx.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(c.opacity(on ? 0.18:0.10)))
        ctx.stroke(Path(roundedRect: body, cornerRadius: 4), with: .color(c.opacity(a)), lineWidth: 1.5)
        // Keys — 3 rows
        let keyW: CGFloat = w*0.10, keyH: CGFloat = h*0.10
        let pressIdx = on ? Int(phase / (.pi * 2 / 9)) % 9 : -1
        for row in 0..<3 {
            let cols = row == 2 ? 5 : 8
            for col in 0..<cols {
                let kx = w*(0.12 + CGFloat(col)*(row==2 ? 0.16 : 0.10))
                let ky = h*(0.32 + CGFloat(row)*0.14)
                let keyRect = CGRect(x:kx,y:ky,width:keyW,height:keyH)
                let lit = on && (row * 8 + col) == pressIdx
                ctx.fill(Path(roundedRect: keyRect, cornerRadius: 2),
                         with: .color(c.opacity(lit ? 0.7 : 0.3)))
            }
        }
    }

    private func drawWifi(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double, slashed: Bool) {
        let cx = w/2, cy = h*0.62
        let radii: [CGFloat] = [w*0.38, w*0.27, w*0.16]
        for (i, r) in radii.enumerated() {
            let delay = Double(radii.count - 1 - i)
            let pulse = on ? 0.4 + 0.6*max(0, sin(p - delay*0.6)) : a
            var arc = Path()
            arc.addArc(center: CGPoint(x:cx,y:cy), radius: r,
                       startAngle: .degrees(215), endAngle: .degrees(325), clockwise: false)
            ctx.stroke(arc, with: .color(c.opacity(pulse)), lineWidth: 1.7)
        }
        ctx.fill(Path(ellipseIn: CGRect(x:cx-3.5,y:cy-3.5,width:7,height:7)), with: .color(c.opacity(a)))
        if slashed {
            var sl = Path(); sl.move(to: CGPoint(x:w*0.15,y:h*0.85)); sl.addLine(to: CGPoint(x:w*0.85,y:h*0.15))
            ctx.stroke(sl, with: .color(c.opacity(a)), lineWidth: 1.8)
        }
    }

    private func drawMic(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let pulse: CGFloat = on ? 1.0 + 0.06*CGFloat(sin(p)) : 1.0
        let mic = CGRect(x:w*0.33,y:h*0.06,width:w*0.34,height:h*0.44)
        ctx.fill(Path(roundedRect: mic.insetBy(dx:-2*pulse+2,dy:0), cornerRadius: h*0.17*pulse),
                 with: .color(c.opacity(on ? 0.25:0.15)))
        ctx.stroke(Path(roundedRect: mic, cornerRadius: h*0.17), with: .color(c.opacity(a)), lineWidth: 1.7)
        var stand = Path()
        stand.move(to: CGPoint(x:w*0.20,y:h*0.46))
        stand.addArc(center: CGPoint(x:w/2,y:h*0.46), radius: w*0.30, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        stand.move(to: CGPoint(x:w/2,y:h*0.76)); stand.addLine(to: CGPoint(x:w/2,y:h*0.92))
        stand.move(to: CGPoint(x:w*0.34,y:h*0.92)); stand.addLine(to: CGPoint(x:w*0.66,y:h*0.92))
        ctx.stroke(stand, with: .color(c.opacity(a)), lineWidth: 1.7)
        if name.contains("slash") {
            var sl = Path(); sl.move(to: CGPoint(x:w*0.15,y:h*0.85)); sl.addLine(to: CGPoint(x:w*0.85,y:h*0.15))
            ctx.stroke(sl, with: .color(c.opacity(a)), lineWidth: 1.8)
        }
    }

    private func drawPhone(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let screen = CGRect(x:w*0.28,y:h*0.06,width:w*0.44,height:h*0.88)
        ctx.fill(Path(roundedRect: screen, cornerRadius: 6), with: .color(c.opacity(on ? 0.20:0.12)))
        ctx.stroke(Path(roundedRect: screen, cornerRadius: 6), with: .color(c.opacity(a)), lineWidth: 1.7)
        let inner = CGRect(x:w*0.33,y:h*0.14,width:w*0.34,height:h*0.64)
        let glow = on ? 0.20 + 0.15*CGFloat(sin(p)) : 0.12
        ctx.fill(Path(roundedRect: inner, cornerRadius: 3), with: .color(c.opacity(glow)))
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-3,y:h*0.09,width:6,height:6)), with: .color(c.opacity(a)))
        ctx.fill(Path(roundedRect: CGRect(x:w/2-8,y:h*0.85,width:16,height:3), cornerRadius: 2), with: .color(c.opacity(a)))
    }

    private func drawDoc(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let shadow: CGFloat = on ? CGFloat(sin(p)*3) : 0
        let d2 = CGRect(x:w*0.22+shadow,y:h*0.14+shadow,width:w*0.52,height:h*0.70)
        ctx.fill(Path(roundedRect: d2, cornerRadius: 4), with: .color(c.opacity(on ? 0.18:0.10)))
        ctx.stroke(Path(roundedRect: d2, cornerRadius: 4), with: .color(c.opacity(a*0.6)), lineWidth: 1.2)
        let d1 = CGRect(x:w*0.16,y:h*0.08,width:w*0.52,height:h*0.70)
        ctx.fill(Path(roundedRect: d1, cornerRadius: 4), with: .color(c.opacity(on ? 0.25:0.15)))
        ctx.stroke(Path(roundedRect: d1, cornerRadius: 4), with: .color(c.opacity(a)), lineWidth: 1.5)
        for i in 0..<3 {
            var l = Path()
            l.move(to: CGPoint(x:w*0.24,y:h*(0.28+CGFloat(i)*0.16)))
            l.addLine(to: CGPoint(x:w*(i==2 ? 0.52 : 0.60),y:h*(0.28+CGFloat(i)*0.16)))
            ctx.stroke(l, with: .color(c.opacity(a*0.7)), lineWidth: 1.2)
        }
    }

    private func drawCheck(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let scale: CGFloat = on ? 1.0 + 0.08*CGFloat(sin(p)) : 1.0
        let circle = Path(ellipseIn: CGRect(x:w/2-w*0.38*scale,y:h/2-h*0.38*scale,width:w*0.76*scale,height:h*0.76*scale))
        ctx.stroke(circle, with: .color(c.opacity(a)), lineWidth: 1.7)
        var chk = Path()
        chk.move(to: CGPoint(x:w*0.28,y:h*0.50))
        chk.addLine(to: CGPoint(x:w*0.44,y:h*0.65))
        chk.addLine(to: CGPoint(x:w*0.72,y:h*0.36))
        ctx.stroke(chk, with: .color(c.opacity(a)), lineWidth: 2.0)
    }

    private func drawLink(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let shift: CGFloat = on ? CGFloat(sin(p))*2 : 0
        func ring(_ cx: CGFloat,_ cy: CGFloat,_ r: CGFloat) {
            var path = Path()
            path.addArc(center: CGPoint(x:cx,y:cy), radius: r, startAngle: .degrees(45), endAngle: .degrees(225), clockwise: false)
            ctx.stroke(path, with: .color(c.opacity(a)), lineWidth: 2.2)
        }
        ring(w*0.36+shift, h*0.50, h*0.22)
        ring(w*0.64-shift, h*0.50, h*0.22)
        var mid = Path(); mid.move(to: CGPoint(x:w*0.38,y:h*0.50)); mid.addLine(to: CGPoint(x:w*0.62,y:h*0.50))
        ctx.stroke(mid, with: .color(c.opacity(a)), lineWidth: 1.5)
    }

    private func drawMoon(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        var moon = Path()
        moon.addArc(center: CGPoint(x:w/2,y:h/2), radius: h*0.38, startAngle: .degrees(40), endAngle: .degrees(290), clockwise: false)
        moon.addArc(center: CGPoint(x:w*0.40,y:h*0.42), radius: h*0.30, startAngle: .degrees(290), endAngle: .degrees(40), clockwise: true)
        moon.closeSubpath()
        ctx.fill(moon, with: .color(c.opacity(on ? 0.25:0.15)))
        ctx.stroke(moon, with: .color(c.opacity(a)), lineWidth: 1.5)
        if name.contains("star") {
            for i in 0..<3 {
                let sx = w*(0.65 + CGFloat(i)*0.10)
                let sy = h*(0.15 + CGFloat(i)*0.12)
                let sr: CGFloat = on ? 2.5 + CGFloat(sin(p + Double(i)*1.2))*1.0 : 2.0
                ctx.fill(Path(ellipseIn: CGRect(x:sx-sr,y:sy-sr,width:sr*2,height:sr*2)), with: .color(c.opacity(a)))
            }
        }
    }

    private func drawBolt(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        var bolt = Path()
        bolt.move(to: CGPoint(x:w*0.60, y:h*0.08))
        bolt.addLine(to: CGPoint(x:w*0.32, y:h*0.50))
        bolt.addLine(to: CGPoint(x:w*0.52, y:h*0.50))
        bolt.addLine(to: CGPoint(x:w*0.40, y:h*0.92))
        bolt.addLine(to: CGPoint(x:w*0.68, y:h*0.46))
        bolt.addLine(to: CGPoint(x:w*0.50, y:h*0.46))
        bolt.closeSubpath()
        let glow = on ? c.opacity(0.30 + 0.20*sin(p)) : c.opacity(0.15)
        ctx.fill(bolt, with: glow)
        ctx.stroke(bolt, with: .color(c.opacity(a)), lineWidth: 1.5)
    }

    private func drawPerson(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let hr: CGFloat = h*0.16
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-hr,y:h*0.08,width:hr*2,height:hr*2)), with: .color(c.opacity(a)))
        var body = Path()
        body.move(to: CGPoint(x:w*0.10,y:h*0.92))
        body.addQuadCurve(to: CGPoint(x:w*0.90,y:h*0.92), control: CGPoint(x:w/2,y:h*(on ? 0.48+0.04*CGFloat(sin(p)):0.52)))
        ctx.stroke(body, with: .color(c.opacity(a)), lineWidth: 2.0)
        if name.contains("xmark") || name.contains("slash") {
            var x = Path(); x.move(to: CGPoint(x:w*0.60,y:h*0.30)); x.addLine(to: CGPoint(x:w*0.88,y:h*0.58))
            var x2 = Path(); x2.move(to: CGPoint(x:w*0.88,y:h*0.30)); x2.addLine(to: CGPoint(x:w*0.60,y:h*0.58))
            ctx.stroke(x, with: .color(c.opacity(a)), lineWidth: 1.8)
            ctx.stroke(x2, with: .color(c.opacity(a)), lineWidth: 1.8)
        }
    }

    private func drawDice(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let angle: Double = on ? p * 0.5 : 0
        var gCtx = ctx; gCtx.translateBy(x:w/2,y:h/2); gCtx.rotate(by:.radians(angle)); gCtx.translateBy(x:-w/2,y:-h/2)
        let box = CGRect(x:w*0.16,y:h*0.16,width:w*0.68,height:h*0.68)
        gCtx.fill(Path(roundedRect: box, cornerRadius: 8), with: .color(c.opacity(on ? 0.22:0.12)))
        gCtx.stroke(Path(roundedRect: box, cornerRadius: 8), with: .color(c.opacity(a)), lineWidth: 1.7)
        let dots: [(CGFloat,CGFloat)] = [(0.34,0.34),(0.66,0.34),(0.34,0.66),(0.66,0.66),(0.50,0.50)]
        for (i,(dx,dy)) in dots.enumerated() {
            let r: CGFloat = on ? 3.0 + CGFloat(sin(p + Double(i)*0.7))*0.8 : 2.5
            gCtx.fill(Path(ellipseIn: CGRect(x:w*dx-r,y:h*dy-r,width:r*2,height:r*2)), with: .color(c.opacity(a)))
        }
    }

    private func drawTray(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        var tray = Path()
        tray.move(to: CGPoint(x:w*0.08,y:h*0.56)); tray.addLine(to: CGPoint(x:w*0.08,y:h*0.88))
        tray.addLine(to: CGPoint(x:w*0.92,y:h*0.88)); tray.addLine(to: CGPoint(x:w*0.92,y:h*0.56))
        ctx.stroke(tray, with: .color(c.opacity(a)), lineWidth: 1.7)
        let arrY: CGFloat = h*(on ? 0.42 + 0.06*CGFloat(sin(p)) : 0.42)
        var arr = Path()
        arr.move(to: CGPoint(x:w/2,y:h*0.10)); arr.addLine(to: CGPoint(x:w/2,y:arrY))
        arr.move(to: CGPoint(x:w*0.34,y:h*0.30)); arr.addLine(to: CGPoint(x:w/2,y:h*0.10))
        arr.addLine(to: CGPoint(x:w*0.66,y:h*0.30))
        ctx.stroke(arr, with: .color(c.opacity(a)), lineWidth: 1.7)
    }

    private func drawCalendar(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let cal = CGRect(x:w*0.10,y:h*0.18,width:w*0.80,height:h*0.74)
        ctx.fill(Path(roundedRect: cal, cornerRadius: 5), with: .color(c.opacity(on ? 0.18:0.10)))
        ctx.stroke(Path(roundedRect: cal, cornerRadius: 5), with: .color(c.opacity(a)), lineWidth: 1.6)
        var header = Path(); header.move(to: CGPoint(x:w*0.10,y:h*0.38)); header.addLine(to: CGPoint(x:w*0.90,y:h*0.38))
        ctx.stroke(header, with: .color(c.opacity(a*0.5)), lineWidth: 1)
        for col in 0..<3 {
            let cx = w*(0.28+CGFloat(col)*0.22), cy = h*(on ? 0.62 + 0.04*CGFloat(sin(p+Double(col)*0.8)) : 0.62)
            ctx.fill(Path(roundedRect: CGRect(x:cx-5,y:cy-5,width:10,height:10), cornerRadius: 2), with: .color(c.opacity(a*0.7)))
        }
        var rings = Path()
        rings.move(to: CGPoint(x:w*0.32,y:h*0.10)); rings.addLine(to: CGPoint(x:w*0.32,y:h*0.26))
        rings.move(to: CGPoint(x:w*0.68,y:h*0.10)); rings.addLine(to: CGPoint(x:w*0.68,y:h*0.26))
        ctx.stroke(rings, with: .color(c.opacity(a)), lineWidth: 2.0)
    }

    private func drawSim(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let card = CGRect(x:w*0.25,y:h*0.10,width:w*0.50,height:h*0.80)
        var s = Path()
        s.move(to: CGPoint(x:w*0.44,y:h*0.10)); s.addLine(to: CGPoint(x:w*0.25,y:h*0.10))
        s.addLine(to: CGPoint(x:w*0.25,y:h*0.90)); s.addLine(to: CGPoint(x:w*0.75,y:h*0.90))
        s.addLine(to: CGPoint(x:w*0.75,y:h*0.10)); s.addLine(to: CGPoint(x:w*0.60,y:h*0.10))
        s.addLine(to: CGPoint(x:w*0.50,y:h*0.22)); s.addLine(to: CGPoint(x:w*0.44,y:h*0.10))
        ctx.fill(s, with: .color(c.opacity(on ? 0.22:0.12)))
        ctx.stroke(s, with: .color(c.opacity(a)), lineWidth: 1.6)
        let pulse = on ? 0.5 + 0.5*CGFloat(sin(p)) : 0.6
        let inner = CGRect(x:w*0.34,y:h*0.38,width:w*0.32,height:h*0.38)
        ctx.fill(Path(roundedRect: inner, cornerRadius: 3), with: .color(c.opacity(pulse)))
    }

    private func drawQR(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let corners: [(CGFloat,CGFloat)] = [(0.08,0.08),(0.56,0.08),(0.08,0.56)]
        for (ox,oy) in corners {
            let outer = CGRect(x:w*ox,y:h*oy,width:w*0.32,height:h*0.32)
            let inner = CGRect(x:w*(ox+0.08),y:h*(oy+0.08),width:w*0.16,height:h*0.16)
            ctx.stroke(Path(roundedRect: outer, cornerRadius: 3), with: .color(c.opacity(a)), lineWidth: 1.4)
            let fill = on ? c.opacity(0.5+0.4*sin(p)) : c.opacity(0.6)
            ctx.fill(Path(roundedRect: inner, cornerRadius: 2), with: fill)
        }
        // Data dots
        for row in 0..<3 {
            for col in 0..<3 {
                let dx = w*(0.60+CGFloat(col)*0.12), dy = h*(0.60+CGFloat(row)*0.12)
                let r: CGFloat = on ? 3.5 + CGFloat(sin(p+Double(row+col)*0.8))*1 : 3
                ctx.fill(Path(ellipseIn: CGRect(x:dx-r/2,y:dy-r/2,width:r,height:r)), with: .color(c.opacity(a)))
            }
        }
    }

    private func drawFigure(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let legSwing: CGFloat = on ? CGFloat(sin(p*2))*10 : 0
        let hr: CGFloat = h*0.14
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-hr,y:h*0.05,width:hr*2,height:hr*2)), with: .color(c.opacity(a)))
        var body = Path(); body.move(to: CGPoint(x:w/2,y:h*0.33)); body.addLine(to: CGPoint(x:w/2,y:h*0.65))
        ctx.stroke(body, with: .color(c.opacity(a)), lineWidth: 2.0)
        var arms = Path()
        arms.move(to: CGPoint(x:w*0.25,y:h*0.42+legSwing*0.3)); arms.addLine(to: CGPoint(x:w*0.75,y:h*0.42-legSwing*0.3))
        ctx.stroke(arms, with: .color(c.opacity(a)), lineWidth: 1.8)
        var legs = Path()
        legs.move(to: CGPoint(x:w/2,y:h*0.65))
        legs.addLine(to: CGPoint(x:w*0.32,y:h*0.92+legSwing))
        legs.move(to: CGPoint(x:w/2,y:h*0.65))
        legs.addLine(to: CGPoint(x:w*0.68,y:h*0.92-legSwing))
        ctx.stroke(legs, with: .color(c.opacity(a)), lineWidth: 1.8)
    }

    private func drawAntenna(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        var pole = Path(); pole.move(to: CGPoint(x:w/2,y:h*0.92)); pole.addLine(to: CGPoint(x:w/2,y:h*0.30))
        ctx.stroke(pole, with: .color(c.opacity(a)), lineWidth: 2.0)
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-4,y:h*0.22,width:8,height:8)), with: .color(c.opacity(a)))
        let waves = 3
        for i in 0..<waves {
            let r = w*(0.15 + CGFloat(i)*0.12)
            let pulse = on ? 0.3 + 0.7*max(0,sin(p - Double(i)*0.8)) : a*0.5
            var arc = Path()
            arc.addArc(center: CGPoint(x:w/2,y:h*0.26), radius: r, startAngle: .degrees(250), endAngle: .degrees(290), clockwise: false)
            arc.move(to: CGPoint(x:w/2-w*0.04, y:h*0.26))
            arc.addArc(center: CGPoint(x:w/2,y:h*0.26), radius: r, startAngle: .degrees(250), endAngle: .degrees(290), clockwise: false)
            var arcL = Path()
            arcL.addArc(center: CGPoint(x:w/2,y:h*0.26), radius: r, startAngle: .degrees(250), endAngle: .degrees(290), clockwise: true)
            let fullArc = Path(ellipseIn: CGRect(x:w/2-r,y:h*0.26-r,width:r*2,height:r*2))
            ctx.stroke(
                { var p2 = Path(); p2.addArc(center:CGPoint(x:w/2,y:h*0.26),radius:r,startAngle:.degrees(40),endAngle:.degrees(140),clockwise:false); return p2 }(),
                with: .color(c.opacity(pulse)), lineWidth: 1.6)
            ctx.stroke(
                { var p2 = Path(); p2.addArc(center:CGPoint(x:w/2,y:h*0.26),radius:r,startAngle:.degrees(40),endAngle:.degrees(140),clockwise:true); return p2 }(),
                with: .color(c.opacity(pulse)), lineWidth: 1.6)
        }
    }

    private func drawCamera(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let body = CGRect(x:w*0.08,y:h*0.26,width:w*0.84,height:h*0.56)
        ctx.fill(Path(roundedRect: body, cornerRadius: 6), with: .color(c.opacity(on ? 0.20:0.12)))
        ctx.stroke(Path(roundedRect: body, cornerRadius: 6), with: .color(c.opacity(a)), lineWidth: 1.6)
        var bump = Path(); bump.move(to: CGPoint(x:w*0.36,y:h*0.26)); bump.addLine(to: CGPoint(x:w*0.36,y:h*0.16)); bump.addLine(to: CGPoint(x:w*0.52,y:h*0.16)); bump.addLine(to: CGPoint(x:w*0.52,y:h*0.26))
        ctx.stroke(bump, with: .color(c.opacity(a)), lineWidth: 1.6)
        let lr = w*(on ? 0.20 + 0.02*CGFloat(sin(p)) : 0.20)
        ctx.stroke(Path(ellipseIn: CGRect(x:w/2-lr,y:h/2-lr,width:lr*2,height:lr*2)), with: .color(c.opacity(a)), lineWidth: 1.5)
        let ir: CGFloat = lr * 0.55
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-ir,y:h/2-ir,width:ir*2,height:ir*2)), with: .color(c.opacity(a*0.8)))
    }

    private func drawArrow(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let dy: CGFloat = on ? CGFloat(sin(p))*3 : 0
        var arr = Path()
        arr.move(to: CGPoint(x:w*0.20,y:h*0.50+dy)); arr.addLine(to: CGPoint(x:w*0.80,y:h*0.50+dy))
        arr.move(to: CGPoint(x:w*0.58,y:h*0.28+dy)); arr.addLine(to: CGPoint(x:w*0.80,y:h*0.50+dy))
        arr.addLine(to: CGPoint(x:w*0.58,y:h*0.72+dy))
        ctx.stroke(arr, with: .color(c.opacity(a)), lineWidth: 2.0)
    }

    private func drawWrench(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let angle: Double = on ? sin(p*1.5)*0.25 : 0
        var gCtx = ctx; gCtx.translateBy(x:w*0.32,y:h*0.32); gCtx.rotate(by:.radians(angle)); gCtx.translateBy(x:-w*0.32,y:-h*0.32)
        var wr = Path()
        wr.move(to: CGPoint(x:w*0.22,y:h*0.30)); wr.addLine(to: CGPoint(x:w*0.70,y:h*0.78))
        gCtx.stroke(wr, with: .color(c.opacity(a)), lineWidth: 4.5)
        gCtx.stroke(wr, with: .color(c.opacity(0.3)), lineWidth: 2.0)
        var circ = Path()
        circ.addArc(center: CGPoint(x:w*0.30,y:h*0.28), radius: h*0.18, startAngle: .degrees(0), endAngle: .degrees(260), clockwise: false)
        gCtx.stroke(circ, with: .color(c.opacity(a)), lineWidth: 2.0)
    }

    private func drawEnvelope(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let env = CGRect(x:w*0.08,y:h*0.22,width:w*0.84,height:h*0.56)
        ctx.fill(Path(roundedRect: env, cornerRadius: 4), with: .color(c.opacity(on ? 0.20:0.12)))
        ctx.stroke(Path(roundedRect: env, cornerRadius: 4), with: .color(c.opacity(a)), lineWidth: 1.6)
        var flap = Path()
        flap.move(to: CGPoint(x:w*0.08,y:h*0.22))
        flap.addLine(to: CGPoint(x:w/2,y:h*(0.22+on ? 0.26+0.04*CGFloat(sin(p)):0.28)))
        flap.addLine(to: CGPoint(x:w*0.92,y:h*0.22))
        ctx.stroke(flap, with: .color(c.opacity(a)), lineWidth: 1.6)
    }

    private func drawNetwork(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let nodes: [(CGFloat,CGFloat)] = [(0.5,0.14),(0.18,0.60),(0.82,0.60),(0.5,0.88)]
        for (a1,b1) in [(0,1),(0,2),(1,3),(2,3)] {
            var line = Path()
            line.move(to: CGPoint(x:w*nodes[a1].0,y:h*nodes[a1].1))
            line.addLine(to: CGPoint(x:w*nodes[b1].0,y:h*nodes[b1].1))
            let pulse = on ? 0.3 + 0.6*sin(p + Double(a1+b1)*0.7) : 0.35
            ctx.stroke(line, with: .color(c.opacity(pulse)), lineWidth: 1.3)
        }
        for (i,(nx,ny)) in nodes.enumerated() {
            let r: CGFloat = on ? 5 + CGFloat(sin(p+Double(i)*0.9))*1.5 : 4
            ctx.fill(Path(ellipseIn: CGRect(x:w*nx-r,y:h*ny-r,width:r*2,height:r*2)), with: .color(c.opacity(a)))
        }
    }

    private func drawCircleDash(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ p: Double,_ on: Bool,_ a: Double) {
        let segments = 8
        for i in 0..<segments {
            let a1 = Double(i) / Double(segments) * .pi * 2 + (on ? p*0.3 : 0)
            let a2 = a1 + .pi / Double(segments) * 0.7
            var arc = Path()
            arc.addArc(center: CGPoint(x:w/2,y:h/2), radius: h*0.38, startAngle: .radians(a1), endAngle: .radians(a2), clockwise: false)
            let pulse = on ? 0.4 + 0.6*sin(p + Double(i)*0.5) : a
            ctx.stroke(arc, with: .color(c.opacity(pulse)), lineWidth: 2.2)
        }
    }

    private func fallbackDot(_ ctx: GraphicsContext,_ w: CGFloat,_ h: CGFloat,_ c: Color,_ a: Double) {
        ctx.fill(Path(ellipseIn: CGRect(x:w/2-6,y:h/2-6,width:12,height:12)), with: .color(c.opacity(a)))
    }
}
