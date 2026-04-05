import SwiftUI

// MARK: - Pet species
enum PetSpecies: String, CaseIterable {
    case cat, dog, bunny, duck, frog, hamster, fox, panda

    var label: String {
        switch self {
        case .cat:     return "🐱 Кот"
        case .dog:     return "🐶 Собака"
        case .bunny:   return "🐰 Кролик"
        case .duck:    return "🐥 Утёнок"
        case .frog:    return "🐸 Лягушка"
        case .hamster: return "🐹 Хомяк"
        case .fox:     return "🦊 Лиса"
        case .panda:   return "🐼 Панда"
        }
    }

    // Walking speed pts/sec
    var speed: Double {
        switch self {
        case .bunny: return 90
        case .frog:  return 55
        case .duck:  return 50
        case .dog:   return 75
        case .cat:   return 65
        case .fox:   return 70
        case .panda: return 40
        case .hamster: return 60
        }
    }

    // Gait: true = hop/jump, false = walk
    var hops: Bool {
        switch self {
        case .bunny, .frog: return true
        default: return false
        }
    }

    // Body color
    var bodyColor: Color {
        switch self {
        case .cat:     return Color(red:0.75, green:0.72, blue:0.68)
        case .dog:     return Color(red:0.82, green:0.65, blue:0.40)
        case .bunny:   return Color(red:0.92, green:0.88, blue:0.88)
        case .duck:    return Color(red:1.00, green:0.88, blue:0.20)
        case .frog:    return Color(red:0.30, green:0.78, blue:0.30)
        case .hamster: return Color(red:0.90, green:0.72, blue:0.55)
        case .fox:     return Color(red:0.92, green:0.50, blue:0.18)
        case .panda:   return Color(red:0.95, green:0.95, blue:0.95)
        }
    }

    var accentColor: Color {
        switch self {
        case .cat:     return Color(red:0.55, green:0.52, blue:0.48)
        case .dog:     return Color(red:0.60, green:0.44, blue:0.22)
        case .bunny:   return Color(red:0.95, green:0.70, blue:0.75)
        case .duck:    return Color(red:1.00, green:0.55, blue:0.10)
        case .frog:    return Color(red:0.18, green:0.58, blue:0.18)
        case .hamster: return Color(red:0.75, green:0.52, blue:0.35)
        case .fox:     return Color(red:0.25, green:0.18, blue:0.12)
        case .panda:   return Color(red:0.12, green:0.12, blue:0.12)
        }
    }
}

// MARK: - Animated Pet Sprite (Canvas-based)
private struct PetSprite: View {
    let species: PetSpecies
    let phase:   Double   // 0..1 walk cycle
    let flipped: Bool
    let jumping: Bool     // for hoppers: in-air state
    let idle:    Bool

