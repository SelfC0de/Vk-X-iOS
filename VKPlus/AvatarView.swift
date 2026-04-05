import SwiftUI

// MARK: - Image Cache
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 300; cache.totalCostLimit = 60 * 1024 * 1024 }
    func get(_ url: String) -> UIImage? { cache.object(forKey: url as NSString) }
    func set(_ url: String, image: UIImage) { cache.setObject(image, forKey: url as NSString) }
}

// MARK: - Shapes

struct HexagonShape: Shape {
    var rotation: Double = 17
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let r  = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + rotation * .pi / 180
            let pt = CGPoint(x: cx + r * CGFloat(cos(angle)),
                             y: cy + r * CGFloat(sin(angle)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct RhombShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Shape helpers
private func makeShape(_ id: String) -> AnyShape {
    switch id {
    case "nft":   return AnyShape(HexagonShape(rotation: 17))
    case "rhomb": return AnyShape(RhombShape())
    default:      return AnyShape(Circle())
    }
}

// MARK: - AvatarShapeCard
struct AvatarShapeCard: View {
    @ObservedObject private var s = SettingsStore.shared

    private let shapes: [(id: String, label: String)] = [
        ("circle", "Circle"),
        ("nft",    "NFT"),
        ("rhomb",  "Rhomb"),
    ]

    // Per-shape color keys
    private func colorKey(_ shapeId: String) -> String { "avatar_color_\(shapeId)" }

    private func color(for shapeId: String) -> Color {
        let hex = UserDefaults.standard.string(forKey: colorKey(shapeId))
        switch shapeId {
        case "nft":   return hex.map { Color(hex: $0) } ?? Color(r:0x8B,g:0x5C,b:0xF6)
        case "rhomb": return hex.map { Color(hex: $0) } ?? Color.cyberBlue
        default:      return hex.map { Color(hex: $0) } ?? Color.cyberBlue
        }
    }

    private func setColor(_ c: Color, for shapeId: String) {
        UserDefaults.standard.set(c.toHex(), forKey: colorKey(shapeId))
        // Also update main key used by AvatarView
        s.avatarColorHex = c.toHex() ?? "auto"
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Shape selector row ─────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(shapes, id: \.id) { shape in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            s.avatarShape = shape.id
                            // Apply stored color for this shape
                            s.avatarColorHex = UserDefaults.standard.string(forKey: colorKey(shape.id)) ?? "auto"
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ShapePreview(
                                shapeId:  shape.id,
                                size:     56,
                                color:    color(for: shape.id),
                                glow:     s.avatarGlow && s.avatarShape == shape.id,
                                intensity: s.avatarGlowIntensity
                            )
                            Text(shape.label)
                                .font(.system(size: 11, weight: s.avatarShape == shape.id ? .semibold : .regular))
                                .foregroundStyle(s.avatarShape == shape.id ? accentForShape(shape.id) : Color.onSurfaceMut)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(s.avatarShape == shape.id ? accentForShape(shape.id).opacity(0.10) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(s.avatarShape == shape.id ? accentForShape(shape.id).opacity(0.45) : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider().background(Color.divider)

            // ── Color Avatar (per-shape) ───────────────────────────────
            VStack(spacing: 0) {
                ForEach(shapes, id: \.id) { shape in
                    HStack(spacing: 12) {
                        // Shape mini icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentForShape(shape.id).opacity(0.12))
                                .frame(width: 32, height: 32)
                            shapeIcon(shape.id)
                                .foregroundStyle(accentForShape(shape.id))
                        }

                        Text(shape.label)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.onSurface)

                        Spacer()

                        // Color picker per shape
                        ColorPicker("", selection: Binding(
                            get: { color(for: shape.id) },
                            set: { newColor in
                                UserDefaults.standard.set(newColor.toHex(), forKey: colorKey(shape.id))
                                if s.avatarShape == shape.id {
                                    s.avatarColorHex = newColor.toHex() ?? "auto"
                                }
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)

                    if shape.id != "rhomb" {
                        Divider().background(Color.divider).padding(.leading, 58)
                    }
                }
            }

            Divider().background(Color.divider)

            // ── Glow toggle ───────────────────────────────────────────
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(r:0xFF,g:0xD7,b:0x00).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(r:0xFF,g:0xD7,b:0x00))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Glow").font(.system(size: 14)).foregroundStyle(Color.onSurface)
                    Text("Свечение вокруг аватара").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                }
                Spacer()
                Toggle("", isOn: $s.avatarGlow).tint(Color(r:0xFF,g:0xD7,b:0x00)).labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            // ── Glow intensity (visible when on) ─────────────────────
            if s.avatarGlow {
                Divider().background(Color.divider).padding(.leading, 58)
                HStack(spacing: 10) {
                    Image(systemName: "sun.min").font(.system(size: 12)).foregroundStyle(Color.onSurfaceMut)
                    Slider(value: $s.avatarGlowIntensity, in: 0.15...1.0)
                        .tint(Color(r:0xFF,g:0xD7,b:0x00))
                    Image(systemName: "sun.max").font(.system(size: 15)).foregroundStyle(Color.onSurfaceMut)
                    Text("\(Int(s.avatarGlowIntensity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.onSurfaceMut)
                        .frame(width: 34)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: s.avatarGlow)
            }
        }
        .padding(.vertical, 4)
    }

    private func accentForShape(_ id: String) -> Color {
        switch id {
        case "nft":   return Color(r:0x8B,g:0x5C,b:0xF6)
        case "rhomb": return Color.cyberBlue
        default:      return Color.cyberBlue
        }
    }

    @ViewBuilder private func shapeIcon(_ id: String) -> some View {
        switch id {
        case "nft":
            // Hexagon icon
            Canvas { ctx, sz in
                var p = Path()
                let cx = sz.width/2, cy = sz.height/2, r = min(sz.width,sz.height)*0.42
                for i in 0..<6 {
                    let a = Double(i) * .pi/3 + 17 * .pi/180
                    let pt = CGPoint(x: cx + r*CGFloat(cos(a)), y: cy + r*CGFloat(sin(a)))
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
                p.closeSubpath()
                ctx.stroke(p, with: .foreground, lineWidth: 1.6)
            }
            .frame(width: 18, height: 18)
        case "rhomb":
            Canvas { ctx, sz in
                var p = Path()
                p.move(to: CGPoint(x: sz.width/2, y: 0))
                p.addLine(to: CGPoint(x: sz.width, y: sz.height/2))
                p.addLine(to: CGPoint(x: sz.width/2, y: sz.height))
                p.addLine(to: CGPoint(x: 0, y: sz.height/2))
                p.closeSubpath()
                ctx.stroke(p, with: .foreground, lineWidth: 1.6)
            }
            .frame(width: 16, height: 16)
        default:
            Image(systemName: "circle").font(.system(size: 16))
        }
    }
}

// MARK: - Shape Preview (used in selector)
private struct ShapePreview: View {
    let shapeId: String
    let size: CGFloat
    let color: Color
    let glow: Bool
    let intensity: Double

    var body: some View {
        let shape = makeShape(shapeId)
        ZStack {
            // Glow layer
            if glow {
                glowContent(shape: shape)
            }
            // Fill
            shape.fill(Color(red:0.10,green:0.13,blue:0.20))
            // NFT: gradient stroke
            if shapeId == "nft" {
                shape.stroke(
                    LinearGradient(
                        colors: [Color(r:0xC0,g:0x7A,b:0xFF), Color(r:0x8B,g:0x5C,b:0xF6), Color(r:0x6D,g:0x28,b:0xD9)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.2
                )
            } else {
                shape.stroke(color, lineWidth: 1.8)
            }
            // Person icon
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.34))
                .foregroundStyle(shapeId == "nft"
                    ? AnyShapeStyle(LinearGradient(colors: [Color(r:0xC0,g:0x7A,b:0xFF), Color(r:0x8B,g:0x5C,b:0xF6)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(color.opacity(0.8))
                )
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private func glowContent(shape: AnyShape) -> some View {
        if shapeId == "nft" {
            shape.fill(
                LinearGradient(
                    colors: [Color(r:0xC0,g:0x7A,b:0xFF).opacity(intensity * 0.6),
                             Color(r:0x6D,g:0x28,b:0xD9).opacity(intensity * 0.4)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .blur(radius: size * 0.22).scaleEffect(1.4)
        } else {
            shape.fill(color.opacity(intensity * 0.5))
                .blur(radius: size * 0.18).scaleEffect(1.35)
        }
    }
}

// MARK: - Cached async image
struct CachedAsyncImage: View {
    let url: String
    let size: CGFloat
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
    var applyShape: Bool = true

    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        let shapeId  = applyShape ? store.avatarShape : "circle"
        let shape    = makeShape(shapeId)
        let accent   = store.avatarColorHex == "auto"
            ? (shapeId == "nft" ? Color(r:0x8B,g:0x5C,b:0xF6) : Color.cyberBlue)
            : Color(hex: store.avatarColorHex)

        ZStack {
            // Glow
            if applyShape && store.avatarGlow {
                if shapeId == "nft" {
                    shape.fill(
                        LinearGradient(
                            colors: [Color(r:0xC0,g:0x7A,b:0xFF).opacity(store.avatarGlowIntensity * 0.55),
                                     Color(r:0x6D,g:0x28,b:0xD9).opacity(store.avatarGlowIntensity * 0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: size * 0.20).scaleEffect(1.38)
                } else {
                    shape.fill(accent.opacity(store.avatarGlowIntensity * 0.5))
                        .blur(radius: size * 0.18).scaleEffect(1.35)
                }
            }

            // Image clipped to shape
            if let u = url, !u.isEmpty {
                CachedAsyncImageShaped(url: u, size: size, shapeId: shapeId)
            } else {
                shape.fill(Color(red:0.12,green:0.14,blue:0.20))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                            .font(.system(size: size * 0.4))
                            .clipShape(shape)
                    )
                    .clipShape(shape)
            }

            // Stroke overlay
            if applyShape {
                if shapeId == "nft" {
                    shape.stroke(
                        LinearGradient(
                            colors: [Color(r:0xC0,g:0x7A,b:0xFF), Color(r:0x8B,g:0x5C,b:0xF6), Color(r:0x6D,g:0x28,b:0xD9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.0
                    )
                } else if shapeId != "circle" {
                    shape.stroke(accent.opacity(0.75), lineWidth: 1.6)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// Image loader that clips to any shape
private struct CachedAsyncImageShaped: View {
    let url: String; let size: CGFloat; let shapeId: String
    @State private var image: UIImage? = nil

    var body: some View {
        let shape = makeShape(shapeId)
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(shape)
            } else {
                shape.fill(Color(red:0.12,green:0.14,blue:0.20))
                    .frame(width: size, height: size)
            }
        }
        .task(id: url) {
            if let cached = ImageCache.shared.get(url) { image = cached; return }
            guard let u = URL(string: url),
                  let (data, _) = try? await URLSession.shared.data(from: u),
                  let img = UIImage(data: data) else { return }
            ImageCache.shared.set(url, image: img)
            image = img
        }
    }
}
