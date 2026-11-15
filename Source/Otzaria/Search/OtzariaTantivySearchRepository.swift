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
    }

    private func openIndexStamp(databasePath: String) throws -> OpenIndexStamp {
        let url = manager.indexURL(for: databasePath)
        return try OpenIndexStamp(profile: OtzariaDataProfileRegistry.activeProfileID,
            database: manager.currentFingerprint(databasePath: databasePath), path: url.path,
            metadata: smallMetadata(at: url.appendingPathComponent("meta.json")),
            identity: smallMetadata(at: manager.identityURL(indexURL: url)))
    }

    private func smallMetadata(at url: URL) throws -> Data {
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        guard let size, size.uint64Value <= 1_048_576 else {
            throw OtzariaSearchError.invalidEngineResponse("Search readiness metadata is missing or oversized")
        }
        return try Data(contentsOf: url)
    }

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
