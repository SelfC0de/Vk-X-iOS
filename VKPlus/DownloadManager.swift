import Foundation
import UIKit

// MARK: - DownloadManager
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    // progress 0.0…1.0, keyed by normalized URL string
    @Published var progress: [String: Double] = [:]

    private var session: URLSession!
    private var taskCompletions: [Int: (Result<URL, Error>) -> Void] = [:]
    private var taskKeys:        [Int: String] = [:]  // tid → normalized urlStr

    // Folder: Documents/VKPlus/Audio
    static var audioDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("VKPlus/Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.protocolClasses = (cfg.protocolClasses ?? []).filter { $0 != PrivacyURLProtocol.self }
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    /// Generic download — returns temp URL, caller decides what to do
    func download(from urlStr: String) async throws -> URL {
        let key = urlStr  // use raw URL as key so CircularDownloadButton can find it
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        return try await withCheckedThrowingContinuation { cont in
            Task { @MainActor in
                self.progress[key] = 0.001
                var req = URLRequest(url: url)
                req.timeoutInterval = 120
                let task = self.session.downloadTask(with: req)
                let tid  = task.taskIdentifier
                self.taskCompletions[tid] = { result in cont.resume(with: result) }
                self.taskKeys[tid] = key
                task.resume()
            }
        }
    }

    /// Download audio directly to Documents/VKPlus/Audio/{filename}.mp3
    /// Returns the saved file URL, shows toast on success
    func downloadAudio(from urlStr: String, filename: String) async {
        let key = urlStr  // raw URL as key
        guard progress[key] == nil else { return }
        guard let url = URL(string: urlStr) else {
            ToastManager.shared.show("Неверная ссылка", icon: "exclamationmark.triangle.fill", style: .warning)
            return
        }
        let dest = Self.audioDir.appendingPathComponent(safeFilename(filename))
        // Already exists — skip download
        if FileManager.default.fileExists(atPath: dest.path) {
            ToastManager.shared.show("Уже сохранено", icon: "checkmark.circle.fill", style: .success)
            return
        }
        progress[key] = 0.001
        var req = URLRequest(url: url)
        req.timeoutInterval = 120

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                let task = self.session.downloadTask(with: req)
                let tid  = task.taskIdentifier
                self.taskKeys[tid] = key
                self.taskCompletions[tid] = { [weak self] result in
                    Task { @MainActor in
                        switch result {
                        case .success(let tmpUrl):
                            do {
                                try? FileManager.default.removeItem(at: dest)
                                try FileManager.default.moveItem(at: tmpUrl, to: dest)
                                ToastManager.shared.show(
                                    "Сохранено в Файлы → VKPlus/Audio",
                                    icon: "checkmark.circle.fill", style: .success)
                            } catch {
                                ToastManager.shared.show(
                                    "Ошибка сохранения", icon: "exclamationmark.triangle.fill", style: .warning)
                            }
                        case .failure:
                            ToastManager.shared.show(
                                "Ошибка загрузки", icon: "exclamationmark.triangle.fill", style: .warning)
                        }
                        self?.progress.removeValue(forKey: key)
                        cont.resume()
                    }
                }
                task.resume()
            }
        }
    }

    func cancel(urlStr: String) {
        let key = normalize(urlStr)
        session.getAllTasks { tasks in
            for t in tasks {
                Task { @MainActor in
                    if self.taskKeys[t.taskIdentifier] == key { t.cancel() }
                }
            }
        }
        progress.removeValue(forKey: key)
    }

    // MARK: - Helpers

    private func normalize(_ urlStr: String) -> String {
        // Strip query params for key stability (VK audio URLs have expiring tokens)
        URL(string: urlStr).flatMap { URL(string: $0.absoluteString.components(separatedBy: "?")[0]) }?.absoluteString ?? urlStr
    }

    private func safeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let safe    = name.components(separatedBy: illegal).joined(separator: "_")
        return safe.hasSuffix(".mp3") ? safe : "\(safe).mp3"
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData _: Int64,
                                totalBytesWritten written: Int64,
                                totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        let pct = max(0.001, min(0.99, Double(written) / Double(total)))
        let tid = downloadTask.taskIdentifier
        Task { @MainActor in
            if let key = self.taskKeys[tid] { self.progress[key] = pct }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let tid  = downloadTask.taskIdentifier
        // Copy from ephemeral location before delegate returns
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("dm_\(tid)_\(UUID().uuidString)")
        try? FileManager.default.copyItem(at: location, to: dest)
        Task { @MainActor in
            self.taskKeys.removeValue(forKey: tid)
            if let completion = self.taskCompletions.removeValue(forKey: tid) {
                completion(.success(dest))
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        let tid = task.taskIdentifier
        Task { @MainActor in
            if let key = self.taskKeys[tid] { self.progress.removeValue(forKey: key) }
            self.taskKeys.removeValue(forKey: tid)
            if let completion = self.taskCompletions.removeValue(forKey: tid) {
                completion(.failure(error))
            }
        }
    }
}
