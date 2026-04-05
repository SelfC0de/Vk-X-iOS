import SwiftUI

struct AboutView: View {
    @State private var visible    = false
    @State private var glowPhase  = false
    @State private var pulsePhase = false

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

                        Text("SC")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cyberBlue)
                            .tracking(2)
                    }
                    .opacity(visible ? 1 : 0)
                    .scaleEffect(visible ? 1 : 0.6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.0), value: visible)

                    Spacer().frame(height: 20)

                    // ── Name ────────────────────────────────────────────────
                    VStack(spacing: 4) {
                        Text("SelfCode")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.onSurface)
                            .tracking(1)
                        Text("selfcode_dev")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.onSurfaceMut)
                    }
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.2), value: visible)

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
            // Reset and replay animation every time tab is opened
            visible = false
            glowPhase = false
            pulsePhase = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                visible = true
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    glowPhase = true
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulsePhase = true
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
