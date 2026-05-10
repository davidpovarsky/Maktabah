import Combine
import Foundation
import SwiftUI

struct iOSReadingEntry: Codable, Identifiable, Equatable {
    let bookId: Int
    var lastContentId: Int?
    var lastOpenedAt: Date?
    var favoritedAt: Date?
    var positionUpdatedAt: Date?
    var favoriteUpdatedAt: Date?
    var updatedAt: Date
    var isFavorite: Bool

    var id: Int {
        bookId
    }
}

@MainActor
class iOSHistoryViewModel: ObservableObject {
    static let shared = iOSHistoryViewModel()

    @Published private(set) var entriesByBookId: [Int: iOSReadingEntry] = [:]
    @Published private(set) var historyOrder: [Int] = []

    @Published var historyBooks: [BooksData] = []
    @Published var favoriteBooks: [BooksData] = []

    private var cloudObserver: NSObjectProtocol?
    private var isApplyingRemoteUpdate = false
    private var lastKVSUpdateDate: Date = .distantPast
    private let kvsUpdateInterval: TimeInterval = 5.0
    private var pendingCloudSyncTimer: Timer?

    var historyBookIds: [Int] {
        get { historyOrder }
        set {
            historyOrder = Array(newValue.prefix(maxHistoryCount))
            let validIds = Set(historyOrder)
            entriesByBookId = entriesByBookId.filter { validIds.contains($0.key) || $0.value.isFavorite }
            for bookId in historyOrder where entriesByBookId[bookId] == nil {
                entriesByBookId[bookId] = iOSReadingEntry(
                    bookId: bookId,
                    lastContentId: nil,
                    lastOpenedAt: .distantPast,
                    favoritedAt: nil,
                    positionUpdatedAt: .distantPast,
                    favoriteUpdatedAt: nil,
                    updatedAt: .distantPast,
                    isFavorite: false
                )
            }
            persistAndReload(forceCloud: true)
        }
    }

    var favoriteBookIds: [Int] {
        get {
            entriesByBookId.values
                .filter(\.isFavorite)
                .sorted { lhs, rhs in
                    let lDate = lhs.favoritedAt ?? lhs.updatedAt
                    let rDate = rhs.favoritedAt ?? rhs.updatedAt
                    if lDate != rDate { return lDate > rDate }
                    return lhs.bookId < rhs.bookId
                }
                .map(\.bookId)
        }
        set {
            let newFavorites = Set(newValue)
            let now = Date()

            for bookId in newFavorites {
                var entry = entry(for: bookId)
                if !entry.isFavorite {
                    entry.isFavorite = true
                    entry.favoritedAt = now
                    entry.favoriteUpdatedAt = now
                    entry.updatedAt = now
                }
                entriesByBookId[bookId] = entry
            }

            for bookId in entriesByBookId.keys where !newFavorites.contains(bookId) {
                var entry = entriesByBookId[bookId]!
                entry.isFavorite = false
                entry.favoritedAt = nil
                entry.favoriteUpdatedAt = now
                entry.updatedAt = now
                if historyOrder.contains(bookId) {
                    entriesByBookId[bookId] = entry
                } else {
                    entriesByBookId.removeValue(forKey: bookId)
                }
            }

            persistAndReload(forceCloud: true)
        }
    }

    private let storageKey = "iOSReadingEntries"
    private let legacyHistoryKey = "iOSHistoryBookIds"
    private let legacyFavoritesKey = "iOSFavoriteBookIds"
    private let maxHistoryCount = 50
    private let cloudStore = NSUbiquitousKeyValueStore.default

    init() {
        startObservingCloudChanges()
        loadFromUserDefaults()
    }

    deinit {
        pendingCloudSyncTimer?.invalidate()
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
    }

    func loadFromUserDefaults() {
        cloudStore.synchronize()

        let localPayload = loadPayloadFromUserDefaults()
        let fallbackPayload = localPayload ?? migrateLegacyStoragePayload()
        let remotePayload = loadPayloadFromCloud()
        let merged = merge(local: fallbackPayload, remote: remotePayload)

        applyPayload(merged, persistToDisk: false)
        persistLocalPayload(merged)
    }

    func saveToUserDefaults() {
        persistStores(forceCloud: true)
    }

    func refreshFromCloud() {
        cloudStore.synchronize()

        guard let remotePayload = loadPayloadFromCloud() else { return }

        let merged = merge(local: currentPayload(), remote: remotePayload)
        applyPayload(merged, persistToDisk: false)
        persistLocalPayload(merged)
    }

