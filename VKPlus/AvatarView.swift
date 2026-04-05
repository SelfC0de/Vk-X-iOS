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
        let cx = rect.midX, cy = rect.midY, r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 + rotation * .pi / 180
            let pt = CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath(); return p
    }
}

struct RhombShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath(); return p
    }
}

func avatarAnyShape(_ id: String) -> AnyShape {
    switch id {
    case "nft":   return AnyShape(HexagonShape(rotation: 17))
    case "rhomb": return AnyShape(RhombShape())
    default:      return AnyShape(Circle())
    }
}

// MARK: - AvatarShapeCard
struct AvatarShapeCard: View {
    @ObservedObject private var s = SettingsStore.shared

    private struct ShapeDef {
        let id: String; let label: String
    }
    private let shapes = [
        ShapeDef(id: "circle", label: "Circle"),
        ShapeDef(id: "nft",    label: "NFT"),
        ShapeDef(id: "rhomb",  label: "Rhomb"),
    ]

    // Bindings for per-shape stroke color
    private func strokeColorBinding(_ id: String) -> Binding<Color> {
        switch id {
        case "nft":   return Binding(get: { Color(hex: s.avatarColorNft) },   set: { s.avatarColorNft   = $0.toHex() ?? "#8B5CF6" })
        case "rhomb": return Binding(get: { Color(hex: s.avatarColorRhomb) }, set: { s.avatarColorRhomb = $0.toHex() ?? "#00B4FF" })
        default:      return Binding(get: { Color(hex: s.avatarColorCircle) },set: { s.avatarColorCircle = $0.toHex() ?? "#00B4FF" })
        }
    }

    // Bindings for per-shape glow color
    private func glowColorBinding(_ id: String) -> Binding<Color> {
        switch id {
        case "nft":   return Binding(get: { Color(hex: s.avatarGlowNft) },   set: { s.avatarGlowNft   = $0.toHex() ?? "#8B5CF6" })
        case "rhomb": return Binding(get: { Color(hex: s.avatarGlowRhomb) }, set: { s.avatarGlowRhomb = $0.toHex() ?? "#00B4FF" })
        default:      return Binding(get: { Color(hex: s.avatarGlowCircle) },set: { s.avatarGlowCircle = $0.toHex() ?? "#00B4FF" })
        }
    }

    private func strokeColor(_ id: String) -> Color { strokeColorBinding(id).wrappedValue }
    private func glowColor(_ id: String) -> Color   { glowColorBinding(id).wrappedValue }

