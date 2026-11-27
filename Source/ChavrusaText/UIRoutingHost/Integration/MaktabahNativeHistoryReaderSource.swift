#if os(iOS)
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Bounded metadata over the original History model. Reading this catalog
/// neither reloads the model nor writes its original database or sidecar.
@MainActor final class MaktabahNativeHistoryReaderCatalog {
    typealias Record = NativeHistoryReaderIntentService.Record
    private let snapshot: @MainActor () throws -> ActionBackendSnapshot
    private var current: MaktabahNativeHistoryReaderPublication?
    private var accessing = false

    init(snapshot: @escaping @MainActor () throws -> ActionBackendSnapshot) {
        self.snapshot = snapshot
    }
    func records(_ expected: ActionBackendSnapshot) throws -> [Record] {
        guard !accessing else { throw UIRouteError(.unavailable, "history_reader_catalog_busy") }
        accessing = true
        defer { accessing = false }
        try Task.checkCancellation()
        guard try snapshot() == expected else { throw ActionPortError.staleState }
        if let current {
            var valid = true
            do { try current.validate() }
            catch is CancellationError { throw CancellationError() }
            catch { valid = false }
            guard self.current === current else {
                throw UIRouteError(.staleState, "history_reader_publication_retired")
            }
            if !valid { self.current = nil }
        }
        if current == nil {
            let captured = try MaktabahNativeHistoryReaderPublication(
                model: .shared, snapshot: expected, readSnapshot: snapshot)
            guard current == nil else {
                throw UIRouteError(.staleState, "history_reader_publication_replaced")
            }
            current = captured
        }
        guard let current else { return [] }
        try current.validate()
        guard self.current === current else {
            throw UIRouteError(.staleState, "history_reader_publication_retired")
        }
        return current.availableRecords
    }
    func retain(_ request: NativeHistoryReaderIntentService.OpenRequest) throws
        -> MaktabahNativeHistoryReaderSource {
        // Execution must consume the exact existing metadata publication.
        // A new discovery here could revive a retired cached reference.
        guard !accessing, let current, current.snapshot == request.invocation.snapshot else {
            throw UIRouteError(.staleState, "history_reader_publication_retired")
        }
        accessing = true
        defer { accessing = false }
        let frame = try current.claim(request.record)
        guard self.current === current else {
            throw UIRouteError(.staleState, "history_reader_publication_retired")
        }
        return .init(publication: current, frame: frame, request: request)
    }
    func finish(_ source: MaktabahNativeHistoryReaderSource) {
        if current === source.publication { current = nil }
        source.release()
    }
}

