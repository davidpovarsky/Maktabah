//
//  CoreDatabaseDownloader.swift
//  Maktabah
//
//  Mengelola download main.sqlite + special.sqlite dari GitHub Releases
//  ke ~/Library/Application Support/Maktabah/Caches/
//

import AppKit
import Foundation
import SwiftUI

// MARK: - CoreFile

enum CoreFile: CaseIterable {
    case main
    case special

    /// Nama file hasil dekompresi yang disimpan ke disk
    var filename: String {
        switch self {
        case .main:    return "main.sqlite"
        case .special: return "special.sqlite"
        }
    }

    /// Nama file asset di GitHub Release (selalu .zst)
    var releaseFilename: String { filename + ".zst" }
}

// MARK: - CoreDownloadError

enum CoreDownloadError: LocalizedError {
    case invalidBaseURL
    case destinationUnavailable
    case invalidResponse
    case httpStatus(file: String, statusCode: Int)
    case downloadFailed(file: String)
    case decompressionFailed(file: String, reason: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return String(
                localized: "core.error.invalidBaseURL",
                defaultValue:
                    "Invalid download URL. Please check your configuration."
            )

        case .destinationUnavailable:
            return String(
                localized: "core.error.destinationUnavailable",
                defaultValue: "The destination folder could not be created."
            )

        case .invalidResponse:
            return String(
                localized: "core.error.invalidResponse",
                defaultValue: "Invalid server response."
            )

        case .httpStatus(let file, let code):
            return String(
                localized: "core.error.httpStatus",
                defaultValue: "Failed to download “\(file)” (HTTP \(code))."
            )

        case .downloadFailed(let file):
            return String(
                localized: "core.error.downloadFailed",
                defaultValue: "File “\(file)” is incomplete after download."
            )

        case .decompressionFailed(let file, let reason):
            return String(
                localized: "core.error.decompressionFailed",
                defaultValue: "Failed to decompress “\(file)”: \(reason)."
            )

        case .cancelled:
            return String(
                localized: "core.error.cancelled",
                defaultValue: "Download cancelled."
            )
        }
    }
}

// MARK: - CoreDatabaseDownloader

/// Download dan dekompresi main.sqlite + special.sqlite dari GitHub Releases.
/// Semua operasi file/network berjalan di background thread;
/// progress callback dipanggil di main thread.
final class CoreDatabaseDownloader: NSObject {
    private let fileManager = FileManager.default
    private var session: URLSession?

    // Dipanggil di main thread oleh CoreDownloadModalCenter
    typealias ProgressHandler = (_ progress: Double, _ detail: String) -> Void
    typealias CompletionHandler = (_ error: Error?) -> Void

    override init() {}

    // MARK: - Check

    func areCoreFilesReady() -> Bool {
        CoreFile.allCases.allSatisfy { fileExistsAndHasSize(for: $0) }
    }

    // MARK: - Download (non-async, background thread)

