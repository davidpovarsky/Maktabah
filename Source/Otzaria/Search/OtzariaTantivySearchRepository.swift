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

    func search(databasePath: String, request: OtzariaSearchRequest) throws -> OtzariaSearchPage {
        let engine = try engine(databasePath: databasePath)
        return try engine.search(request)
    }

    func navigationItems(from page: OtzariaSearchPage) -> [SearchResultItem] {
        page.results.map { result in
            SearchResultItem(
                archive: "Otzaria",
                tableName: "otzaria:\(bookId(from: result.filePath) ?? 0)",
                bookId: bookId(from: result.filePath) ?? 0,
                bookTitle: result.title,
                page: Int(result.segment),
                part: 1,
                attributedText: highlightedText(from: result.text)
            )
        }
    }

    private func bookId(from filePath: String) -> Int? {
        guard filePath.hasPrefix("otzaria-book:") else { return nil }
        return Int(filePath.dropFirst("otzaria-book:".count))
    }

    private func highlightedText(from html: String) -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: "")
        var remaining = html
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
            mutable.append(NSAttributedString(
                string: OtzariaSearchSnippetRenderer.plainText(fromHTML: highlighted),
                attributes: highlightAttributes()
            ))
            remaining = String(remaining[closeRange.upperBound...])
        }

        if !remaining.isEmpty {
            mutable.append(NSAttributedString(string: OtzariaSearchSnippetRenderer.plainText(fromHTML: remaining)))
        }

        if mutable.length == 0 {
            return NSAttributedString(string: OtzariaSearchSnippetRenderer.plainText(fromHTML: html))
        }
        return mutable
    }

    private func highlightAttributes() -> [NSAttributedString.Key: Any] {
        #if canImport(UIKit)
        return [
            .foregroundColor: UIColor.systemRed,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        #else
        return [:]
        #endif
    }
}
