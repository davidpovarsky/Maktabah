import Foundation
import Observation
import SwiftUI

@Observable
class HistoryViewModel: ViewModelBase, ObservableObject {
    static let shared = HistoryViewModel()

    var entriesByBookId: [Int: ReadingEntry] = [:]
    var historyOrder: [Int] = []

    var historyBooks: [BooksData] = []
    var favoriteBooks: [BooksData] = []
    var searchText: String = ""

    /// Passive provenance only. The original arrays remain the UI's data owner;
    /// unqualified or obsolete publications never become record-route authority.
    private(set) var qualifiedPublication: HistoryQualifiedPublication?
    private var qualifiedLoadRevision: UInt64? = 0

    func beginQualifiedPublication() -> HistoryQualifiedPublication.Load {
        qualifiedPublication = nil
        if let revision = qualifiedLoadRevision, revision < .max {
            qualifiedLoadRevision = revision + 1
        } else {
            qualifiedLoadRevision = nil
        }
        return .init(revision: qualifiedLoadRevision)
    }

    func invalidateQualifiedPublication() { qualifiedPublication = nil }

    func completeQualifiedPublication(_ load: HistoryQualifiedPublication.Load,
                                      entries: QualifiedLocatorStore.PublishedEntries) {
        qualifiedPublication = nil
        guard let revision = load.revision, qualifiedLoadRevision == revision,
              load.isCurrent, let observation = entries.observation, observation.isCurrent,
              let publication = HistoryQualifiedPublication(
                model: self, load: load, entries: entries.entries, observation: observation) else { return }
        qualifiedPublication = publication
    }

    func isCurrentQualifiedLoad(_ load: HistoryQualifiedPublication.Load) -> Bool {
        guard let revision = load.revision else { return false }
        return qualifiedLoadRevision == revision && load.isCurrent
    }

    func filterBooks(_ books: [BooksData]) -> [BooksData] {
        guard !searchText.isEmpty else { return books }
        let normalizedSearchText = searchText.normalizeArabic(false)
        return books.filter { book in
            book.book.normalizeArabic(false).localizedStandardContains(normalizedSearchText)
        }
    }

    var filteredFavorites: [BooksData] {
        filterBooks(favoriteBooks)
    }

    var filteredHistory: [BooksData] {
        filterBooks(historyBooks)
    }

    let maxHistoryCount = 50

    /// Legacy UserDefaults keys
    let legacyHistoryKey = "iOSReadingEntries"

    /// Debounce for batched CloudKit deletions
    var pendingCloudKitDeletes: Set<String> = []
    var deleteDebounceTask: Task<Void, Never>?

    private var saveDebounceTask: Task<Void, Never>?
    private var reloadDebounceTask: Task<Void, Never>?

    var historyBookIds: [Int] {
        get { historyOrder }
        set {
            historyOrder = Array(newValue.prefix(maxHistoryCount))
            scheduleSave()
            loadBooksData()
            notifyHistoryChanged()
        }
    }

    private func scheduleSave() {
        saveDebounceTask?.cancel()
        let order = historyOrder
        saveDebounceTask = Task.detached {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            HistoryDatabaseManager.shared.saveHistoryOrder(order)
            await MainActor.run { [weak self] in
                self?.saveDebounceTask = nil
            }
        }
    }

    private func scheduleReloadBooksData() {
        reloadDebounceTask?.cancel()
        reloadDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.loadBooksData()
            self?.reloadDebounceTask = nil
        }
    }

    var favoriteBookIds: [Int] {
        entriesByBookId.values
            .filter(\.isFavorite)
            .sorted { lhs, rhs in
                // Gunakan favoritedAt atau favoriteUpdatedAt.
                // Jangan gunakan updatedAt/lastOpenedAt karena nilainya akan berubah
                // saat user membaca buku, membuat posisinya naik ke atas.
                let lDate = lhs.favoritedAt ?? Date.distantPast
                let rDate = rhs.favoritedAt ?? Date.distantPast
                if lDate != rDate {
                    return lDate > rDate
                }
                return lhs.bookId < rhs.bookId
            }
            .map(\.bookId)
    }

    override init() {
        super.init()
        HistoryDatabaseManager.shared.setupDatabase()
        HistoryDatabaseManager.shared.migrateFromUserDefaultsIfNeeded()
        migrateLegacyKVSDataIfNeeded()
        loadFromDatabase()
        backfillCloudKitFieldsIfNeeded()
        loadBooksData()

        for name in [Notification.Name.bookIntegrated, .booksChanged] {
            addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.scheduleReloadBooksData()
                }
            }
        }

        enableBookIdMigrationObserver()
        addObserver(forName: .activeLibraryBackendDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadBooksData()
            }
        }
    }

    override func migrateBookId(from oldId: Int, to newId: Int) {
        guard let entry = entriesByBookId.removeValue(forKey: oldId) else { return }
        let migrated = ReadingEntry(
            bookId: newId,
            lastContentId: entry.lastContentId,
            lastOpenedAt: entry.lastOpenedAt,
            favoritedAt: entry.favoritedAt,
            positionUpdatedAt: entry.positionUpdatedAt,
            updatedAt: Date(),
            isFavorite: entry.isFavorite,
            ckRecordId: String(newId)
        )
        entriesByBookId[newId] = migrated
        if let idx = historyOrder.firstIndex(of: oldId) {
            historyOrder[idx] = newId
        }

        // Update DB: delete old, insert new
        if let oldCkId = entry.ckRecordId {
            try? HistoryDatabaseManager.shared.addPendingSync(ckRecordId: oldCkId, operation: "delete")
        }
        HistoryDatabaseManager.shared.deleteEntry(bookId: oldId)
        if let ckId = migrated.ckRecordId {
            try? HistoryDatabaseManager.shared.addPendingSync(ckRecordId: ckId, operation: "upload")
        }
        HistoryDatabaseManager.shared.upsertEntry(migrated)
        HistoryDatabaseManager.shared.saveHistoryOrder(historyOrder)

        // Hapus entry lama dari CloudKit
        if let oldCkId = entry.ckRecordId {
            CloudKitSyncManager.shared.delete(ckRecordIds: [oldCkId], target: .history, trackPending: false)
        }

        // Upload entry baru
        loadBooksData()
        notifyHistoryChanged()
        CloudKitSyncManager.shared.uploadHistory(entries: [migrated], trackPending: false)
    }

    // MARK: - Notifications

    func notifyHistoryChanged() {
        NotificationCenter.default.post(name: .historyDidChange, object: self)
    }
}

