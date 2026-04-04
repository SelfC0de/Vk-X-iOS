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

    var body: some View {
        HStack(spacing: 10) {
            // Play/pause button
            Button {
                player.toggle(url: url)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cyberBlue.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: player.isPlaying && player.currentUrl == url
                          ? "pause.fill" : (isVoice ? "waveform" : "play.fill"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cyberBlue)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Waveform progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                        Capsule()
                            .fill(Color.cyberBlue)
                            .frame(width: geo.size.width * CGFloat(player.currentUrl == url ? player.progress : 0),
                                   height: 3)
                    }
                    .frame(height: 3)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onEnded { v in
                            let pct = v.location.x / geo.size.width
                            player.seek(to: Double(pct))
                        })
                }
                .frame(height: 3)

                // Time
                Text(timeStr(player.currentUrl == url
                             ? Int(player.progress * Double(duration)) : 0, total: duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(red:0.55,green:0.75,blue:0.95))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onDisappear { if player.currentUrl == url { player.stop() } }
    }

    private func timeStr(_ cur: Int, total: Int) -> String {
        String(format: "%d:%02d / %d:%02d", cur/60, cur%60, total/60, total%60)
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
    @State private var videoUrl: String? = nil
    @State private var player: AVPlayer? = nil
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let p = player {
                VideoPlayer(player: p).ignoresSafeArea()
                    .onAppear { p.play() }
                    .onDisappear { p.pause() }
            } else if isLoading {
                VStack(spacing: 16) {
                    if let thumb, let u = URL(string: thumb) {
                        AsyncImage(url: u) { phase in
                            if case .success(let img) = phase { img.resizable().scaledToFit() }
                            else { Color(red:0.1,green:0.1,blue:0.15) }
                        }
                        .opacity(0.5)
                    }
                    ProgressView().tint(.white)
                    Text("Загрузка видео...").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.white)
                    Text("Не удалось загрузить видео").foregroundStyle(.white.opacity(0.7))
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button { player?.pause(); dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28)).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
        .task { await loadVideo() }
        .statusBarHidden()
    }

    private func loadVideo() async {
        // Fetch video URL via VK API video.get
        let json = try? await VKAPIClient.shared.rawCall("video.get", params: [
            "videos": "\(ownerId)_\(videoId)", "extended": "0"
        ])
        guard let response = json?["response"] as? [String: Any],
              let items = response["items"] as? [[String: Any]],
              let item = items.first,
              let files = item["files"] as? [String: Any] else {
            isLoading = false; return
        }
        // Try quality from best to worst
        for q in ["mp4_1080","mp4_720","mp4_480","mp4_360","mp4_240","external"] {
            if let url = files[q] as? String, !url.isEmpty {
                if q == "external" {
                    // external = YouTube etc — open in Safari
                    await MainActor.run {
                        if let u = URL(string: url) { UIApplication.shared.open(u) }
                        isLoading = false
                    }
                    return
                }
                await MainActor.run {
                    player = AVPlayer(url: URL(string: url)!)
                    isLoading = false
                }
                return
            }
        }
        isLoading = false
    }
}