    func addBookToHistory(_ bookId: Int, lastContentId: Int? = nil) {
        var entry = entry(for: bookId)
        let now = Date()
        entry.updatedAt = now
        entry.lastOpenedAt = now
        entry.positionUpdatedAt = now
        if let lastContentId {
            entry.lastContentId = lastContentId
        }
        entriesByBookId[bookId] = entry

        historyOrder.removeAll { $0 == bookId }
        historyOrder.insert(bookId, at: 0)

        if historyOrder.count > maxHistoryCount {
            historyOrder = Array(historyOrder.prefix(maxHistoryCount))
        }

        pruneOrphanedEntries()
        persistAndReload(forceCloud: true)
    }

    func updateLastContentId(_ contentId: Int?, for bookId: Int) {
        guard entriesByBookId[bookId] != nil || historyOrder.contains(bookId) else { return }

        var entry = entry(for: bookId)
        let now = Date()
        if entry.lastContentId == contentId { return }
        entry.lastContentId = contentId
        entry.positionUpdatedAt = now
        entry.updatedAt = now

        // Also update lastOpenedAt if it's been more than 5 minutes to keep it fresh in history
        let lastOpen = entry.lastOpenedAt ?? .distantPast
        if now.timeIntervalSince(lastOpen) > 300 {
            entry.lastOpenedAt = now

            // Move to top of history order
            historyOrder.removeAll { $0 == bookId }
            historyOrder.insert(bookId, at: 0)
        }

        entriesByBookId[bookId] = entry
        persistAndReload(forceCloud: false)
    }

    func lastContentId(for bookId: Int) -> Int? {
        entriesByBookId[bookId]?.lastContentId
    }

    func toggleFavorite(_ bookId: Int) {
        var entry = entry(for: bookId)
        let now = Date()
        entry.isFavorite.toggle()
        entry.favoriteUpdatedAt = now
        entry.updatedAt = now
        entry.favoritedAt = entry.isFavorite ? now : nil

        if entry.isFavorite || historyOrder.contains(bookId) {
            entriesByBookId[bookId] = entry
        } else {
            entriesByBookId.removeValue(forKey: bookId)
        }

        persistAndReload(forceCloud: true)
    }

    func removeHistory(_ bookId: Int) {
        historyOrder.removeAll { $0 == bookId }

        if var entry = entriesByBookId[bookId] {
            if entry.isFavorite {
                let now = Date()
                entry.lastOpenedAt = nil
                entry.positionUpdatedAt = now
                entry.updatedAt = now
                entriesByBookId[bookId] = entry
            } else {
                entriesByBookId.removeValue(forKey: bookId)
            }
        }

        persistAndReload(forceCloud: true)
    }

    func loadBooksData() {
        let dm = LibraryDataManager.shared
        historyBooks = historyOrder.compactMap { dm.getBook([$0]).first }
        favoriteBooks = favoriteBookIds.compactMap { dm.getBook([$0]).first }
    }

    private func entry(for bookId: Int) -> iOSReadingEntry {
        entriesByBookId[bookId] ?? iOSReadingEntry(
            bookId: bookId,
            lastContentId: nil,
            lastOpenedAt: nil,
            favoritedAt: nil,
            positionUpdatedAt: nil,
            favoriteUpdatedAt: nil,
            updatedAt: Date(),
            isFavorite: false
        )
    }

    private func pruneOrphanedEntries() {
        let historyIds = Set(historyOrder)
        entriesByBookId = entriesByBookId.filter { historyIds.contains($0.key) || $0.value.isFavorite }
    }

    private func migrateLegacyStoragePayload() -> StoredReadingEntries {
        let hIds = UserDefaults.standard.array(forKey: legacyHistoryKey) as? [Int] ?? []
        let fIds = UserDefaults.standard.array(forKey: legacyFavoritesKey) as? [Int] ?? []
        let favoriteSet = Set(fIds)

        var migratedEntries: [iOSReadingEntry] = []
        let migratedOrder = Array(hIds.prefix(maxHistoryCount))

        for bookId in migratedOrder {
            migratedEntries.append(iOSReadingEntry(
                bookId: bookId,
                lastContentId: nil,
                lastOpenedAt: .distantPast,
                favoritedAt: favoriteSet.contains(bookId) ? .distantPast : nil,
                positionUpdatedAt: .distantPast,
                favoriteUpdatedAt: favoriteSet.contains(bookId) ? .distantPast : nil,
                updatedAt: .distantPast,
                isFavorite: favoriteSet.contains(bookId)
            ))
        }

        for bookId in favoriteSet where !migratedEntries.contains(where: { $0.bookId == bookId }) {
            migratedEntries.append(iOSReadingEntry(
                bookId: bookId,
                lastContentId: nil,
                lastOpenedAt: nil,
                favoritedAt: .distantPast,
                positionUpdatedAt: nil,
                favoriteUpdatedAt: .distantPast,
                updatedAt: .distantPast,
                isFavorite: true
            ))
        }

        return StoredReadingEntries(historyOrder: migratedOrder, entries: migratedEntries)
    }