@MainActor fileprivate final class MaktabahNativeHistoryReaderPublication {
    typealias Record = NativeHistoryReaderIntentService.Record
    struct Frame {
        let record: Record
        let book: BooksData
        let originalBookLocator: TextLocator?
        let legacy: ReadingEntry?
        let registeredLegacyLocator: TextLocator?
    }
    let snapshot: ActionBackendSnapshot
    private let readSnapshot: @MainActor () throws -> ActionBackendSnapshot
    private let model: HistoryViewModel
    private let qualified: HistoryQualifiedPublication?
    private let nativeDataPath: Bool
    private let sourceBooks: [BooksData]
    private let filter: [UInt8]
    private let observation: MaktabahNativeComponentSourceObservation
    private let frames: [Frame]
    private var claimed = Set<String>()

    init?(model: HistoryViewModel, snapshot: ActionBackendSnapshot,
          readSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot) throws {
        let backend = BackendCoordinator.shared
        guard !backend.isTransitioning,
              ActionAppIdentityBridge.actionBackend(backend.activeBackendID) == snapshot.backend,
              try readSnapshot() == snapshot else { throw ActionPortError.staleState }
        let native = backend.usesNativeMaktabahDataPath
        let qualified = native ? nil : model.qualifiedPublication
        if native {
            guard snapshot.backend == .otzaria, OtzariaBackendActivation.isActive else { return nil }
        } else {
            guard let qualified, qualified.isCurrent(in: model) else { return nil }
        }
        // This one-way willSet witness is never reset after an await. Original
        // qualified-store mutations also retire its separate original token.
        let observation = MaktabahNativeComponentSourceObservation {
            _ = model.historyBooks; _ = model.favoriteBooks
            _ = model.entriesByBookId; _ = model.historyOrder; _ = model.searchText
            _ = model.qualifiedPublication
            _ = backend.generation; _ = backend.activeTransitionToken
            _ = backend.activeBackendID; _ = backend.isTransitioning
            _ = backend.usesNativeMaktabahDataPath
        }
        let books = model.filteredHistory
        guard books.count <= 500, Set(books.map(\.id)).count == books.count,
              Set(books.map(ObjectIdentifier.init)).count == books.count else {
            throw UIRouteError(.failed, "ambiguous_history_reader_publication")
        }
        var frames: [Frame] = []
        for book in books {
            let locator: TextLocator
            let legacy: ReadingEntry?
            let registered: TextLocator?
            if native {
                guard let entry = model.entriesByBookId[book.id],
                      entry.bookId == book.id, entry.lastOpenedAt != nil,
                      let contentID = entry.lastContentId else { continue }
                guard model.historyOrder.contains(book.id), book.id > 0,
                      book.backendLocator == nil || book.backendLocator?.backend == .otzaria else {
                    throw UIRouteError(.staleState, "history_reader_original_work_changed")
                }
                // The existing Otzaria bridge owns this exact numeric work
                // mapping. No title match, cross-backend alias or line guess.
                let workKey = "book:\(book.id)"
                let actual = try OtzariaMaktabahBridge.shared.resolveBook(
                    stableKey: workKey, expectedBookId: book.id)
                guard actual.id == book.id, actual.book.utf8.elementsEqual(book.book.utf8),
                      book.backendLocator == nil || book.backendLocator?.workKey == workKey else {
                    throw UIRouteError(.staleState, "history_reader_original_work_changed")
                }
                let work = TextLocator(backend: .otzaria, workKey: workKey, position: .legacyLine(0))
                registered = LegacyIdentityRegistry.shared.locator(for: contentID)
                guard let original = ReaderDestinationResolver.resolve(contentID: contentID,
                    in: work, registeredLocator: registered) else {
                    throw UIRouteError(.staleState, "history_reader_saved_position_unavailable")
                }
                locator = original.focusLocator ?? original.sectionLocator
                legacy = entry
            } else {
                guard let qualified else { throw ActionPortError.staleState }
                let matches = qualified.history.filter { $0.book === book }
                guard matches.count == 1, let card = matches.first,
                      card.book.backendLocator == card.locator,
                      ActionAppIdentityBridge.actionBackend(card.locator.backend) == snapshot.backend else {
                    throw UIRouteError(.staleState, "history_reader_original_card_changed")
                }
                locator = card.locator; legacy = nil; registered = nil
            }
            let record = Record(reference: .init(backend: snapshot.backend, metadataID: UUID()),
                title: book.book, locator: try ActionAppIdentityBridge.actionRef(locator))
            frames.append(.init(record: record, book: book, originalBookLocator: book.backendLocator,
                legacy: legacy, registeredLegacyLocator: registered))
        }
        self.model = model; self.snapshot = snapshot; self.readSnapshot = readSnapshot
        self.qualified = qualified; nativeDataPath = native; sourceBooks = books
        filter = Array(model.searchText.utf8); self.observation = observation; self.frames = frames
        try validate()
    }
    var availableRecords: [Record] { frames.map(\.record).filter { !claimed.contains($0.id) } }
    func claim(_ record: Record) throws -> Frame {
        try validate()
        let matches = frames.filter { $0.record == record }
        guard matches.count == 1, let frame = matches.first, claimed.insert(record.id).inserted else {
            throw UIRouteError(.staleState, "history_reader_reference_consumed")
        }
        return frame
    }
    func validate() throws {
        try Task.checkCancellation(); try observation.validate()
        let backend = BackendCoordinator.shared, books = model.filteredHistory
        guard !backend.isTransitioning, try readSnapshot() == snapshot,
              ActionAppIdentityBridge.actionBackend(backend.activeBackendID) == snapshot.backend,
              backend.usesNativeMaktabahDataPath == nativeDataPath,
              model.searchText.utf8.elementsEqual(filter), books.count == sourceBooks.count,
              zip(books, sourceBooks).allSatisfy({ $0 === $1 }) else {
            throw UIRouteError(.staleState, "history_reader_source_changed")
        }
        if nativeDataPath {
            guard snapshot.backend == .otzaria, OtzariaBackendActivation.isActive else {
                throw ActionPortError.staleState
            }
        } else {
            guard let qualified, model.qualifiedPublication === qualified,
                  qualified.isCurrent(in: model) else { throw ActionPortError.staleState }
        }
        for frame in frames {
            guard frame.book.backendLocator == frame.originalBookLocator else {
                throw UIRouteError(.staleState, "history_reader_original_work_changed")
            }
            if let entry = frame.legacy {
                guard model.entriesByBookId[entry.bookId] == entry,
                      model.historyOrder.contains(entry.bookId), let id = entry.lastContentId,
                      LegacyIdentityRegistry.shared.locator(for: id) == frame.registeredLegacyLocator else {
                    throw UIRouteError(.staleState, "history_reader_saved_position_changed")
                }
            }
        }
        try observation.validate()
    }
    func performOriginalApply(_ operation: () throws -> Void) throws {
        try validate()
        if let qualified {
            // The original store's lock covers only this synchronous source
            // check and the already authorized original native operation.
            let applied = try qualified.withCurrent(in: model) {
                try validate(); try operation(); return true
            }
            guard applied == true else { throw ActionPortError.staleState }
        } else {
            try operation()
        }
    }
}

