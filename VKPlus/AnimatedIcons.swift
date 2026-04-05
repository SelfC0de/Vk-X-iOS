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
