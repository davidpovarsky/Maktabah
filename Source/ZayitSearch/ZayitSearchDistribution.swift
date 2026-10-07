import CryptoKit
import Foundation

struct ZayitSearchArtifactManifest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentIndexSchemaVersion = 2

    let manifestSchemaVersion: Int
    let artifactIdentity: String
    let component: String
    let version: String
    let requiredDatabase: RequiredDatabase
    let engine: Engine
    let counts: Counts
    let stableBookIdentity: StableBookIdentity
    let sharedLexicalDatabase: SharedLexicalDatabase
    let extractedBytes: Int64
    let packagedBytes: Int64
    let parts: [Part]

    struct RequiredDatabase: Codable, Equatable, Sendable {
        let releaseTag: String
        let compressedAssetSHA256: String
        let canonicalSHA256: String
        let bytes: Int64
    }

    struct Engine: Codable, Equatable, Sendable {
        let indexSchemaVersion: Int
        let builderVersion: String
        let builderCommit: String
        let upstreamCommit: String
        let tantivyVersion: String
    }

    struct Counts: Codable, Equatable, Sendable {
        let books: UInt64
        let lines: UInt64
        let documents: UInt64
        let splitLines: UInt64
    }

    struct StableBookIdentity: Codable, Equatable, Sendable {
        let field: String
        let fallback: String
    }

    struct SharedLexicalDatabase: Codable, Equatable, Sendable {
        let version: String
        let sha256: String
        let bytes: Int64
    }

    struct Part: Codable, Equatable, Sendable {
        let assetName: String
        let packagedBytes: Int64
        let sha256: String
        let destinationPath: String
        let destinationOffset: Int64
        let uncompressedBytes: Int64
        let compression: String
    }
}

enum ZayitSearchPackageState: Equatable, Sendable {
    case notInstalled
    case discovering
    case available(downloadBytes: Int64, installedBytes: Int64)
    case downloading(completed: Int64, total: Int64)
    case installing(completed: Int64, total: Int64)
    case ready(ZayitSearchArtifactManifest)
    case updateAvailable(installed: String, available: String)
    case repairRequired(String)
    case incompatible(String)
    case failed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

enum ZayitSearchDistributionError: LocalizedError, Sendable {
    case unavailable
    case malformedManifest(String)
    case incompatible(String)
    case missingPart(String)
    case unsafePath(String)
    case insufficientStorage(required: Int64, available: Int64)
    case invalidResponse(Int)
    case sizeMismatch(String)
    case digestMismatch(String)
    case extractionFailed(String)
    case validationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable: "A compatible Zayit search package is not available yet."
        case .malformedManifest(let detail): "The Zayit manifest is invalid: \(detail)"
        case .incompatible(let detail): "The Zayit index is incompatible: \(detail)"
        case .missingPart(let name): "The Zayit package is missing \(name)."
        case .unsafePath(let path): "The Zayit package contains an unsafe path: \(path)"
        case .insufficientStorage(let required, let available):
            "Zayit installation requires \(Self.bytes(required)); \(Self.bytes(available)) is available."
        case .invalidResponse(let status): "The Zayit download failed (HTTP \(status))."
        case .sizeMismatch(let name): "The downloaded Zayit part has the wrong size: \(name)."
        case .digestMismatch(let name): "The downloaded Zayit part failed SHA-256 validation: \(name)."
        case .extractionFailed(let detail): "The Zayit index could not be extracted: \(detail)"
        case .validationFailed(let detail): "The Zayit index failed validation: \(detail)"
        case .cancelled: "The Zayit download was cancelled and can be resumed later."
        }
    }

    private static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

struct ZayitSearchArtifactStorage: Sendable {
    static let reserveBytes: Int64 = 1_073_741_824
    let root: URL
    let downloads: URL

    init() throws {
        guard let appSupport = AppConfig.appSupportDir else {
            throw ZayitSearchDistributionError.validationFailed("Application Support is unavailable")
        }
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        root = appSupport.appendingPathComponent("Otzaria/Zayit", isDirectory: true)
        downloads = caches.appendingPathComponent("Maktabah/Zayit/Downloads", isDirectory: true)
    }