    /// Mulai download semua core files yang belum tersedia.
    /// `onProgress` dan `onCompletion` dipanggil di **main thread**.
    func startDownload(
        onProgress: @escaping ProgressHandler,
        onCompletion: @escaping CompletionHandler
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try self.downloadMissingCoreFiles(onProgress: onProgress)
                DispatchQueue.main.async { onCompletion(nil) }
            } catch {
                DispatchQueue.main.async { onCompletion(error) }
            }
        }
    }

    // MARK: - Private: orchestrate

    private func downloadMissingCoreFiles(
        onProgress: @escaping ProgressHandler
    ) throws {
        let missing = CoreFile.allCases.filter { !fileExistsAndHasSize(for: $0) }
        guard !missing.isEmpty else { return }

        guard let baseURL = AppConfig.coreReleaseBaseURL,
              let tag    = AppConfig.coreReleaseTag else {
            throw CoreDownloadError.invalidBaseURL
        }

        for (index, file) in missing.enumerated() {
            let fileURL = baseURL
                .appendingPathComponent(tag)
                .appendingPathComponent(file.releaseFilename)

            try downloadSingleFile(file, from: fileURL) { progress in
                let base = Double(index) / Double(missing.count)
                let step = 1.0 / Double(missing.count)
                let combined = base + progress * step
                let pct = Int((combined * 100).rounded())
                DispatchQueue.main.async {
                    onProgress(combined, "\(pct)%")
                }
            }
        }
    }

    // MARK: - Private: single file (synchronous, on background thread)

    private func downloadSingleFile(
        _ coreFile: CoreFile,
        from url: URL,
        onProgress: @escaping (Double) -> Void
    ) throws {
        guard let destDir = AppConfig.coreDatabasePath else {
            throw CoreDownloadError.destinationUnavailable
        }
        let destURL = URL(fileURLWithPath: destDir)
            .appendingPathComponent(coreFile.filename)

        // Semaphore untuk membuat URLSession.downloadTask berjalan sinkron
        let semaphore = DispatchSemaphore(value: 0)
        var downloadedTempURL: URL?
        var downloadError: Error?

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 120
        config.timeoutIntervalForResource = 3600
        config.waitsForConnectivity = false

        let delegate = CoreDownloadDelegate(
            onProgress: onProgress,
            onFinish: { tempURL, error in
                downloadedTempURL = tempURL
                downloadError    = error
                semaphore.signal()
            }
        )
        let sess = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        session = sess

        let task = sess.downloadTask(with: url)
        task.resume()
        semaphore.wait()
        session?.invalidateAndCancel()
        session = nil

        if let error = downloadError { throw error }

        guard let tempURL = downloadedTempURL else {
            throw CoreDownloadError.downloadFailed(file: coreFile.filename)
        }
        defer { try? fileManager.removeItem(at: tempURL) }

        // Validasi HTTP sudah dilakukan di delegate; di sini tinggal proses file
        if url.pathExtension.lowercased() == "zst" {
            try decompressZstdFile(from: tempURL, to: destURL, filename: coreFile.filename)
        } else {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: tempURL, to: destURL)
        }

        guard fileExistsAndHasSize(for: coreFile) else {
            throw CoreDownloadError.downloadFailed(file: coreFile.filename)
        }
    }

    // MARK: - Private: zstd

    private func decompressZstdFile(
        from sourceURL: URL,
        to destinationURL: URL,
        filename: String
    ) throws {
        let compressed = try Data(contentsOf: sourceURL)
        guard !compressed.isEmpty else {
            throw CoreDownloadError.decompressionFailed(file: filename, reason: "Empty file")
        }

        let expectedSize = ZSTD_getFrameContentSize(
            (compressed as NSData).bytes,
            compressed.count
        )

        if expectedSize == ZSTD_CONTENTSIZE_ERROR || expectedSize == ZSTD_CONTENTSIZE_UNKNOWN {
            throw CoreDownloadError.decompressionFailed(file: filename, reason: "Unknown content size")
        }

        var output = Data(count: Int(expectedSize))
        let decompressedSize = output.withUnsafeMutableBytes { outPtr in
            compressed.withUnsafeBytes { inPtr in
                ZSTD_decompress(
                    outPtr.baseAddress,
                    Int(expectedSize),
                    inPtr.baseAddress,
                    compressed.count
                )
            }
        }

        if ZSTD_isError(decompressedSize) != 0 {
            let errorName = String(cString: ZSTD_getErrorName(decompressedSize))
            throw CoreDownloadError.decompressionFailed(file: filename, reason: errorName)
        }

        output.count = decompressedSize

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try output.write(to: destinationURL, options: [.atomic])
    }

    // MARK: - Private: helpers

    private func fileExistsAndHasSize(for coreFile: CoreFile) -> Bool {
        guard let dirPath = AppConfig.coreDatabasePath else { return false }
        let path = URL(fileURLWithPath: dirPath)
            .appendingPathComponent(coreFile.filename).path
        guard fileManager.fileExists(atPath: path) else { return false }
        let size = (try? fileManager.attributesOfItem(atPath: path)[.size]
                    as? NSNumber)?.int64Value ?? 0
        return size > 0
    }
}

// MARK: - URLSession Delegate

private final class CoreDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    private let onFinish: (URL?, Error?) -> Void
    private var httpError: Error?

    init(
        onProgress: @escaping (Double) -> Void,
        onFinish: @escaping (URL?, Error?) -> Void
    ) {
        self.onProgress = onProgress
        self.onFinish   = onFinish
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Cek HTTP status
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            let filename = downloadTask.originalRequest?.url?.lastPathComponent ?? "?"
            httpError = CoreDownloadError.httpStatus(file: filename, statusCode: http.statusCode)
            onFinish(nil, httpError)
            return
        }

        // Pindahkan ke temp yang tidak akan dihapus oleh sistem sebelum semaphore signal
        let tempDest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tempDest)
            onFinish(tempDest, nil)
        } catch {
            onFinish(nil, error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, httpError == nil {
            onFinish(nil, error)
        }
    }
}

