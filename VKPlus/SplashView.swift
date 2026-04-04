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
                Color(red:0.02,green:0.03,blue:0.06).ignoresSafeArea()
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
    }

    private func startSplit(h: CGFloat) {
        splitting = true
        withAnimation(.easeIn(duration: 0.55).delay(0.05)) {
            splitTop = h/2 + 80; splitBot = h/2 + 80
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.6) { onFinished() }
    }
}

// MARK: - SplashCanvas
struct SplashCanvas: View {
    var isAuthenticated: Bool = false
    var onReadyToTransition: () -> Void = {}

    private let T_DRAW: Double = 3.6   // circuit draw duration
    private let T_DONE: Double = 4.5   // fire transition after bySelfCode appears

    @State private var startDate = Date()
    @State private var doneFired = false

    var body: some View {
        TimelineView(.animation) { tl in
            let now = tl.date
            let el  = max(0, now.timeIntervalSince(startDate))
            let dp  = min(1.0, el / T_DRAW)
            Canvas { ctx, size in
                draw(ctx: ctx, size: size, dp: dp, el: el)
            }
        }
        .background(Color(red:0.02,green:0.03,blue:0.06))
        .onAppear { startDate = Date() }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(T_DONE * 1_000_000_000))
            if !doneFired { doneFired = true; onReadyToTransition() }
        }
    }

    // MARK: - Draw
    private func draw(ctx: GraphicsContext, size: CGSize, dp: Double, el: Double) {
        let W = size.width, H = size.height
        let cx = W/2, cy = H*0.42
        let BLUE = Color(red:0, green:0.706, blue:1)
        let ACC  = Color(red:0, green:0.933, blue:1)

        let FS: CGFloat = 42
        let tw: CGFloat = 78, th: CGFloat = FS*0.72
        let lL=cx-tw/2, lR=cx+tw/2, lT=cy-th/2, lB=cy+th/2
        let bx1=cx-112, by1=cy-98, bx2=cx+112, by2=cy+98
        let br: CGFloat = 18

        let traces:[[CGPoint]] = [
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
        let borders:[[CGPoint]] = [
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
        let vias:[CGPoint] = [
            .init(x:bx1,y:by1),.init(x:bx2,y:by1),.init(x:bx1,y:by2),.init(x:bx2,y:by2),
            .init(x:lL+10,y:lT-24),.init(x:cx+20,y:lT-36),
            .init(x:lR+14,y:lT-44),.init(x:lR+24,y:lB+40),
            .init(x:lL-18,y:lB+40),.init(x:lL-44,y:cy-32),
            .init(x:lL-22,y:cy+38),.init(x:cx-14,y:lB+52),
            .init(x:cx+6,y:lT-48),.init(x:lR+44,y:cy-18),
        ]
        let labelY = by2 + 52

        func pLen(_ pts:[CGPoint]) -> CGFloat {
            var l:CGFloat=0
            for i in 1..<pts.count { let dx=pts[i].x-pts[i-1].x,dy=pts[i].y-pts[i-1].y; l+=sqrt(dx*dx+dy*dy) }
            return l
        }
        func drawTrace(_ pts:[CGPoint],_ prog:Double,_ color:Color,_ lw:CGFloat) {
            guard prog>0, pts.count>=2 else { return }
            let tot=pLen(pts); var d=CGFloat(prog)*tot
            var path=Path(); path.move(to:pts[0])
            var ex=pts[0].x,ey=pts[0].y
            for i in 1..<pts.count {
                let dx=pts[i].x-pts[i-1].x,dy=pts[i].y-pts[i-1].y,sl=sqrt(dx*dx+dy*dy)
                guard d>0 else { break }
                let tk=min(sl,d); ex=pts[i-1].x+dx*(tk/sl); ey=pts[i-1].y+dy*(tk/sl)
                path.addLine(to:.init(x:ex,y:ey)); d-=tk
            }
            ctx.stroke(path, with:.color(color), style:StrokeStyle(lineWidth:lw,lineCap:.round,lineJoin:.round))
            ctx.fill(Path(ellipseIn:CGRect(x:ex-lw*1.8,y:ey-lw*1.8,width:lw*3.6,height:lw*3.6)), with:.color(ACC))
        }

        // borders
        for (i,bp) in borders.enumerated() {
            let p = min(1.0, max(0,(dp-Double(i)*0.03)/(1-Double(i)*0.03))*1.1)
            drawTrace(bp, p, BLUE.opacity(0.3), 0.9)
        }
        // traces
        for (i,tr) in traces.enumerated() {
            let delay = 0.05+Double(i)*0.05
            let p = min(1.0, max(0,(dp-delay)/(1-delay)))
            drawTrace(tr, p, BLUE.opacity(0.6), 1.1)
        }
        // vias
        if dp>0.35 {
            let va=min(1.0,(dp-0.35)/0.3)
            for v in vias {
                ctx.fill(Path(ellipseIn:CGRect(x:v.x-3,y:v.y-3,width:6,height:6)), with:.color(ACC.opacity(va*0.85)))
                ctx.stroke(Path(ellipseIn:CGRect(x:v.x-6,y:v.y-6,width:12,height:12)), with:.color(BLUE.opacity(va*0.2)), lineWidth:0.5)
            }
        }
        // VK+
        if dp>0.55 {
            let ta=min(1.0,(dp-0.55)/0.28)
            var t=AttributedString("VK+")
            t.font = .systemFont(ofSize:FS,weight:.black)
            t.foregroundColor = UIColor(red:0,green:0.706,blue:1,alpha:CGFloat(ta))
            ctx.draw(Text(t), at:.init(x:cx,y:cy), anchor:.center)
        }
        // pulse glow on VK+ after fully drawn
        if dp>=1.0 {
            let pulse = 0.08 + sin(el*2.5)*0.08
            var t=AttributedString("VK+")
            t.font = .systemFont(ofSize:FS,weight:.black)
            t.foregroundColor = UIColor(red:0,green:0.706,blue:1,alpha:CGFloat(max(0,pulse)))
            ctx.draw(Text(t), at:.init(x:cx,y:cy), anchor:.center)
        }
        // by SelfCode
        let bsStart=0.82, bsEnd=0.97
        if dp>bsStart {
            let la=min(1.0,(dp-bsStart)/(bsEnd-bsStart))
            let ease=1.0-pow(1.0-la,3.0)
            var t=AttributedString("by SelfCode")
            t.font = .systemFont(ofSize:15,weight:.semibold)
            t.foregroundColor = UIColor(red:0.71,green:0.75,blue:0.82,alpha:CGFloat(ease))
            ctx.draw(Text(t), at:.init(x:cx,y:labelY+CGFloat((1-ease)*18)), anchor:.center)
        }
    }
}
