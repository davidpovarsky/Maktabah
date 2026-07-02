import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension SearchResultItem: @unchecked Sendable {}

final class OtzariaTantivySearchRepository: @unchecked Sendable {
    static let shared = OtzariaTantivySearchRepository()

    private let manager = OtzariaSearchIndexManager.shared
    private var engineCache: [String: OtzariaSearchEngineBridge] = [:]
    private let lock = NSRecursiveLock()

    private init() {}

    func engine(databasePath: String) throws -> OtzariaSearchEngineBridge {
        lock.lock()
        defer { lock.unlock() }
        if let cached = engineCache[databasePath] {
            return cached
        }
        let indexURL = manager.indexURL(for: databasePath)
        let engine = try OtzariaSearchEngineBridge(indexURL: indexURL)
        engineCache[databasePath] = engine
        return engine
    }

    func documentCount(databasePath: String) throws -> UInt64 {
        try engine(databasePath: databasePath).documentCount()
    }

    func invalidate(databasePath: String) {
        lock.lock()
        defer { lock.unlock() }
        engineCache[databasePath] = nil
    }

    func search(databasePath: String, request: OtzariaSearchRequest) throws -> [SearchResultItem] {
        let engine = try engine(databasePath: databasePath)
        let results = try engine.search(request)
        return results.map { result in
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
                mutable.append(NSAttributedString(string: OtzariaSearchTextNormalizer.plainTextFromSnippetHTML(before)))
            }
            remaining = String(remaining[openRange.upperBound...])
            guard let closeRange = remaining.range(of: closeTag, options: [.caseInsensitive]) else { break }
            let highlighted = String(remaining[..<closeRange.lowerBound])
            mutable.append(NSAttributedString(
                string: OtzariaSearchTextNormalizer.plainTextFromSnippetHTML(highlighted),
                attributes: highlightAttributes()
            ))
            remaining = String(remaining[closeRange.upperBound...])
        }

        if !remaining.isEmpty {
            mutable.append(NSAttributedString(string: OtzariaSearchTextNormalizer.plainTextFromSnippetHTML(remaining)))
        }

        if mutable.length == 0 {
            return NSAttributedString(string: OtzariaSearchTextNormalizer.plainTextFromSnippetHTML(html))
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
