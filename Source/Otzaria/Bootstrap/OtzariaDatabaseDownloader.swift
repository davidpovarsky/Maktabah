import CryptoKit
import Foundation

actor OtzariaDatabaseDownloader {
    typealias ProgressHandler = @Sendable (_ downloaded: Int64, _ total: Int64, _ resumedFrom: Int64) -> Void

    static let partFileName = "seforim.db.zst.part"
    static let sidecarFileName = "seforim.db.zst.part.json"

    private var activeTask: URLSessionDataTask?
    private var cancellationRequested = false
    private var isDownloading = false

    func cancel() {
        cancellationRequested = true
        activeTask?.cancel()
    }

    func download(
        release: OtzariaLibraryRelease,
        workspaceURL: URL,
        progress: @escaping ProgressHandler
    ) async throws -> URL {
        guard !isDownloading else {
            throw OtzariaDatabaseBootstrapError.invalidResumeResponse(
                "another Otzaria database download is already active"
            )
        }
        isDownloading = true
        defer { isDownloading = false }
        cancellationRequested = false

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try Self.excludeFromBackup(workspaceURL)

        let partURL = workspaceURL.appendingPathComponent(Self.partFileName)
        let sidecarURL = workspaceURL.appendingPathComponent(Self.sidecarFileName)
        try prepareDownloadState(
            release: release,
            partURL: partURL,
            sidecarURL: sidecarURL
        )

        var noProgressRounds = 0
        var forcedFreshRestarts = 0

        while true {
            try checkCancellation()

            let currentLength = Self.fileSize(at: partURL)
            if currentLength == release.asset.compressedSize {
                progress(currentLength, release.asset.compressedSize, currentLength)
                return partURL
            }
            if currentLength > release.asset.compressedSize {
                try invalidate(partURL: partURL, sidecarURL: sidecarURL)
                try writeMetadata(
                    OtzariaDownloadResumeMetadata(release: release),
                    to: sidecarURL
                )
            }

            var metadata = try loadMetadata(from: sidecarURL)
                ?? OtzariaDownloadResumeMetadata(release: release)
            let offset = Self.fileSize(at: partURL)
            let reusableOffset = OtzariaDownloadPolicy.reusableOffset(
                metadata: metadata,
                release: release,
                localSize: offset
            )
            let validator = metadata.resumeValidator
            let canResume = reusableOffset > 0 && reusableOffset < release.asset.compressedSize

            if offset > 0 && !canResume {
                try invalidate(partURL: partURL, sidecarURL: sidecarURL)
                metadata = OtzariaDownloadResumeMetadata(release: release)
                try writeMetadata(metadata, to: sidecarURL)
            }

            let actualOffset = canResume ? reusableOffset : 0
            let delegate = OtzariaDownloadRoundDelegate(
                release: release,
                partURL: partURL,
                sidecarURL: sidecarURL,
                metadata: metadata,
                requestedOffset: actualOffset,
                validator: canResume ? validator : nil,
                progress: progress
            )
            let request = Self.makeRequest(
                release: release,
                offset: actualOffset,
                validator: canResume ? validator : nil
            )

            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60 * 60 * 24
            configuration.httpMaximumConnectionsPerHost = 1
            let queue = OperationQueue()
            queue.name = "Otzaria database download"
            queue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
            let task = session.dataTask(with: request)
            activeTask = task

            let outcome: OtzariaDownloadRoundOutcome
            do {
                outcome = try await delegate.run(task: task)
            } catch {
                activeTask = nil
                session.invalidateAndCancel()
                if cancellationRequested || (error as? URLError)?.code == .cancelled {
                    throw OtzariaDatabaseBootstrapError.cancelled
                }
                throw error
            }
            activeTask = nil
            session.finishTasksAndInvalidate()

            switch outcome {
            case .restartFresh(let reason):
                forcedFreshRestarts += 1
                guard forcedFreshRestarts <= 2 else {
                    throw OtzariaDatabaseBootstrapError.invalidResumeResponse(reason)
                }
                try invalidate(partURL: partURL, sidecarURL: sidecarURL)
                try writeMetadata(
                    OtzariaDownloadResumeMetadata(release: release),
                    to: sidecarURL
                )
                continue
            case .complete:
                return partURL
            case .receivedBody:
                let newLength = Self.fileSize(at: partURL)
                if newLength == release.asset.compressedSize { return partURL }
                if newLength > release.asset.compressedSize {
                    try invalidate(partURL: partURL, sidecarURL: sidecarURL)
                    throw OtzariaDatabaseBootstrapError.downloadSizeMismatch(
                        expected: release.asset.compressedSize,
                        actual: newLength
                    )
                }
                if newLength <= actualOffset {
                    noProgressRounds += 1
                    guard noProgressRounds < 2 else {
                        throw OtzariaDatabaseBootstrapError.downloadSizeMismatch(
                            expected: release.asset.compressedSize,
                            actual: newLength
                        )
                    }
                } else {
                    noProgressRounds = 0
                }
            }
        }
    }

    func invalidateDownload(workspaceURL: URL) throws {
        try invalidate(
            partURL: workspaceURL.appendingPathComponent(Self.partFileName),
            sidecarURL: workspaceURL.appendingPathComponent(Self.sidecarFileName)
        )
    }

    func cleanupAfterSuccessfulInstall(workspaceURL: URL) {
        let fileManager = FileManager.default
        for name in [Self.partFileName, Self.sidecarFileName] {
            let url = workspaceURL.appendingPathComponent(name)
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            } catch {
                print("[OtzariaBootstrap] cleanup failed for \(name): \(error.localizedDescription)")
            }
        }
    }

    static func verifyDownload(at url: URL, release: OtzariaLibraryRelease) throws {
        let actualSize = fileSize(at: url)
        guard actualSize == release.asset.compressedSize else {
            throw OtzariaDatabaseBootstrapError.downloadSizeMismatch(
                expected: release.asset.compressedSize,
                actual: actualSize
            )
        }
        guard let expected = release.expectedSHA256 else { return }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 4 * 1_024 * 1_024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw OtzariaDatabaseBootstrapError.digestMismatch(expected: expected, actual: actual)
        }
    }

    static func existingPartialSize(workspaceURL: URL, release: OtzariaLibraryRelease) -> Int64 {
        let partURL = workspaceURL.appendingPathComponent(Self.partFileName)
        let sidecarURL = workspaceURL.appendingPathComponent(Self.sidecarFileName)
        let metadata = try? loadMetadata(from: sidecarURL)
        return OtzariaDownloadPolicy.reusableOffset(
            metadata: metadata,
            release: release,
            localSize: fileSize(at: partURL)
        )
    }
}