    private let W: CGFloat = 28
    private let H: CGFloat = 22

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: flipped ? -1 : 1, y: 1)
            let ox: CGFloat = flipped ? -size.width : 0
            draw(ctx: ctx, ox: ox, size: size)
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }

    private func draw(ctx: GraphicsContext, ox: CGFloat, size: CGSize) {
        let cx = size.width / 2 + ox
        let ground = size.height - 3

        switch species {
        case .bunny:  drawBunny(ctx: ctx, cx: cx, ground: ground)
        case .frog:   drawFrog(ctx: ctx, cx: cx, ground: ground)
        case .duck:   drawDuck(ctx: ctx, cx: cx, ground: ground)
        default:      drawQuadruped(ctx: ctx, cx: cx, ground: ground)
        }
    }

    // MARK: - Quadruped (cat/dog/fox/panda/hamster)
    private func drawQuadruped(ctx: GraphicsContext, cx: CGFloat, ground: CGFloat) {
        let sp    = species
        let bc    = sp.bodyColor
        let ac    = sp.accentColor
        let t     = phase  // 0..1

        // Leg oscillation: 4 legs alternating pairs
        let legSwing: CGFloat = idle ? 0 : CGFloat(sin(t * .pi * 2)) * 5
        let legSwing2: CGFloat = idle ? 0 : CGFloat(-sin(t * .pi * 2)) * 5

        // Body y-bob while walking
        let bodyBob: CGFloat = idle ? 0 : abs(CGFloat(sin(t * .pi * 2))) * 1.2

        let bodyY = ground - 8 - bodyBob

        // === LEGS (drawn first, behind body) ===
        let legColor = ac
        // Front-left leg
        drawLeg(ctx, from: CGPoint(x: cx - 4, y: bodyY + 3),
                angle: legSwing,  len: 6, color: legColor)
        // Back-right leg
        drawLeg(ctx, from: CGPoint(x: cx + 4, y: bodyY + 3),
                angle: legSwing, len: 6, color: legColor)
        // Front-right leg
        drawLeg(ctx, from: CGPoint(x: cx - 2, y: bodyY + 3),
                angle: legSwing2, len: 6, color: legColor)
        // Back-left leg
        drawLeg(ctx, from: CGPoint(x: cx + 2, y: bodyY + 3),
                angle: legSwing2, len: 6, color: legColor)

        // === TAIL ===
        let tailWag: CGFloat = idle ? 0 : CGFloat(sin(t * .pi * 4)) * 8
        drawTail(ctx, at: CGPoint(x: cx + 7, y: bodyY), wag: tailWag, color: bc, accent: ac, species: sp)

        // === BODY ===
        let bodyRect = CGRect(x: cx - 7, y: bodyY - 3, width: 14, height: 9)
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(bc))

        // === HEAD ===
        let headX = cx - 8
        let headRect = CGRect(x: headX, y: bodyY - 9, width: 9, height: 8)
        ctx.fill(Path(ellipseIn: headRect), with: .color(bc))

        // Species-specific head features
        drawHeadDetails(ctx, hx: headX, hy: bodyY - 9, species: sp, bc: bc, ac: ac, idle: idle, t: t)
    }

    private func drawLeg(_ ctx: GraphicsContext, from pt: CGPoint, angle: CGFloat, len: CGFloat, color: Color) {
        let endX = pt.x + CGFloat(sin(Double(angle) * .pi / 180)) * len * 0.6
        let endY = pt.y + len
        var path = Path()
        path.move(to: pt)
        // Knee bend
        let kneeX = pt.x + (endX - pt.x) * 0.5 + angle * 0.15
        let kneeY = pt.y + len * 0.5
        path.addQuadCurve(to: CGPoint(x: endX, y: endY),
                          control: CGPoint(x: kneeX, y: kneeY))
        ctx.stroke(path, with: .color(color), lineWidth: 2)

        // Paw
        ctx.fill(Path(ellipseIn: CGRect(x: endX - 1.5, y: endY - 1, width: 3, height: 2)),
                 with: .color(color))
    }

    private func drawTail(_ ctx: GraphicsContext, at pt: CGPoint, wag: CGFloat, color: Color, accent: Color, species: PetSpecies) {
        var path = Path()
        path.move(to: pt)
        let tipX = pt.x + 5 + wag * 0.3
        let tipY = pt.y - 4 - abs(wag) * 0.2
        path.addQuadCurve(to: CGPoint(x: tipX, y: tipY),
                          control: CGPoint(x: pt.x + 4, y: pt.y + 2))
        // Fox/cat: bushy tail
        let width: CGFloat = (species == .fox || species == .cat) ? 3 : 2
        ctx.stroke(path, with: .color(species == .fox ? accent : color), lineWidth: width)
        if species == .fox {
            ctx.fill(Path(ellipseIn: CGRect(x: tipX - 2, y: tipY - 2, width: 4, height: 4)), with: .color(.white))
        }
    }

    private func drawHeadDetails(_ ctx: GraphicsContext, hx: CGFloat, hy: CGFloat, species: PetSpecies, bc: Color, ac: Color, idle: Bool, t: Double) {
        // Ears
        switch species {
        case .cat, .fox:
            // Pointed ears
            drawTriEar(ctx, at: CGPoint(x: hx + 1, y: hy), color: bc, accent: ac)
            drawTriEar(ctx, at: CGPoint(x: hx + 5, y: hy), color: bc, accent: ac)
        case .dog:
            // Floppy ears
            ctx.fill(Path(ellipseIn: CGRect(x: hx - 1, y: hy + 1, width: 3, height: 5)), with: .color(ac))
            ctx.fill(Path(ellipseIn: CGRect(x: hx + 6, y: hy + 1, width: 3, height: 5)), with: .color(ac))
        case .panda:
            // Round ears with black patches
            ctx.fill(Path(ellipseIn: CGRect(x: hx,     y: hy - 1, width: 3, height: 3)), with: .color(ac))
            ctx.fill(Path(ellipseIn: CGRect(x: hx + 6, y: hy - 1, width: 3, height: 3)), with: .color(ac))
        case .hamster:
            ctx.fill(Path(ellipseIn: CGRect(x: hx + 1, y: hy,     width: 2.5, height: 2.5)), with: .color(ac))
            ctx.fill(Path(ellipseIn: CGRect(x: hx + 5, y: hy,     width: 2.5, height: 2.5)), with: .color(ac))
        default: break
        }
        // Eye
        ctx.fill(Path(ellipseIn: CGRect(x: hx + 1.5, y: hy + 2, width: 2, height: 2)), with: .color(.black))
        // Nose
        ctx.fill(Path(ellipseIn: CGRect(x: hx + 1, y: hy + 5, width: 2.5, height: 1.5)),
                 with: .color(species == .panda ? .black : Color(red:0.9, green:0.5, blue:0.55)))
    }

    private func drawTriEar(_ ctx: GraphicsContext, at pt: CGPoint, color: Color, accent: Color) {
        var p = Path()
        p.move(to: CGPoint(x: pt.x, y: pt.y))
        p.addLine(to: CGPoint(x: pt.x + 2.5, y: pt.y - 4))
        p.addLine(to: CGPoint(x: pt.x + 5, y: pt.y))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
        // Inner
        var p2 = Path()
        p2.move(to: CGPoint(x: pt.x + 1, y: pt.y - 0.5))
        p2.addLine(to: CGPoint(x: pt.x + 2.5, y: pt.y - 3))
        p2.addLine(to: CGPoint(x: pt.x + 4, y: pt.y - 0.5))
        p2.closeSubpath()
        ctx.fill(p2, with: .color(accent))
    }

    // MARK: - Bunny (hops)
    private func drawBunny(ctx: GraphicsContext, cx: CGFloat, ground: CGFloat) {
        let bc = species.bodyColor
        let ac = species.accentColor
        let jumpY: CGFloat = jumping ? -7 : 0
        let squash: CGFloat = jumping ? 1.2 : (idle ? 1.0 : 0.9)
        let stretch: CGFloat = jumping ? 0.85 : 1.0

        let bodyY = ground - 8 + jumpY

        // Hind legs (big, behind body)
        let legSpread: CGFloat = jumping ? 8 : 3
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 3, y: bodyY + 2, width: 6, height: legSpread)), with: .color(ac))
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 4, y: bodyY + 2, width: 3, height: 4)), with: .color(bc))

        // Body
        let bodyRect = CGRect(x: cx - 5, y: bodyY - 3,
                               width: CGFloat(12) * squash, height: CGFloat(8) * stretch)
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(bc))

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 8, y: bodyY - 10, width: 8, height: 8)), with: .color(bc))

        // Long ears
        let earWobble: CGFloat = jumping ? -3 : (idle ? 0 : CGFloat(sin(phase * .pi * 2)) * 2)
        drawBunnyEar(ctx, at: CGPoint(x: cx - 6, y: bodyY - 10), wobble: earWobble, bc: bc, ac: ac)
        drawBunnyEar(ctx, at: CGPoint(x: cx - 3, y: bodyY - 10), wobble: earWobble * 0.7, bc: bc, ac: ac)

        // Eye + nose
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 8, y: bodyY - 7, width: 2, height: 2)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 8.5, y: bodyY - 5, width: 2, height: 1.5)),
                 with: .color(Color(red:1,green:0.6,blue:0.7)))

        // Shadow when jumping
        if jumping {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: ground - 2, width: 10, height: 3)),
                     with: .color(.black.opacity(0.15)))
        }
    }

    private func drawBunnyEar(_ ctx: GraphicsContext, at pt: CGPoint, wobble: CGFloat, bc: Color, ac: Color) {
        var p = Path()
        p.move(to: CGPoint(x: pt.x, y: pt.y))
        p.addQuadCurve(to: CGPoint(x: pt.x + wobble, y: pt.y - 8),
                       control: CGPoint(x: pt.x - 1, y: pt.y - 4))
        ctx.stroke(p, with: .color(bc), lineWidth: 3)
        var p2 = Path()
        p2.move(to: CGPoint(x: pt.x, y: pt.y))
        p2.addQuadCurve(to: CGPoint(x: pt.x + wobble, y: pt.y - 7),
                        control: CGPoint(x: pt.x - 0.5, y: pt.y - 3.5))
        ctx.stroke(p2, with: .color(ac), lineWidth: 1.5)
    }

    // MARK: - Frog (hops)
    private func drawFrog(ctx: GraphicsContext, cx: CGFloat, ground: CGFloat) {
        let bc = species.bodyColor
        let ac = species.accentColor
        let jumpY: CGFloat = jumping ? -8 : 0
        let squash: CGFloat = jumping ? 0.8 : 1.15

        let bodyY = ground - 7 + jumpY

        // Back legs
        if jumping {
            // Extended jump legs
            ctx.stroke(makeLine(from: CGPoint(x: cx + 2, y: bodyY + 3),
                                to: CGPoint(x: cx + 9, y: bodyY + 5)),
                       with: .color(ac), lineWidth: 3)
            ctx.stroke(makeLine(from: CGPoint(x: cx - 2, y: bodyY + 3),
                                to: CGPoint(x: cx - 9, y: bodyY + 5)),
                       with: .color(ac), lineWidth: 3)
        } else {
            // Crouched legs
            ctx.fill(Path(ellipseIn: CGRect(x: cx + 3, y: bodyY + 1, width: 5, height: 3)), with: .color(ac))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 8, y: bodyY + 1, width: 5, height: 3)), with: .color(ac))
        }

        // Body (flattened oval)
        let bodyRect = CGRect(x: cx - 7, y: bodyY - 3,
                               width: 14, height: CGFloat(8) * squash)
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(bc))

        // Head (merged with body)
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: bodyY - 7, width: 10, height: 7)), with: .color(bc))

        // Eyes (bulging)
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: bodyY - 9, width: 4, height: 4)), with: .color(bc))
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 1, y: bodyY - 9, width: 4, height: 4)), with: .color(bc))
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 4, y: bodyY - 8.5, width: 2.5, height: 2.5)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 2, y: bodyY - 8.5, width: 2.5, height: 2.5)), with: .color(.black))
        // Eye highlights
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 3.5, y: bodyY - 8.5, width: 1, height: 1)), with: .color(.white.opacity(0.8)))
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 2.5, y: bodyY - 8.5, width: 1, height: 1)), with: .color(.white.opacity(0.8)))

        // Smile
        var smile = Path()
        smile.move(to: CGPoint(x: cx - 3, y: bodyY - 3))
        smile.addQuadCurve(to: CGPoint(x: cx + 3, y: bodyY - 3),
                           control: CGPoint(x: cx, y: bodyY - 1))
        ctx.stroke(smile, with: .color(ac), lineWidth: 1)

        if jumping {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: ground - 2, width: 10, height: 3)),
                     with: .color(.black.opacity(0.15)))
        }
    }

    // MARK: - Duck
    private func drawDuck(ctx: GraphicsContext, cx: CGFloat, ground: CGFloat) {
        let bc = species.bodyColor
        let ac = species.accentColor

        // Waddle: side-to-side tilt
        let tilt = idle ? 0.0 : sin(phase * .pi * 2) * 8.0
        let legL = idle ? 0.0 : max(0, sin(phase * .pi * 2))
        let legR = idle ? 0.0 : max(0, -sin(phase * .pi * 2))

        let bodyY = ground - 9

        // Legs/feet (orange)
        let footColor = Color(red:1.0, green:0.6, blue:0.1)
        // Left leg
        ctx.stroke(makeLine(from: CGPoint(x: cx - 2, y: bodyY + 4),
                            to: CGPoint(x: cx - 3, y: ground - CGFloat(legL) * 3)),
                   with: .color(footColor), lineWidth: 2)
        // Right leg
        ctx.stroke(makeLine(from: CGPoint(x: cx + 2, y: bodyY + 4),
                            to: CGPoint(x: cx + 3, y: ground - CGFloat(legR) * 3)),
                   with: .color(footColor), lineWidth: 2)
        // Feet
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: ground - 2, width: 4, height: 2)), with: .color(footColor))
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 2, y: ground - 2, width: 4, height: 2)), with: .color(footColor))

        // Body (round)
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 6, y: bodyY - 2, width: 12, height: 9)), with: .color(bc))

        // Wing suggestion
        var wing = Path()
        wing.move(to: CGPoint(x: cx, y: bodyY))
        wing.addQuadCurve(to: CGPoint(x: cx + 5, y: bodyY + 3),
                          control: CGPoint(x: cx + 3, y: bodyY - 1))
        ctx.stroke(wing, with: .color(Color(red:0.9, green:0.75, blue:0.1)), lineWidth: 2)

        // Head
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 8, y: bodyY - 7, width: 7, height: 7)), with: .color(bc))

        // Beak
        var beak = Path()
        beak.move(to: CGPoint(x: cx - 9, y: bodyY - 4))
        beak.addLine(to: CGPoint(x: cx - 13, y: bodyY - 3))
        beak.addLine(to: CGPoint(x: cx - 9, y: bodyY - 2))
        beak.closeSubpath()
        ctx.fill(beak, with: .color(ac))

        // Eye
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 8, y: bodyY - 6, width: 2.5, height: 2.5)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 7.5, y: bodyY - 5.5, width: 1, height: 1)), with: .color(.white.opacity(0.8)))
    }

    private func makeLine(from a: CGPoint, to b: CGPoint) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }
}

