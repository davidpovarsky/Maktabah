import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension SearchResultItem: @unchecked Sendable {}

final class OtzariaTantivySearchRepository: @unchecked Sendable {
    static let shared = OtzariaTantivySearchRepository()

    private let manager = OtzariaSearchIndexManager.shared
    private var engineCache: [String: OtzariaSearchEngineBridge] = [:]
    private var indexingDatabasePaths: Set<String> = []
    private let lock = NSRecursiveLock()

    private init() {}

    func engine(databasePath: String) throws -> OtzariaSearchEngineBridge {
        lock.lock()
        defer { lock.unlock() }
        if indexingDatabasePaths.contains(databasePath) {
            throw OtzariaSearchError.invalidEngineResponse("Otzaria Tantivy indexing is in progress for this database.")
        }
        try OtzariaSearchEngineBridge.configureLibrarySource(databaseURL: URL(fileURLWithPath: databasePath))
        if let cached = engineCache[databasePath] {
            return cached
        }
        let indexURL = manager.indexURL(for: databasePath)
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
        return engine
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
        try engine(databasePath: databasePath).documentCount()
    }

    func invalidate(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        if let engine = engineCache[databasePath] {
            engine.close()
            engineCache[databasePath] = nil
        }
        OtzariaIndexFileLogger.log("repository cache invalidated databasePath=\(databasePath)")
    }

    func closeEngine(databasePath: String) {
        invalidate(databasePath: databasePath)
    }

    func closeAllEngines() {
        lock.lock()
        defer { lock.unlock() }
        for engine in engineCache.values {
            engine.close()
        }
        engineCache.removeAll()
        OtzariaIndexFileLogger.log("repository closeAllEngines done")
    }

    func beginExclusiveIndexing(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        if let engine = engineCache[databasePath] {
            engine.close()
            engineCache[databasePath] = nil
        }
        indexingDatabasePaths.insert(databasePath)
        OtzariaIndexFileLogger.log("exclusive indexing begin databasePath=\(databasePath)")
    }

    func endExclusiveIndexing(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        if let engine = engineCache[databasePath] {
            engine.close()
            engineCache[databasePath] = nil
        }
        indexingDatabasePaths.remove(databasePath)
        OtzariaIndexFileLogger.log("exclusive indexing end databasePath=\(databasePath)")
    }

    func search(databasePath: String, request: OtzariaSearchRequest) async throws -> OtzariaSearchPage {
        let generation = OtzariaMaktabahBridge.shared.generationSnapshot()
        let engine = try engine(databasePath: databasePath)
        var page = try await engine.searchCancellable(request)
        guard generation == OtzariaMaktabahBridge.shared.generationSnapshot(),
              databasePath == OtzariaMaktabahBridge.shared.databasePath else { throw CancellationError() }
        page.sourceGeneration = generation
        return page
    }

    func navigationItems(from page: OtzariaSearchPage) throws -> [SearchResultItem] {
        guard page.sourceGeneration == OtzariaMaktabahBridge.shared.generationSnapshot() else { throw CancellationError() }
        guard page.results.allSatisfy({ $0.textStatus == nil || $0.textStatus == "ok" }) else {
            throw OtzariaSearchError.invalidEngineResponse("The search index no longer matches the available library text. Repair or rebuild the matching index.")
        }
        let canonical: [String: [UInt64: Int]] = try OtzariaMaktabahBridge.shared.withDatabase { database in
            let capabilities = try OtzariaDatabaseCapabilities(database: database)
            let groups = Dictionary(grouping: page.results.filter { !$0.isPdf }, by: \.filePath)
            var result: [String: [UInt64: Int]] = [:]
            for (path, hits) in groups {
                guard let bookID = bookId(from: path) else { throw LibraryBackendError.invalidLocator }
                result[path] = try OtzariaSearchLineIndexResolver.resolve(ordinals: Set(hits.map(\.segment)),
                    bookID: bookID, database: database, capabilities: capabilities)
            }
            return result
        }
        return try page.results.map { result in
            let (attrText, highlightTerms) = highlightedText(from: result.text)
            guard let bkid = bookId(from: result.filePath), bkid > 0 else { throw LibraryBackendError.invalidLocator }
            let line: Int
            if result.isPdf {
                guard let pageIndex = Int(exactly: result.segment) else { throw LibraryBackendError.invalidLocator }
                line = pageIndex
            } else {
                guard let actual = canonical[result.filePath]?[result.segment] else { throw LibraryBackendError.invalidLocator }
                line = actual
            }
            let locator = TextLocator(
                backend: .otzaria,
                workKey: "book:\(bkid)",
                position: .legacyLine(line)
            )
            return SearchResultItem(
                archive: "Otzaria",
                tableName: "otzaria:\(bkid)",
                bookId: bkid,
                bookTitle: result.title,
                page: line,
                part: 0,
                attributedText: attrText,
                backendLocator: locator,
                locationDisplayText: result.reference.isEmpty ? nil : result.reference,
                highlightTerms: highlightTerms.isEmpty ? nil : highlightTerms
            )
        }
    }

    private func bookId(from filePath: String) -> Int? {
        let prefix = filePath.hasPrefix("id:") ? "id:" : "otzaria-book:"
        guard filePath.hasPrefix(prefix) else { return nil }
        return Int(filePath.dropFirst(prefix.count))
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
