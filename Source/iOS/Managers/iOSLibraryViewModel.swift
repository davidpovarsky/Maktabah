import Foundation
import SwiftUI

@MainActor
@Observable
class iOSLibraryViewModel {
    var rootCategories: [CategoryData] = []

    /// We use a backing property so @Observable can track changes and trigger view updates
    var _showOnlyDownloadedTracker: Bool = false

    var showOnlyDownloaded: Bool {
        get {
            // Read from UserDefaults but also access the tracker to register the dependency in @Observable
            _ = _showOnlyDownloadedTracker
            return UserDefaults.standard.integer(forKey: "filterSegmentIndex") == 1
        }
        set {
            UserDefaults.standard.set(newValue ? 1 : 0, forKey: "filterSegmentIndex")
            // Update the tracker to notify SwiftUI that displayedCategories needs to be recomputed
            _showOnlyDownloadedTracker = newValue
        }
    }

    var searchText: String = "" {
        didSet {
            // Just updating the text will trigger SwiftUI if it's used, but let's make sure
        }
    }

    var isLoading = true
    private var hasLoadedLibrary = false

    init() {
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .bookIntegrated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rootCategories = LibraryDataManager.shared.allRootCategories
            }
        }

        NotificationCenter.default.addObserver(
            forName: .libraryFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshLibrary()
            }
        }
    }

    var displayedCategories: [CategoryData] {
        var base = rootCategories
        if showOnlyDownloaded {
            base = LibraryDataManager.shared.filterIntegrated()
        }

        if searchText.isEmpty {
            return base
        } else {
            var filtered: [CategoryData] = []
            _ = LibraryDataManager.shared.filterContent(
                with: searchText,
                displayedCategories: &filtered,
                baseCategories: base
            )
            return filtered
        }
    }

    func loadLibrary() async {
        if hasLoadedLibrary { return }
        await load()
    }

    func refreshLibrary() async {
        await load()
    }

    private func load() async {
        isLoading = true
        await LibraryDataManager.shared.loadData()
        rootCategories = LibraryDataManager.shared.allRootCategories
        isLoading = false
        hasLoadedLibrary = LibraryDataManager.shared.isDataLoaded
    }

    func isBookDownloaded(_ book: BooksData) -> Bool {
        BookArchiveIntegrator.shared.isBookIntegrated(book)
    }
}
