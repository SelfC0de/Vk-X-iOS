import SwiftUI
import Photos
import AVKit
import AVFoundation

// MARK: - VideoCard (inline in feed)
struct VideoCard: View {
    let video: VKVideoAttachment
    @State private var resolved:    VKVideoAttachment? = nil
    @State private var loading      = false
    @State private var showPlayer   = false
    @State private var showFullscreen = false

    private var fmtDuration: String {
        guard let d = (resolved?.duration ?? video.duration), d > 0 else { return "" }
        let m = d / 60; let s = d % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Thumbnail
            ZStack {
                Color.surfaceVar
                if let thumb = (resolved?.thumbUrl ?? video.thumbUrl).flatMap(URL.init) {
                    AsyncImage(url: thumb) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else { Color.surfaceVar }
                    }
                    .clipped()
                }

                // Play button overlay
                if !showPlayer {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.55))
                            .frame(width: 54, height: 54)
                        if loading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .offset(x: 2)
                        }
                    }
                }

                // Inline player
                if showPlayer {
                    if let url = directVideoURL {
                        InlineVideoPlayer(url: url, onFullscreen: { showFullscreen = true })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let url = embedVideoURL {
                        VideoWebPlayer(url: url, onFullscreen: { showFullscreen = true })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !showPlayer else { return }
                if playableURL != nil {
                    showPlayer = true
                } else {
                    Task { await resolve() }
                }
            }

            // Duration badge
            if !fmtDuration.isEmpty && !showPlayer {
                Text(fmtDuration)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            let urlStr = (resolved ?? video).directUrl ?? ""
            CircularDownloadButton(
                urlStr: urlStr.isEmpty ? "video_\(video.id)" : urlStr,
                size: 36,
                iconColor: .white
            ) {
                Task { await downloadVideo() }
            }
            .padding(8)
        }
        // Title
        .overlay(alignment: .topLeading) {
            if let title = (resolved?.title ?? video.title), !title.isEmpty, !showPlayer {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(8)
            }
        }
        // Fullscreen
        .fullScreenCover(isPresented: $showFullscreen) {
            if let url = directVideoURL {
                FullscreenVideoPlayer(url: url)
            } else if let url = embedVideoURL {
                FullscreenWebPlayer(url: url)
            }
        }
    }

    private var directVideoURL: URL? {
        let src = resolved ?? video
        return src.directUrl.flatMap(URL.init)
    }
    private var embedVideoURL: URL? {
        let src = resolved ?? video
        return src.player.flatMap(URL.init)
    }
    private var playableURL: URL? { directVideoURL ?? embedVideoURL }

    private func downloadVideo() async {
        ToastManager.shared.show("Получаем ссылку...", icon: "arrow.down.circle", style: .info)

        // Resolve direct URL
        let src = resolved ?? video
        var urlStr = src.directUrl
        if urlStr == nil {
            if let fetched = try? await VKAPIClient.shared.getVideo(ownerId: video.ownerId, videoId: video.id) {
                urlStr = fetched.directUrl
                await MainActor.run { resolved = fetched }
            }
        }
        guard let str = urlStr, let url = URL(string: str) else {
            await MainActor.run {
                                ToastManager.shared.show("Прямая ссылка недоступна", icon: "exclamationmark.triangle.fill", style: .warning)
            }
            return
        }

        // Download to temp file (not in memory — avoids OOM on large videos)
        let session = URLSession(configuration: .default)
        do {
            let (tmpUrl, resp) = try await session.download(from: url)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("vkplus_video_\(Int(Date().timeIntervalSince1970)).mp4")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpUrl, to: dest)
            // Save to Photos gallery
            await saveVideoToGallery(url: dest)
        } catch {
            await MainActor.run {
                                ToastManager.shared.show("Ошибка загрузки видео", icon: "exclamationmark.triangle.fill", style: .warning)
            }
        }
    }

    private func saveVideoToGallery(url: URL) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            await performSave(url: url)
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
            if granted { await performSave(url: url) }
            else { ToastManager.shared.show("Нет доступа к галерее", icon: "exclamationmark.triangle.fill", style: .warning) }
        default:
            ToastManager.shared.show("Нет доступа к галерее", icon: "exclamationmark.triangle.fill", style: .warning)
        }
    }

    private func performSave(url: URL) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            await MainActor.run {
                                ToastManager.shared.show("Видео сохранено в галерею", icon: "checkmark.circle.fill", style: .success)
            }
        } catch {
            await MainActor.run {
                                ToastManager.shared.show("Ошибка сохранения", icon: "exclamationmark.triangle.fill", style: .warning)
            }
        }
    }

    private func resolve() async {
        guard !loading else { return }
        loading = true
        if let v = try? await VKAPIClient.shared.getVideo(ownerId: video.ownerId, videoId: video.id) {
            await MainActor.run {
                resolved = v
                loading  = false
                // Always show player — FullscreenVideoPlayer handles both directUrl and player URL
                showPlayer = true
            }
        } else {
            await MainActor.run { loading = false }
        }
    }
}

