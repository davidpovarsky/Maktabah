import CryptoKit
import Foundation

actor OtzariaSearchArtifactDownloader {
    typealias ProgressHandler = @Sendable (_ completed: Int64, _ total: Int64) -> Void

    private var activeTask: URLSessionDataTask?
    private var cancellationRequested = false

    func cancel() {
        cancellationRequested = true
        activeTask?.cancel()
    }

    func downloadAndVerify(
        artifact: OtzariaResolvedSearchArtifact,
        workspaceURL: URL,
        progress: @escaping ProgressHandler
    ) async throws -> [String: URL] {
        cancellationRequested = false
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try excludeFromBackup(workspaceURL)
        let parts = artifact.manifest.lexicalArtifact.parts
        let total = artifact.manifest.lexicalArtifact.packagedBytes
        var completed = existingVerifiedBytes(parts: parts, workspaceURL: workspaceURL)
        progress(completed, total)
        var result: [String: URL] = [:]

        for part in parts {
            try checkCancellation()
            guard let remoteURL = artifact.partURLs[part.assetName] else {
                throw OtzariaSearchArtifactError.missingPart(part.assetName)
            }
            let localURL = partURL(part, workspaceURL: workspaceURL)
            if try verifyIfComplete(localURL, part: part) {
                result[part.assetName] = localURL
                continue
            }
            let baseCompleted = completed
            try await downloadPart(part, from: remoteURL, to: localURL) { received in
                progress(baseCompleted + received, total)
            }
            try verify(localURL, part: part)
            completed += part.packagedBytes
            progress(completed, total)
            result[part.assetName] = localURL
        }
        return result
    }

    func existingBytes(
        manifest: OtzariaSearchArtifactManifest,
        workspaceURL: URL
    ) -> Int64 {
        manifest.lexicalArtifact.parts.reduce(0) { total, part in
            let size = fileSize(partURL(part, workspaceURL: workspaceURL))
            return total + min(max(0, size), part.packagedBytes)
        }
    }

    func cleanup(workspaceURL: URL) {
        try? FileManager.default.removeItem(at: workspaceURL)
    }
}

private extension OtzariaSearchArtifactDownloader {
    func checkCancellation() throws {
        if cancellationRequested || Task.isCancelled {
            throw OtzariaSearchArtifactError.cancelled
        }
    }

