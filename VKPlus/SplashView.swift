import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var logoScale:    CGFloat = 0.3
    @State private var logoOpacity:  Double  = 0.0
    @State private var logoGlow:     CGFloat = 0.0
    @State private var ring1Scale:   CGFloat = 0.5
    @State private var ring1Opacity: Double  = 0.0
    @State private var ring2Scale:   CGFloat = 0.5
    @State private var ring2Opacity: Double  = 0.0
    @State private var ring3Scale:   CGFloat = 0.5
    @State private var ring3Opacity: Double  = 0.0
    @State private var titleOpacity:    Double  = 0.0
    @State private var titleOffset:     CGFloat = 24
    @State private var subtitleOpacity: Double  = 0.0
    @State private var dotPhase: Bool = false

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            RadialGradient(
                colors: [Color.cyberBlue.opacity(0.10), Color.clear],
                center: .center, startRadius: 0, endRadius: 280
            )
            .ignoresSafeArea()
            .opacity(logoOpacity)

            VStack(spacing: 0) {
                Spacer()

                // Rings + Logo
                ZStack {
                    Circle()
                        .stroke(Color.cyberBlue.opacity(ring3Opacity * 0.2),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 10]))
                        .frame(width: 280, height: 280)
                        .scaleEffect(ring3Scale)

                    Circle()
                        .stroke(Color.cyberBlue.opacity(ring2Opacity * 0.35),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 7]))
                        .frame(width: 200, height: 200)
                        .scaleEffect(ring2Scale)

                    Circle()
                        .stroke(Color.cyberBlue.opacity(ring1Opacity * 0.5), lineWidth: 1.5)
                        .frame(width: 134, height: 134)
                        .scaleEffect(ring1Scale)

                    // Logo with uploaded VK+ icon
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.cyberBlue.opacity(0.18), Color.background],
                                center: .center, startRadius: 0, endRadius: 52
                            ))
                            .frame(width: 104, height: 104)

                        Circle()
                            .stroke(LinearGradient.cyberGrad, lineWidth: 2)
                            .frame(width: 104, height: 104)

                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: Color.cyberBlue.opacity(logoGlow), radius: 28)
                }

                Spacer().frame(height: 38)

                VStack(spacing: 6) {
                    Text("VK+")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient.cyberGrad)
                        .shadow(color: Color.cyberBlue.opacity(0.45), radius: 14)

                    Text("Enhanced VKontakte")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.onSurfaceMut)
                        .opacity(subtitleOpacity)

                    Text("by SelfCode")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.onSurfaceMut.opacity(0.5))
                        .opacity(subtitleOpacity)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)

                Spacer()

                // Pulse dots
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.cyberBlue)
                            .frame(width: 5, height: 5)
                            .opacity(subtitleOpacity)
                            .scaleEffect(dotPhase && i == 1 ? 1.4 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                                value: dotPhase
                            )
                    }
                }
                .padding(.bottom, 56)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.62).delay(0.15)) {
            logoScale = 1.0; logoOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 1.0).delay(0.4)) {
            logoGlow = 0.55
        }
        withAnimation(.easeOut(duration: 0.75).delay(0.45)) {
            ring1Scale = 1.0; ring1Opacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.90).delay(0.60)) {
            ring2Scale = 1.0; ring2Opacity = 1.0
        }
        withAnimation(.easeOut(duration: 1.10).delay(0.75)) {
            ring3Scale = 1.0; ring3Opacity = 1.0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.95)) {
            titleOpacity = 1.0; titleOffset = 0
        }
        withAnimation(.easeIn(duration: 0.45).delay(1.2)) {
            subtitleOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { dotPhase = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { onFinished() }
    }
}