    init(root: URL, downloads: URL) {
        self.root = root
        self.downloads = downloads
    }

    var finalIndex: URL { root.appendingPathComponent("zayit-search-index", isDirectory: true) }
    var installingIndex: URL { root.appendingPathComponent("zayit-search-index.installing", isDirectory: true) }
    var previousIndex: URL { root.appendingPathComponent("zayit-search-index.previous", isDirectory: true) }
    var installedManifest: URL { root.appendingPathComponent("zayit-installation.json") }

    func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try exclude(root)
        try exclude(downloads)
    }

    func cleanupOrphans(preservingPartialDownloads: Bool = true) {
        let manager = FileManager.default
        try? manager.removeItem(at: installingIndex)
        if !manager.fileExists(atPath: finalIndex.path), manager.fileExists(atPath: previousIndex.path) {
            try? manager.moveItem(at: previousIndex, to: finalIndex)
        } else if manager.fileExists(atPath: previousIndex.path) {
            try? manager.removeItem(at: previousIndex)
        }
        guard !preservingPartialDownloads else { return }
        try? manager.removeItem(at: downloads)
    }

    func availableCapacity() -> Int64 {
        let values = try? root.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        return values?.volumeAvailableCapacityForImportantUsage
            ?? Int64(values?.volumeAvailableCapacity ?? 0)
    }

    private func exclude(_ url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
}

private struct ZayitResolvedArtifact: Sendable {
    let releaseTag: String
    let manifest: ZayitSearchArtifactManifest
    let partURLs: [String: URL]
}

actor ZayitSearchArtifactService {
    static let shared = ZayitSearchArtifactService()
    static let repository = "davidpovarsky/Maktabah"
    static let manifestName = "zayit-search-manifest.json"

    typealias Progress = @Sendable (ZayitSearchPackageState) -> Void

    private var activeTask: URLSessionDataTask?
    private var cancelled = false

    func status(databaseURL: URL?) async -> ZayitSearchPackageState {
        do {
            let storage = try ZayitSearchArtifactStorage()
            try storage.prepare()
            storage.cleanupOrphans()
            guard let databaseURL else { return .incompatible("Seforim DB is not installed") }
            let installed = try installedManifest(storage: storage)
            guard let installed else { return .notInstalled }
            guard FileManager.default.fileExists(atPath: storage.finalIndex.path) else {
                return .repairRequired("installed manifest exists but the index directory is missing")
            }
            try validateCompatibility(installed, databaseURL: databaseURL)
            try validateStaging(storage.finalIndex, manifest: installed)
            return .ready(installed)
        } catch let error as ZayitSearchDistributionError {
            return .repairRequired(error.localizedDescription)
        } catch {
            return .repairRequired(error.localizedDescription)
        }
    }

    func discover(databaseURL: URL) async throws -> ZayitSearchPackageState {
        let artifact = try await resolveArtifact()
        try validateCompatibility(artifact.manifest, databaseURL: databaseURL)
        let storage = try ZayitSearchArtifactStorage()
        try storage.prepare()
        if let installed = try installedManifest(storage: storage) {
            if installed.artifactIdentity == artifact.manifest.artifactIdentity,
               FileManager.default.fileExists(atPath: storage.finalIndex.path) {
                return .ready(installed)
            }
            return .updateAvailable(
                installed: installed.artifactIdentity,
                available: artifact.manifest.artifactIdentity
            )
        }
        return .available(
            downloadBytes: artifact.manifest.packagedBytes,
            installedBytes: artifact.manifest.extractedBytes
        )
    }

    func install(databaseURL: URL, lexicalDatabaseURL: URL, progress: @escaping Progress) async throws {
        cancelled = false
        let artifact = try await resolveArtifact()
        try validateCompatibility(artifact.manifest, databaseURL: databaseURL)
        try validateLexicalDatabase(artifact.manifest, url: lexicalDatabaseURL)
        let storage = try ZayitSearchArtifactStorage()
        try storage.prepare()
        let required = ZayitInstallCapacityPolicy.requiredBytes(
            extractedBytes: artifact.manifest.extractedBytes,
            packagedPartBytes: artifact.manifest.parts.map(\.packagedBytes)
        )
        let available = storage.availableCapacity()
        guard available >= required else {
            throw ZayitSearchDistributionError.insufficientStorage(required: required, available: available)
        }

        try? FileManager.default.removeItem(at: storage.installingIndex)
        try FileManager.default.createDirectory(at: storage.installingIndex, withIntermediateDirectories: true)
        var downloaded: Int64 = 0
        var extracted: Int64 = 0
        do {
            for part in artifact.manifest.parts {
                try checkCancellation()
                guard let remote = artifact.partURLs[part.assetName] else {
                    throw ZayitSearchDistributionError.missingPart(part.assetName)
                }
                let local = storage.downloads.appendingPathComponent("\(part.sha256).part")
                progress(.downloading(completed: downloaded, total: artifact.manifest.packagedBytes))
                let baseDownloaded = downloaded
                try await download(part, from: remote, to: local) { received in
                    progress(.downloading(completed: baseDownloaded + received, total: artifact.manifest.packagedBytes))
                }
                try verify(local, part: part)
                downloaded += part.packagedBytes
                let baseExtracted = extracted
                try extract(part, archive: local, root: storage.installingIndex) { consumed in
                    progress(.installing(completed: baseExtracted + consumed, total: artifact.manifest.extractedBytes))
                }
                extracted += part.uncompressedBytes
                try FileManager.default.removeItem(at: local)
            }
            try validateStaging(storage.installingIndex, manifest: artifact.manifest)
            try promote(storage: storage, manifest: artifact.manifest)
            progress(.ready(artifact.manifest))
        } catch {
            try? FileManager.default.removeItem(at: storage.installingIndex)
            if cancelled || error is CancellationError { throw ZayitSearchDistributionError.cancelled }
            throw error
        }
    }

    func cancel() {
        cancelled = true
        activeTask?.cancel()
    }

    func remove() throws {
        let storage = try ZayitSearchArtifactStorage()
        try? FileManager.default.removeItem(at: storage.finalIndex)
        try? FileManager.default.removeItem(at: storage.previousIndex)
        try? FileManager.default.removeItem(at: storage.installingIndex)
        try? FileManager.default.removeItem(at: storage.installedManifest)
        storage.cleanupOrphans(preservingPartialDownloads: false)
    }
}

