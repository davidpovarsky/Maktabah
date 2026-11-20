import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension SearchResultItem: @unchecked Sendable {}

final class OtzariaTantivySearchRepository: @unchecked Sendable {
    static let shared = OtzariaTantivySearchRepository()

    private let manager = OtzariaSearchIndexManager.shared
    private var engineCache: [String: OtzariaSearchEngineBridge] = [:]
    private var engineStamps: [String: OpenIndexStamp] = [:]
    private var publicationRevision: UInt64 = 0
    private let revisionLock = NSLock()

    private func readPublicationRevision() -> UInt64 {
        revisionLock.lock(); defer { revisionLock.unlock() }
        return publicationRevision
    }

    private func advancePublicationRevision() {
        revisionLock.lock(); defer { revisionLock.unlock() }
        publicationRevision &+= 1
    }
    private var indexingDatabasePaths: Set<String> = []
    private let lock = NSRecursiveLock()

    private init() {}

    func engine(databasePath: String) throws -> OtzariaSearchEngineBridge {
        lock.lock()
        defer { lock.unlock() }
        if indexingDatabasePaths.contains(databasePath) {
            throw OtzariaSearchError.invalidEngineResponse("Otzaria Tantivy indexing is in progress for this database.")
        }
        if let cached = engineCache[databasePath] {
            return cached
        }
        let indexURL = manager.indexURL(for: databasePath)
        let before = try? openIndexStamp(databasePath: databasePath)
        let engine = try OtzariaSearchEngineBridge(indexURL: indexURL)
        do {
            try Self.configureRequiredDictionaries(
                engine: engine,
                magic: OtzariaMagicDictionaryManager.shared.validatedDatabaseURL,
                translation: Bundle.main.url(forResource: "dictionary", withExtension: "json"),
                acronyms: Bundle.main.url(forResource: "Acronyms", withExtension: "json")
            )
        } catch {
            engine.close()
            throw error
        }
        engineCache[databasePath] = engine
        if let before, before == (try? openIndexStamp(databasePath: databasePath)) {
            engineStamps[databasePath] = before
        }
        return engine
    }