// MARK: - Inline AVPlayer (embedded in feed)
struct InlineVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    var onFullscreen: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.videoGravity = .resizeAspect
        // Disable built-in fullscreen to use our own
        vc.allowsPictureInPicturePlayback = false
        player.play()

        // Observe fullscreen button — override with our handler
        context.coordinator.vc = vc
        context.coordinator.onFullscreen = onFullscreen
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var vc: AVPlayerViewController?
        var onFullscreen: (() -> Void)?
    }
}

// MARK: - Fullscreen video player
struct FullscreenVideoPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer? = nil
    @State private var isPlaying   = true
    @State private var progress:   Double = 0
    @State private var duration:   Double = 1
    @State private var timeString  = "0:00"
    @State private var showControls = true
    @State private var timer: Timer? = nil
    @State private var isMuted = false
    @State private var timeObserver: Any? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video
            if let player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture { toggleControls() }
            }

            // Controls overlay
            if showControls {
                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 52)

                    Spacer()

                    // Center play/pause
                    Button {
                        togglePlay()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                            .frame(width: 70, height: 70)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Bottom: progress + time
                    VStack(spacing: 8) {
                        // Seek bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(Color.cyberBlue)
                                    .frame(width: geo.size.width * CGFloat(progress / max(duration, 1)), height: 4)
                            }
                            .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 28)).offset(x: 0, y: -12))
                            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                                let pct = min(1, max(0, v.location.x / geo.size.width))
                                let target = pct * duration
                                player?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                                progress = target
                            })
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 16)

                        HStack {
                            Text(formatTime(progress))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(formatTime(duration))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 36)
                }
                .background(
                    LinearGradient(colors: [.black.opacity(0.7), .clear, .clear, .black.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                )
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            addTimeObserver(p)
            p.play()
            scheduleControlsHide()
        }
        .onDisappear {
            if let obs = timeObserver { player?.removeTimeObserver(obs) }
            timer?.invalidate()
            player?.pause()
            player = nil
        }
    }

    private func togglePlay() {
        guard let p = player else { return }
        if isPlaying { p.pause() } else { p.play() }
        isPlaying.toggle()
        resetControlsTimer()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
        if showControls { scheduleControlsHide() }
    }

    private func scheduleControlsHide() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { showControls = false }
        }
    }

    private func resetControlsTimer() {
        showControls = true
        scheduleControlsHide()
    }

    private func addTimeObserver(_ p: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            progress = time.seconds
            if let d = p.currentItem?.duration.seconds, d.isFinite { duration = d }
            // Loop
            if progress >= duration - 0.3 && duration > 1 {
                p.seek(to: .zero); p.play(); isPlaying = true
            }
        }
    }

    private func formatTime(_ s: Double) -> String {
        let t = max(0, Int(s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - AVPlayerLayer UIView wrapper
private struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.player = player
        return v
    }
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
    }

    class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue; playerLayer.videoGravity = .resizeAspect }
        }
    }
}

// MARK: - WKWebView embed player (for VK player URLs)
import WebKit

struct VideoWebPlayer: UIViewRepresentable {
    let url: URL
    var onFullscreen: (() -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.backgroundColor = .black
        wv.scrollView.isScrollEnabled = false
        wv.isOpaque = false
        // Autoplay via JS injection
        let req = URLRequest(url: url)
        wv.load(req)
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Fullscreen web player
struct FullscreenWebPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoWebPlayer(url: url)
                .ignoresSafeArea()
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
        }
        .statusBarHidden()
    }
}
