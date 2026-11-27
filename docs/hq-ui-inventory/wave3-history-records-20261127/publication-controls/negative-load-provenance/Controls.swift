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


import Foundation

/// Non-destructive sidecar persistence for source-qualified positions. Existing numeric
/// Maktabah records remain authoritative until an associated locator is written.
actor QualifiedLocatorStore {
    static let shared = QualifiedLocatorStore()

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
    private let publicationSource = PublicationSource()

    private struct State: Codable {
        var schemaVersion = 1
        var locatorsByLegacyKey: [String: TextLocator] = [:]
        var favorites: [String: TextLocator] = [:]
        var history: [HistoryEntry] = []
    }

    struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
        let locator: TextLocator
        var title: String
        var lastOpened: Date
        var isFavorite: Bool
        var id: String { locator.persistenceKey }
    }

    private let fileURL: URL
    private var state: State

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = fileURL ?? base.appendingPathComponent("Maktabah/qualified-locators-v1.json")
        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    func associate(_ locator: TextLocator, withLegacyKey key: String) async throws {
        publicationSource.willChange()
        state.locatorsByLegacyKey[key] = locator
        try persist()
    }

    func locator(forLegacyKey key: String) -> TextLocator? { state.locatorsByLegacyKey[key] }

    func record(_ locator: TextLocator, title: String) async throws {
        publicationSource.willChange()
        let favorite = state.favorites[locator.persistenceKey] != nil
        state.history.removeAll { $0.id == locator.persistenceKey }
        state.history.insert(.init(locator: locator, title: title, lastOpened: Date(), isFavorite: favorite), at: 0)
        state.history = Array(state.history.prefix(500))
        try persist()
    }

    func setFavorite(_ favorite: Bool, locator: TextLocator, title: String) async throws {
        publicationSource.willChange()
        if favorite { state.favorites[locator.persistenceKey] = locator }
        else { state.favorites.removeValue(forKey: locator.persistenceKey) }
        if let index = state.history.firstIndex(where: { $0.id == locator.persistenceKey }) {
            state.history[index].isFavorite = favorite
        } else if favorite {
            state.history.insert(.init(locator: locator, title: title, lastOpened: Date(), isFavorite: true), at: 0)
        }
        try persist()
    }

    func entries() -> [HistoryEntry] { state.history }

    /// No suspension separates the original entries and their source token.
    func entriesWithObservation() -> PublishedEntries {
        PublishedEntries(entries: state.history, observation: publicationSource.capture())
    }

    func removeHistory(_ locator: TextLocator) async throws {
        if let index = state.history.firstIndex(where: { $0.id == locator.persistenceKey }) {
            publicationSource.willChange()
            if state.history[index].isFavorite {
                state.history[index].lastOpened = .distantPast
            } else {
                state.history.remove(at: index)
            }
            try persist()
        }
    }

    private func persist() throws {
        let manager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        let temporary = directory.appendingPathComponent(".qualified-locators-\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        if manager.fileExists(atPath: fileURL.path) {
            _ = try manager.replaceItemAt(fileURL, withItemAt: temporary)
        } else {
            try manager.moveItem(at: temporary, to: fileURL)
        }
    }
}


