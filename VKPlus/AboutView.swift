import SwiftUI

// MARK: - SelfCode Logo Canvas
// Replicates the SelfCode brand mark: "Self" white + "Code" green-yellow gradient
struct SelfCodeLogoView: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            // "Self" — white
            let selfAttrs = AttributedString("Self", attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: h * 0.85, weight: .light),
                .foregroundColor: UIColor.white
            ]))
            // "Code" — lime green
            let codeAttrs = AttributedString("Code", attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: h * 0.85, weight: .light),
                .foregroundColor: UIColor(red: 0.49, green: 0.73, blue: 0.09, alpha: 1)
            ]))
            // Measure Self width
            let selfResolved = ctx.resolve(Text(selfAttrs))
            let codeResolved = ctx.resolve(Text(codeAttrs))
            let selfSize = selfResolved.measure(in: sz)
            let totalWidth = selfSize.width + codeResolved.measure(in: sz).width
            let startX = (w - totalWidth) / 2
            let baseY = (h - selfSize.height) / 2
            ctx.draw(selfResolved, at: CGPoint(x: startX, y: baseY), anchor: .topLeading)
            ctx.draw(codeResolved, at: CGPoint(x: startX + selfSize.width, y: baseY), anchor: .topLeading)
        }
    }
}

struct AboutView: View {
    @State private var visible      = false
    @State private var logoVisible   = false
    @State private var nameVisible   = false
    @State private var subVisible    = false
    @State private var glowPhase     = false
    @State private var pulsePhase    = false
    // Typewriter states
    @State private var selfCodeText  = ""     // typewritten "SelfCode"
    @State private var subText       = ""     // typewritten "selfcode_dev"
    @State private var cursorVisible = true   // blinking cursor