    func downloadPart(
        _ part: OtzariaSearchArtifactManifest.Part,
        from remoteURL: URL,
        to localURL: URL,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        var restartCount = 0
        while true {
            try checkCancellation()
            var offset = fileSize(localURL)
            if offset > part.packagedBytes {
                try? FileManager.default.removeItem(at: localURL)
                offset = 0
            }
            if offset == part.packagedBytes { return }

            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 60
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("Maktabah-iOS-Otzaria-Search", forHTTPHeaderField: "User-Agent")
            if offset > 0 { request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range") }

            let delegate = OtzariaArtifactDownloadDelegate(
                outputURL: localURL,
                requestedOffset: offset,
                expectedBytes: part.packagedBytes,
                progress: progress
            )
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 24 * 60 * 60
            configuration.httpMaximumConnectionsPerHost = 1
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
            let task = session.dataTask(with: request)
            activeTask = task
            do {
                let outcome = try await delegate.run(task: task)
                activeTask = nil
                session.finishTasksAndInvalidate()
                switch outcome {
                case .complete:
                    return
                case .restart:
                    restartCount += 1
                    guard restartCount <= 1 else {
                        throw OtzariaSearchArtifactError.downloadFailed("server refused a valid range")
                    }
                    try? FileManager.default.removeItem(at: localURL)
                }
            } catch {
                activeTask = nil
                session.invalidateAndCancel()
                if cancellationRequested || (error as? URLError)?.code == .cancelled {
                    throw OtzariaSearchArtifactError.cancelled
                }
                throw error
            }
        }
    }

    func verifyIfComplete(
        _ url: URL,
        part: OtzariaSearchArtifactManifest.Part
    ) throws -> Bool {
        guard fileSize(url) == part.packagedBytes else { return false }
        do {
            try verify(url, part: part)
            return true
        } catch {
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    func verify(_ url: URL, part: OtzariaSearchArtifactManifest.Part) throws {
        let actualSize = fileSize(url)
        guard actualSize == part.packagedBytes else {
            throw OtzariaSearchArtifactError.sizeMismatch(
                asset: part.assetName,
                expected: part.packagedBytes,
                actual: actualSize
            )
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try checkCancellation()
            let data = try handle.read(upToCount: 4 * 1_024 * 1_024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == part.sha256.lowercased() else {
            throw OtzariaSearchArtifactError.digestMismatch(asset: part.assetName)
        }
    }

    func existingVerifiedBytes(
        parts: [OtzariaSearchArtifactManifest.Part],
        workspaceURL: URL
    ) -> Int64 {
        parts.reduce(0) { total, part in
            fileSize(partURL(part, workspaceURL: workspaceURL)) == part.packagedBytes
                ? total + part.packagedBytes : total
        }
    }

    func partURL(_ part: OtzariaSearchArtifactManifest.Part, workspaceURL: URL) -> URL {
        workspaceURL.appendingPathComponent("\(part.sha256).part")
    }

    func fileSize(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    func excludeFromBackup(_ url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
}

private enum OtzariaArtifactDownloadOutcome {
    case complete
    case restart
}

private final class OtzariaArtifactDownloadDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    private let outputURL: URL
    private let requestedOffset: Int64
    private let expectedBytes: Int64
    private let progress: @Sendable (Int64) -> Void
    private var handle: FileHandle?
    private var received: Int64
    private var continuation: CheckedContinuation<OtzariaArtifactDownloadOutcome, Error>?
    private var outcome: OtzariaArtifactDownloadOutcome?
    private var terminalError: Error?

    init(
        outputURL: URL,
        requestedOffset: Int64,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) {
        self.outputURL = outputURL
        self.requestedOffset = requestedOffset
        self.expectedBytes = expectedBytes
        self.progress = progress
        received = requestedOffset
    }

    func run(task: URLSessionDataTask) async throws -> OtzariaArtifactDownloadOutcome {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        do {
            guard let http = response as? HTTPURLResponse else {
                throw OtzariaSearchArtifactError.downloadFailed("non-HTTP response")
            }
            if requestedOffset > 0 && http.statusCode == 200 {
                outcome = .restart
                completionHandler(.cancel)
                return
            }
            guard http.statusCode == (requestedOffset > 0 ? 206 : 200) else {
                throw OtzariaSearchArtifactError.downloadFailed("HTTP \(http.statusCode)")
            }
            if requestedOffset > 0 {
                let prefix = "bytes \(requestedOffset)-"
                guard http.value(forHTTPHeaderField: "Content-Range")?.hasPrefix(prefix) == true else {
                    throw OtzariaSearchArtifactError.downloadFailed("invalid Content-Range")
                }
            }
            if requestedOffset == 0 {
                FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            }
            handle = try FileHandle(forWritingTo: outputURL)
            try handle?.seekToEnd()
            progress(received)
            completionHandler(.allow)
        } catch {
            terminalError = error
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard terminalError == nil, outcome == nil else { return }
        do {
            received += Int64(data.count)
            guard received <= expectedBytes else {
                throw OtzariaSearchArtifactError.sizeMismatch(
                    asset: outputURL.lastPathComponent,
                    expected: expectedBytes,
                    actual: received
                )
            }
            try handle?.write(contentsOf: data)
            progress(received)
        } catch {
            terminalError = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil
        let continuation = continuation
        self.continuation = nil
        if let terminalError {
            continuation?.resume(throwing: terminalError)
        } else if let outcome {
            continuation?.resume(returning: outcome)
        } else if let error {
            continuation?.resume(throwing: error)
        } else if received == expectedBytes {
            continuation?.resume(returning: .complete)
        } else {
            continuation?.resume(throwing: OtzariaSearchArtifactError.sizeMismatch(
                asset: outputURL.lastPathComponent,
                expected: expectedBytes,
                actual: received
            ))
        }
    }
}
