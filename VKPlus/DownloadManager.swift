import Foundation
import UIKit

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var progress: [String: Double] = [:]

    private var session: URLSession!
    // Key by task identifier — eliminates URL mismatch on redirect
    private var taskCompletions: [Int: (Result<URL, Error>) -> Void] = [:]
    private var taskKeys: [Int: String] = [:]

    private override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.protocolClasses = (cfg.protocolClasses ?? []).filter { $0 != PrivacyURLProtocol.self }
        // Follow redirects automatically
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func download(from urlStr: String) async throws -> URL {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        return try await withCheckedThrowingContinuation { cont in
            Task { @MainActor in
                self.progress[urlStr] = 0.001 // show ring immediately
                var req = URLRequest(url: url)
                req.timeoutInterval = 120
                let task = self.session.downloadTask(with: req)
                let tid = task.taskIdentifier
                self.taskCompletions[tid] = { result in
                    cont.resume(with: result)
                }
                self.taskKeys[tid] = urlStr
                task.resume()
            }
        }
    }

    func cancel(urlStr: String) {
        for (tid, key) in taskKeys where key == urlStr {
            // find task by id
            session.getAllTasks { tasks in
                tasks.filter { $0.taskIdentifier == tid }.forEach { $0.cancel() }
            }
            taskKeys.removeValue(forKey: tid)
            taskCompletions.removeValue(forKey: tid)
        }
        progress.removeValue(forKey: urlStr)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData _: Int64,
                                totalBytesWritten written: Int64,
                                totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        let pct = max(0.001, Double(written) / Double(total))
        let tid = downloadTask.taskIdentifier
        Task { @MainActor in
            if let key = self.taskKeys[tid] {
                self.progress[key] = pct
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let tid = downloadTask.taskIdentifier
        // Copy to stable temp path before delegate returns (file deleted after)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("dm_\(tid)_\(location.lastPathComponent)")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: location, to: dest)
        Task { @MainActor in
            if let key = self.taskKeys[tid] {
                self.progress.removeValue(forKey: key)
            }
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
            if let key = self.taskKeys[tid] {
                self.progress.removeValue(forKey: key)
            }
            self.taskKeys.removeValue(forKey: tid)
            if let completion = self.taskCompletions.removeValue(forKey: tid) {
                completion(.failure(error))
            }
        }
    }
}