// MARK: - CoreDatabaseBootstrap

/// Entry point yang dipanggil sinkron dari AppDelegate.applicationDidFinishLaunching
/// (pada main thread). Menampilkan modal blocking jika core files belum tersedia,
/// lalu memanggil DatabaseManager.shared.setupFolders() setelah siap.
final class CoreDatabaseBootstrap {

    static func run() {
        // Custom mode: folder dipilih user, DatabaseManager langsung setup.
        if AppConfig.hasCustomDatabaseFolder() {
            DatabaseManager.shared.setupFolders()
            return
        }

        // Bundle mode: cek apakah core files sudah ada.
        let downloader = CoreDatabaseDownloader()
        if downloader.areCoreFilesReady() {
            DatabaseManager.shared.setupFolders()
            return
        }

        // Belum ada → tampilkan modal download (blocking via NSApp.runModal).
        // Modal memegang downloader selama proses berlangsung; setelah selesai keduanya dibuang.
        let modal = CoreDownloadModalCenter(downloader: downloader)
        modal.runBlocking()

        // Setelah modal selesai (download berhasil), init DatabaseManager.
        DatabaseManager.shared.setupFolders()
    }
}

// MARK: - CoreDownloadModalCenter

/// Modal sinkron-blocking untuk download core files.
/// Berjalan di main thread; download di-dispatch ke background.
final class CoreDownloadModalCenter {
    private let downloader: CoreDatabaseDownloader
    private var window: NSWindow?
    private var progressState: CoreDownloadProgressState?

    init(downloader: CoreDatabaseDownloader) {
        self.downloader = downloader
    }

    // MARK: - Public

    /// Tampilkan modal dan block main thread via NSApp.runModal sampai download selesai
    /// atau user memilih keluar.
    func runBlocking() {
        showConfirmation()
        // NSApp.runModal di dalam showConfirmation/startDownload yang mengendalikan loop.
    }

    // MARK: - Private: modal lifecycle

    private func showConfirmation() {
        let state = CoreDownloadProgressState()
        progressState = state

        presentWindow(state: state)

        // runModal blocks until NSApp.stopModal() dipanggil
        NSApp.runModal(for: window!)
    }

    private func presentWindow(state: CoreDownloadProgressState) {
        let view = CoreDownloadProgressView(
            state: state,
            onDownload: { [weak self] in self?.userDidTapDownload() },
            onQuit:     { [weak self] in self?.userDidTapQuit() }
        )
        let hosting = NSHostingView(rootView: view)
        // Beri lebar tetap dulu, biarkan SwiftUI menghitung tinggi yang dibutuhkan
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 0)
        let fittedSize = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: fittedSize)

        let w = makeWindow(contentView: hosting, size: fittedSize)
        window = w
        w.center()
        w.makeKeyAndOrderFront(nil)
    }

    private func userDidTapDownload() {
        guard let state = progressState else { return }
        state.phase = .downloading
        state.progress = 0
        state.detail = ""

        downloader.startDownload(
            onProgress: { [weak state] progress, detail in
                // Sudah di main thread dari startDownload
                state?.progress = progress
                state?.detail   = detail
            },
            onCompletion: { [weak self] error in
                // Sudah di main thread
                if let error {
                    self?.progressState?.phase = .error(
                        error.localizedDescription
                    )
                    self?.progressState?.progress = 0
                } else {
                    // Berhasil: tutup modal
                    NSApp.stopModal()
                    self?.window?.orderOut(nil)
                    self?.window?.close()
                    self?.window = nil
                    self?.progressState = nil
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        )
    }

    private func userDidTapQuit() {
        NSApp.stopModal()
        window?.orderOut(nil)
        window?.close()
        window = nil
        progressState = nil
        NSApp.terminate(nil)
    }

    private func makeWindow(contentView: NSView, size: NSSize) -> NSWindow {
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.contentView = contentView
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.standardWindowButton(.closeButton)?.isHidden = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        return w
    }
}

// MARK: - Progress State

final class CoreDownloadProgressState: ObservableObject {
    enum Phase: Equatable {
        case confirmation
        case downloading
        case error(String)
    }

    @Published var phase: Phase = .confirmation
    @Published var progress: Double = 0
    @Published var detail: String = ""
}
