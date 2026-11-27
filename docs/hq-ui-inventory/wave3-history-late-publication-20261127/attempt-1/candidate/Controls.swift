import Foundation

enum BackendID: String, Codable, CaseIterable, Identifiable, Sendable {
    case otzaria
    case sefaria
    case sefariaEmbedded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .otzaria: return "אוצריא"
        case .sefaria: return "ספריא (ישן)"
        case .sefariaEmbedded: return "ספריא"
        }
    }

    var englishDisplayName: String {
        switch self {
        case .otzaria: return "Otzaria"
        case .sefaria: return "Sefaria (Legacy)"
        case .sefariaEmbedded: return "Sefaria"
        }
    }
}

struct BackendCapabilities: OptionSet, Codable, Sendable {
    let rawValue: Int

    static let catalog = Self(rawValue: 1 << 0)
    static let reading = Self(rawValue: 1 << 1)
    static let navigation = Self(rawValue: 1 << 2)
    static let search = Self(rawValue: 1 << 3)
    static let authors = Self(rawValue: 1 << 4)
    static let links = Self(rawValue: 1 << 5)
    static let versions = Self(rawValue: 1 << 6)
    static let offlineLibrary = Self(rawValue: 1 << 7)
    static let offlineSearch = Self(rawValue: 1 << 8)
    static let workMetadata = Self(rawValue: 1 << 9)
}

enum TextPosition: Codable, Hashable, Sendable, CustomStringConvertible {
    case legacyLine(Int)
    case canonicalRef(String)

    private enum CodingKeys: String, CodingKey { case kind, integer, string }
    private enum Kind: String, Codable { case legacyLine, canonicalRef }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .legacyLine: self = .legacyLine(try values.decode(Int.self, forKey: .integer))
        case .canonicalRef: self = .canonicalRef(try values.decode(String.self, forKey: .string))
        }
    }

    var description: String {
        switch self {
        case .legacyLine(let value): return "line:\(value)"
        case .canonicalRef(let value): return value
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .legacyLine(let value):
            try values.encode(Kind.legacyLine, forKey: .kind)
            try values.encode(value, forKey: .integer)
        case .canonicalRef(let value):
            try values.encode(Kind.canonicalRef, forKey: .kind)
            try values.encode(value, forKey: .string)
        }
    }
}

struct TextLocator: Codable, Hashable, Sendable {
    let backend: BackendID
    let workKey: String
    let position: TextPosition

    var persistenceKey: String {
        let positionKey: String
        switch position {
        case .legacyLine(let value): positionKey = "line:\(value)"
        case .canonicalRef(let value): positionKey = "ref:\(value)"
        }
        return "\(backend.rawValue)|\(workKey)|\(positionKey)"
    }
}