    private func persistAndReload(forceCloud: Bool = false) {
        persistStores(forceCloud: forceCloud)
        loadBooksData()
    }

    private func persistLocalPayload(_ payload: StoredReadingEntries) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func persistStores(forceCloud: Bool = false) {
        let payload = currentPayload()
        guard let data = try? JSONEncoder().encode(payload) else { return }

        UserDefaults.standard.set(data, forKey: storageKey)

        if !isApplyingRemoteUpdate {
            let now = Date()
            if forceCloud || now.timeIntervalSince(lastKVSUpdateDate) > kvsUpdateInterval {
                pendingCloudSyncTimer?.invalidate()
                pendingCloudSyncTimer = nil

                cloudStore.set(data, forKey: storageKey)
                cloudStore.synchronize()
                lastKVSUpdateDate = now
            } else if pendingCloudSyncTimer == nil {
                // Schedule a delayed sync to ensure the final state is captured
                pendingCloudSyncTimer = Timer.scheduledTimer(withTimeInterval: kvsUpdateInterval, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        self.persistStores(forceCloud: true)
                    }
                }
            }
        }
    }

    private func currentPayload() -> StoredReadingEntries {
        StoredReadingEntries(
            historyOrder: Array(historyOrder.prefix(maxHistoryCount)),
            entries: Array(entriesByBookId.values)
        )
    }

    private func loadPayloadFromUserDefaults() -> StoredReadingEntries? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(StoredReadingEntries.self, from: data)
    }

    private func loadPayloadFromCloud() -> StoredReadingEntries? {
        if let data = cloudStore.data(forKey: storageKey) {
            return try? JSONDecoder().decode(StoredReadingEntries.self, from: data)
        }

        // Migration: Check for legacy array-based keys in the cloud
        let hIds = cloudStore.array(forKey: legacyHistoryKey) as? [Int] ?? []
        let fIds = cloudStore.array(forKey: legacyFavoritesKey) as? [Int] ?? []

        if !hIds.isEmpty || !fIds.isEmpty {
            let favoriteSet = Set(fIds)
            var entries: [iOSReadingEntry] = []

            for bookId in hIds {
                entries.append(iOSReadingEntry(
                    bookId: bookId,
                    lastContentId: nil,
                    lastOpenedAt: .distantPast,
                    favoritedAt: favoriteSet.contains(bookId) ? .distantPast : nil,
                    positionUpdatedAt: .distantPast,
                    favoriteUpdatedAt: favoriteSet.contains(bookId) ? .distantPast : nil,
                    updatedAt: .distantPast,
                    isFavorite: favoriteSet.contains(bookId)
                ))
            }

            for bookId in favoriteSet where !entries.contains(where: { $0.bookId == bookId }) {
                entries.append(iOSReadingEntry(
                    bookId: bookId,
                    lastContentId: nil,
                    lastOpenedAt: nil,
                    favoritedAt: .distantPast,
                    positionUpdatedAt: nil,
                    favoriteUpdatedAt: .distantPast,
                    updatedAt: .distantPast,
                    isFavorite: true
                ))
            }

            return StoredReadingEntries(historyOrder: hIds, entries: entries)
        }

        return nil
    }

    private func applyPayload(_ payload: StoredReadingEntries, persistToDisk: Bool) {
        entriesByBookId = Dictionary(uniqueKeysWithValues: payload.entries.map { ($0.bookId, $0) })
        historyOrder = normalizedHistoryOrder(
            payload.historyOrder,
            entriesByBookId: entriesByBookId
        )
        pruneOrphanedEntries()
        loadBooksData()

        if persistToDisk {
            persistStores(forceCloud: false)
        }
    }

    private func merge(local: StoredReadingEntries, remote: StoredReadingEntries?) -> StoredReadingEntries {
        guard let remote else { return local }

        var mergedEntries = Dictionary(uniqueKeysWithValues: local.entries.map { ($0.bookId, $0) })
        let remoteEntries = Dictionary(uniqueKeysWithValues: remote.entries.map { ($0.bookId, $0) })

        for (bookId, remoteEntry) in remoteEntries {
            if let localEntry = mergedEntries[bookId] {
                mergedEntries[bookId] = mergeEntry(local: localEntry, remote: remoteEntry)
            } else {
                mergedEntries[bookId] = remoteEntry
            }
        }

        let mergedOrder = normalizedHistoryOrder(
            local.historyOrder + remote.historyOrder,
            entriesByBookId: mergedEntries
        )

        return StoredReadingEntries(
            historyOrder: mergedOrder,
            entries: Array(mergedEntries.values)
        )
    }

    private func mergeEntry(local: iOSReadingEntry, remote: iOSReadingEntry) -> iOSReadingEntry {
        var merged = local

        let localPositionUpdatedAt = local.positionUpdatedAt ?? .distantPast
        let remotePositionUpdatedAt = remote.positionUpdatedAt ?? .distantPast
        if remotePositionUpdatedAt > localPositionUpdatedAt {
            merged.lastContentId = remote.lastContentId
            merged.lastOpenedAt = remote.lastOpenedAt
            merged.positionUpdatedAt = remote.positionUpdatedAt
        }

        let localFavoriteUpdatedAt = local.favoriteUpdatedAt ?? .distantPast
        let remoteFavoriteUpdatedAt = remote.favoriteUpdatedAt ?? .distantPast
        if remoteFavoriteUpdatedAt > localFavoriteUpdatedAt {
            merged.isFavorite = remote.isFavorite
            merged.favoritedAt = remote.favoritedAt
            merged.favoriteUpdatedAt = remote.favoriteUpdatedAt
        }

        if let remoteLastOpenedAt = remote.lastOpenedAt,
           remoteLastOpenedAt > (merged.lastOpenedAt ?? .distantPast)
        {
            merged.lastOpenedAt = remoteLastOpenedAt
        }

        merged.updatedAt = [
            merged.positionUpdatedAt ?? .distantPast,
            merged.favoriteUpdatedAt ?? .distantPast,
            local.updatedAt,
            remote.updatedAt,
        ].max() ?? .distantPast

        return merged
    }

    private func normalizedHistoryOrder(
        _ rawOrder: [Int],
        entriesByBookId: [Int: iOSReadingEntry]
    ) -> [Int] {
        var seen = Set<Int>()
        let candidates = rawOrder.filter { seen.insert($0).inserted }
        let fallbackOrder = entriesByBookId.values
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .map(\.bookId)

        let combined = candidates + fallbackOrder
        var normalizedSeen = Set<Int>()
        let unique = combined.filter { bookId in
            guard entriesByBookId[bookId] != nil else { return false }
            return normalizedSeen.insert(bookId).inserted
        }

        let orderIndex = Dictionary(uniqueKeysWithValues: unique.enumerated().map { ($0.element, $0.offset) })
        let normalized = unique.sorted { lhs, rhs in
            let leftOpenedAt = entriesByBookId[lhs]?.lastOpenedAt ?? .distantPast
            let rightOpenedAt = entriesByBookId[rhs]?.lastOpenedAt ?? .distantPast
            if leftOpenedAt != rightOpenedAt { return leftOpenedAt > rightOpenedAt }
            return (orderIndex[lhs] ?? .max) < (orderIndex[rhs] ?? .max)
        }

        return Array(normalized.prefix(maxHistoryCount))
    }

    private func startObservingCloudChanges() {
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                self.handleCloudStoreChange(notification)
            }
        }
    }

    private func handleCloudStoreChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              reason != NSUbiquitousKeyValueStoreQuotaViolationChange
        else { return }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        let hasOurKey = changedKeys?.contains(storageKey) ?? false
        let hasLegacyKey = changedKeys?.contains(legacyHistoryKey) ?? false || changedKeys?.contains(legacyFavoritesKey) ?? false

        if hasOurKey || hasLegacyKey || reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            guard let remotePayload = loadPayloadFromCloud() else { return }

            let local = currentPayload()
            let merged = merge(local: local, remote: remotePayload)

            isApplyingRemoteUpdate = true
            applyPayload(merged, persistToDisk: false)

            // Persist merged result locally
            if let data = try? JSONEncoder().encode(merged) {
                UserDefaults.standard.set(data, forKey: storageKey)

                // If merged result is different from what we just got from cloud,
                // it means we had local changes that should be pushed back.
                let remoteData = try? JSONEncoder().encode(remotePayload)
                if data != remoteData {
                    cloudStore.set(data, forKey: storageKey)
                    cloudStore.synchronize()
                    lastKVSUpdateDate = Date()
                }
            }
            isApplyingRemoteUpdate = false
        }
    }
}

private struct StoredReadingEntries: Codable {
    let historyOrder: [Int]
    let entries: [iOSReadingEntry]
}