/// Source-owned correlation between the actual original cards and the exact
/// qualified entries that produced them. This is not a second History model.
@MainActor
final class HistoryQualifiedPublication {
    @MainActor struct Load {
        let revision: UInt64?
        let backend: BackendID
        let generation: UInt64
        let transition: UInt64
        let qualified: Bool

        init(revision: UInt64?) {
            let source = BackendCoordinator.shared
            self.revision = revision
            backend = source.activeBackendID; generation = source.generation
            transition = source.activeTransitionToken
            qualified = !source.usesNativeMaktabahDataPath && !source.isTransitioning
        }
        var isCurrent: Bool {
            let source = BackendCoordinator.shared
            return revision != nil && qualified && !source.usesNativeMaktabahDataPath
                && !source.isTransitioning && source.activeBackendID == backend
                && source.generation == generation && source.activeTransitionToken == transition
        }
    }
    struct Card {
        let book: BooksData
        let locator: TextLocator
        let recordID: String
    }
    let load: Load
    let history: [Card]
    let favorites: [Card]
    private weak var model: HistoryViewModel?
    private let observation: QualifiedLocatorStore.PublicationSource.Observation

    init?(model: HistoryViewModel, load: Load,
          entries: [QualifiedLocatorStore.HistoryEntry],
          observation: QualifiedLocatorStore.PublicationSource.Observation) {
        guard load.isCurrent, observation.isCurrent else { return nil }
        let relevant = entries.filter { $0.locator.backend == load.backend }
        guard Set(relevant.map(\.id)).count == relevant.count else { return nil }
        let byID = Dictionary(uniqueKeysWithValues: relevant.map { ($0.id, $0) })
        func cards(_ books: [BooksData], favorite: Bool) -> [Card]? {
            // The original ForEach uses numeric work IDs. Two positions of the
            // same work cannot be distinguished by that original row identity.
            guard Set(books.map(\.id)).count == books.count else { return nil }
            var result: [Card] = []
            for book in books {
                guard let locator = book.backendLocator, locator.backend == load.backend,
                      let entry = byID[locator.persistenceKey], entry.locator == locator,
                      favorite ? entry.isFavorite : entry.lastOpened != .distantPast else { return nil }
                result.append(Card(book: book, locator: locator, recordID: entry.id))
            }
            return result
        }
        guard let history = cards(model.historyBooks, favorite: false),
              let favorites = cards(model.favoriteBooks, favorite: true) else { return nil }
        self.model = model; self.load = load; self.observation = observation
        self.history = history; self.favorites = favorites
    }

    func isCurrent(in model: HistoryViewModel) -> Bool {
        guard self.model === model, model.qualifiedPublication === self,
              load.isCurrent, observation.isCurrent else { return false }
        func matches(_ cards: [Card], _ books: [BooksData]) -> Bool {
            cards.count == books.count && zip(cards, books).allSatisfy {
                $0.book === $1 && $1.backendLocator == $0.locator
                    && $0.recordID == $0.locator.persistenceKey
            }
        }
        return matches(history, model.historyBooks) && matches(favorites, model.favoriteBooks)
    }

    /// Atomic only with respect to the original actor's publication metadata;
    /// callers still must validate the exact scene/view/route before reporting.
    func withCurrent<Result>(in model: HistoryViewModel,
                             _ operation: () throws -> Result) rethrows -> Result? {
        try observation.withCurrent {
            guard isCurrent(in: model) else { return nil as Result? }
            return try operation()
        } ?? nil
    }
}
