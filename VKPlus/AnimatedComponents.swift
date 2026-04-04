import SwiftUI

// MARK: - Animated Like Button
struct AnimatedLikeButton: View {
    let isLiked: Bool
    let count:   Int
    let onTap:   () -> Void

    @State private var scale:    CGFloat = 1.0
    @State private var particles: [LikeParticle] = []
    @State private var prevLiked = false

    var body: some View {
        Button(action: {
            onTap()
            if !isLiked { triggerParticles() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 4) {
                ZStack {
                    // Burst particles
                    ForEach(particles) { p in
                        Circle()
                            .fill(Color.errorRed)
                            .frame(width: p.size, height: p.size)
                            .offset(x: p.x, y: p.y)
                            .opacity(p.opacity)
                    }
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundStyle(isLiked ? Color.errorRed : Color.onSurfaceMut)
                        .scaleEffect(scale)
                }
                .frame(width: 24, height: 24)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(isLiked ? Color.errorRed : Color.onSurfaceMut)
                        .contentTransition(.numericText())
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isLiked) { old, new in
            if new && !old {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { scale = 1.4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { scale = 1.0 }
                }
            }
        }
    }

    private func triggerParticles() {
        particles = (0..<6).map { i in
            let angle = Double(i) * 60.0 * .pi / 180.0
            return LikeParticle(
                id: UUID(), x: 0, y: 0,
                tx: CGFloat(cos(angle) * 18),
                ty: CGFloat(sin(angle) * 18),
                size: CGFloat.random(in: 3...5),
                opacity: 1
            )
        }
        withAnimation(.easeOut(duration: 0.5)) {
            for i in particles.indices {
                particles[i].x = particles[i].tx
                particles[i].y = particles[i].ty
                particles[i].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { particles = [] }
    }
}

struct LikeParticle: Identifiable {
    let id: UUID
    var x: CGFloat; var y: CGFloat
    var tx: CGFloat; var ty: CGFloat
    var size: CGFloat; var opacity: Double
}

// MARK: - Pulsing Online Dot
struct PulsingDot: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(pulse ? 0 : 0.4))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.8 : 1.0)
                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Shimmer loading skeleton
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.surfaceVar,
                            Color.surfaceVar.opacity(0.4),
                            Color.surfaceVar,
                        ],
                        startPoint: .init(x: phase, y: 0.5),
                        endPoint:   .init(x: phase + 1, y: 0.5)
                    )
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}

// MARK: - Cyber Button
struct CyberButton: View {
    let title: String
    let icon:  String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = false }
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.background)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    Color.cyberBlue
                    // Shimmer on press
                    if pressed {
                        Color.white.opacity(0.15)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyberBlue.opacity(0.6), lineWidth: 0.5)
            )
            .scaleEffect(pressed ? 0.95 : 1.0)
            .shadow(color: Color.cyberBlue.opacity(pressed ? 0.5 : 0.25), radius: pressed ? 8 : 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated Counter
struct AnimatedCounter: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.onSurface)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: value)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.onSurfaceMut)
        }
    }
}

// MARK: - Scan line effect (for cyber themed screens)
struct ScanLineEffect: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.cyberBlue.opacity(0.04), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 60)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        offset = geo.size.height + 60
                    }
                }
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

// MARK: - Typing indicator (for chat)
struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.onSurfaceMut)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.4 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.surfaceVar)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16))
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