    /// Discovery can inspect an already-open engine, but must never construct
    /// one (the native constructor can create/write an index). A disk/profile
    /// change makes the observation unknown, even if a cached engine still works.
    func observedOpenIndexDocumentCount(databasePath: String) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        guard !indexingDatabasePaths.contains(databasePath),
              let engine = engineCache[databasePath], let stamp = engineStamps[databasePath],
              stamp == (try? openIndexStamp(databasePath: databasePath)),
              let count = try? engine.documentCount(),
              stamp == (try? openIndexStamp(databasePath: databasePath)) else { return nil }
        return count
    }

    /// Current source evidence, not an action generation or cached readiness.
    /// Revision detects supported A -> B -> A invalidations between observations.
    func resourceObservation(databasePath: String?) -> (revision: UInt64, fingerprint: Data?) {
        // Synchronous commit guards must not wait behind a long FFI query.
        // This lock protects the source revision only, never an engine/await.
        let before = readPublicationRevision()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let fingerprint = databasePath.flatMap { path in
            (try? openIndexStamp(databasePath: path)).flatMap { try? encoder.encode($0) }
        }
        let after = readPublicationRevision()
        return (after, before == after ? fingerprint : nil)
    }

    private struct OpenIndexStamp: Codable, Equatable, Sendable {
        let profile: String
        let database: OtzariaIndexFingerprint
        let path: String
        let metadata: Data
        let identity: Data
        // Missing optional manifests preserve legacy/custom-index observations.
        // The occurrence caller requires both, and validates their semantics.
        let indexInstallationManifest: Data?
        let databaseInstallationManifest: Data?
    }

    private func openIndexStamp(databasePath: String) throws -> OpenIndexStamp {
        let url = manager.indexURL(for: databasePath)
        let databaseURL = URL(fileURLWithPath: databasePath)
        return try OpenIndexStamp(profile: OtzariaDataProfileRegistry.activeProfileID,
            database: manager.currentFingerprint(databasePath: databasePath), path: url.path,
            metadata: smallMetadata(at: url.appendingPathComponent("meta.json")),
            identity: smallMetadata(at: manager.identityURL(indexURL: url)),
            indexInstallationManifest: optionalSmallMetadata(
                at: url.appendingPathComponent("otzaria_prebuilt_installation.json")),
            databaseInstallationManifest: optionalSmallMetadata(
                at: databaseURL.deletingLastPathComponent().appendingPathComponent("seforim-installation.json")))
    }

    private func optionalSmallMetadata(at url: URL) throws -> Data? {
        do { return try smallMetadata(at: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
    }

    private func smallMetadata(at url: URL) throws -> Data {
        let maximum = 1_048_576
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.uint64Value <= UInt64(maximum),
              attributes[.type] as? FileAttributeType == .typeRegular else {
            throw OtzariaSearchError.invalidEngineResponse("Search readiness metadata is missing or oversized")
        }
        // The size check alone does not bound a file that grows while reading.
        // Read at most maximum + 1 bytes and reject that sentinel extra byte.
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var data = Data()
        while data.count <= maximum {
            guard let chunk = try file.read(upToCount: maximum + 1 - data.count),
                  !chunk.isEmpty else { return data }
            data.append(chunk)
        }
        throw OtzariaSearchError.invalidEngineResponse("Search readiness metadata is oversized")
    }

    /// Count only through an already-open original engine. This API cannot open,
    /// recover, install or rebuild an index. The caller supplies the exact live
    /// resource observation already bound to its managed-source proof.
    func countExactTokenOccurrences(
        databasePath: String,
        request: OtzariaExactOccurrenceRequest,
        expectedSource: OtzariaExactOccurrenceSource,
        expectedRevision: UInt64,
        expectedFingerprint: Data,
        deadlineUptimeNanoseconds: UInt64
    ) async throws -> OtzariaExactOccurrenceResult {
        let now = DispatchTime.now().uptimeNanoseconds
        let (requestDeadline, overflow) = now.addingReportingOverflow(request.timeoutMs * 1_000_000)
        guard !overflow else { throw OtzariaExactOccurrenceError.invalidLimits }
        let deadline = min(deadlineUptimeNanoseconds, requestDeadline)
        let lease: OccurrenceLease
        while true {
            if let captured = try tryOccurrenceLease(
                databasePath: databasePath, expectedRevision: expectedRevision,
                expectedFingerprint: expectedFingerprint, deadline: deadline
            ) {
                lease = captured
                break
            }
            try await waitForOccurrenceCache(deadline: deadline)
        }

        // No repository/revision lock is retained across this await. The strong
        // engine lease keeps ownership alive; invalidate/close may still cancel
        // it and the post-await identity checks then reject its old authority.
        try checkOccurrenceDeadline(deadline)
        let capturedNow = DispatchTime.now().uptimeNanoseconds
        guard capturedNow < deadline else { throw OtzariaExactOccurrenceError.deadlineExceeded }
        let remaining = deadline - capturedNow
        let remainingMs = min(request.timeoutMs, remaining / 1_000_000)
        guard remainingMs > 0 else { throw OtzariaExactOccurrenceError.deadlineExceeded }
        let boundedRequest = try OtzariaExactOccurrenceRequest(
            query: request.query, facets: request.facets, bookIds: request.bookIds,
            timeoutMs: remainingMs, limits: request.limits
        )
        let result = try await lease.engine.countExactTokenOccurrences(
            request: boundedRequest, expectedSource: expectedSource
        )

        while true {
            if try tryOccurrenceLease(
                databasePath: databasePath, expectedRevision: expectedRevision,
                expectedFingerprint: expectedFingerprint, deadline: deadline,
                expectedEngine: lease.engine, expectedStamp: lease.stamp
            ) != nil { break }
            try await waitForOccurrenceCache(deadline: deadline)
        }
        try checkOccurrenceDeadline(deadline)
        return result
    }

    private struct OccurrenceLease: Sendable {
        let engine: OtzariaSearchEngineBridge
        let stamp: OpenIndexStamp
    }

    /// Synchronous, nonblocking lock attempt. Acquire and release occur on the
    /// same thread, before the async caller may suspend or move executors.
    private func tryOccurrenceLease(
        databasePath: String,
        expectedRevision: UInt64,
        expectedFingerprint: Data,
        deadline: UInt64,
        expectedEngine: OtzariaSearchEngineBridge? = nil,
        expectedStamp: OpenIndexStamp? = nil
    ) throws -> OccurrenceLease? {
        try checkOccurrenceDeadline(deadline)
        guard lock.try() else { return nil }
        defer { lock.unlock() }
        try checkOccurrenceDeadline(deadline)
        guard readPublicationRevision() == expectedRevision else {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
        guard !indexingDatabasePaths.contains(databasePath),
              let engine = engineCache[databasePath],
              let stamp = engineStamps[databasePath] else {
            throw OtzariaExactOccurrenceError.engineUnavailable
        }
        if let expectedEngine, engine !== expectedEngine {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
        if let expectedStamp, stamp != expectedStamp {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let current = try? openIndexStamp(databasePath: databasePath),
              current == stamp,
              current.indexInstallationManifest != nil,
              current.databaseInstallationManifest != nil,
              let fingerprint = try? encoder.encode(current),
              fingerprint == expectedFingerprint,
              readPublicationRevision() == expectedRevision else {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
        try checkOccurrenceDeadline(deadline)
        return OccurrenceLease(engine: engine, stamp: stamp)
    }

    private func checkOccurrenceDeadline(_ deadline: UInt64) throws {
        guard !Task.isCancelled else { throw OtzariaExactOccurrenceError.cancelled }
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw OtzariaExactOccurrenceError.deadlineExceeded
        }
    }

    private func waitForOccurrenceCache(deadline: UInt64) async throws {
        try checkOccurrenceDeadline(deadline)
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadline else { throw OtzariaExactOccurrenceError.deadlineExceeded }
        do {
            try await Task<Never, Never>.sleep(nanoseconds: min(1_000_000, deadline - now))
        } catch {
            throw OtzariaExactOccurrenceError.cancelled
        }
    }

    #if OTZARIA_OCCURRENCE_TESTING
    /// Test scheduling only, using the actual cache lock. No engine, cache,
    /// source observation or result is injected by this hook.
    func occurrenceTestWithCacheLock(_ work: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        work()
    }
    #endif

    @discardableResult
    static func configureRequiredDictionaries(
        engine: OtzariaSearchEngineBridge,
        magic: URL?,
        translation: URL?,
        acronyms: URL?
    ) throws -> [String: Bool] {
        guard let translation else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Required Otzaria resource dictionary.json is missing from the app bundle."
            )
        }
        guard let acronyms else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Required Otzaria resource Acronyms.json is missing from the app bundle."
            )
        }
        for (name, url) in [("dictionary.json", translation), ("Acronyms.json", acronyms)] {
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw OtzariaSearchError.invalidEngineResponse(
                    "Required Otzaria resource \(name) is not readable."
                )
            }
        }

        let status = try engine.configureDictionaries(
            magic: magic,
            translation: translation,
            acronyms: acronyms
        )
        guard status["translation"] == true else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Otzaria could not load required dictionary.json."
            )
        }
        guard status["acronyms"] == true else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Otzaria could not load required Acronyms.json."
            )
        }
        if magic != nil, status["magic"] != true {
            print("[OtzariaSearch] optional lexical.db could not be loaded; continuing without lexical expansion")
        }
        return status
    }

    func documentCount(databasePath: String) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return try engine(databasePath: databasePath).documentCount()
    }

    func invalidate(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        advancePublicationRevision()
        if let engine = engineCache[databasePath] {
            engine.close()
            engineCache[databasePath] = nil
            engineStamps[databasePath] = nil
        }
        OtzariaIndexFileLogger.log("repository cache invalidated databasePath=\(databasePath)")
    }

    func closeEngine(databasePath: String) {
        invalidate(databasePath: databasePath)
    }

    func closeAllEngines() {
        lock.lock()
        defer { lock.unlock() }
        advancePublicationRevision()
        for engine in engineCache.values {
            engine.close()
        }
        engineCache.removeAll()
        engineStamps.removeAll()
        OtzariaIndexFileLogger.log("repository closeAllEngines done")
    }

    func beginExclusiveIndexing(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        advancePublicationRevision()
        if let engine = engineCache[databasePath] {
            engine.close()
            engineCache[databasePath] = nil
            engineStamps[databasePath] = nil
        }
        indexingDatabasePaths.insert(databasePath)
        OtzariaIndexFileLogger.log("exclusive indexing begin databasePath=\(databasePath)")
    }

    func endExclusiveIndexing(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        advancePublicationRevision()
        if let engine = engineCache[databasePath] {
            engine.close()
            engineCache[databasePath] = nil
            engineStamps[databasePath] = nil
        }
        indexingDatabasePaths.remove(databasePath)
        OtzariaIndexFileLogger.log("exclusive indexing end databasePath=\(databasePath)")
    }

    func search(databasePath: String, request: OtzariaSearchRequest) throws -> OtzariaSearchPage {
        lock.lock()
        defer { lock.unlock() }
        let engine = try engine(databasePath: databasePath)
        return try engine.search(request)
    }

    func navigationItems(from page: OtzariaSearchPage) -> [SearchResultItem] {
        page.results.map { result in
            let (attrText, highlightTerms) = highlightedText(from: result.text)
            let bkid = bookId(from: result.filePath) ?? 0
            let locator = TextLocator(
                backend: .otzaria,
                workKey: "book:\(bkid)",
                position: .legacyLine(Int(result.segment))
            )
            return SearchResultItem(
                archive: "Otzaria",
                tableName: "otzaria:\(bkid)",
                bookId: bkid,
                bookTitle: result.title,
                page: Int(result.segment),
                part: 0,
                attributedText: attrText,
                backendLocator: locator,
                locationDisplayText: result.reference.isEmpty ? nil : result.reference,
                highlightTerms: highlightTerms.isEmpty ? nil : highlightTerms,
                backendHitID: result.stableHitID
            )
        }
    }

    private func bookId(from filePath: String) -> Int? {
        guard filePath.hasPrefix("otzaria-book:") else { return nil }
        return Int(filePath.dropFirst("otzaria-book:".count))
    }

    private func highlightedText(from html: String) -> (NSAttributedString, [String]) {
        let mutable = NSMutableAttributedString(string: "")
        var remaining = html
        var terms: [String] = []
        let openTag = "<font color=red>"
        let closeTag = "</font>"

        while let openRange = remaining.range(of: openTag, options: [.caseInsensitive]) {
            let before = String(remaining[..<openRange.lowerBound])
            if !before.isEmpty {
                mutable.append(NSAttributedString(string: OtzariaSearchSnippetRenderer.plainText(fromHTML: before)))
            }
            remaining = String(remaining[openRange.upperBound...])
            guard let closeRange = remaining.range(of: closeTag, options: [.caseInsensitive]) else { break }
            let highlighted = String(remaining[..<closeRange.lowerBound])
            let plainHighlighted = OtzariaSearchSnippetRenderer.plainText(fromHTML: highlighted)
            mutable.append(NSAttributedString(
                string: plainHighlighted,
                attributes: highlightAttributes()
            ))
            let words = plainHighlighted
                .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            terms.append(contentsOf: words)
            remaining = String(remaining[closeRange.upperBound...])
        }

        if !remaining.isEmpty {
            mutable.append(NSAttributedString(string: OtzariaSearchSnippetRenderer.plainText(fromHTML: remaining)))
        }

        var seen = Set<String>()
        let uniqueTerms = terms.filter { seen.insert($0).inserted }

        if mutable.length == 0 {
            return (NSAttributedString(string: OtzariaSearchSnippetRenderer.plainText(fromHTML: html)), uniqueTerms)
        }
        return (mutable, uniqueTerms)
    }

    private func highlightAttributes() -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key("NSBold"): true
        ]
        #if canImport(UIKit)
        attrs[.foregroundColor] = UIColor.systemRed
        attrs[.font] = UIFont.boldSystemFont(ofSize: 17)
        #endif
        return attrs
    }
}
