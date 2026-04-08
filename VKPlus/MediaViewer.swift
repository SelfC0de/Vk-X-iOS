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
struct ZoomablePhoto: View {
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
    let duration: Int       // hint from API (may be 0 for docs)
    let isVoice: Bool
    var artist: String? = nil
    var title: String?  = nil

    @StateObject private var player = AudioPlayerModel()
    @StateObject private var meta   = ID3MetadataReader()

    // Pseudo-random waveform stable per URL
    private var bars: [CGFloat] {
        var rng = url.hashValue
        return (0..<32).map { _ -> CGFloat in
            rng = rng &* 1664525 &+ 1013904223
            return 0.15 + CGFloat((rng >> 16) & 0xFF) / 255.0 * 0.85
        }
    }

    private var isActive: Bool  { player.currentUrl == url }
    private var displayProg: Double { isActive ? player.displayProgress : 0 }
    private var totalSec: Int {
        if isActive && player.realDuration > 0 { return Int(player.realDuration) }
        return duration
    }
    private var currentSec: Int { Int(displayProg * Double(max(totalSec, 1))) }

    // API data shown immediately; ID3 loaded as fallback for non-VK audio
    private var displayArtist: String? { artist ?? meta.artist }
    private var displayTitle:  String? { title  ?? meta.title  }

    var body: some View {
        HStack(spacing: 10) {
            // Play button
            Button { player.toggle(url: url) } label: {
                ZStack {
                    Circle()
                        .fill(isVoice
                              ? Color(red:0.11,green:0.63,blue:0.95)
                              : Color.cyberBlue.opacity(isActive ? 0.3 : 0.15))
                        .frame(width: 40, height: 40)
                    if isActive && player.isLoading {
                        ProgressView()
                            .tint(isVoice ? .white : Color.cyberBlue)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isActive && player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isVoice ? .white : Color.cyberBlue)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Title row
                if !isVoice {
                    if let t = displayTitle, !t.isEmpty {
                        Text(t)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.onSurface)
                            .lineLimit(1)
                        if let a = displayArtist, !a.isEmpty {
                            Text(a)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.onSurfaceMut)
                                .lineLimit(1)
                        }
                    }
                }

                // Seekbar
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        if isVoice {
                            // Waveform bars
                            let barW: CGFloat = (w - CGFloat(bars.count - 1) * 2) / CGFloat(bars.count)
                            let filled = Int(displayProg * Double(bars.count))
                            HStack(spacing: 2) {
                                ForEach(Array(bars.enumerated()), id: \.offset) { i, h in
                                    Capsule()
                                        .fill(i < filled
                                              ? Color(red:0.11,green:0.63,blue:0.95)
                                              : Color.white.opacity(0.2))
                                        .frame(width: max(2, barW), height: geo.size.height * h)
                                }
                            }
                        } else {
                            // Progress bar with thumb
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.cyberBlue)
                                .frame(width: w * CGFloat(displayProg), height: 4)
                            // Thumb dot
                            if isActive {
                                Circle()
                                    .fill(Color.cyberBlue)
                                    .frame(width: 11, height: 11)
                                    .offset(x: w * CGFloat(displayProg) - 5.5)
                                    .animation(.linear(duration: 0.05), value: displayProg)
                            }
                        }
                    }
                    .frame(height: geo.size.height)
                    .contentShape(Rectangle())
                    // Drag gesture for scrubbing
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let pct = max(0, min(1, v.location.x / w))
                                if player.currentUrl == url {
                                    if player.isDragging {
                                        player.moveDrag(to: pct)
                                    } else {
                                        player.beginDrag(at: pct)
                                    }
                                } else {
                                    player.toggle(url: url)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        player.beginDrag(at: pct)
                                    }
                                }
                            }
                            .onEnded { _ in player.endDrag() }
                    )
                }
                .frame(height: isVoice ? 28 : 16)

                // Time row
                HStack {
                    Text(timeStr(isActive ? currentSec : 0))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isVoice
                            ? Color(red:0.11,green:0.63,blue:0.95).opacity(isActive ? 1 : 0.5)
                            : Color(red:0.55,green:0.75,blue:0.95))
                    Spacer()
                    Text(timeStr(totalSec))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onAppear {
            if !isVoice && artist == nil && title == nil {
                meta.load(urlStr: url)
            }
        }
        .onDisappear { if isActive { player.stop() } }
        .overlay(alignment: .topTrailing) {
            if isVoice {
                CircularDownloadButton(urlStr: url, size: 26,
                                       iconColor: Color(red:0.11,green:0.63,blue:0.95)) {
                    Task { await downloadVoiceFile() }
                }
                .padding(.top, 4).padding(.trailing, 4)
            }
        }
    }

    private func downloadVoiceFile() async {
        let ext  = url.hasSuffix(".ogg") ? "ogg" : "mp3"
        let name = "voice_\(Int(Date().timeIntervalSince1970)).\(ext)"
        await DownloadManager.shared.downloadAudio(from: url, filename: name, isVoice: true)
    }

    private func timeStr(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - ID3 Metadata Reader
@MainActor
final class ID3MetadataReader: ObservableObject {
    @Published var title:  String? = nil
    @Published var artist: String? = nil

    func load(urlStr: String) {
        guard title == nil, artist == nil else { return }
        guard let url = URL(string: urlStr) else { return }
        Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            do {
                let meta = try await asset.load(.commonMetadata)
                var titleVal: String? = nil
                var artistVal: String? = nil
                for item in meta {
                    guard let key = item.commonKey else { continue }
                    if key == .commonKeyTitle, titleVal == nil {
                        titleVal = try? await item.load(.stringValue)
                    }
                    if key == .commonKeyArtist, artistVal == nil {
                        artistVal = try? await item.load(.stringValue)
                    }
                }
                // Fallback: filename decomposition "Artist - Title.mp3"
                if titleVal == nil, artistVal == nil {
                    let name = url.deletingPathExtension().lastPathComponent
                    let parts = name.components(separatedBy: " - ")
                    if parts.count >= 2 {
                        artistVal = parts[0].trimmingCharacters(in: .whitespaces)
                        titleVal  = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    }
                }
                let finalTitle  = titleVal
                let finalArtist = artistVal
                await MainActor.run {
                    self.title  = finalTitle
                    self.artist = finalArtist
                }
            } catch {}
        }
    }
}