private extension ZayitSearchArtifactService {
    struct Release: Decodable {
        let tagName: String
        let assets: [Asset]
        enum CodingKeys: String, CodingKey { case tagName = "tag_name", assets }
    }
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        enum CodingKeys: String, CodingKey { case name, browserDownloadURL = "browser_download_url" }
    }

    func resolveArtifact() async throws -> ZayitResolvedArtifact {
        let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases?per_page=30")!
        var request = URLRequest(url: url)
        request.setValue("Maktabah-iOS-Zayit", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ZayitSearchDistributionError.unavailable
        }
        let releases = try JSONDecoder().decode([Release].self, from: data)
        for release in releases where release.tagName.hasPrefix("zayit-search-data-") {
            guard let manifestAsset = release.assets.first(where: { $0.name == Self.manifestName }) else { continue }
            let (manifestData, manifestResponse) = try await URLSession.shared.data(from: manifestAsset.browserDownloadURL)
            guard (manifestResponse as? HTTPURLResponse)?.statusCode == 200 else { continue }
            guard let manifest = try? JSONDecoder().decode(ZayitSearchArtifactManifest.self, from: manifestData),
                  manifest.manifestSchemaVersion == ZayitSearchArtifactManifest.currentSchemaVersion,
                  manifest.engine.indexSchemaVersion == ZayitSearchArtifactManifest.currentIndexSchemaVersion else {
                continue
            }
            let urls = Dictionary(uniqueKeysWithValues: release.assets.map { ($0.name, $0.browserDownloadURL) })
            guard manifest.parts.allSatisfy({ urls[$0.assetName] != nil }) else { continue }
            return .init(releaseTag: release.tagName, manifest: manifest, partURLs: urls)
        }
        throw ZayitSearchDistributionError.unavailable
    }

    func validateCompatibility(_ manifest: ZayitSearchArtifactManifest, databaseURL: URL) throws {
        guard manifest.component == "zayitIndex",
              manifest.manifestSchemaVersion == ZayitSearchArtifactManifest.currentSchemaVersion,
              manifest.engine.indexSchemaVersion == ZayitSearchArtifactManifest.currentIndexSchemaVersion else {
            throw ZayitSearchDistributionError.incompatible("unsupported manifest or index schema")
        }
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size]) as? NSNumber)?.int64Value ?? 0
        guard bytes == manifest.requiredDatabase.bytes else {
            throw ZayitSearchDistributionError.incompatible("database size/identity mismatch")
        }
        if let storage = try? OtzariaDatabaseStorage(),
           let data = try? Data(contentsOf: storage.installationManifestURL),
           let installed = try? JSONDecoder().decode(OtzariaDatabaseInstallationManifest.self, from: data) {
            let digest = installed.digest?.replacingOccurrences(of: "sha256:", with: "").lowercased()
            guard installed.releaseTag == manifest.requiredDatabase.releaseTag,
                  digest == manifest.requiredDatabase.compressedAssetSHA256.lowercased() else {
                throw ZayitSearchDistributionError.incompatible("the index was built for a different DB release")
            }
        }
    }

    func validateLexicalDatabase(_ manifest: ZayitSearchArtifactManifest, url: URL) throws {
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
        guard bytes == manifest.sharedLexicalDatabase.bytes else {
            throw ZayitSearchDistributionError.incompatible("shared lexical.db identity mismatch")
        }
        guard try digest(url) == manifest.sharedLexicalDatabase.sha256.lowercased() else {
            throw ZayitSearchDistributionError.incompatible("shared lexical.db checksum mismatch")
        }
    }

    func installedManifest(storage: ZayitSearchArtifactStorage) throws -> ZayitSearchArtifactManifest? {
        guard FileManager.default.fileExists(atPath: storage.installedManifest.path) else { return nil }
        return try JSONDecoder().decode(
            ZayitSearchArtifactManifest.self,
            from: Data(contentsOf: storage.installedManifest)
        )
    }

    func download(
        _ part: ZayitSearchArtifactManifest.Part,
        from remote: URL,
        to local: URL,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        var existing = fileSize(local)
        if existing > part.packagedBytes { try? FileManager.default.removeItem(at: local); existing = 0 }
        if existing == part.packagedBytes { return }
        var request = URLRequest(url: remote)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if existing > 0 { request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range") }
        let (temporary, response) = try await URLSession.shared.download(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == (existing > 0 ? 206 : 200) else {
            if existing > 0, status == 200 {
                try? FileManager.default.removeItem(at: local)
                return try await download(part, from: remote, to: local, progress: progress)
            }
            throw ZayitSearchDistributionError.invalidResponse(status)
        }
        if existing == 0 {
            try? FileManager.default.removeItem(at: local)
            try FileManager.default.moveItem(at: temporary, to: local)
        } else {
            let input = try FileHandle(forReadingFrom: temporary)
            defer { try? input.close() }
            let output = try FileHandle(forWritingTo: local)
            defer { try? output.close() }
            try output.seekToEnd()
            while let chunk = try input.read(upToCount: 4 * 1_024 * 1_024), !chunk.isEmpty {
                try checkCancellation()
                try output.write(contentsOf: chunk)
                existing += Int64(chunk.count)
                progress(existing)
            }
        }
        progress(fileSize(local))
    }

    func verify(_ url: URL, part: ZayitSearchArtifactManifest.Part) throws {
        guard fileSize(url) == part.packagedBytes else {
            throw ZayitSearchDistributionError.sizeMismatch(part.assetName)
        }
        guard try digest(url) == part.sha256.lowercased() else {
            try? FileManager.default.removeItem(at: url)
            throw ZayitSearchDistributionError.digestMismatch(part.assetName)
        }
    }

    func extract(
        _ part: ZayitSearchArtifactManifest.Part,
        archive: URL,
        root: URL,
        progress: @escaping @Sendable (Int64) -> Void
    ) throws {
        let destination = root.appendingPathComponent(part.destinationPath)
        guard destination.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw ZayitSearchDistributionError.unsafePath(part.destinationPath)
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try OtzariaZstdStreamExtractor().extractPart(
                archiveURL: archive,
                outputURL: destination,
                expectedOffset: part.destinationOffset,
                expectedOutputBytes: part.uncompressedBytes
            ) { consumed, total in
                let fraction = total > 0 ? Double(consumed) / Double(total) : 0
                progress(Int64(Double(part.uncompressedBytes) * fraction))
            }
        } catch {
            throw ZayitSearchDistributionError.extractionFailed(error.localizedDescription)
        }
    }

    func validateStaging(_ url: URL, manifest: ZayitSearchArtifactManifest) throws {
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("meta.json").path),
              FileManager.default.fileExists(atPath: url.appendingPathComponent("zayit-index-metadata.json").path) else {
            throw ZayitSearchDistributionError.validationFailed("Tantivy metadata is missing")
        }
        let metadataData = try Data(contentsOf: url.appendingPathComponent("zayit-index-metadata.json"))
        let object = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        guard (object?["schema_version"] as? NSNumber)?.intValue == manifest.engine.indexSchemaVersion,
              object?["database_sha256"] as? String == manifest.requiredDatabase.canonicalSHA256,
              (object?["index_documents"] as? NSNumber)?.uint64Value == manifest.counts.documents else {
            throw ZayitSearchDistributionError.validationFailed("metadata identity/count mismatch")
        }
    }

    func promote(storage: ZayitSearchArtifactStorage, manifest: ZayitSearchArtifactManifest) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: storage.previousIndex.path) { try manager.removeItem(at: storage.previousIndex) }
        if manager.fileExists(atPath: storage.finalIndex.path) { try manager.moveItem(at: storage.finalIndex, to: storage.previousIndex) }
        do {
            try manager.moveItem(at: storage.installingIndex, to: storage.finalIndex)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: storage.installedManifest, options: .atomic)
            if manager.fileExists(atPath: storage.previousIndex.path) { try manager.removeItem(at: storage.previousIndex) }
            for item in (try? manager.contentsOfDirectory(at: storage.downloads, includingPropertiesForKeys: nil)) ?? [] {
                try? manager.removeItem(at: item)
            }
        } catch {
            try? manager.removeItem(at: storage.finalIndex)
            if manager.fileExists(atPath: storage.previousIndex.path) {
                try? manager.moveItem(at: storage.previousIndex, to: storage.finalIndex)
            }
            throw error
        }
    }

    func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 4 * 1_024 * 1_024), !data.isEmpty {
            try checkCancellation()
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func checkCancellation() throws {
        if cancelled || Task.isCancelled { throw ZayitSearchDistributionError.cancelled }
    }

    func fileSize(_ url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
    }

    func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return enumerator.compactMap { $0 as? URL }.reduce(0) { result, item in
            result + Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}

@MainActor
final class ZayitSearchDataController: ObservableObject {
    static let shared = ZayitSearchDataController()
    @Published private(set) var state: ZayitSearchPackageState = .notInstalled

    func refresh(discover: Bool = false) async {
        guard let database = ZayitSearchExistingDatabaseProvider.currentURL else {
            state = .incompatible("Seforim DB is not installed")
            return
        }
        state = discover ? .discovering : await ZayitSearchArtifactService.shared.status(databaseURL: database)
        guard discover, !state.isReady else { return }
        do {
            state = try await ZayitSearchArtifactService.shared.discover(databaseURL: database)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func install() async {
        guard let database = ZayitSearchExistingDatabaseProvider.currentURL,
              let lexical = OtzariaMagicDictionaryManager.shared.validatedDatabaseURL else {
            state = .incompatible("Seforim DB or shared lexical.db is unavailable")
            return
        }
        do {
            try await ZayitSearchArtifactService.shared.install(
                databaseURL: database,
                lexicalDatabaseURL: lexical
            ) { [weak self] update in
                Task { @MainActor in self?.state = update }
            }
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        Task { await ZayitSearchArtifactService.shared.cancel() }
    }

    func remove() {
        Task {
            do {
                try await ZayitSearchArtifactService.shared.remove()
                state = .notInstalled
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