    var body: some View {
        VStack(spacing: 0) {

            // ── Shape selector ─────────────────────────────────────────
            HStack(spacing: 6) {
                ForEach(shapes, id: \.id) { shape in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            s.avatarShape = shape.id
                        }
                    } label: {
                        VStack(spacing: 7) {
                            AvatarPreviewTile(
                                shapeId:       shape.id,
                                size:          54,
                                strokeColor:   strokeColor(shape.id),
                                glowColor:     glowColor(shape.id),
                                glow:          s.avatarGlow && s.avatarShape == shape.id,
                                glowIntensity: s.avatarGlowIntensity
                            )
                            Text(shape.label)
                                .font(.system(size: 11, weight: s.avatarShape == shape.id ? .semibold : .regular))
                                .foregroundStyle(s.avatarShape == shape.id ? strokeColor(shape.id) : Color.onSurfaceMut)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(s.avatarShape == shape.id ? strokeColor(shape.id).opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(s.avatarShape == shape.id ? strokeColor(shape.id).opacity(0.5) : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)

            Divider().background(Color.divider)

            // ── Per-shape: Stroke color + Glow color ───────────────────
            ForEach(shapes, id: \.id) { shape in
                VStack(spacing: 0) {
                    // Shape header
                    HStack(spacing: 10) {
                        shapeIconView(shape.id)
                        Text(shape.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(strokeColor(shape.id))
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)

                    // Stroke color row
                    HStack(spacing: 12) {
                        Image(systemName: "circle.dotted")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.onSurfaceMut)
                            .frame(width: 22)
                        Text("Обводка")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.onSurface)
                        Spacer()
                        // Color preview swatch
                        RoundedRectangle(cornerRadius: 6)
                            .fill(strokeColor(shape.id))
                            .frame(width: 26, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        ColorPicker("", selection: strokeColorBinding(shape.id))
                            .labelsHidden().frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)

                    // Glow color row
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(r:0xFF,g:0xD7,b:0x00))
                            .frame(width: 22)
                        Text("Glow цвет")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.onSurface)
                        Spacer()
                        RoundedRectangle(cornerRadius: 6)
                            .fill(glowColor(shape.id))
                            .frame(width: 26, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        ColorPicker("", selection: glowColorBinding(shape.id))
                            .labelsHidden().frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6).padding(.bottom, 8)
                }

                if shape.id != "rhomb" { Divider().background(Color.divider) }
            }

            Divider().background(Color.divider)

            // ── Glow toggle ────────────────────────────────────────────
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(r:0xFF,g:0xD7,b:0x00).opacity(0.14))
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

            // Glow intensity slider
            if s.avatarGlow {
                Divider().background(Color.divider).padding(.leading, 58)
                HStack(spacing: 10) {
                    Image(systemName: "sun.min").font(.system(size: 11)).foregroundStyle(Color.onSurfaceMut)
                    Slider(value: $s.avatarGlowIntensity, in: 0.15...1.0)
                        .tint(Color(r:0xFF,g:0xD7,b:0x00))
                    Image(systemName: "sun.max").font(.system(size: 14)).foregroundStyle(Color.onSurfaceMut)
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

    @ViewBuilder private func shapeIconView(_ id: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(strokeColor(id).opacity(0.14))
                .frame(width: 28, height: 28)
            switch id {
            case "nft":
                Canvas { ctx, sz in
                    var p = Path()
                    let cx = sz.width/2, cy = sz.height/2, r = min(sz.width,sz.height)*0.42
                    for i in 0..<6 {
                        let a = Double(i) * .pi/3 + 17 * .pi/180
                        let pt = CGPoint(x: cx + r*CGFloat(cos(a)), y: cy + r*CGFloat(sin(a)))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                    p.closeSubpath()
                    ctx.stroke(p, with: .color(strokeColor(id)), lineWidth: 1.5)
                }
                .frame(width: 16, height: 16)
            case "rhomb":
                Canvas { ctx, sz in
                    var p = Path()
                    p.move(to: CGPoint(x: sz.width/2, y: 0))
                    p.addLine(to: CGPoint(x: sz.width, y: sz.height/2))
                    p.addLine(to: CGPoint(x: sz.width/2, y: sz.height))
                    p.addLine(to: CGPoint(x: 0, y: sz.height/2))
                    p.closeSubpath()
                    ctx.stroke(p, with: .color(strokeColor(id)), lineWidth: 1.5)
                }
                .frame(width: 14, height: 14)
            default:
                Image(systemName: "circle").font(.system(size: 14)).foregroundStyle(strokeColor(id))
            }
        }
    }
}

// MARK: - AvatarPreviewTile (shape selector preview)
struct AvatarPreviewTile: View {
    let shapeId:       String
    let size:          CGFloat
    let strokeColor:   Color
    let glowColor:     Color
    let glow:          Bool
    let glowIntensity: Double

    var body: some View {
        let shape = avatarAnyShape(shapeId)
        ZStack {
            if glow {
                shape.fill(glowColor.opacity(glowIntensity * 0.55))
                    .blur(radius: size * 0.22).scaleEffect(1.4)
            }
            shape.fill(Color(red:0.10,green:0.13,blue:0.20))
            if shapeId == "nft" {
                shape.stroke(
                    LinearGradient(
                        colors: [strokeColor.opacity(0.9), strokeColor, strokeColor.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 2.2
                )
            } else {
                shape.stroke(strokeColor, lineWidth: 1.8)
            }
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.34))
                .foregroundStyle(strokeColor.opacity(0.8))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Cached async image (circle only, for dialogs etc)
struct CachedAsyncImage: View {
    let url: String; let size: CGFloat
    @State private var image: UIImage? = nil
    @State private var failed = false

    var body: some View {
        Group {
            if let img = image { Image(uiImage: img).resizable().scaledToFill() }
            else if failed { placeholder }
            else { Color(red:0.12,green:0.14,blue:0.20) }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) { await load() }
    }
    private var placeholder: some View {
        Color(red:0.12,green:0.14,blue:0.20)
            .overlay(Image(systemName: "person.fill")
                .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                .font(.system(size: size * 0.4)))
    }
    private func load() async {
        if let c = ImageCache.shared.get(url) { image = c; return }
        guard let u = URL(string: url),
              let (data,_) = try? await URLSession.shared.data(from: u),
              let img = UIImage(data: data) else { failed = true; return }
        ImageCache.shared.set(url, image: img); image = img
    }
}

// MARK: - AvatarView (shape-aware, reads SettingsStore)
struct AvatarView: View {
    let url:        String?
    let size:       CGFloat
    var applyShape: Bool = true

    @ObservedObject private var s = SettingsStore.shared

    var body: some View {
        let shapeId = applyShape ? s.avatarShape : "circle"
        let shape   = avatarAnyShape(shapeId)
        let stroke  = Color(hex: s.avatarColorHex)
        let glow    = Color(hex: s.avatarGlowHex)

        ZStack {
            // Glow
            if applyShape && s.avatarGlow {
                shape.fill(glow.opacity(s.avatarGlowIntensity * 0.55))
                    .blur(radius: size * 0.20).scaleEffect(1.38)
            }
            // Image
            if let u = url, !u.isEmpty {
                CachedAsyncImageShaped(url: u, size: size, shapeId: shapeId)
            } else {
                shape.fill(Color(red:0.12,green:0.14,blue:0.20))
                Image(systemName: "person.fill")
                    .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                    .font(.system(size: size * 0.4))
            }
            // Stroke
            if applyShape {
                if shapeId == "nft" {
                    shape.stroke(
                        LinearGradient(
                            colors: [stroke.opacity(0.9), stroke, stroke.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 2.0
                    )
                } else if shapeId != "circle" {
                    shape.stroke(stroke.opacity(0.8), lineWidth: 1.6)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(applyShape ? shape : AnyShape(Circle()))
    }
}

// Image loader clipped to any shape
private struct CachedAsyncImageShaped: View {
    let url: String; let size: CGFloat; let shapeId: String
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(red:0.12,green:0.14,blue:0.20)
            }
        }
        .frame(width: size, height: size)
        .clipShape(avatarAnyShape(shapeId))
        .task(id: url) {
            if let c = ImageCache.shared.get(url) { image = c; return }
            guard let u = URL(string: url),
                  let (data,_) = try? await URLSession.shared.data(from: u),
                  let img = UIImage(data: data) else { return }
            ImageCache.shared.set(url, image: img); image = img
        }
    }
}