    private let links: [(icon: String, label: String, sub: String, color: Color, url: String)] = [
        ("person.fill",         "ВКонтакте",   "vk.com/selfcode_dev",         Color(r:0x4C,g:0x75,b:0xA3), "https://vk.com/selfcode_dev"),
        ("paperplane.fill",     "Telegram",    "t.me/selfcode.dev",            Color(r:0x2A,g:0xAB,b:0xEE), "https://t.me/selfcode.dev"),
        ("chevron.left.forwardslash.chevron.right", "GitHub", "github.com/SelfC0de", Color(r:0xE8,g:0xE8,b:0xE8), "https://github.com/SelfC0de"),
        ("doc.text.fill",       "GitHub Gist", "gist.github.com/SelfC0de",    Color(r:0x8B,g:0x94,b:0x9E), "https://gist.github.com/SelfC0de"),
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(r:0x06,g:0x0A,b:0x14), Color.background],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animated glow blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyberBlue.opacity(glowPhase ? 0.30 : 0.15), Color.clear],
                        center: .center, startRadius: 0, endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(pulsePhase ? 1.03 : 0.97)
                .blur(radius: 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: 40)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)

                    // ── Avatar ──────────────────────────────────────────────
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.cyberBlue.opacity(0.25), Color.clear],
                                center: .center, startRadius: 0, endRadius: 55
                            ))
                            .frame(width: 110, height: 110)
                            .scaleEffect(pulsePhase ? 1.03 : 0.97)

                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(r:0x0D,g:0x15,b:0x20))
                            .frame(width: 90, height: 90)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(LinearGradient.cyberGrad, lineWidth: 1.5)
                            )

                        SelfCodeLogoView()
                            .frame(width: 56, height: 28)
                    }
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.5)
                    .rotationEffect(.degrees(logoVisible ? 0 : -15))
                    .animation(.spring(response: 0.7, dampingFraction: 0.60), value: logoVisible)

                    Spacer().frame(height: 20)

                    // ── Name (Typewriter) ────────────────────────────────
                    VStack(spacing: 6) {
                        // "SelfCode" typed out letter by letter
                        HStack(spacing: 0) {
                            // "Self" white portion
                            Text(String(selfCodeText.prefix(min(selfCodeText.count, 4))))
                                .font(.system(size: 26, weight: .light, design: .default))
                                .foregroundStyle(Color.white)
                                .tracking(0.5)
                            // "Code" green portion
                            Text(selfCodeText.count > 4 ? String(selfCodeText.dropFirst(4)) : "")
                                .font(.system(size: 26, weight: .light, design: .default))
                                .foregroundStyle(Color(r:0x7D,g:0xBB,b:0x17))
                                .tracking(0.5)
                            // Blinking cursor after SelfCode, before sub starts
                            if selfCodeText.count < 8 || subText.isEmpty {
                                Text("|")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(Color.cyberBlue)
                                    .opacity(cursorVisible ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorVisible)
                            }
                        }
                        .frame(height: 32)

                        // "selfcode_dev" typed out after SelfCode finishes
                        HStack(spacing: 0) {
                            Text(subText)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.onSurfaceMut)
                            // Cursor at end of sub when typing
                            if !subText.isEmpty && subText.count < 12 {
                                Text("|")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Color.cyberBlue.opacity(0.8))
                                    .opacity(cursorVisible ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorVisible)
                            }
                        }
                        .opacity(subText.isEmpty ? 0 : 1)
                        .frame(height: 18)
                    }

                    Spacer().frame(height: 32)

                    // ── Links ───────────────────────────────────────────────
                    VStack(spacing: 10) {
                        // Section label
                        Text("ССЫЛКИ И КОНТАКТЫ")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.onSurfaceMut)
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(links.indices, id: \.self) { i in
                            LinkCard(
                                icon:  links[i].icon,
                                label: links[i].label,
                                sub:   links[i].sub,
                                color: links[i].color,
                                url:   links[i].url
                            )
                            .opacity(visible ? 1 : 0)
                            .offset(y: visible ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75)
                                    .delay(0.4 + Double(i) * 0.08),
                                value: visible
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)

                    // ── Version ─────────────────────────────────────────────
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image("AppLogo")
                                .resizable().scaledToFit()
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text("VK+ for iOS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.onSurfaceMut)
                        }
                        Text("Made with ❤️ by SelfCode · 2026")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.onSurfaceMut.opacity(0.4))
                            .tracking(0.5)
                    }
                    .opacity(visible ? 1 : 0)
                    .animation(.easeIn(duration: 0.5).delay(0.8), value: visible)

                    Spacer().frame(height: 32)
                }
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                ZStack(alignment: .leading) {
                    GarlandView()
                        .frame(width: UIScreen.main.bounds.width)
                        .allowsHitTesting(false)
                    PetView()
                        .frame(width: UIScreen.main.bounds.width)
                        .allowsHitTesting(false)
                    ClockView()
                        .padding(.leading, 6)
                }
            } }
        .onAppear {
            // Reset all
            visible = false; logoVisible = false
            selfCodeText = ""; subText = ""
            glowPhase = false; pulsePhase = false

            // Start ambient animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                visible = true
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { glowPhase = true }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulsePhase = true }
            }

            // Step 1: Logo appears (0.1s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                logoVisible = true
                cursorVisible = true
            }

            // Step 2: Type "SelfCode" (starts 0.55s, 55ms per char)
            let selfFull = "SelfCode"
            for (i, ch) in selfFull.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(i) * 0.055) {
                    selfCodeText += String(ch)
                }
            }

            // Step 3: Pause, then type "selfcode_dev" (starts after SelfCode + 0.2s)
            let subFull = "selfcode_dev"
            let subStart = 0.55 + Double(selfFull.count) * 0.055 + 0.20
            for (i, ch) in subFull.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + subStart + Double(i) * 0.045) {
                    subText += String(ch)
                }
            }
        }
    }
}

private struct LinkCard: View {
    let icon: String; let label: String; let sub: String
    let color: Color; let url: String

    @State private var borderPhase = false
    @State private var pressed     = false

    var body: some View {
        Button {
            guard let u = URL(string: url) else { return }
            UIApplication.shared.open(u)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.onSurface)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.onSurfaceMut.opacity(0.5))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.08), Color.surfaceVar],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(borderPhase ? 0.5 : 0.2), lineWidth: 0.5)
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double.random(in: 0...1))) {
                borderPhase = true
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in withAnimation(.easeOut(duration: 0.1)) { pressed = true } }
            .onEnded   { _ in withAnimation(.spring())               { pressed = false } }
        )
    }
}

// MARK: - Inline version for SettingsView tab
struct AboutInlineView: View {
    var body: some View { AboutView() }
}
