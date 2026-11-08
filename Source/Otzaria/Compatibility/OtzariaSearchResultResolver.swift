import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum OtzariaSearchResultResolver {
    private static let tablePrefix = "otzaria:"

    static var allowsSearchWithoutSelectedTables: Bool {
        #if os(iOS)
        OtzariaBackendActivation.isActive
        #else
        false
        #endif
    }

    static func bookId(from tableName: String) -> Int? {
        if tableName.hasPrefix(tablePrefix) {
            return Int(tableName.dropFirst(tablePrefix.count))
        }
        if tableName.hasPrefix("b") {
            return Int(tableName.dropFirst())
        }
        return Int(tableName)
    }

    static func resolveBook(
        from result: SearchResultItem,
        libraryDataManager: LibraryDataManager
    ) -> BooksData? {
        guard let bookId = bookId(from: result.tableName) else { return nil }
        return libraryDataManager.getBook([bookId]).first
    }
}

#if canImport(UIKit)
extension SearchResultItem {
    /// Check the current database policy at the export boundary, including collapsed snippets.
    @MainActor
    func copySearchResultToPasteboard(includingSource: Bool) async {
        if let locator = backendLocator, locator.backend == .otzaria {
            let generation = OtzariaMaktabahBridge.shared.generationSnapshot()
            guard (try? await OtzariaLineDecorationRepository().allowsTextExport(workKey: locator.workKey)) == true,
                  !Task.isCancelled,
                  generation == OtzariaMaktabahBridge.shared.generationSnapshot() else { return }
        }
        let parts = includingSource ? [attributedText.string, bookTitle] : [attributedText.string]
        UIPasteboard.general.string = parts.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
#endif
