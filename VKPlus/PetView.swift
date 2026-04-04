import SwiftUI

// MARK: - Pet sprite data
struct PetSprite {
    let id: String
    let label: String
    // walk frames, idle frame, run frame
    let walkFrames: [String]
    let idleFrame:  String
    let speed: Double   // pts/sec walk
    let runSpeed: Double
    let size: CGFloat
    let bounceAmp: CGFloat  // vertical bounce amplitude
}

let allPets: [PetSprite] = [
    PetSprite(id:"cat",    label:"🐱 Кот",    walkFrames:["🐱","😺","🐱","😸"], idleFrame:"😻", speed:55, runSpeed:110, size:26, bounceAmp:3),
    PetSprite(id:"dog",    label:"🐶 Собака", walkFrames:["🐶","🐕","🐶","🐕"], idleFrame:"🐶", speed:65, runSpeed:130, size:26, bounceAmp:4),
    PetSprite(id:"bunny",  label:"🐰 Кролик", walkFrames:["🐰","🐇","🐰","🐇"], idleFrame:"🐰", speed:30, runSpeed:140, size:24, bounceAmp:8),
    PetSprite(id:"duck",   label:"🐥 Утёнок", walkFrames:["🐥","🐤","🐥","🐤"], idleFrame:"🐣", speed:40, runSpeed:70,  size:24, bounceAmp:2),
    PetSprite(id:"frog",   label:"🐸 Лягушка",walkFrames:["🐸","🐸","🐸","🐸"], idleFrame:"🐸", speed:20, runSpeed:80,  size:24, bounceAmp:10),
    PetSprite(id:"hamster",label:"🐹 Хомяк",  walkFrames:["🐹","🐹","🐹","🐹"], idleFrame:"🐹", speed:50, runSpeed:100, size:22, bounceAmp:2),
    PetSprite(id:"fox",    label:"🦊 Лиса",   walkFrames:["🦊","🦊","🦊","🦊"], idleFrame:"🦊", speed:60, runSpeed:120, size:26, bounceAmp:3),
    PetSprite(id:"panda",  label:"🐼 Панда",  walkFrames:["🐼","🐼","🐼","🐼"], idleFrame:"🐼", speed:30, runSpeed:60,  size:28, bounceAmp:2),
]

// MARK: - Movement state
private enum PetState { case walking, running, idle }

// MARK: - Pet View
struct PetView: View {
    @ObservedObject private var s = SettingsStore.shared

    @State private var posX:    CGFloat = -50
    @State private var posY:    CGFloat = 0
    @State private var frameIdx: Int    = 0
    @State private var flipped: Bool    = false
    @State private var petState: PetState = .walking
    @State private var rotation: Double = 0
    @State private var scale:    CGFloat = 1.0
    @State private var screenW:  CGFloat = UIScreen.main.bounds.width
    @State private var isIdle:   Bool   = false
    @State private var walkTimer: Timer? = nil
    @State private var stateTimer: Timer? = nil
    @State private var posTimer:   Timer? = nil
    @State private var tick: Int = 0

    private var pet: PetSprite {
        allPets.first { $0.id == s.petType } ?? allPets[0]
    }

    var body: some View {
        if s.showPet {
            GeometryReader { geo in
                ZStack {
                    // Shadow
                    Ellipse()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: pet.size * 0.8, height: 4)
                        .offset(y: pet.bounceAmp + 2)
                        .scaleEffect(x: 0.6 + 0.4 * (1 - abs(posY) / pet.bounceAmp), y: 1)
                        .blur(radius: 1.5)
                        .position(x: posX, y: geo.size.height * 0.85)

                    // Pet sprite
                    Text(currentFrame)
                        .font(.system(size: pet.size))
                        .scaleEffect(x: flipped ? -1 : 1, y: 1)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(isIdle ? 0 : rotation))
                        .position(x: posX, y: geo.size.height * 0.55 + posY)
                }
                .onAppear {
                    screenW = geo.size.width
                    posX = -50
                    startPet()
                }
                .onChange(of: s.petType) { _, _ in
                    stopTimers()
                    posX = -50
                    startPet()
                }
                .onChange(of: s.showPet) { _, show in
                    if !show { stopTimers() }
                    else { posX = -50; startPet() }
                }
            }
            .frame(height: 36)
            .clipped()
            .allowsHitTesting(false)
        }
    }

    private var currentFrame: String {
        if isIdle { return pet.idleFrame }
        return pet.walkFrames[frameIdx % pet.walkFrames.count]
    }

    private func stopTimers() {
        walkTimer?.invalidate(); walkTimer = nil
        stateTimer?.invalidate(); stateTimer = nil
        posTimer?.invalidate(); posTimer = nil
    }

    private func startPet() {
        stopTimers()
        tick = 0
        petState = .walking
        isIdle = false
        flipped = false

        // Frame ticker — fast for run, slower for walk
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
            guard s.showPet else { return }
            tick += 1
            frameIdx += 1
            // Body sway left/right
            let swayAmp: Double = petState == .running ? 6 : 3
            rotation = sin(Double(tick) * 0.6) * swayAmp
            // Bounce up/down
            let bounceFreq: Double = petState == .running ? 1.2 : 0.8
            posY = sin(Double(tick) * bounceFreq) * pet.bounceAmp
            // Squash & stretch
            let ss = 1.0 + sin(Double(tick) * bounceFreq) * 0.06
            scale = ss
        }

        // Position ticker — moves pet smoothly
        posTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            guard s.showPet else { return }
            guard !isIdle else { return }
            let spd = petState == .running ? pet.runSpeed : pet.speed
            let dt: CGFloat = 1.0/60.0
            posX += (flipped ? -1 : 1) * spd * dt

            // Reached edge — turn around or idle
            if !flipped && posX > screenW + 50 {
                decideAction(atEdge: true)
            } else if flipped && posX < -50 {
                decideAction(atEdge: true)
            }
        }
    }

    private func decideAction(atEdge: Bool) {
        guard !isIdle else { return }
        // Random: idle, turn, run
        let roll = Int.random(in: 0...3)
        if atEdge || roll == 0 {
            // Turn around
            withAnimation(.easeInOut(duration: 0.2)) { flipped.toggle() }
            // Sometimes run after turning
            if Int.random(in: 0...2) == 0 {
                petState = .running
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...2.5)) {
                    petState = .walking
                }
            }
        } else if roll == 1 && !atEdge {
            // Sit down briefly
            isIdle = true
            posY = 0; rotation = 0; scale = 1.1
            let idleDuration = Double.random(in: 0.8...2.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + idleDuration) {
                guard s.showPet else { return }
                isIdle = false
                // After idle, maybe run
                petState = Int.random(in: 0...2) == 0 ? .running : .walking
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...2.0)) {
                    petState = .walking
                }
            }
        }
    }
}
