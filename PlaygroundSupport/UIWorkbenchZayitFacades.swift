import Foundation
import SwiftUI

actor ZayitSearchRepository {
    private(set) var configured = false

    func configure(paths: ZayitSearchDataPaths) throws { configured = true }
    func reset() { configured = false }

    func search(
        query: String,
        near: UInt32,
        offset: Int,
        limit: Int,
        filters: ZayitSearchFilters
    ) throws -> ZayitSearchPage {
        ZayitSearchPage(hits: [], totalHits: 0, isLastPage: true)
    }
}

@MainActor
final class ZayitSearchSessionController: ObservableObject {
    enum State: Equatable {
        case notConfigured
        case restoring
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .ready
    let model = ZayitSearchViewModel(repository: ZayitSearchRepository())

    func restoreIfNeeded(existingSeforimDB: URL?) async { state = .ready }
    func chooseFolder(_ url: URL, existingSeforimDB: URL?) async { state = .ready }
    func forget() async {
        await model.reset()
        state = .notConfigured
    }
}

enum ZayitSearchExistingDatabaseProvider {
    static var currentURL: URL? { nil }
}

enum ZayitSearchReaderNavigationAdapter {
    static func open(
        _ hit: ZayitSearchHit,
        using navigationManager: iOSNavigationManager
    ) -> Bool { false }
}
