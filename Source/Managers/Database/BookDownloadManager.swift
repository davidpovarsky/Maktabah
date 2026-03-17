//
//  BookDownloadManager.swift
//  Maktabah
//
//  Created by Codex on 11/03/26.
//  Manages per-book downloads for bundle mode
//

import Foundation
import Network

enum BookDownloadError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(bookId: Int, statusCode: Int)
    case downloadFailed(bookId: Int)
    case decompressionFailed(bookId: Int, reason: String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return String(localized: "error.invalidBaseURL")
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .httpStatus(let bookId, let statusCode):
            return String(localized: "error.httpStatus.\(bookId).\(statusCode)")
        case .downloadFailed(let bookId):
            return String(localized: "error.downloadFailed.\(bookId)")
        case .decompressionFailed(let bookId, let reason):
            return String(localized: "error.decompressionFailed.\(bookId).\(reason)")
        case .networkUnavailable:
            return String(localized: "error.networkUnavailable")
        }
    }
}

actor BookDownloadSingleFlight {
    static let shared = BookDownloadSingleFlight()

    private var runningTasks: [Int: Task<URL, Error>] = [:]

    private init() {}

    func run(
        bookId: Int,
        operation: @escaping () async throws -> URL
    ) async throws -> URL {
        if let existingTask = runningTasks[bookId] {
            return try await existingTask.value
        }

        let task = Task {
            try await operation()
        }
        runningTasks[bookId] = task

        do {
            let result = try await task.value
            runningTasks.removeValue(forKey: bookId)
            return result
        } catch {
            runningTasks.removeValue(forKey: bookId)
            throw error
        }
    }

    func cancelAll() {
        for (_, task) in runningTasks {
            task.cancel()
        }
        runningTasks.removeAll()
    }
}

final class BookDownloadManager {
    static let shared = BookDownloadManager()

    private let fileManager = FileManager.default
    private let networkMonitor = NetworkMonitor.shared
    private let indexCache = BookDownloadIndexCache.shared

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 3600
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private init() {
        networkMonitor.onConnectivityLost = { [weak self] in
            Task {
                await self?.cancelAllDownloads()
            }
        }
    }

    func localBookURL(bookId: Int) -> URL? {
        guard let basePath = AppConfig.bookFilesPath else { return nil }
        let url = URL(fileURLWithPath: basePath)
            .appendingPathComponent("\(bookId).sqlite")

        guard fileExistsAndHasSize(url) else { return nil }
        return url
    }

    func ensureBookDownloaded(bookId: Int) async throws -> URL {
        if let local = localBookURL(bookId: bookId) {
            return local
        }

        return try await BookDownloadSingleFlight.shared.run(bookId: bookId) {
            if let local = self.localBookURL(bookId: bookId) {
                return local
            }
            return try await self.downloadBook(bookId: bookId)
        }
    }

