import SwiftUI

// MARK: - Adaptive Colors via UIColor dynamicProvider
extension Color {
    static let cyberBlue    = Color(r: 0x00, g: 0xB4, b: 0xFF)
    static let cyberAccent  = Color(r: 0x00, g: 0xEE, b: 0xFF)
    static let errorRed     = Color(r: 0xFF, g: 0x44, b: 0x66)

    static let background   = Color(UIColor.vkBackground)
    static let surface      = Color(UIColor.vkSurface)
    static let surfaceVar   = Color(UIColor.vkSurfaceVar)
    static let onSurface    = Color(UIColor.vkOnSurface)
    static let onSurfaceMut = Color(UIColor.vkOnSurfaceMut)
    static let divider      = Color(UIColor.vkDivider)

    init(r: Int, g: Int, b: Int) {
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

extension UIColor {
    static let vkBackground  = UIColor { t in t.userInterfaceStyle == .dark ? .init(r:0x05,g:0x08,b:0x10) : .init(r:0xF2,g:0xF4,b:0xF7) }
    static let vkSurface     = UIColor { t in t.userInterfaceStyle == .dark ? .init(r:0x0D,g:0x13,b:0x20) : .init(r:0xFF,g:0xFF,b:0xFF) }
    static let vkSurfaceVar  = UIColor { t in t.userInterfaceStyle == .dark ? .init(r:0x11,g:0x18,b:0x27) : .init(r:0xE8,g:0xEC,b:0xF2) }
    static let vkOnSurface   = UIColor { t in t.userInterfaceStyle == .dark ? .init(r:0xE8,g:0xEE,b:0xF4) : .init(r:0x0D,g:0x13,b:0x20) }
    static let vkOnSurfaceMut = UIColor { t in t.userInterfaceStyle == .dark ? .init(r:0x6B,g:0x7A,b:0x8D) : .init(r:0x5A,g:0x66,b:0x78) }
    static let vkDivider     = UIColor { t in t.userInterfaceStyle == .dark ? .init(r:0x1E,g:0x2A,b:0x3A) : .init(r:0xD0,g:0xD6,b:0xDF) }

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