/// Additional input provenance for one existing Reader reservation. It never
/// grants navigation, replaces Core or performs an independent UI operation.
@MainActor final class MaktabahNativeHistoryReaderSource {
    fileprivate let publication: MaktabahNativeHistoryReaderPublication
    private let frame: MaktabahNativeHistoryReaderPublication.Frame
    let request: NativeHistoryReaderIntentService.OpenRequest
    private enum Phase { case retained, claimed, applying, applied, retired }
    private var phase = Phase.retained
    var locator: ActionTextRef { frame.record.locator }
    var didApply: Bool { if case .applied = phase { true } else { false } }

    fileprivate init(publication: MaktabahNativeHistoryReaderPublication,
                     frame: MaktabahNativeHistoryReaderPublication.Frame,
                     request: NativeHistoryReaderIntentService.OpenRequest) {
        self.publication = publication; self.frame = frame; self.request = request
    }
    func validate() throws {
        try validateLifetime()
        switch phase {
        case .retained, .claimed: try publication.validate()
        // Own Reader effects may update History. The original Reader binding,
        // Core command and actual native witness still validate their owners.
        case .applying, .applied: break
        case .retired: throw UIRouteError(.staleState, "history_reader_source_retired")
        }
    }
    private func validateLifetime() throws {
        try Task.checkCancellation()
        guard SystemActionClock().now() < request.invocation.deadlineUptimeNanoseconds else {
            throw UIRouteError(.unavailable, "deadline_exceeded")
        }
    }
    func performOriginalApply(_ operation: () throws -> Void) throws {
        guard case .retained = phase else {
            throw UIRouteError(.staleState, "history_reader_source_already_applied")
        }
        // Claim before any original callback can re-enter or retire this source.
        phase = .claimed
        do {
            try validateLifetime()
            try publication.performOriginalApply {
                guard case .claimed = phase else {
                    throw UIRouteError(.staleState, "history_reader_source_retired")
                }
                try validateLifetime()
                phase = .applying
                try operation()
                guard case .applying = phase else {
                    throw UIRouteError(.staleState, "history_reader_source_retired")
                }
                phase = .applied
            }
            guard case .applied = phase else {
                throw UIRouteError(.staleState, "history_reader_source_retired")
            }
        } catch {
            phase = .retired
            throw error
        }
    }
    func release() { phase = .retired }
}
#endif
