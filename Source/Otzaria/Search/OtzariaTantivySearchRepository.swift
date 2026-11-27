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

    /// Ordinary reads share the same storage -> cache order as index
    /// promotion and explicit occurrence preparation. No recovery runs here.
    private func withSearchReadAccess<T>(databasePath: String, _ body: () throws -> T) throws -> T {
        let profile = OtzariaDataProfileRegistry.activeProfileID
        return try ITorahStorageLock.withLock(name: "migration-\(profile)") {
            try ITorahStorageLock.withLock(name: "database-mutation-\(profile)") {
                try ITorahStorageLock.withLock(name: "otzaria-search-mutation-\(profile)") {
                    lock.lock()
                    defer { lock.unlock() }
                    guard profile == OtzariaDataProfileRegistry.activeProfileID else {
                        throw OtzariaSearchArtifactError.incompatible("data profile changed during search")
                    }
                    return try body()
                }
            }
        }
    }

    private func engine(databasePath: String) throws -> OtzariaSearchEngineBridge {
        lock.lock()
        defer { lock.unlock() }
        if indexingDatabasePaths.contains(databasePath) {
            throw OtzariaSearchError.invalidEngineResponse("Otzaria Tantivy indexing is in progress for this database.")
        }
        let before: OpenIndexStamp
        let manifest: OtzariaSearchArtifactManifest?
        do {
            before = try openIndexStamp(databasePath: databasePath)
            manifest = try manager.validateCurrentIndexSource(databasePath: databasePath)
            guard before == (try openIndexStamp(databasePath: databasePath)) else {
                throw OtzariaSearchArtifactError.incompatible("source changed during index admission")
            }
        } catch {
            invalidate(databasePath: databasePath)
            throw OtzariaSearchArtifactError.incompatible(error.localizedDescription)
        }
        if let cached = engineCache[databasePath] {
            if engineStamps[databasePath] == before { return cached }
            invalidate(databasePath: databasePath)
        }
        let indexURL = manager.indexURL(for: databasePath)
        let engine = try OtzariaSearchEngineBridge(existingIndexURL: indexURL)
        do {
            try Self.configureRequiredDictionaries(
                engine: engine,
                magic: OtzariaMagicDictionaryManager.shared.validatedDatabaseURL,
                translation: Bundle.main.url(forResource: "dictionary", withExtension: "json"),
                acronyms: Bundle.main.url(forResource: "Acronyms", withExtension: "json")
            )
            if let manifest, try engine.documentCount() != manifest.lexicalArtifact.documentCount {
                throw OtzariaSearchArtifactError.incompatible("managed index document count")
            }
            guard before == (try openIndexStamp(databasePath: databasePath)) else {
                throw OtzariaSearchArtifactError.incompatible("source changed while opening index")
            }
        } catch {
            engine.close()
            throw error
        }
        engineCache[databasePath] = engine
        engineStamps[databasePath] = before
        return engine
    }

    /// Explicit execution may acquire an existing, already compatible index.
    /// It shares the original cache and storage ownership; it cannot install,
    /// recover, rebuild or run a query. The native constructor remains writer-
    /// capable, so this guarantee covers cooperative app mutations, not external
    /// filesystem writers that ignore the application's storage locks.
    func prepareExistingSearchExecution(
        databasePath: String, profileID: String, expectedIndexURL: URL,
        expectedRevision: UInt64, expectedFingerprint: Data, expectedIndexMetadata: Data,
        expectedDocumentCount: UInt64, requiredResourceHashes: [String: String],
        deadlineUptimeNanoseconds: UInt64,
        validateSource: @escaping @Sendable () throws -> Void
    ) async throws {
        while true {
            try OtzariaSearchEngineBridge.checkExecutionPreparationDeadline(deadlineUptimeNanoseconds)
            do {
                try validateSource()
                if try tryPrepareExistingSearchExecution(databasePath: databasePath, profileID: profileID,
                    expectedIndexURL: expectedIndexURL, expectedRevision: expectedRevision,
                    expectedFingerprint: expectedFingerprint, expectedIndexMetadata: expectedIndexMetadata,
                    expectedDocumentCount: expectedDocumentCount, requiredResourceHashes: requiredResourceHashes,
                    deadline: deadlineUptimeNanoseconds, validateSource: validateSource) { return }
            } catch OtzariaSearchExecutionPreparationError.sourceBusy {
                // The bridge can own its lock while waiting for migration.
                // Every storage/cache lock has unwound before this retry.
            }
            try OtzariaSearchEngineBridge.checkExecutionPreparationDeadline(deadlineUptimeNanoseconds)
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadlineUptimeNanoseconds else { throw OtzariaSearchExecutionPreparationError.deadlineExceeded }
            try await Task<Never, Never>.sleep(nanoseconds: min(1_000_000, deadlineUptimeNanoseconds - now))
        }
    }

    /// Acquire/release every lock synchronously on the same thread. A busy
    /// inner lock releases both outer locks before the async retry can suspend.
    /// Original mutations already use search -> cache; no cache -> storage path
    /// is introduced. Legacy migration precedes database -> search -> cache.
    /// validateSource must use the bridge's nonblocking owner observation.
    private func tryPrepareExistingSearchExecution(
        databasePath: String, profileID: String, expectedIndexURL: URL,
        expectedRevision: UInt64, expectedFingerprint: Data, expectedIndexMetadata: Data,
        expectedDocumentCount: UInt64, requiredResourceHashes: [String: String], deadline: UInt64,
        validateSource: @Sendable () throws -> Void
    ) throws -> Bool {
        let prepared = try ITorahStorageLock.tryWithLock(name: "migration-\(profileID)") {
            try ITorahStorageLock.tryWithLock(name: "database-mutation-\(profileID)") {
                try ITorahStorageLock.tryWithLock(name: "otzaria-search-mutation-\(profileID)") {
                    guard lock.try() else { return false }
                    defer { lock.unlock() }
                    try OtzariaSearchEngineBridge.checkExecutionPreparationDeadline(deadline)
                    try validateSource()
                    guard profileID == OtzariaDataProfileRegistry.activeProfileID,
                          manager.indexURL(for: databasePath) == expectedIndexURL,
                          readPublicationRevision() == expectedRevision else {
                        throw OtzariaSearchExecutionPreparationError.sourceChanged
                    }
                    let fileManager = FileManager.default
                    guard !indexingDatabasePaths.contains(databasePath),
                          !fileManager.fileExists(atPath: manager.sentinelURL(for: databasePath).path),
                          !fileManager.fileExists(atPath: manager.buildingIndexURL(for: databasePath).path),
                          !fileManager.fileExists(atPath: expectedIndexURL.appendingPathExtension("installing").path) else {
                        throw OtzariaSearchExecutionPreparationError.unavailable
                    }
                    let before = try openIndexStamp(databasePath: databasePath)
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                    guard try encoder.encode(before) == expectedFingerprint,
                          try smallMetadata(at: expectedIndexURL.appendingPathComponent("otzaria_index_meta.json")) == expectedIndexMetadata else {
                        throw OtzariaSearchExecutionPreparationError.sourceChanged
                    }
                    try OtzariaSearchEngineBridge.validateExistingCompatibleIndex(expectedIndexURL)
                    let translationKey = "Vendor/OtzariaSearchEngine/Resources/dictionary.json"
                    let acronymsKey = "Vendor/OtzariaSearchEngine/Resources/Acronyms.json"
                    guard Set(requiredResourceHashes.keys) == Set([translationKey, acronymsKey]),
                          let translationHash = requiredResourceHashes[translationKey],
                          let acronymsHash = requiredResourceHashes[acronymsKey],
                          let translation = Bundle.main.url(forResource: "dictionary", withExtension: "json"),
                          let acronyms = Bundle.main.url(forResource: "Acronyms", withExtension: "json") else {
                        throw OtzariaSearchExecutionPreparationError.unavailable
                    }
                    func validateDictionaries() throws {
                        try OtzariaSearchEngineBridge.validateExecutionDictionary(translation, expectedSHA256: translationHash, deadline: deadline)
                        try OtzariaSearchEngineBridge.validateExecutionDictionary(acronyms, expectedSHA256: acronymsHash, deadline: deadline)
                    }
                    func validateCurrentSource() throws {
                        try OtzariaSearchEngineBridge.checkExecutionPreparationDeadline(deadline)
                        try validateSource()
                        guard profileID == OtzariaDataProfileRegistry.activeProfileID,
                              manager.indexURL(for: databasePath) == expectedIndexURL,
                              readPublicationRevision() == expectedRevision,
                              before == (try openIndexStamp(databasePath: databasePath)),
                              try smallMetadata(at: expectedIndexURL.appendingPathComponent("otzaria_index_meta.json")) == expectedIndexMetadata else {
                            throw OtzariaSearchExecutionPreparationError.sourceChanged
                        }
                    }
                    func validateCount(_ engine: OtzariaSearchEngineBridge) throws {
                        try validateCurrentSource()
                        let count = try engine.documentCount()
                        guard count > 0, count == expectedDocumentCount else {
                            throw OtzariaSearchExecutionPreparationError.unavailable
                        }
                        try validateCurrentSource()
                    }
                    try validateDictionaries()
                    try validateCurrentSource()
                    if let cached = engineCache[databasePath] {
                        guard engineStamps[databasePath] == before else {
                            throw OtzariaSearchExecutionPreparationError.sourceChanged
                        }
                        try validateCount(cached)
                        try validateDictionaries()
                        try validateCurrentSource()
                        return true
                    }
                    let engine = try OtzariaSearchEngineBridge(existingIndexURL: expectedIndexURL)
                    var published = false
                    defer { if !published { engine.close() } }
                    // A synchronous native open cannot be interrupted. Reject
                    // changed authority before any further native operation.
                    try validateCurrentSource()
                    try Self.configureRequiredDictionaries(engine: engine,
                        magic: OtzariaMagicDictionaryManager.shared.validatedDatabaseURL,
                        translation: translation, acronyms: acronyms)
                    try validateCount(engine)
                    try validateDictionaries()
                    try validateCurrentSource()
                    // Opening does not change source authority. As in the original
                    // engine(), retain its exact current stamp without a new grant.
                    engineCache[databasePath] = engine
                    engineStamps[databasePath] = before
                    published = true
                    return true
                } ?? false
            } ?? false
        }
        return prepared ?? false
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
        try withSearchReadAccess(databasePath: databasePath) {
            try engine(databasePath: databasePath).documentCount()
        }
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
        try withSearchReadAccess(databasePath: databasePath) {
            let engine = try engine(databasePath: databasePath)
            let before = engineStamps[databasePath]
            let page = try engine.search(request)
            guard let before, before == (try? openIndexStamp(databasePath: databasePath)) else {
                invalidate(databasePath: databasePath)
                throw OtzariaSearchArtifactError.incompatible("source changed during search")
            }
            return page
        }
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
