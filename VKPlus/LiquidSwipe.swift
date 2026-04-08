import SwiftUI

// MARK: - Liquid Wave Mask
// Реализация liquid swipe анимации (аналог Cuberto/liquid-swipe)
// Использует кубические кривые Безье для создания "жидкой" волны
struct LiquidWaveMask: View {
    /// 0 → 1: прогресс анимации
    let progress: CGFloat
    /// -1 = свайп влево (открываем справа), 1 = свайп вправо (открываем слева)
    let direction: Int
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            let p = min(max(progress, 0), 1)

            // Параметры волны
            let waveX: CGFloat = direction < 0
                ? w - p * (w + 80)      // слева направо (свайп влево → новый экран справа)
                : p * (w + 80) - 80     // справа налево

            let bulge: CGFloat = 80 * sin(p * .pi)  // пузырь максимален в середине анимации
            let vertR: CGFloat = h * 0.4 + 60 * sin(p * .pi)

            var path = Path()

            if direction < 0 {
                // Новый экран появляется справа
                path.move(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: waveX + bulge, y: 0))
                // верхняя кривая
                path.addCurve(
                    to: CGPoint(x: waveX, y: h/2 - vertR),
                    control1: CGPoint(x: waveX + bulge, y: h/2 - vertR * 0.7),
                    control2: CGPoint(x: waveX, y: h/2 - vertR * 0.6)
                )
                // центральный пузырь
                path.addCurve(
                    to: CGPoint(x: waveX, y: h/2 + vertR),
                    control1: CGPoint(x: waveX - bulge * 1.4, y: h/2 - vertR * 0.2),
                    control2: CGPoint(x: waveX - bulge * 1.4, y: h/2 + vertR * 0.2)
                )
                // нижняя кривая
                path.addCurve(
                    to: CGPoint(x: waveX + bulge, y: h),
                    control1: CGPoint(x: waveX, y: h/2 + vertR * 0.6),
                    control2: CGPoint(x: waveX + bulge, y: h/2 + vertR * 0.7)
                )
                path.addLine(to: CGPoint(x: w, y: h))
            } else {
                // Новый экран появляется слева
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: waveX - bulge, y: 0))
                path.addCurve(
                    to: CGPoint(x: waveX, y: h/2 - vertR),
                    control1: CGPoint(x: waveX - bulge, y: h/2 - vertR * 0.7),
                    control2: CGPoint(x: waveX, y: h/2 - vertR * 0.6)
                )
                path.addCurve(
                    to: CGPoint(x: waveX, y: h/2 + vertR),
                    control1: CGPoint(x: waveX + bulge * 1.4, y: h/2 - vertR * 0.2),
                    control2: CGPoint(x: waveX + bulge * 1.4, y: h/2 + vertR * 0.2)
                )
                path.addCurve(
                    to: CGPoint(x: waveX - bulge, y: h),
                    control1: CGPoint(x: waveX, y: h/2 + vertR * 0.6),
                    control2: CGPoint(x: waveX - bulge, y: h/2 + vertR * 0.7)
                )
                path.addLine(to: CGPoint(x: 0, y: h))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(.black))
        }
        .frame(width: size.width, height: size.height)
    }
}
