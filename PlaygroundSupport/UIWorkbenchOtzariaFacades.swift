import Foundation
import SwiftUI

final class OtzariaMaktabahBridge {
    static let shared = OtzariaMaktabahBridge()
    var isEnabled = false
}

enum OtzariaLibraryImportActions {
    static var isEnabled: Bool { false }
    static func handleSelectionChange(
        viewModel: LibraryViewModel,
        navigationManager: iOSNavigationManager
    ) {}
    static func handleDownloadSingleBook(
        _ book: BooksData,
        viewModel: LibraryViewModel,
        navigationManager: iOSNavigationManager
    ) {
        navigationManager.openBook(book)
    }
    static func disconnectDatabase(viewModel: LibraryViewModel) {}
    static func installDatabase(
        from result: Result<[URL], Error>,
        viewModel: LibraryViewModel
    ) throws {}
}

final class OtzariaDatabaseAccessController {
    enum Source { case managedInternal, external }
    static let shared = OtzariaDatabaseAccessController()
    var source: Source = .managedInternal
}

enum OtzariaIndexFileLogger {
    static func logFileURL() -> URL? { nil }
    static func readLog() -> String { "UI workbench — indexing disabled." }
}

enum OtzariaSearchEngineBridge {
    static func splitQueryWords(_ query: String) throws -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }
    static func highlightPattern(
        for request: OtzariaSearchRequest
    ) throws -> PlaygroundHighlightPattern? { nil }
}

enum PlaygroundOtzariaSearchStatus: Equatable {
    case ready
    case checkingPackage
    case building
    case finalizing
    case downloadingPackage
    case installingPackage
    case unavailable

    var label: String {
        switch self {
        case .ready: "מוכן"
        case .checkingPackage: "בודק חבילה…"
        case .building: "בונה אינדקס…"
        case .finalizing: "מסיים…"
        case .downloadingPackage: "מוריד…"
        case .installingPackage: "מתקין…"
        case .unavailable: "לא מותקן"
        }
    }
}

final class OtzariaTextSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var mode: OtzariaSearchMode = .advanced
    @Published var order: OtzariaSearchOrder = .catalogue
    @Published var negativeQuery = ""
    @Published var scope: OtzariaSearchScope = .wordDistance
    @Published var negativeScope: OtzariaSearchScope = .wordDistance
    @Published var wordMatchMode: OtzariaWordMatchMode = .all
    @Published var wordMatchCount = 1
    @Published var distance = 0
    @Published var negativeDistance = 0
    @Published var matchNikud = false
    @Published var matchTaamim = false
    @Published var grouping: OtzariaResultGrouping?
    @Published var customSpacing: [String: String] = [:]
    @Published var alternativeWords: [String: [String]] = [:]
    @Published var searchOptions: [String: [String: Bool]] = [:]
    @Published var results: [SearchResultItem] = []
    @Published var enginePage: OtzariaSearchPage?
    @Published var isSearching = false
    @Published var isIndexing = false
    @Published var errorMessage: String?
    @Published var indexStatusDetail: String?
    @Published var totalCount = 0
    @Published var resultsTruncated = false
    @Published var status: PlaygroundOtzariaSearchStatus = .ready

    func refreshStatus() { status = .ready }
    func search() { isSearching = false }
    func rebuildIndex() { isIndexing = false }
    func cancelIndexing() { isIndexing = false }
}

final class OtzariaMagicDictionaryManager {
    static let shared = OtzariaMagicDictionaryManager()
    var validatedDatabaseURL: URL? { nil }
}

struct OtzariaReaderSourcesInspectorHost: View {
    let viewModel: ReaderViewModel
    let navigationManager: iOSNavigationManager

    var body: some View {
        ContentUnavailableView(
            "Sources",
            systemImage: "link",
            description: Text("Source lookup is disabled in the UI-only workbench.")
        )
    }
}