extension OtzariaDatabaseDownloader {
    func checkCancellation() throws {
        if cancellationRequested || Task.isCancelled {
            throw OtzariaDatabaseBootstrapError.cancelled
        }
    }

    func prepareDownloadState(
        release: OtzariaLibraryRelease,
        partURL: URL,
        sidecarURL: URL
    ) throws {
        let metadata = try Self.loadMetadata(from: sidecarURL)
        let partExists = FileManager.default.fileExists(atPath: partURL.path)
        guard partExists || metadata != nil else {
            try Self.writeMetadata(OtzariaDownloadResumeMetadata(release: release), to: sidecarURL)
            return
        }
        guard let metadata, metadata.matches(release) else {
            try invalidate(partURL: partURL, sidecarURL: sidecarURL)
            try Self.writeMetadata(OtzariaDownloadResumeMetadata(release: release), to: sidecarURL)
            return
        }
        if !partExists, metadata.downloadedBytes > 0 {
            try invalidate(partURL: partURL, sidecarURL: sidecarURL)
            try Self.writeMetadata(OtzariaDownloadResumeMetadata(release: release), to: sidecarURL)
        }
    }

    func invalidate(partURL: URL, sidecarURL: URL) throws {
        let fileManager = FileManager.default
        for url in [partURL, sidecarURL] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func makeRequest(
        release: OtzariaLibraryRelease,
        offset: Int64,
        validator: String?
    ) -> URLRequest {
        var request = URLRequest(url: release.asset.downloadURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("Maktabah-iOS-Otzaria-Library", forHTTPHeaderField: "User-Agent")
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
            if let validator { request.setValue(validator, forHTTPHeaderField: "If-Range") }
        }
        return request
    }

    static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func loadMetadata(from url: URL) throws -> OtzariaDownloadResumeMetadata? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OtzariaDownloadResumeMetadata.self, from: data)
    }

    static func writeMetadata(_ metadata: OtzariaDownloadResumeMetadata, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(metadata).write(to: url, options: .atomic)
        try excludeFromBackup(url)
    }

    static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}

private enum OtzariaDownloadRoundOutcome {
    case receivedBody
    case complete
    case restartFresh(String)
}

private final class OtzariaDownloadRoundDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    private let release: OtzariaLibraryRelease
    private let partURL: URL
    private let sidecarURL: URL
    private var metadata: OtzariaDownloadResumeMetadata
    private let requestedOffset: Int64
    private let validator: String?
    private let progress: OtzariaDatabaseDownloader.ProgressHandler

    private var continuation: CheckedContinuation<OtzariaDownloadRoundOutcome, Error>?
    private var fileHandle: FileHandle?
    private var result: OtzariaDownloadRoundOutcome?
    private var terminalError: Error?
    private var receivedBytes: Int64 = 0
    private var lastPersistedBytes: Int64 = 0
    private var didFinish = false

    init(
        release: OtzariaLibraryRelease,
        partURL: URL,
        sidecarURL: URL,
        metadata: OtzariaDownloadResumeMetadata,
        requestedOffset: Int64,
        validator: String?,
        progress: @escaping OtzariaDatabaseDownloader.ProgressHandler
    ) {
        self.release = release
        self.partURL = partURL
        self.sidecarURL = sidecarURL
        self.metadata = metadata
        self.requestedOffset = requestedOffset
        self.validator = validator
        self.progress = progress
    }

    func run(task: URLSessionDataTask) async throws -> OtzariaDownloadRoundOutcome {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirected = request
        redirected.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        redirected.setValue("Maktabah-iOS-Otzaria-Library", forHTTPHeaderField: "User-Agent")
        if requestedOffset > 0 {
            redirected.setValue("bytes=\(requestedOffset)-", forHTTPHeaderField: "Range")
            if let validator { redirected.setValue(validator, forHTTPHeaderField: "If-Range") }
        }
        completionHandler(redirected)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            terminalError = OtzariaDatabaseBootstrapError.invalidResumeResponse("non-HTTP response")
            completionHandler(.cancel)
            return
        }

        print(
            "[OtzariaBootstrap] download response status=\(http.statusCode) " +
            "resumeOffset=\(requestedOffset) host=\(http.url?.host ?? "unknown")"
        )

        let responseAction = OtzariaDownloadPolicy.responseAction(
            statusCode: http.statusCode,
            requestedOffset: requestedOffset,
            localSize: OtzariaDatabaseDownloader.fileSize(at: partURL),
            expectedSize: release.asset.compressedSize,
            contentRange: http.value(forHTTPHeaderField: "Content-Range")
        )
        switch responseAction {
        case .complete:
            result = .complete
            completionHandler(.cancel)
            return
        case .restartFresh(let reason):
            result = .restartFresh(reason)
            completionHandler(.cancel)
            return
        case .failHTTP(let status):
            terminalError = OtzariaDatabaseBootstrapError.downloadHTTPError(status)
            completionHandler(.cancel)
            return
        case .acceptFresh, .append:
            break
        }

        let responseETag = Self.strongETag(http.value(forHTTPHeaderField: "ETag"))
        let responseLastModified = http.value(forHTTPHeaderField: "Last-Modified")
        if http.statusCode == 206, let validator {
            if validator.hasPrefix("\"") && responseETag != nil && responseETag != validator {
                result = .restartFresh("ETag changed during resume")
                completionHandler(.cancel)
                return
            }
            if !validator.hasPrefix("\""),
               let responseLastModified,
               responseLastModified != validator {
                result = .restartFresh("Last-Modified changed during resume")
                completionHandler(.cancel)
                return
            }
        }

        do {
            if http.statusCode == 200 {
                if FileManager.default.fileExists(atPath: partURL.path) {
                    fileHandle = try FileHandle(forWritingTo: partURL)
                    try fileHandle?.truncate(atOffset: 0)
                } else {
                    FileManager.default.createFile(atPath: partURL.path, contents: nil)
                    fileHandle = try FileHandle(forWritingTo: partURL)
                }
                receivedBytes = 0
            } else {
                guard OtzariaDatabaseDownloader.fileSize(at: partURL) == requestedOffset else {
                    result = .restartFresh("the partial file changed before append")
                    completionHandler(.cancel)
                    return
                }
                fileHandle = try FileHandle(forWritingTo: partURL)
                try fileHandle?.seekToEnd()
                receivedBytes = requestedOffset
            }

            metadata.etag = responseETag
            metadata.lastModified = responseLastModified
            metadata.downloadedBytes = receivedBytes
            metadata.updatedAt = Date()
            try OtzariaDatabaseDownloader.writeMetadata(metadata, to: sidecarURL)
            try OtzariaDatabaseDownloader.excludeFromBackup(partURL)
            lastPersistedBytes = receivedBytes
            progress(receivedBytes, release.asset.compressedSize, requestedOffset)
            completionHandler(.allow)
        } catch {
            terminalError = error
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard terminalError == nil, result == nil else { return }
        do {
            guard receivedBytes + Int64(data.count) <= release.asset.compressedSize else {
                throw OtzariaDatabaseBootstrapError.downloadSizeMismatch(
                    expected: release.asset.compressedSize,
                    actual: receivedBytes + Int64(data.count)
                )
            }
            try fileHandle?.write(contentsOf: data)
            receivedBytes += Int64(data.count)
            progress(receivedBytes, release.asset.compressedSize, requestedOffset)

            if receivedBytes - lastPersistedBytes >= 32 * 1_024 * 1_024 {
                metadata.downloadedBytes = receivedBytes
                metadata.updatedAt = Date()
                try OtzariaDatabaseDownloader.writeMetadata(metadata, to: sidecarURL)
                lastPersistedBytes = receivedBytes
            }
        } catch {
            terminalError = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !didFinish else { return }
        didFinish = true

        do {
            try fileHandle?.synchronize()
            try fileHandle?.close()
        } catch where terminalError == nil {
            terminalError = OtzariaDatabaseBootstrapError.extractionWriteFailed(error.localizedDescription)
        }
        fileHandle = nil

        metadata.downloadedBytes = OtzariaDatabaseDownloader.fileSize(at: partURL)
        metadata.updatedAt = Date()
        try? OtzariaDatabaseDownloader.writeMetadata(metadata, to: sidecarURL)

        let continuation = continuation
        self.continuation = nil
        if let terminalError {
            continuation?.resume(throwing: terminalError)
        } else if let result {
            continuation?.resume(returning: result)
        } else if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: .receivedBody)
        }
    }

    private static func strongETag(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.hasPrefix("W/") else { return nil }
        return value
    }

}