// MARK: - Audio Player Model
@MainActor
final class AudioPlayerModel: ObservableObject {
    @Published var isPlaying:    Bool   = false
    @Published var progress:     Double = 0
    @Published var currentUrl:   String = ""
    @Published var realDuration: Double = 0
    @Published var isDragging:   Bool   = false
    @Published var dragProgress: Double = 0
    @Published var isLoading:    Bool   = false

    private var player:         AVPlayer?
    private var timeObserver:   Any?
    private var endObserver:    NSObjectProtocol?
    private var itemObserver:   NSKeyValueObservation?

    var displayProgress: Double { isDragging ? dragProgress : progress }

    func toggle(url: String) {
        if currentUrl == url {
            isPlaying ? pause() : resume()
        } else {
            stop()
            play(url: url)
        }
    }

    private func play(url: String) {
        guard let u = URL(string: url) else { return }
        currentUrl   = url
        progress     = 0
        realDuration = 0
        isLoading    = true

        // Determine if AVPlayer can stream directly or needs local file
        // Direct streaming works for: .mp3, .ogg, .m4a, .aac (VK CDN sets correct Content-Type)
        // Needs local copy: .dat and any URL without recognised audio extension
        let ext = (URL(string: url)?.pathExtension ?? "").lowercased()
        let streamableExts: Set<String> = ["mp3", "ogg", "m4a", "aac", "flac", "wav"]
        let needsLocalPlay = !streamableExts.contains(ext)

        if needsLocalPlay {
            // Check local cache first (avoid re-downloading on replay)
            let cacheKey = "vkplus_audio_" + abs(url.hashValue).description + ".mp3"
            let cacheUrl = FileManager.default.temporaryDirectory.appendingPathComponent(cacheKey)
            if FileManager.default.fileExists(atPath: cacheUrl.path) {
                isLoading = false
                startAVPlayer(localUrl: cacheUrl, trackUrl: url)
            } else {
                Task {
                    do {
                        let localUrl = try await Self.downloadToLocal(remoteUrl: u, cacheUrl: cacheUrl)
                        await MainActor.run {
                            self.isLoading = false
                            self.startAVPlayer(localUrl: localUrl, trackUrl: url)
                        }
                    } catch {
                        await MainActor.run { self.isLoading = false; self.isPlaying = false }
                    }
                }
            }
        } else {
            isLoading = false
            startAVPlayer(localUrl: u, trackUrl: url)
        }
    }

    // Download remote file → local .mp3 (with cache support)
    private static func downloadToLocal(remoteUrl: URL, cacheUrl: URL? = nil) async throws -> URL {
        let (tmpUrl, _) = try await URLSession.shared.download(from: remoteUrl)
        let dest = cacheUrl ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("vkplus_audio_\(Int(Date().timeIntervalSince1970)).mp3")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmpUrl, to: dest)
        return dest
    }

    private func startAVPlayer(localUrl: URL, trackUrl: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let item = AVPlayerItem(url: localUrl)
        let avp  = AVPlayer(playerItem: item)
        player   = avp

        // KVO: item status → get duration once ready
        itemObserver = item.observe(\.status, options: [.new, .initial]) { [weak item] _, _ in
            guard let item, item.status == .readyToPlay else { return }
            let d = item.duration.seconds
            guard d.isFinite, d > 0 else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.realDuration == 0 { self.realDuration = d }
            }
        }

        // End-of-track
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        }

        // Periodic timer — MUST capture self strongly enough to survive
        // Use unowned to avoid retain cycle but still fire updates
        timeObserver = avp.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),  // 0.1s
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isDragging else { return }
                let dur = self.player?.currentItem?.duration.seconds ?? self.realDuration
                guard dur.isFinite, dur > 0 else { return }
                self.progress = min(time.seconds / dur, 1.0)
                if self.realDuration == 0 { self.realDuration = dur }
            }
        }

        avp.play()
        isPlaying = true
    }

    private func pause()  { player?.pause(); isPlaying = false }
    private func resume() { player?.play();  isPlaying = true  }

    func stop() {
        if let obs = timeObserver    { player?.removeTimeObserver(obs); timeObserver  = nil }
        if let obs = endObserver     { NotificationCenter.default.removeObserver(obs); endObserver = nil }
        itemObserver?.invalidate(); itemObserver = nil
        player?.pause(); player = nil
        isPlaying = false; progress = 0; realDuration = 0; currentUrl = ""; isLoading = false
    }

    func seek(to pct: Double) {
        let p   = max(0, min(1, pct))
        let dur = player?.currentItem?.duration.seconds ?? realDuration
        guard dur.isFinite, dur > 0 else { progress = p; return }
        let t = CMTime(seconds: p * dur, preferredTimescale: 600)
        player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        progress = p
    }

    func beginDrag(at pct: Double) { isDragging = true;  dragProgress = max(0, min(1, pct)) }
    func moveDrag(to pct: Double)  { dragProgress = max(0, min(1, pct)) }
    func endDrag()                 { seek(to: dragProgress); isDragging = false }

    deinit { stop() }
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
