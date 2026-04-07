import Foundation
import UIKit

// MARK: - DownloadManager
// Singleton that tracks download progress per URL
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    // progress 0.0 ... 1.0 per URL
    @Published var progress: [String: Double] = [:]

    private var session: URLSession!
    private var completions: [URL: (Result<URL, Error>) -> Void] = [:]
    private var urlMap: [URLSessionTask: String] = [:]

    private override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.protocolClasses = (cfg.protocolClasses ?? []).filter { $0 != PrivacyURLProtocol.self }
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func download(from urlStr: String) async throws -> URL {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        return try await withCheckedThrowingContinuation { cont in
            Task { @MainActor in
                self.progress[urlStr] = 0.0
                let task = self.session.downloadTask(with: url)
                self.completions[url] = { result in
                    Task { @MainActor in self.progress.removeValue(forKey: urlStr) }
                    cont.resume(with: result)
                }
                self.urlMap[task] = urlStr
                task.resume()
            }
        }
    }

    func cancel(urlStr: String) {
        for (task, key) in urlMap where key == urlStr {
            task.cancel()
        }
        progress.removeValue(forKey: urlStr)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData _: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(total)
        let key = downloadTask.originalRequest?.url?.absoluteString ?? ""
        Task { @MainActor in self.progress[key] = pct }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let key  = downloadTask.originalRequest?.url?.absoluteString ?? ""
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(location.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: location, to: dest)
        let origUrl = downloadTask.originalRequest?.url
        Task { @MainActor in
            self.urlMap.removeValue(forKey: downloadTask)
            if let u = origUrl, let completion = self.completions[u] {
                self.completions.removeValue(forKey: u)
                completion(.success(dest))
            }
            self.progress.removeValue(forKey: key)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        let origUrl = task.originalRequest?.url
        Task { @MainActor in
            self.urlMap.removeValue(forKey: task)
            if let u = origUrl, let completion = self.completions[u] {
                self.completions.removeValue(forKey: u)
                completion(.failure(error))
            }
            let key = task.originalRequest?.url?.absoluteString ?? ""
            self.progress.removeValue(forKey: key)
        }
    }
}
