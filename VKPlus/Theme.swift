import SwiftUI

// MARK: - Colors
extension Color {
    static let cyberBlue    = Color(r: 0x00, g: 0xB4, b: 0xFF)
    static let cyberAccent  = Color(r: 0x00, g: 0xEE, b: 0xFF)
    static let background   = Color(r: 0x05, g: 0x08, b: 0x10)
    static let surface      = Color(r: 0x0D, g: 0x13, b: 0x20)
    static let surfaceVar   = Color(r: 0x11, g: 0x18, b: 0x27)
    static let onSurface    = Color(r: 0xE8, g: 0xEE, b: 0xF4)
    static let onSurfaceMut = Color(r: 0x6B, g: 0x7A, b: 0x8D)
    static let divider      = Color(r: 0x1E, g: 0x2A, b: 0x3A)
    static let errorRed     = Color(r: 0xFF, g: 0x44, b: 0x66)

    init(r: Int, g: Int, b: Int) {
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
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
