import SwiftUI

// MARK: - Image Cache
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 300; cache.totalCostLimit = 60 * 1024 * 1024 }

    func get(_ url: String) -> UIImage? { cache.object(forKey: url as NSString) }
    func set(_ url: String, image: UIImage) { cache.setObject(image, forKey: url as NSString) }
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
                placeholder
            } else {
                Color(red:0.12,green:0.14,blue:0.20)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) { await load() }
    }

    private var placeholder: some View {
        Circle().fill(Color(red:0.12,green:0.14,blue:0.20))
            .overlay(Image(systemName: "person.fill")
                .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                .font(.system(size: size * 0.4)))
    }

    private func load() async {
        if let cached = ImageCache.shared.get(url) { image = cached; return }
        guard let u = URL(string: url) else { failed = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            if let img = UIImage(data: data) {
                ImageCache.shared.set(url, image: img)
                image = img
            } else { failed = true }
        } catch { failed = true }
    }
}

// MARK: - AvatarView
struct AvatarView: View {
    let url:  String?
    let size: CGFloat

    var body: some View {
        if let u = url, !u.isEmpty {
            CachedAsyncImage(url: u, size: size)
        } else {
            Circle().fill(Color(red:0.12,green:0.14,blue:0.20))
                .frame(width: size, height: size)
                .overlay(Image(systemName: "person.fill")
                    .foregroundStyle(Color(red:0.4,green:0.45,blue:0.55))
                    .font(.system(size: size * 0.4)))
        }
    }
}