// EXPLICIT DOMAIN BOUNDARIES: a controllable actor read models permitted await
// completion order; BooksData/catalog/backend expose only original read fields.
// The actual original loadBooksData body is below, with one fixture-only defer.
actor QualifiedLocatorStore {
    static let shared=QualifiedLocatorStore()
    /// Read-only provenance for the exact actor-owned history publication.
    /// The lock guards only this monotonically advancing metadata. Existing
    /// state mutation, persistence and actor ordering remain the original path.
    final class PublicationSource: @unchecked Sendable {
        private let lock = NSRecursiveLock()
        private var revision: UInt64? = 0

        struct Observation: Sendable {
            fileprivate let source: PublicationSource
            fileprivate let revision: UInt64
            var isCurrent: Bool { source.matches(revision) }
            /// The final synchronous native report may revalidate this same
            /// token. No actor call or suspension belongs inside this boundary.
            func withCurrent<Result>(_ operation: () throws -> Result) rethrows -> Result? {
                try source.withCurrent(revision, operation)
            }
        }

        fileprivate func capture() -> Observation? {
            lock.lock(); defer { lock.unlock() }
            guard let revision else { return nil }
            return Observation(source: self, revision: revision)
        }
        fileprivate func willChange() {
            lock.lock(); defer { lock.unlock() }
            guard let revision, revision < .max else { self.revision = nil; return }
            self.revision = revision + 1
        }
        private func matches(_ expected: UInt64) -> Bool {
            lock.lock(); defer { lock.unlock() }
            return revision == expected
        }
        private func withCurrent<Result>(_ expected: UInt64,
                                         _ operation: () throws -> Result) rethrows -> Result? {
            lock.lock(); defer { lock.unlock() }
            guard revision == expected else { return nil }
            let value = try operation()
            guard revision == expected else { return nil }
            return value
        }
    }

    struct PublishedEntries: Sendable {
        let entries: [HistoryEntry]
        let observation: PublicationSource.Observation?
    }
    struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
        let locator: TextLocator
        var title: String
        var lastOpened: Date
        var isFavorite: Bool
        var id: String { locator.persistenceKey }
    }


    private var source=PublicationSource()
    private var payloads:[[HistoryEntry]]=[]
    private var continuations:[Int:CheckedContinuation<PublishedEntries,Never>]=[:]
    private var observations:[Int:PublishedEntries]=[:]
    private var total=0
    private var arrivals:[(Int,CheckedContinuation<Void,Never>)]=[]
    func reset(_ payloads:[[HistoryEntry]]) {
        precondition(continuations.isEmpty)
        self.payloads=payloads; source=PublicationSource(); total=0; observations=[:]; arrivals=[]
    }
    func entriesWithObservation() async -> PublishedEntries {
        let index=total;total += 1
        let captured=PublishedEntries(entries:payloads[index],observation:source.capture())
        return await withCheckedContinuation { continuation in
            continuations[index]=continuation;observations[index]=captured
            let ready=arrivals.filter { $0.0 <= total };arrivals.removeAll { $0.0 <= total }
            for (_,waiter) in ready { waiter.resume() }
        }
    }
    func waitForReads(_ count:Int) async {
        if total >= count { return }
        await withCheckedContinuation { arrivals.append((count,$0)) }
    }
    func deliver(_ index:Int) {
        let continuation=continuations.removeValue(forKey:index)!
        continuation.resume(returning:observations.removeValue(forKey:index)!)
    }
    func changeOriginalStorePublication() { source.willChange() }
}
@MainActor final class BackendCoordinator {
    static let shared=BackendCoordinator()
    var activeBackendID:BackendID = .otzaria
    var generation:UInt64=1
    var activeTransitionToken:UInt64=1
    var usesNativeMaktabahDataPath=false
    var isTransitioning=false
    func reset() { activeBackendID = .otzaria;generation=1;activeTransitionToken=1
        usesNativeMaktabahDataPath=false;isTransitioning=false }
}
final class BooksData {
    let id:Int;let book:String;var backendLocator:TextLocator?
    init(id:Int,locator:TextLocator?) { self.id=id;self.backendLocator=locator;book=locator?.persistenceKey ?? "legacy:\(id)" }
}
@MainActor final class LibraryDataManager {
    static let shared=LibraryDataManager()
    func getBook(_ ids:[Int]) -> [BooksData] { ids.map { BooksData(id:$0,locator:nil) } }
}
@MainActor enum MaktabahBackendAdapter {
    static func resolveBook(for locator:TextLocator,in manager:LibraryDataManager) -> BooksData? {
        BooksData(id:Int(locator.workKey.dropFirst("book:".count))!,locator:locator)
    }
}
@MainActor final class HistoryViewModel {
    var historyOrder=[90]
    var favoriteBookIds=[91]
    var historyBooks:[BooksData]=[]
    var favoriteBooks:[BooksData]=[]
    private var finished=0
    private var waiters:[(Int,CheckedContinuation<Void,Never>)]=[]
    func fixtureLoadFinished() {
        finished += 1
        let ready=waiters.filter { $0.0 <= finished };waiters.removeAll { $0.0 <= finished }
        for (_,waiter) in ready { waiter.resume() }
    }
    func waitForFinished(_ count:Int) async {
        if finished >= count { return }
        await withCheckedContinuation { waiters.append((count,$0)) }
    }
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