// MARK: - PetView (full-width toolbar widget)
struct PetView: View {
    @ObservedObject private var s = SettingsStore.shared

    @State private var posX:     CGFloat = -40
    @State private var phase:    Double  = 0     // 0..1 walk cycle
    @State private var flipped:  Bool    = false
    @State private var jumping:  Bool    = false
    @State private var idle:     Bool    = false
    @State private var screenW:  CGFloat = UIScreen.main.bounds.width

    private var species: PetSpecies {
        PetSpecies(rawValue: s.petType) ?? .cat
    }

    private let fps: Double = 30

    var body: some View {
        if s.showPet {
            GeometryReader { geo in
                PetSprite(species: species, phase: phase,
                          flipped: flipped, jumping: jumping, idle: idle)
                    .position(x: posX, y: geo.size.height * 0.55)
                    .onAppear {
                        screenW = geo.size.width
                        startWalking()
                    }
                    .onChange(of: s.petType) { _, _ in
                        stopMotion()
                        posX = -40; flipped = false
                        startWalking()
                    }
            }
            .frame(height: 30)
            .clipped()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Motion
    private var motionTimer: Timer? { nil }
    @State private var _phaseTimer: Timer? = nil
    @State private var _posTimer:   Timer? = nil
    @State private var _stateTimer: Timer? = nil

    private func stopMotion() {
        _phaseTimer?.invalidate(); _phaseTimer = nil
        _posTimer?.invalidate();   _posTimer   = nil
        _stateTimer?.invalidate(); _stateTimer = nil
    }

    private func startWalking() {
        stopMotion()
        idle = false
        walkForward()
    }

    private func walkForward() {
        flipped = false
        moveAcross(direction: 1) {
            decideAtEdge()
        }
    }

    private func walkBack() {
        flipped = true
        moveAcross(direction: -1) {
            decideAtEdge()
        }
    }

    private func moveAcross(direction: CGFloat, completion: @escaping () -> Void) {
        let sp = CGFloat(species.speed)
        let hops = species.hops
        let interval = 1.0 / fps
        // Phase speed: one full cycle per ~0.5 sec
        let phaseStep = interval / 0.45

        _phaseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            guard s.showPet else { t.invalidate(); return }

            // Position
            posX += direction * sp * interval

            // Phase
            let oldPhase = phase
            phase = (phase + phaseStep).truncatingRemainder(dividingBy: 1.0)

            // Hop logic for bunny/frog
            if hops {
                // Jump at phase 0.1..0.5, land at 0.5..1.0
                let wasInFirstHalf = oldPhase < 0.5
                let nowInFirstHalf = phase < 0.5
                if wasInFirstHalf != nowInFirstHalf {
                    // Landed
                    withAnimation(.easeIn(duration: 0.05)) { jumping = false }
                } else if phase < 0.15 && oldPhase > 0.85 {
                    // Launched
                    withAnimation(.easeOut(duration: 0.12)) { jumping = true }
                }
            }

            // Check edge
            let reached = direction > 0 ? posX > screenW + 40 : posX < -40
            if reached {
                t.invalidate()
                _phaseTimer = nil
                jumping = false
                completion()
            }
        }
    }

    private func decideAtEdge() {
        let roll = Int.random(in: 0...2)
        if roll == 0 {
            // Idle pause
            idle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.8...2.5)) {
                guard s.showPet else { return }
                idle = false
                if flipped { walkForward() } else { walkBack() }
            }
        } else {
            if flipped { walkForward() } else { walkBack() }
        }
    }
}

// MARK: - allPets for settings grid
let allPets: [PetSpecies] = PetSpecies.allCases
