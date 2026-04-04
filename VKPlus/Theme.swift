import SwiftUI

// MARK: - Adaptive Colors
// Colors respond to colorScheme — dark/light/system works automatically
extension Color {
    // Accent — same in both themes
    static let cyberBlue   = Color(r: 0x00, g: 0xB4, b: 0xFF)
    static let cyberAccent = Color(r: 0x00, g: 0xEE, b: 0xFF)
    static let errorRed    = Color(r: 0xFF, g: 0x44, b: 0x66)

    // Adaptive backgrounds
    static let background  = Color(adaptive: dark: (0x05, 0x08, 0x10), light: (0xF2, 0xF4, 0xF7))
    static let surface     = Color(adaptive: dark: (0x0D, 0x13, 0x20), light: (0xFF, 0xFF, 0xFF))
    static let surfaceVar  = Color(adaptive: dark: (0x11, 0x18, 0x27), light: (0xE8, 0xEC, 0xF2))
    static let onSurface   = Color(adaptive: dark: (0xE8, 0xEE, 0xF4), light: (0x0D, 0x13, 0x20))
    static let onSurfaceMut = Color(adaptive: dark: (0x6B, 0x7A, 0x8D), light: (0x5A, 0x66, 0x78))
    static let divider     = Color(adaptive: dark: (0x1E, 0x2A, 0x3A), light: (0xD0, 0xD6, 0xDF))

    // Hex init
    init(r: Int, g: Int, b: Int) {
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }

    // Adaptive UIColor-backed init
    init(adaptive dark: (Int, Int, Int), light: (Int, Int, Int)) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(r: dark.0,  g: dark.1,  b: dark.2)
                : UIColor(r: light.0, g: light.1, b: light.2)
        })
    }
}

private extension UIColor {
    convenience init(r: Int, g: Int, b: Int) {
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

extension LinearGradient {
    static let cyberGrad = LinearGradient(
        colors: [.cyberBlue, .cyberAccent],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Card modifier
struct CyberCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.divider, lineWidth: 0.5))
    }
}

extension View {
    func cyberCard() -> some View { modifier(CyberCard()) }
}