    func loadBooksData() {
        let publicationLoad = beginQualifiedPublication()
        let hIds = historyOrder
        let fIds = favoriteBookIds
        let allNeededIds = Set(hIds).union(Set(fIds))

        let books = LibraryDataManager.shared.getBook(Array(allNeededIds))
        let booksDict = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })

        historyBooks = hIds.compactMap { booksDict[$0] }
        favoriteBooks = fIds.compactMap { booksDict[$0] }

        Task { [weak self] in
            defer { self?.fixtureLoadFinished() }
            let publicationEntries = await QualifiedLocatorStore.shared.entriesWithObservation()
            let qualified = publicationEntries.entries
            await MainActor.run {
                guard let self else { return }
                guard self.isCurrentQualifiedLoad(publicationLoad),
                      publicationEntries.observation?.isCurrent == true else { return }
                let active = BackendCoordinator.shared.activeBackendID
                if BackendCoordinator.shared.usesNativeMaktabahDataPath { return }
                let relevant = qualified.filter { $0.locator.backend == active }
                self.invalidateQualifiedPublication()
                self.historyBooks = relevant.filter { $0.lastOpened != .distantPast }.compactMap { entry in
                    MaktabahBackendAdapter.resolveBook(for: entry.locator, in: LibraryDataManager.shared)
                }
                self.favoriteBooks = relevant.filter(\.isFavorite).compactMap { entry in
                    MaktabahBackendAdapter.resolveBook(for: entry.locator, in: LibraryDataManager.shared)
                }
                self.completeQualifiedPublication(publicationLoad, entries: publicationEntries)
            }
        }
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


struct Failed:Error { let reason:String }
@main @MainActor struct Controls {
    static var passed=0,failed=0
    static func check(_ ok:@autoclosure () -> Bool,_ reason:String) throws {
        if !ok() { throw Failed(reason:reason) }
    }
    static func entry(_ work:Int,backend:BackendID = .otzaria,favorite:Bool=false) -> QualifiedLocatorStore.HistoryEntry {
        .init(locator:.init(backend:backend,workKey:"book:\(work)",position:.legacyLine(3)),title:"Original \(work)",lastOpened:Date(timeIntervalSince1970:1),isFavorite:favorite)
    }
    static func checkUnchanged(_ model:HistoryViewModel,_ before:[BooksData]) throws {
        try check(model.historyBooks.count==before.count && zip(model.historyBooks,before).allSatisfy { $0 === $1 },
            "obsolete result replaced original visible-model cards: \(model.historyBooks.map(\.book))")
    }
    static func test(_ name:String,_ body:() async throws -> Void) async {
        BackendCoordinator.shared.reset()
        do { try await body();passed += 1;print("PASS \(name)") }
        catch { failed += 1;print("FAIL \(name): \(error)") }
    }
    static func main() async {
        await test("current qualified load keeps original order and favorite subset") {
            await QualifiedLocatorStore.shared.reset([[entry(1),entry(2,favorite:true)]])
            let model=HistoryViewModel();model.loadBooksData()
            await QualifiedLocatorStore.shared.waitForReads(1)
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try check(model.historyBooks.map(\.id)==[1,2] && model.favoriteBooks.map(\.id)==[2],"current load changed original output")
        }
        await test("older async load cannot replace newer visible cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)],[entry(2,favorite:true)]])
            let model=HistoryViewModel();model.loadBooksData()
            await QualifiedLocatorStore.shared.waitForReads(1)
            model.loadBooksData();await QualifiedLocatorStore.shared.waitForReads(2)
            await QualifiedLocatorStore.shared.deliver(1);await model.waitForFinished(1)
            let before=model.historyBooks
            try check(before.map(\.id)==[2],"newer task did not publish original cards")
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(2)
            try checkUnchanged(model,before)
        }
        await test("different backend cannot consume an older actor result") {
            await QualifiedLocatorStore.shared.reset([[entry(1),entry(7,backend:.sefaria)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.activeBackendID = .sefaria;BackendCoordinator.shared.generation += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("backend A B A cannot apply old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.activeBackendID = .sefaria;BackendCoordinator.shared.generation += 1
            BackendCoordinator.shared.activeBackendID = .otzaria;BackendCoordinator.shared.generation += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("same backend resource replacement rejects old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.generation += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("aborted source transition rejects old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            BackendCoordinator.shared.activeTransitionToken += 1
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("sidecar change during pending read rejects old cards") {
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            await QualifiedLocatorStore.shared.changeOriginalStorePublication()
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        await test("original native data-path legacy arrays remain unchanged") {
            BackendCoordinator.shared.usesNativeMaktabahDataPath=true
            await QualifiedLocatorStore.shared.reset([[entry(1)]])
            let model=HistoryViewModel();model.loadBooksData();let before=model.historyBooks
            await QualifiedLocatorStore.shared.waitForReads(1)
            await QualifiedLocatorStore.shared.deliver(0);await model.waitForFinished(1)
            try checkUnchanged(model,before)
        }
        print("RESULT \(passed) PASS / \(failed) FAIL")
        exit(failed==0 ? 0 : 1)
    }
}
