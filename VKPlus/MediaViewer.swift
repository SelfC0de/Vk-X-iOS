import SwiftUI
import AVKit

// MARK: - Photo/Video Viewer
struct MediaViewerSheet: View {
    let photos: [String]  // array of URL strings
    var startIndex: Int = 0
    @Environment(\.dismiss) var dismiss
    @State private var current: Int

    init(photos: [String], startIndex: Int = 0) {
        self.photos = photos
        self.startIndex = startIndex
        self._current = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(photos.indices, id: \.self) { i in
                    ZoomablePhoto(url: photos[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .ignoresSafeArea()

            // Close
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                    .padding(16)
                }
                Spacer()
                // Counter
                if photos.count > 1 {
                    Text("\(current + 1) / \(photos.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 40)
                }
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Zoomable photo
private struct ZoomablePhoto: View {
    let url: String
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnificationGesture()
                        .onChanged { v in scale = max(1, v) }
                        .onEnded { _ in if scale < 1.05 { withAnimation { scale = 1; offset = .zero } } })
                    .gesture(DragGesture()
                        .onChanged { v in if scale > 1 { offset = v.translation } }
                        .onEnded { _ in if scale <= 1 { withAnimation { offset = .zero } } })
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35)) {
                            if scale > 1 { scale = 1; offset = .zero } else { scale = 2.5 }
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Audio/Voice Player
struct AudioPlayerView: View {
    let url: String
    let duration: Int
    let isVoice: Bool

    @StateObject private var player = AudioPlayerModel()

    // Fake waveform bars — pseudo-random but stable per url
    private var bars: [CGFloat] {
        var rng = url.hashValue
        return (0..<28).map { _ -> CGFloat in
            rng = rng &* 1664525 &+ 1013904223
            let v = CGFloat((rng >> 16) & 0xFF) / 255.0
            return 0.15 + v * 0.85
        }
    }

    private var isActive: Bool { player.currentUrl == url }
    private var progress: Double { isActive ? player.progress : 0 }

    var body: some View {
        HStack(spacing: 10) {
            // Play/pause button
            Button { player.toggle(url: url) } label: {
                ZStack {
                    Circle()
                        .fill(isVoice ? Color(red:0.11,green:0.63,blue:0.95) : Color.cyberBlue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: isActive && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isVoice ? .white : Color.cyberBlue)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                if isVoice {
                    // VK-style waveform
                    GeometryReader { geo in
                        let barW: CGFloat = (geo.size.width - CGFloat(bars.count - 1) * 2) / CGFloat(bars.count)
                        let filled = Int(progress * Double(bars.count))
                        HStack(spacing: 2) {
                            ForEach(Array(bars.enumerated()), id: \.offset) { i, h in
                                Capsule()
                                    .fill(i < filled
                                          ? Color(red:0.11,green:0.63,blue:0.95)
                                          : Color.white.opacity(0.25))
                                    .frame(width: max(2, barW), height: geo.size.height * h)
                            }
                        }
                        .frame(height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                            player.seek(to: Double(v.location.x / geo.size.width))
                        })
                    }
                    .frame(height: 28)
                } else {
                    // Regular audio — slim bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                            Capsule().fill(Color.cyberBlue)
                                .frame(width: geo.size.width * CGFloat(progress), height: 3)
                        }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                            player.seek(to: Double(v.location.x / geo.size.width))
                        })
                    }
                    .frame(height: 3)
                }

                HStack {
                    Text(timeStr(isActive ? Int(progress * Double(duration)) : duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(isVoice
                            ? (isActive && player.isPlaying ? Color(red:0.11,green:0.63,blue:0.95) : Color.white.opacity(0.5))
                            : Color(red:0.55,green:0.75,blue:0.95))
                    if !isVoice {
                        Spacer()
                        Text(timeStr(duration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onDisappear { if isActive { player.stop() } }
        .overlay(alignment: .topTrailing) {
            if isVoice {
                Button {
                    Task { await downloadVoiceFile() }
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red:0.11,green:0.63,blue:0.95).opacity(0.85))
                }
                .buttonStyle(.plain)
                .padding(.top, 4).padding(.trailing, 4)
            }
        }
    }

    private func downloadVoiceFile() async {
        guard let audioUrl = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: audioUrl) else {
            ToastManager.shared.show("Ошибка загрузки", icon: "exclamationmark.triangle.fill", style: .warning)
            return
        }
        let ext  = url.hasSuffix(".ogg") ? "ogg" : "mp3"
        let tmp  = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).\(ext)")
        try? data.write(to: tmp)
        await MainActor.run {
            let av = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.rootViewController?
                .present(av, animated: true)
        }
    }

    private func timeStr(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Audio Player Model
final class AudioPlayerModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentUrl: String = ""

    private var player: AVPlayer?
    private var observer: Any?
    private var timeObserver: Any?

    func toggle(url: String) {
        if isPlaying && currentUrl == url { pause(); return }
        if currentUrl != url { stop(); play(url: url) }
        else { resume() }
    }

    private func play(url: String) {
        guard let u = URL(string: url) else { return }
        currentUrl = url
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        player = AVPlayer(url: u)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, let dur = self.player?.currentItem?.duration.seconds,
                  !dur.isNaN, dur > 0 else { return }
            self.progress = time.seconds / dur
            if self.progress >= 0.999 { self.stop() }
        }
        player?.play()
        isPlaying = true
    }

    private func pause() { player?.pause(); isPlaying = false }
    private func resume() { player?.play(); isPlaying = true }

    func stop() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        player?.pause(); player = nil
        isPlaying = false; progress = 0
    }

    func seek(to pct: Double) {
        guard let dur = player?.currentItem?.duration.seconds, !dur.isNaN else { return }
        let t = CMTime(seconds: pct * dur, preferredTimescale: 600)
        player?.seek(to: t)
    }
}

// MARK: - Video Player Sheet
struct VideoPlayerSheet: View {
    let videoId: Int
    let ownerId: Int
    let thumb: String?
    @Environment(\.dismiss) var dismiss

    @State private var resolvedUrl: URL? = nil
    @State private var isLoading = true
    @State private var failed    = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                // Loading state with thumbnail
                VStack(spacing: 20) {
                    if let thumb, let u = URL(string: thumb) {
                        AsyncImage(url: u) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFit()
                                    .frame(maxHeight: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else { Color.clear }
                        }
                        .opacity(0.45)
                    }
                    ProgressView().tint(.white).scaleEffect(1.3)
                    Text("Загрузка видео...")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 32)
            } else if let url = resolvedUrl {
                // Full-featured player (reuse FullscreenVideoPlayer logic)
                FullscreenVideoPlayer(url: url)
            } else if failed {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44)).foregroundStyle(.white.opacity(0.6))
                    Text("Не удалось загрузить видео")
                        .foregroundStyle(.white.opacity(0.6))
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(Color.cyberBlue)
                }
            }

            // Close button (when loading or failed)
            if isLoading || failed {
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 52)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .task { await loadVideo() }
        .statusBarHidden()
    }

    private func loadVideo() async {
        guard let video = try? await VKAPIClient.shared.getVideo(ownerId: ownerId, videoId: videoId) else {
            await MainActor.run { isLoading = false; failed = true }
            return
        }
        await MainActor.run {
            isLoading = false
            if let urlStr = video.directUrl, let url = URL(string: urlStr) {
                resolvedUrl = url
            } else if let urlStr = video.player, let url = URL(string: urlStr) {
                // External (YouTube etc) — open in Safari
                UIApplication.shared.open(url)
                failed = true
            } else {
                failed = true
            }
        }
    }
}