// Explicit domain boundary: original backend publisher and BooksData are
// represented only by fields read by the verbatim publication implementation.
// No UIKit, Observation, app/Core or saved-reader acceptance is asserted.
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation: UInt64 = 1
    var activeTransitionToken: UInt64 = 1
    var usesNativeMaktabahDataPath = false
    var isTransitioning = false
    func reset() { activeBackendID = .otzaria; generation = 1; activeTransitionToken = 1
        usesNativeMaktabahDataPath = false; isTransitioning = false }
}
final class BooksData {
    let id: Int
    var backendLocator: TextLocator?
    init(id: Int, locator: TextLocator?) { self.id=id; backendLocator=locator }
}
@MainActor final class HistoryViewModel {
    var historyBooks: [BooksData] = []
    var favoriteBooks: [BooksData] = []
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
        guard let revision = load.revision, revision == revision,
              load.isCurrent, let observation = entries.observation, observation.isCurrent,
              let publication = HistoryQualifiedPublication(
                model: self, load: load, entries: entries.entries, observation: observation) else { return }
        qualifiedPublication = publication
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
                && source.generation == source.generation && source.activeTransitionToken == source.activeTransitionToken
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


// Test-only same-file access exercises metadata exhaustion, never app state.
extension QualifiedLocatorStore.PublicationSource {
    func testRevision(_ value: UInt64?) { lock.lock(); defer { lock.unlock() }; revision=value }
}
extension HistoryViewModel { func testLoadRevision(_ value: UInt64?) { qualifiedLoadRevision=value } }

struct ControlFailure: Error { let message: String }
@main @MainActor struct Controls {
    static var passed=0, failed=0
    static let base=URL(fileURLWithPath: CommandLine.arguments[1], isDirectory:true)
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ControlFailure(message:message) }
    }
    static func test(_ name:String, _ body: () async throws -> Void) async {
        BackendCoordinator.shared.reset()
        do { try await body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    static func locator(_ line:Int=3, backend:BackendID = .otzaria) -> TextLocator {
        .init(backend:backend,workKey:"book:3891",position:.legacyLine(line))
    }
    static func newStore() -> QualifiedLocatorStore {
        .init(fileURL:base.appendingPathComponent("record-\(UUID()).json"))
    }
    static func fixture(favorite:Bool=false) async throws -> (QualifiedLocatorStore,HistoryViewModel,HistoryQualifiedPublication.Load,QualifiedLocatorStore.PublishedEntries) {
        let store=newStore(), model=HistoryViewModel()
        let load=model.beginQualifiedPublication()
        if favorite { try await store.setFavorite(true,locator:locator(),title:"Original") }
        else { try await store.record(locator(),title:"Original") }
        let entries=await store.entriesWithObservation()
        model.historyBooks=[BooksData(id:3891,locator:locator())]
        if favorite { model.favoriteBooks=[BooksData(id:3891,locator:locator())] }
        model.completeQualifiedPublication(load,entries:entries)
        try check(model.qualifiedPublication?.isCurrent(in:model)==true,"fixture publication unavailable")
        return (store,model,load,entries)
    }
    static func mutation(_ body:() async throws -> Void) async {
        // Tokens must retire BEFORE mutation, including original persistence
        // failure. We report any actual Foundation I/O error separately.
        do { try await body() } catch { print("OBSERVED original persistence error: \(error)") }
    }
    static func main() async {
        do { try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true) }
        catch { print("HARNESS_SETUP_FAILURE \(error)"); exit(2) }
        await test("same actor entries and exact published objects") {
            let (store,model,_,entries)=try await fixture(favorite:true)
            let ordinary=await store.entries()
            try check(ordinary==entries.entries,"observed entries differ from original read")
            try check(model.qualifiedPublication?.history.first?.book === model.historyBooks.first,"history copied the original card")
            try check(model.qualifiedPublication?.favorites.first?.book === model.favoriteBooks.first,"favorite copied the original card")
        }
        await test("full position identity distinct from numeric work identity") {
            let (_,model,_,_)=try await fixture()
            try check(model.qualifiedPublication?.history.first?.recordID==locator().persistenceKey,"record lacks full locator")
            try check(locator().persistenceKey != locator(4).persistenceKey,"position identity collapsed")
        }
        await test("record invalidates retained publication before persistence") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.record(locator(4),title:"Later") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"record retained stale authority")
        }
        await test("favorite mutation invalidates retained publication") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.setFavorite(true,locator:locator(),title:"Original") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"favorite retained stale authority")
        }
        await test("equal favorite publication invalidates") {
            let (store,model,_,_)=try await fixture(favorite:true)
            await mutation { try await store.setFavorite(true,locator:locator(),title:"Original") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"equal write was ignored")
        }
        await test("favorite ABA cannot renew old proof") {
            let (store,model,_,_)=try await fixture(favorite:true)
            await mutation { try await store.setFavorite(false,locator:locator(),title:"Original") }
            await mutation { try await store.setFavorite(true,locator:locator(),title:"Original") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"ABA renewed old proof")
        }
        await test("history deletion invalidates") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.removeHistory(locator()) }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"deletion retained old proof")
        }
        await test("favorite history suppression invalidates") {
            let (store,model,_,_)=try await fixture(favorite:true)
            await mutation { try await store.removeHistory(locator()) }
            let entries=await store.entries()
            try check(entries.first?.lastOpened == .distantPast,"original favorite suppression changed")
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"suppression retained old proof")
        }
        await test("no-op absent deletion preserves publication") {
            let (store,model,_,_)=try await fixture()
            try await store.removeHistory(locator(99))
            try check(model.qualifiedPublication?.isCurrent(in:model)==true,"nonmutation retired source")
        }
        await test("legacy association mutation retires source") {
            let (store,model,_,_)=try await fixture()
            await mutation { try await store.associate(locator(),withLegacyKey:"book.3891") }
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"association mutation was omitted")
        }
        await test("publication source overflow permanently refuses") {
            let source=QualifiedLocatorStore.PublicationSource()
            source.testRevision(.max)
            let old=source.capture()
            try check(old?.isCurrent==true,"max should still describe pre-mutation source")
            source.willChange()
            try check(old?.isCurrent==false && source.capture()==nil,"overflow renewed proof")
            source.willChange(); try check(source.capture()==nil,"nil overflow reset")
        }
        await test("new load retires original publication before arrays change") {
            let (_,model,_,_)=try await fixture()
            let old=model.qualifiedPublication!
            _=model.beginQualifiedPublication()
            try check(model.qualifiedPublication==nil && !old.isCurrent(in:model),"load failed to retire proof")
        }
        await test("stale load cannot publish after newer load") {
            let (_,model,old,entries)=try await fixture()
            let latest=model.beginQualifiedPublication()
            model.completeQualifiedPublication(latest,entries:entries)
            try check(model.qualifiedPublication != nil,"latest load unexpectedly refused")
            model.completeQualifiedPublication(old,entries:entries)
            try check(model.qualifiedPublication==nil,"late old load renewed source")
        }
        await test("backend changed during actor await refuses publication") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.activeBackendID = .sefaria
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"wrong backend published")
        }
        await test("backend A B A generation invalidates") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.activeBackendID = .sefaria
            BackendCoordinator.shared.generation += 1
            BackendCoordinator.shared.activeBackendID = .otzaria
            BackendCoordinator.shared.generation += 1
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"backend ABA renewed source")
        }
        await test("same backend resources replace generation") {
            let (_,model,_,_)=try await fixture()
            BackendCoordinator.shared.generation += 1
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"resource replacement retained source")
        }
        await test("failed transition publication invalidates without backend change") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.activeTransitionToken += 1
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"failed transition history ignored")
        }
        await test("active transition cannot publish") {
            let (_,model,load,entries)=try await fixture()
            BackendCoordinator.shared.isTransitioning = true
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"transitional source accepted")
        }
        await test("native legacy arrays cannot infer qualified identity") {
            let (_,model,load,entries)=try await fixture()
            model.historyBooks=[BooksData(id:3891,locator:nil)]
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"legacy numeric row acquired authority")
        }
        await test("duplicate original numeric row identities refuse") {
            let (_,model,load,entries)=try await fixture()
            model.historyBooks.append(BooksData(id:3891,locator:locator()))
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"duplicate original row was accepted")
        }
        await test("duplicate full qualified entry identity refuses") {
            let (_,model,load,entries)=try await fixture()
            model.completeQualifiedPublication(load,entries:.init(entries:entries.entries+entries.entries,observation:entries.observation))
            try check(model.qualifiedPublication==nil,"duplicate full entry was accepted")
        }
        await test("favorite section cannot invent membership") {
            let (_,model,load,entries)=try await fixture()
            model.favoriteBooks=[BooksData(id:3891,locator:locator())]
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"history-only entry became favorite")
        }
        await test("same numeric id replacement is a different original object") {
            let (_,model,_,_)=try await fixture()
            model.historyBooks=[BooksData(id:3891,locator:locator())]
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"replacement object accepted")
        }
        await test("actual card locator mutation refuses") {
            let (_,model,_,_)=try await fixture()
            model.historyBooks[0].backendLocator=locator(4)
            try check(model.qualifiedPublication?.isCurrent(in:model)==false,"mutable locator ignored")
        }
        await test("wrong backend locator cannot acquire qualified provenance") {
            let (_,model,load,entries)=try await fixture()
            model.historyBooks=[BooksData(id:3891,locator:locator(3,backend:.sefaria))]
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"numeric cross-backend card accepted")
        }
        await test("original model owner cannot be substituted") {
            let (_,model,_,_)=try await fixture()
            let other=HistoryViewModel(); other.historyBooks=model.historyBooks
            try check(model.qualifiedPublication?.isCurrent(in:other)==false,"foreign model accepted")
        }
        await test("load revision overflow refuses without resetting") {
            let (_,model,_,entries)=try await fixture()
            model.testLoadRevision(.max)
            let load=model.beginQualifiedPublication()
            model.completeQualifiedPublication(load,entries:entries)
            try check(load.revision==nil && model.qualifiedPublication==nil,"load overflow renewed authority")
            try check(model.beginQualifiedPublication().revision==nil,"load revision reset")
        }
        await test("native data path remains explicitly unqualified") {
            let (_,model,_,entries)=try await fixture()
            BackendCoordinator.shared.usesNativeMaktabahDataPath = true
            let load=model.beginQualifiedPublication()
            model.completeQualifiedPublication(load,entries:entries)
            try check(model.qualifiedPublication==nil,"native arrays relabeled as qualified")
        }
        await test("synchronous report can revalidate the same source token") {
            let (_,model,_,_)=try await fixture()
            let publication=model.qualifiedPublication!
            let result=publication.withCurrent(in:model) {
                publication.isCurrent(in:model) ? "same original source" : "stale"
            }
            try check(result=="same original source","nested validation deadlocked or failed")
        }
        await test("retired source never executes report callback") {
            let (store,model,_,_)=try await fixture()
            let publication=model.qualifiedPublication!
            await mutation { try await store.record(locator(4),title:"Later") }
            var calls=0
            let result=publication.withCurrent(in:model) { calls += 1; return true }
            try check(result==nil && calls==0,"retired source executed report")
        }
        await test("reentrant source invalidation cannot return confirmed report") {
            let source=QualifiedLocatorStore.PublicationSource()
            let observed=source.capture()!
            let result=observed.withCurrent { source.willChange(); return true }
            try check(result==nil && !observed.isCurrent,"reentrant source change returned report")
        }
        print("RESULT \(passed) PASS / \(failed) FAIL")
        exit(failed==0 ? 0 : 1)
    }
}
