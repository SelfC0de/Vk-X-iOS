import SwiftUI

// MARK: - Image Cache
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 300; cache.totalCostLimit = 60 * 1024 * 1024 }
    func get(_ url: String) -> UIImage? { cache.object(forKey: url as NSString) }
    func set(_ url: String, image: UIImage) { cache.setObject(image, forKey: url as NSString) }
}

// MARK: - Avatar Shape
enum AvatarShapeType: String {
    case circle = "circle"
    case nft    = "nft"
    case rhomb  = "rhomb"
}

// NFT hexagon path (rotated ~17°)
struct HexagonShape: Shape {
    var rotation: Double = 17
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let r  = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + rotation * .pi / 180
            let pt = CGPoint(x: cx + r * CGFloat(cos(angle)),
                             y: cy + r * CGFloat(sin(angle)))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

// Rhomb (diamond) shape
struct RhombShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX,    y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,    y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX,    y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX,    y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Avatar Shape Card (in VisualSettings)
struct AvatarShapeCard: View {
    @ObservedObject private var s = SettingsStore.shared
    private let shapes: [(id: String, label: String)] = [
        ("circle", "Circle"),
        ("nft",    "NFT"),
        ("rhomb",  "Rhomb"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Shape selector
            HStack(spacing: 12) {
                ForEach(shapes, id: \.id) { shape in
                    Button {
                        withAnimation(.spring(response: 0.3)) { s.avatarShape = shape.id }
                    } label: {
                        VStack(spacing: 6) {
                            ShapePreviewFixed(shape: shape.id, size: 52,
                                         colorHex: s.avatarColorHex,
                                         glow: s.avatarGlow,
                                         glowIntensity: s.avatarGlowIntensity)
                            Text(shape.label)
                                .font(.system(size: 11, weight: s.avatarShape == shape.id ? .semibold : .regular))
                                .foregroundStyle(s.avatarShape == shape.id ? Color.cyberBlue : Color.onSurfaceMut)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 4)
                        .background(s.avatarShape == shape.id ? Color.cyberBlue.opacity(0.10) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(s.avatarShape == shape.id ? Color.cyberBlue.opacity(0.5) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    if shape.id != "rhomb" { Spacer() }
                }
            }
            .padding(.horizontal, 14)

            Divider().background(Color.divider)

            // Color Avatar
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    SFAnimIcon(name: "paintpalette", color: Color(r:0x8B,g:0x5C,b:0xF6), size: 20, isOn: s.avatarColorHex != "auto")
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Color Avatar").foregroundStyle(Color.onSurface).font(.system(size: 14))
                        Text("Цвет обводки фигуры").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                    Spacer()
                    // Color swatch
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: s.avatarColorHex == "auto" ? "#00B4FF" : s.avatarColorHex) },
                        set: { s.avatarColorHex = $0.toHex() ?? "auto" }
                    ))
                    .labelsHidden().frame(width: 32, height: 32)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)

                Divider().background(Color.divider).padding(.leading, 48)

                // Glow toggle
                HStack(spacing: 12) {
                    SFAnimIcon(name: "sparkles", color: Color(r:0xFF,g:0xD7,b:0x00), size: 20, isOn: s.avatarGlow)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Glow").foregroundStyle(Color.onSurface).font(.system(size: 14))
                        Text("Свечение вокруг фигуры").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    }
                    Spacer()
                    Toggle("", isOn: $s.avatarGlow).tint(.cyberBlue).labelsHidden()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)

                // Glow intensity slider (shown when glow is on)
                if s.avatarGlow {
                    Divider().background(Color.divider).padding(.leading, 48)
                    HStack(spacing: 12) {
                        Image(systemName: "circle").font(.system(size: 10)).foregroundStyle(Color.onSurfaceMut)
                        Slider(value: $s.avatarGlowIntensity, in: 0.2...1.0)
                            .tint(Color.cyberBlue)
                        Image(systemName: "circle.fill").font(.system(size: 14)).foregroundStyle(Color.onSurfaceMut)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: s.avatarGlow)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shape preview for selector
private struct ShapePreviewFixed: View {
    let shape: String; let size: CGFloat
    let colorHex: String; let glow: Bool; let glowIntensity: Double

    private var accent: Color {
        colorHex == "auto" ? Color.cyberBlue : Color(hex: colorHex)
    }

    var body: some View {
        ZStack {
            if glow {
                avatarShape.fill(accent.opacity(glowIntensity * 0.45)).blur(radius: 10).scaleEffect(1.4)
            }
            avatarShape.fill(Color(red:0.10,green:0.13,blue:0.20))
            avatarShape.stroke(accent, lineWidth: 1.8)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.36))
                .foregroundStyle(accent.opacity(0.7))
        }
        .frame(width: size, height: size)
    }

    private var avatarShape: AnyShape {
        switch shape {
        case "nft":   return AnyShape(HexagonShape(rotation: 17))
        case "rhomb": return AnyShape(RhombShape())
        default:      return AnyShape(Circle())
        }
    }
}

// MARK: - Cached async image
struct CachedAsyncImage: View {
    let url: String; let size: CGFloat
    @State private var image: UIImage? = nil
    @State private var failed = false

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else if failed {
                placeholderFill
            } else {
                Color(red:0.12,green:0.14,blue:0.20)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) { await load() }
    }

    private var placeholderFill: some View {
        Color(red:0.12,green:0.14,blue:0.20)
            .overlay(Image(systemName: "person.fill")
                .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                .font(.system(size: size * 0.4)))
    }

    private func load() async {
        if let cached = ImageCache.shared.get(url) { image = cached; return }
        guard let u = URL(string: url) else { failed = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            if let img = UIImage(data: data) { ImageCache.shared.set(url, image: img); image = img }
            else { failed = true }
        } catch { failed = true }
    }
}

// MARK: - AvatarView (shape-aware)
struct AvatarView: View {
    let url:  String?
    let size: CGFloat
    var applyShape: Bool = true   // false = always circle (e.g. in chat list for other users)

    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        let shape = applyShape ? store.avatarShape : "circle"
        let accent = store.avatarColorHex == "auto" ? Color.cyberBlue : Color(hex: store.avatarColorHex)

        ZStack {
            // Glow
            if applyShape && store.avatarGlow {
                avatarClip(shape: shape)
                    .fill(accent.opacity(store.avatarGlowIntensity * 0.5))
                    .blur(radius: size * 0.18)
                    .scaleEffect(1.35)
            }
            // Image
            if let u = url, !u.isEmpty {
                CachedAsyncImage(url: u, size: size)
                    .mask(avatarClip(shape: shape).fill(Color.black))
            } else {
                avatarClip(shape: shape)
                    .fill(Color(red:0.12,green:0.14,blue:0.20))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                            .font(.system(size: size * 0.4))
                    )
                    .clipShape(avatarClip(shape: shape))
            }
            // Stroke
            if applyShape && shape != "circle" {
                avatarClip(shape: shape)
                    .stroke(accent.opacity(0.7), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }

    private func avatarClip(shape: String) -> AnyShape {
        switch shape {
        case "nft":   return AnyShape(HexagonShape(rotation: 17))
        case "rhomb": return AnyShape(RhombShape())
        default:      return AnyShape(Circle())
        }
    }
}