    private func downloadBook(bookId: Int) async throws -> URL {
        guard networkMonitor.isConnected else {
            throw BookDownloadError.networkUnavailable
        }
        guard let destinationDir = AppConfig.bookFilesPath else {
            throw ArchiveError.databasePathNotAvailable
        }

        let destinationURL = URL(fileURLWithPath: destinationDir)
            .appendingPathComponent("\(bookId).sqlite")

        let candidates = await candidateURLs(for: bookId)
        guard !candidates.isEmpty else {
            throw BookDownloadError.invalidBaseURL
        }
        var lastError: Error?

        for candidate in candidates {
            do {
                try Task.checkCancellation()
                guard networkMonitor.isConnected else {
                    throw BookDownloadError.networkUnavailable
                }
                let (tempURL, response) = try await urlSession.download(from: candidate)
                defer { try? fileManager.removeItem(at: tempURL) }

                guard let http = response as? HTTPURLResponse else {
                    throw BookDownloadError.invalidResponse
                }

                guard (200..<300).contains(http.statusCode) else {
                    throw BookDownloadError.httpStatus(bookId: bookId, statusCode: http.statusCode)
                }

                if candidate.pathExtension.lowercased() == "zst" {
                    try decompressZstdFile(
                        from: tempURL,
                        to: destinationURL,
                        bookId: bookId
                    )
                } else {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.moveItem(at: tempURL, to: destinationURL)
                }

                guard fileExistsAndHasSize(destinationURL) else {
                    throw BookDownloadError.downloadFailed(bookId: bookId)
                }

                return destinationURL
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? BookDownloadError.downloadFailed(bookId: bookId)
    }

    func removeCachedBook(bookId: Int) {
        guard let basePath = AppConfig.bookFilesPath else { return }
        let url = URL(fileURLWithPath: basePath)
            .appendingPathComponent("\(bookId).sqlite")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    func cancelAllDownloads() async {
        await BookDownloadSingleFlight.shared.cancelAll()
    }

    private func candidateURLs(for bookId: Int) async -> [URL] {
        var urls: [URL] = []

        if let indexURL = AppConfig.bookIndexURL,
           let releaseBase = AppConfig.bookReleaseBaseURL {
            if let entry = try? await indexCache.entry(
                for: bookId,
                indexURL: indexURL,
                urlSession: urlSession
            ) {
                let releaseURL = releaseBase
                    .appendingPathComponent(entry.release)
                    .appendingPathComponent(entry.filename)
                urls.append(releaseURL)

                if entry.filename.lowercased().hasSuffix(".sqlite.zst") {
                    let sqliteName = String(entry.filename.dropLast(4))
                    urls.append(
                        releaseBase
                            .appendingPathComponent(entry.release)
                            .appendingPathComponent(sqliteName)
                    )
                }
            }
        }

        if AppConfig.hasCustomBookDownloadBaseURL,
           let baseURL = AppConfig.bookDownloadBaseURL {
            let sqliteName = "\(bookId).sqlite"
            let zstName = "\(bookId).sqlite.zst"
            urls.append(baseURL.appendingPathComponent(zstName))
            urls.append(baseURL.appendingPathComponent(sqliteName))
        }

        return urls
    }

    private func fileExistsAndHasSize(_ url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        return size > 0
    }

    private func decompressZstdFile(
        from sourceURL: URL,
        to destinationURL: URL,
        bookId: Int
    ) throws {
        let compressed = try Data(contentsOf: sourceURL)
        guard !compressed.isEmpty else {
            throw BookDownloadError.decompressionFailed(bookId: bookId, reason: "Empty file")
        }

        let expectedSize = ZSTD_getFrameContentSize(
            (compressed as NSData).bytes,
            compressed.count
        )

        if expectedSize == ZSTD_CONTENTSIZE_ERROR || expectedSize == ZSTD_CONTENTSIZE_UNKNOWN {
            throw BookDownloadError.decompressionFailed(bookId: bookId, reason: "Unknown content size")
        }

        var output = Data(count: Int(expectedSize))
        let decompressedSize = output.withUnsafeMutableBytes { outPtr in
            return compressed.withUnsafeBytes { inPtr in
                return ZSTD_decompress(
                    outPtr.baseAddress,
                    Int(expectedSize),
                    inPtr.baseAddress,
                    compressed.count
                )
            }
        }

        if ZSTD_isError(decompressedSize) != 0 {
            let errorName = String(cString: ZSTD_getErrorName(decompressedSize))
            throw BookDownloadError.decompressionFailed(bookId: bookId, reason: errorName)
        }

        output.count = decompressedSize

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try output.write(to: destinationURL, options: [.atomic])
    }
}

// MARK: - Book Download Index

private struct BundleBookIndexEntry: Decodable {
    let bkid: Int
    let filename: String
    let release: String
}

private actor BookDownloadIndexCache {
    static let shared = BookDownloadIndexCache()

    private var cachedEntries: [Int: BundleBookIndexEntry] = [:]
    private var lastFetch: Date?
    private var inFlight: Task<[Int: BundleBookIndexEntry], Error>?
    private let ttl: TimeInterval = 60 * 60
    private let etagKey = "book_index_etag"
    private let lastModifiedKey = "book_index_last_modified"

    func entry(
        for bookId: Int,
        indexURL: URL,
        urlSession: URLSession
    ) async throws -> BundleBookIndexEntry? {
        if cachedEntries.isEmpty {
            loadCachedIndexIfNeeded()
        }
        if let cached = cachedEntries[bookId] {
            return cached
        }

        let now = Date()
        if let lastFetch,
           now.timeIntervalSince(lastFetch) < ttl,
           !cachedEntries.isEmpty {
            return cachedEntries[bookId]
        }

        let entries = try await fetchIndex(
            indexURL: indexURL,
            urlSession: urlSession
        )
        return entries[bookId]
    }

    private func fetchIndex(
        indexURL: URL,
        urlSession: URLSession
    ) async throws -> [Int: BundleBookIndexEntry] {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task { () throws -> [Int: BundleBookIndexEntry] in
            var request = URLRequest(url: indexURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let defaults = UserDefaults.standard
            if let etag = defaults.string(forKey: etagKey) {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastModified = defaults.string(forKey: lastModifiedKey) {
                request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
            }

            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BookDownloadError.invalidResponse
            }

            if http.statusCode == 304 {
                if cachedEntries.isEmpty {
                    loadCachedIndexIfNeeded()
                }
                guard !cachedEntries.isEmpty else {
                    throw BookDownloadError.invalidResponse
                }
                return cachedEntries
            }

            guard (200..<300).contains(http.statusCode) else {
                throw BookDownloadError.invalidResponse
            }

            let decoder = JSONDecoder()
            let entries = try decoder.decode([BundleBookIndexEntry].self, from: data)
            var mapped: [Int: BundleBookIndexEntry] = [:]
            mapped.reserveCapacity(entries.count)
            for entry in entries {
                mapped[entry.bkid] = entry
            }

            if let etag = http.value(forHTTPHeaderField: "ETag") {
                defaults.set(etag, forKey: etagKey)
            }
            if let lastModified = http.value(forHTTPHeaderField: "Last-Modified") {
                defaults.set(lastModified, forKey: lastModifiedKey)
            }
            saveCachedIndex(data: data)
            return mapped
        }

        inFlight = task
        do {
            let result = try await task.value
            cachedEntries = result
            lastFetch = Date()
            inFlight = nil
            return result
        } catch {
            inFlight = nil
            throw error
        }
    }

    private func cacheFileURL() -> URL? {
        guard let cachePath = AppConfig.archiveCachePath else { return nil }
        return URL(fileURLWithPath: cachePath).appendingPathComponent("index.json")
    }

    private func loadCachedIndexIfNeeded() {
        guard let fileURL = cacheFileURL(),
              let data = try? Data(contentsOf: fileURL) else {
            return
        }
        let decoder = JSONDecoder()
        guard let entries = try? decoder.decode([BundleBookIndexEntry].self, from: data) else {
            return
        }
        var mapped: [Int: BundleBookIndexEntry] = [:]
        mapped.reserveCapacity(entries.count)
        for entry in entries {
            _ = entry.bkid
            mapped[entry.bkid] = entry
        }
        cachedEntries = mapped
    }

    private func saveCachedIndex(data: Data) {
        guard let fileURL = cacheFileURL() else { return }
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
                print("Failed to cache index.json:", error)
            #endif
        }
    }
}

// MARK: - Network Monitor

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "maktabah.network.monitor")
    private let lock = NSLock()
    private var _isConnected = true
    var onConnectivityLost: (() -> Void)?

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = (path.status == .satisfied)
            var shouldNotify = false
            lock.lock()
            if _isConnected && !connected {
                shouldNotify = true
            }
            _isConnected = connected
            lock.unlock()

            if shouldNotify {
                onConnectivityLost?()
            }
        }
        monitor.start(queue: queue)
    }
}
