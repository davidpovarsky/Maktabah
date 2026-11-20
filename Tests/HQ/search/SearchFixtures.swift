import Combine
import Foundation

protocol CopyableResult { func formatForClipboard() -> String }
extension String { func convertToArabicDigits() -> String { self } }
extension NSAttributedString {
    func archivedData() -> Data { Data(string.utf8) }
    static func unarchiveSecure(from data: Data) -> NSAttributedString? {
        NSAttributedString(string: String(decoding: data, as: UTF8.self))
    }
}

enum FixtureError: Error { case expected }
enum FixtureEnvironment {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("hq-search-" + UUID().uuidString)
}
enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static var activeProfileID = "fixture"
}
enum OtzariaDataProfileCompatibility {
    static func matchesActiveProfile(profileID: String?, profileVersion: Int?) -> Bool {
        (profileID ?? OtzariaDataProfileRegistry.productionID) == OtzariaDataProfileRegistry.activeProfileID
            && (profileVersion ?? 1) == 1
    }
}
struct OtzariaDatabaseInstallationManifest: Codable {
    var profileID: String? = nil
    var profileVersion: Int? = nil
    let repository: String
    let releaseID: Int64
    let releaseTag: String
    let assetID: Int64
    let assetName: String
    let compressedSize: Int64
    let digest: String?
    var effectiveProfileID: String { profileID ?? OtzariaDataProfileRegistry.productionID }
    var effectiveProfileVersion: Int { profileVersion ?? 1 }
}
final class OtzariaDatabaseAccessController {
    enum Source { case managedInternal, external }
    static let shared = OtzariaDatabaseAccessController()
    var source: Source = .managedInternal
}
enum OtzariaIndexFileLogger {
    static func logError(_ message: String, error: Error) {}
    static func log(_ message: String) {}
    static func clearLog() {}
    static func logFileURL() -> URL? { nil }
    static func readLogText() -> String { "" }
}
final class OtzariaSearchEngineBridge {
    static var currentBuild: OtzariaSearchEngineBuildInfo!
    static var freshOpenFails = false
    static var compatible = true
    static var freshCount: UInt64 = 125
    static var opened = 0
    static func buildInfo() throws -> OtzariaSearchEngineBuildInfo { currentBuild }
    static func checkCompatibility(indexURL: URL) throws -> OtzariaIndexCompatibility {
        .init(compatible: compatible, status: "fixture", foundSchemaVersion: 4, requiredSchemaVersion: 4,
              engineVersion: "0.1.0", metadataPath: "fixture", reason: compatible ? nil : "fixture incompatible schema")
    }
    init(indexURL: URL) throws {
        Self.opened += 1
        if Self.freshOpenFails { throw FixtureError.expected }
    }
    func close() {}
    func documentCount() throws -> UInt64 { Self.freshCount }
}
final class FixtureIndexValidator {
    var identity: OtzariaIndexBuildIdentity?
    var fingerprint = OtzariaIndexFingerprint(databasePath: "fixture", fileSize: 3821240320, modificationTime: 1)
    func indexURL(for path: String) -> URL { FixtureEnvironment.root.appendingPathComponent("validation-index") }
    func semanticArtifactURL(for path: String) -> URL { FixtureEnvironment.root.appendingPathComponent("semantic.json") }
    func storedIdentity(indexURL: URL) -> OtzariaIndexBuildIdentity? { identity }
    func currentFingerprint(databasePath: String) throws -> OtzariaIndexFingerprint { fingerprint }
    func recoverTrustedManagedIndex(databasePath: String) throws -> UInt64? { nil }
    func trustedManagedReadManifest(indexURL: URL, databasePath: String, build: OtzariaSearchEngineBuildInfo) -> OtzariaSearchArtifactManifest? { nil }
    func decode<T: Decodable>(_ type: T.Type, at url: URL) -> T? { nil }
}
@MainActor final class iOSNavigationManager { var openedHit: Int64? }
@MainActor enum ZayitSearchReaderNavigationAdapter {
    static func open(_ hit: ZayitSearchHit, using manager: iOSNavigationManager) { manager.openedHit = hit.id }
}
@MainActor final class FixtureHitNavigation {
    enum Scope { case zayit, advanced }
    var scope: Scope = .zayit
    var zayitHits: [String: ZayitSearchHit] = [:]
    var errorMessage: String?
}
@MainActor final class OtzariaMagicDictionaryManager {
    static let shared = OtzariaMagicDictionaryManager()
    var validatedDatabaseURL: URL? = FixtureEnvironment.root.appendingPathComponent("lexical.db")
    func refreshIfNeeded() async throws -> Bool { false }
}
struct ZayitSearchArtifactStorage {
    init() throws {}
    var installedManifest: URL { FixtureEnvironment.root.appendingPathComponent("installed.json") }
    var finalIndex: URL { FixtureEnvironment.root.appendingPathComponent("index") }
}
enum ZayitSearchPackageState {
    case ready, notInstalled, incompatible(String), repairRequired(String), failed(String)
}
enum ZayitSearchDistributionError: LocalizedError {
    case incompatible(String), validationFailed(String)
    var errorDescription: String? {
        switch self { case .incompatible(let text), .validationFailed(let text): return text }
    }
}
actor ZayitSearchArtifactService {
    static let shared = ZayitSearchArtifactService()
    var state: ZayitSearchPackageState = .notInstalled
    var delay: UInt64 = 0
    func set(_ state: ZayitSearchPackageState, delay: UInt64 = 0) { self.state = state; self.delay = delay }
    func status(databaseURL: URL?) async -> ZayitSearchPackageState {
        let captured = state
        let wait = delay
        await Task.detached { try? await Task.sleep(nanoseconds: wait) }.value
        return captured
    }
}
@MainActor final class ZayitSearchDataController: ObservableObject {
    static let shared = ZayitSearchDataController()
    @Published var revision: UInt64 = 0
}
@MainActor final class ZayitSearchFolderAccess {
    static var folder: URL?
    func restoreAndActivate() throws -> URL? { Self.folder }
    func selectAndActivate(_ url: URL) throws -> URL { Self.folder = url; return url }
    func clear() { Self.folder = nil }
    func deactivate() {}
}
@MainActor enum ZayitSearchDataValidator {
    static func managedPaths(seforimDB: URL, lexicalDB: URL, indexDirectory: URL) throws -> ZayitSearchDataPaths {
        .init(seforimDb: seforimDB.path, lexicalDb: lexicalDB.path, indexDir: indexDirectory.path)
    }
    static func paths(in folder: URL, existingSeforimDB: URL?) throws -> ZayitSearchDataPaths {
        .init(seforimDb: existingSeforimDB?.path ?? folder.path, lexicalDb: folder.path, indexDir: folder.path)
    }
}

actor FixtureControl {
    static let shared = FixtureControl()
    var pages: [String: [Int: ZayitSearchPage]] = [:]
    var requests: [ZayitSearchRequest] = []
    var failOffsets: Set<Int> = []
    var delays: [String: UInt64] = [:]
    var configureFails = false
    var configureCount = 0
    func setup(_ pages: [String: [Int: ZayitSearchPage]], failures: Set<Int> = [], delays: [String: UInt64] = [:]) {
        self.pages = pages; self.failOffsets = failures; self.delays = delays; requests = []
    }
    func setConfigureFailure(_ fail: Bool) { configureFails = fail }
    func clearFailures() { failOffsets = [] }
    func configured() throws {
        configureCount += 1
        if configureFails { throw FixtureError.expected }
    }
    func search(_ request: ZayitSearchRequest) async throws -> ZayitSearchPage {
        requests.append(request)
        if failOffsets.contains(request.offset) { throw FixtureError.expected }
        let captured = pages[request.query]?[request.offset] ?? page([], total: 0, last: true)
        let wait = delays[request.query] ?? 0
        await Task.detached { try? await Task.sleep(nanoseconds: wait) }.value
        return captured
    }
}
actor ZayitSearchRepository {
    func configure(paths: ZayitSearchDataPaths) async throws { try await FixtureControl.shared.configured() }
    func reset() {}
    func search(query: String, near: UInt32, offset: Int, limit: Int, filters: ZayitSearchFilters) async throws -> ZayitSearchPage {
        try await FixtureControl.shared.search(.init(query: query, near: near, limit: limit, offset: offset, filters: filters))
    }
}

func hit(_ id: Int) -> ZayitSearchHit {
    .init(bookId: 7, stableBookKey: "book:7", bookTitle: "אותו ספר", lineId: Int64(id),
          lineIndex: 1, reference: "א", snippetHtml: "מילה \(id)", matchedTerms: ["מילה"], score: 1, isBaseBook: true)
}
func page(_ ids: [Int], total: UInt64 = 125, last: Bool = false) -> ZayitSearchPage {
    .init(hits: ids.map(hit), totalHits: total, isLastPage: last)
}
func engineHit(_ id: Int) -> OtzariaEngineSearchResult {
    .init(title: "ספר", reference: "עמוד \(id)", text: "טקסט \(id)", id: UInt64(id),
          segment: 1, isPdf: false, filePath: "otzaria-book:7", mergedCount: 0, merged: [])
}
func item(_ id: String? = nil) -> SearchResultItem {
    .init(archive: "Zayit", tableName: "zayit:book:7", bookId: 7, bookTitle: "אותו ספר", page: 1, part: 1,
          backendLocator: .init(backend: .otzaria, workKey: "book:7", position: .legacyLine(1)), backendHitID: id)
}

@main struct SearchFixtureRunner {
    @MainActor static var assertions = 0
    @MainActor static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { fatalError("FAIL: " + message) }
    }
    @MainActor static func settle(_ model: ZayitSearchViewModel) async {
        for _ in 0..<2000 {
            if !model.isLoading && !model.isLoadingMore { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("Search fixture timed out")
    }
    @MainActor static func main() async throws {
        try FileManager.default.createDirectory(at: FixtureEnvironment.root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: FixtureEnvironment.root) }
        try identityAndMetadata()
        try presentation()
        try manifestAndReadiness()
        try await paging()
        try await restore()
        try await otzariaPaginationRetry()
        print("PASS: \(assertions) portable search assertions (real models/wrapper/session; fake FFI and Combine)")
    }

    @MainActor static func manifestAndReadiness() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: root.appendingPathComponent("docs/hq-search/manifests/otzaria-search-manifest.json")))
        let source = manifest.sourceDatabase, lexical = manifest.lexicalEngine
        let db = OtzariaDatabaseInstallationManifest(repository: source.repository, releaseID: source.releaseID,
            releaseTag: source.releaseTag, assetID: source.assetID, assetName: source.assetName,
            compressedSize: source.compressedBytes, digest: source.sourceAssetDigest)
        let build = OtzariaSearchEngineBuildInfo(upstreamRepository: lexical.repository, upstreamBranch: "fixture",
            upstreamCommit: lexical.commit, engineVersion: lexical.engineVersion, indexSchemaVersion: lexical.indexSchemaVersion,
            defaultGenerationOrder: lexical.defaultGenerationOrder, semanticEnabled: false,
            semanticSidecarRevision: lexical.semanticSidecarRevision, syncedAt: "fixture", adapterVersion: lexical.adapterVersion,
            resourceHashes: manifest.resources.mapValues(\.sha256))
        OtzariaDataProfileRegistry.activeProfileID = "production"
        try OtzariaSearchArtifactPolicy.validate(manifest, database: db, databaseBytes: source.databaseBytes, build: build)
        check(true, "real production v32 manifest accepted by real runtime policy")
        do {
            try OtzariaSearchArtifactPolicy.validate(manifest, database: db, databaseBytes: source.databaseBytes + 1, build: build)
            fatalError("wrong database size accepted")
        } catch { check(true, "wrong source size rejected") }
        OtzariaDataProfileRegistry.activeProfileID = "wrong-profile"
        do {
            try OtzariaSearchArtifactPolicy.validate(manifest, database: db, databaseBytes: source.databaseBytes, build: build)
            fatalError("wrong profile accepted")
        } catch { check(true, "production artifact rejected for other profile") }
        OtzariaDataProfileRegistry.activeProfileID = "production"
        OtzariaSearchEngineBridge.currentBuild = build
        let validator = FixtureIndexValidator()
        do { _ = try validator.validateCurrentIndex(databasePath: "fixture"); fatalError("missing directory accepted") }
        catch { check(error.localizedDescription.contains("אינה קיימת"), "missing index diagnostic") }
        try FileManager.default.createDirectory(at: validator.indexURL(for: "fixture"), withIntermediateDirectories: true)
        do { _ = try validator.validateCurrentIndex(databasePath: "fixture"); fatalError("missing identity accepted") }
        catch { check(error.localizedDescription.contains("הזהות המשני"), "secondary metadata diagnostic") }
        validator.identity = .init(database: validator.fingerprint, upstreamCommit: build.upstreamCommit,
            engineVersion: build.engineVersion, indexSchemaVersion: build.indexSchemaVersion,
            defaultGenerationOrder: build.defaultGenerationOrder, adapterVersion: build.adapterVersion,
            resourceHashes: build.resourceHashes, catalogueHash: "fixture", semanticArtifactIdentity: nil)
        let count = try validator.validateCurrentIndex(databasePath: "fixture")
        check(count == 125 && OtzariaSearchEngineBridge.opened == 1, "readiness requires fresh engine open and count")
        OtzariaSearchEngineBridge.freshOpenFails = true
        check(!validator.isIndexCurrent(databasePath: "fixture"), "cached success cannot hide fresh open failure")
        OtzariaSearchEngineBridge.freshOpenFails = false
        OtzariaSearchEngineBridge.compatible = false
        do { _ = try validator.validateCurrentIndex(databasePath: "fixture"); fatalError("incompatible index accepted") }
        catch { check(error.localizedDescription.contains("incompatible schema"), "compatibility reason preserved") }
        OtzariaSearchEngineBridge.compatible = true
        validator.fingerprint = .init(databasePath: "new container", fileSize: 3821240320, modificationTime: 999)
        check(validator.isIndexCurrent(databasePath: "fixture"), "canonical managed identity tolerates path and mtime changes")
        validator.fingerprint = .init(databasePath: "fixture", fileSize: 99, modificationTime: 1)
        do { _ = try validator.validateCurrentIndex(databasePath: "fixture"); fatalError("wrong identity accepted") }
        catch { check(error.localizedDescription.contains("זהות האינדקס"), "canonical mismatch diagnosis preserved") }
        OtzariaDataProfileRegistry.activeProfileID = "fixture"
    }

    @MainActor static func identityAndMetadata() throws {
        let first = item("zayit:fixture:7"), second = item("zayit:fixture:8")
        check(first.id != second.id && first.stableID != second.stableID, "same locator distinct hit IDs")
        check(Set([first, second]).count == 2, "stable hit hashing")
        let encoded = try JSONEncoder().encode(first)
        let decoded = try JSONDecoder().decode(SearchResultItem.self, from: encoded)
        check(decoded.id == first.id && decoded.backendLocator == first.backendLocator, "identity round trip preserves real locator")
        let legacy = item()
        let oldJSON = try JSONEncoder().encode(legacy)
        check(!String(decoding: oldJSON, as: UTF8.self).contains("backendHitID"), "nil identity not encoded")
        let oldDecoded = try JSONDecoder().decode(SearchResultItem.self, from: oldJSON)
        check(oldDecoded.stableID == legacy.stableID, "old JSON fallback remains unchanged")
        check(legacy.id == "otzaria|book:7|line:1_", "legacy ID unchanged")
        let navigation = FixtureHitNavigation(), manager = iOSNavigationManager()
        navigation.zayitHits = [first.id: hit(7), second.id: hit(8)]
        navigation.openResult(second, using: manager)
        check(manager.openedHit == 8, "real navigation branch resolves exact ID despite identical title/page")
        manager.openedHit = nil; navigation.zayitHits = [first.id: hit(7)]
        navigation.openResult(second, using: manager)
        check(manager.openedHit == nil && navigation.errorMessage != nil, "stale hit rejected after query change, no title fallback")
        navigation.openResult(legacy, using: manager)
        check(manager.openedHit == nil, "legacy Zayit result without hit ID cannot open ambiguous book")
        navigation.scope = .advanced
        navigation.openResult(first, using: manager)
        check(manager.openedHit == nil, "old Zayit row cannot navigate from another search scope")

        var store = OtzariaSearchResultStore<SearchResultItem>()
        let hits1 = (1...100).map(engineHit)
        let hits2 = (100...125).map(engineHit)
        let p1 = OtzariaSearchPage(totalCount: 125, groupCount: nil, truncated: true, results: hits1)
        let p2 = OtzariaSearchPage(totalCount: 125, groupCount: nil, truncated: false, results: hits2)
        try store.apply(page: p1, items: hits1.map { item($0.stableHitID) }, replacing: true)
        try store.apply(page: p2, items: hits2.map { item($0.stableHitID) }, replacing: false)
        check(store.records.count == 125 && store.consumedCount == 126, "metadata dedup cursor uses consumed rows")
        for record in store.records {
            check(record.item.backendHitID == record.metadata.stableHitID, "metadata attached by hit identity across pages")
        }
        check(!p2.hasNextPage(consumed: store.consumedCount), "final metadata page")
        let empty = OtzariaSearchPage(totalCount: 500, groupCount: nil, truncated: true, results: [])
        check(!empty.hasNextPage(consumed: 126), "empty page cannot spin forever")
        do {
            try store.apply(page: p2, items: [], replacing: true)
            fatalError("mismatched metadata accepted")
        } catch { check(store.records.count == 125, "metadata mismatch does not erase valid rows") }
        check(!store.records.contains { $0.item.id == item("missing-metadata").id }, "missing metadata cannot borrow another page's record")
        try store.apply(page: .init(totalCount: 1, groupCount: nil, truncated: false, results: [engineHit(500)]),
                        items: [item(engineHit(500).stableHitID)], replacing: true)
        check(store.records.count == 1 && store.records[0].metadata.id == 500, "new search drops previous metadata")
        store.clear()
        check(store.records.isEmpty && store.consumedCount == 0, "clear drops metadata and cursor")
    }

    @MainActor static func presentation() throws {
        let states: [(Int, Bool, String?, Bool, Bool, UnifiedSearchPresentationState)] = [
            (0, true, nil, true, false, .loading), (0, false, "FFI", true, true, .error("FFI")),
            (0, false, nil, true, false, .missingIndex), (0, false, nil, true, true, .empty),
            (0, false, nil, false, true, .notSearched), (10, false, "page error", true, true, .results),
        ]
        for state in states {
            check(UnifiedSearchPresentationPolicy.resolve(resultCount: state.0, isLoading: state.1,
                  errorMessage: state.2, hasSubmitted: state.3, indexReady: state.4) == state.5,
                  "loading/failure/missing/empty distinction")
        }
    }

    @MainActor static func paging() async throws {
        let control = FixtureControl.shared
        let model = ZayitSearchViewModel(repository: ZayitSearchRepository())
        try await model.configure(paths: .init(seforimDb: "fixture", lexicalDb: "fixture", indexDir: "fixture"))
        await control.setup(["מילה": [0: page(Array(1...50)), 50: page(Array(50...99)),
                                      100: page(Array(100...125), last: true)]])
        model.query = "מילה"
        model.runSearch(filters: .init(bookIds: [7, 8]))
        await settle(model)
        check(model.hits.count == 50 && model.hasMore, "first 50 rows")
        model.query = "edited without submitting"; model.matchMode = .exact; model.filters = .init(bookIds: [999])
        model.loadNextPage(); model.loadNextPage()
        await settle(model)
        check(model.hits.count == 99 && model.hasMore, "append deduplicated rows")
        model.loadNextPage(); await settle(model)
        check(model.hits.count == 125 && !model.hasMore, "125 stable rows through final page")
        let requests = await control.requests
        check(requests.map(\.offset) == [0, 50, 100], "raw offsets and double-load guard")
        check(requests.allSatisfy { $0.query == "מילה" && $0.near == 5 && $0.filters.bookIds == [7, 8] }, "submitted filters/options frozen")
        check(model.hits.map(\.id) == Array(1...125).map(Int64.init), "hit order and identity retained")

        await control.setup(["retry": [0: page(Array(1...50)), 50: page([51], last: true)]], failures: [50])
        model.query = "retry"; model.runSearch(); await settle(model)
        model.loadNextPage(); await settle(model)
        check(model.hits.count == 50 && model.hasMore && model.errorMessage != nil, "page failure retains rows and retry cursor")
        await control.clearFailures(); model.loadNextPage(); await settle(model)
        check(model.hits.count == 51 && model.errorMessage == nil && !model.hasMore, "page retry clears stale error")
        let retries = await control.requests
        check(retries.map(\.offset) == [0, 50, 50], "retry uses same failed cursor")

        await control.setup(["old": [0: page([90], last: true)], "new": [0: page([91], last: true)]], delays: ["old": 80_000_000])
        model.query = "old"; model.runSearch()
        try? await Task.sleep(nanoseconds: 5_000_000)
        model.query = "new"; model.runSearch(); await settle(model)
        try? await Task.sleep(nanoseconds: 100_000_000)
        check(model.hits.map(\.id) == [91] && !model.isLoading, "late cancelled query cannot overwrite new results")
        model.query = "old"; model.runSearch(); model.cancelSearch()
        try? await Task.sleep(nanoseconds: 100_000_000)
        check(model.hits.isEmpty && !model.isLoading && !model.hasMore, "clear cancels late result delivery")
        model.query = "  "; model.runSearch()
        check(model.hits.isEmpty && model.errorMessage == nil && !model.isLoadingMore, "empty query clears all state")
        await control.setup(["empty": [0: page([], total: 500, last: false)]])
        model.query = "empty"; model.runSearch(); await settle(model)
        check(!model.hasMore && model.errorMessage == nil && model.hits.isEmpty, "genuine zero hits differs from failure")
    }

    @MainActor static func restore() async throws {
        let service = ZayitSearchArtifactService.shared
        let control = FixtureControl.shared
        let db = FixtureEnvironment.root.appendingPathComponent("seforim.db")
        try Data([1]).write(to: db)
        let session = ZayitSearchSessionController()
        await service.set(.notInstalled)
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .notConfigured, "missing index is not a failed search")
        await service.set(.ready)
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .ready && session.model.configured, "retry after install without relaunch")
        let count = await control.configureCount
        await session.restoreIfNeeded(existingSeforimDB: db)
        let sameCount = await control.configureCount
        check(count == sameCount, "unchanged ready session reused")
        try Data([1, 2]).write(to: db)
        await session.restoreIfNeeded(existingSeforimDB: db)
        let changedCount = await control.configureCount
        check(changedCount == sameCount + 1, "same-path DB replacement reconfigures")
        OtzariaDataProfileRegistry.activeProfileID = "other-fixture"
        await session.restoreIfNeeded(existingSeforimDB: db)
        let profileCount = await control.configureCount
        check(profileCount == changedCount + 1, "profile change reconfigures")
        await session.invalidate(); await control.setConfigureFailure(true)
        await session.restoreIfNeeded(existingSeforimDB: db)
        if case .failed = session.state { check(true, "FFI failure surfaced") } else { fatalError("FFI error hidden") }
        await control.setConfigureFailure(false)
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .ready, "FFI failure is retryable")
        await session.invalidate(); await service.set(.incompatible("wrong profile"))
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .failed("wrong profile"), "incompatibility not swallowed into missing index")
        await service.set(.repairRequired("metadata missing"))
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .failed("metadata missing"), "repair diagnosis retained")
        await service.set(.ready, delay: 30_000_000)
        let pending = Task { await session.restoreIfNeeded(existingSeforimDB: db) }
        try? await Task.sleep(nanoseconds: 2_000_000)
        await session.forget(); await pending.value
        check(session.state == .notConfigured && !session.model.configured, "forget serializes with pending restore")
        await service.set(.ready)
        await session.restoreIfNeeded(existingSeforimDB: db)
        ZayitSearchDataController.shared.revision += 1
        for _ in 0..<25 { await Task.yield() }
        check(session.state == .notConfigured, "install/repair revision invalidates private search session")
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .ready, "session restored after repair invalidation")
        await session.invalidate()
        OtzariaDatabaseAccessController.shared.source = .external
        ZayitSearchFolderAccess.folder = FixtureEnvironment.root
        await service.set(.incompatible("unrelated managed artifact"))
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .ready, "external folder restore ignores unrelated incompatible managed package")
        await session.invalidate()
        let lexicalURL = OtzariaMagicDictionaryManager.shared.validatedDatabaseURL
        OtzariaMagicDictionaryManager.shared.validatedDatabaseURL = nil
        await service.set(.ready)
        await session.restoreIfNeeded(existingSeforimDB: db)
        check(session.state == .ready, "external folder can supply its own lexical DB")
        OtzariaMagicDictionaryManager.shared.validatedDatabaseURL = lexicalURL
        OtzariaDatabaseAccessController.shared.source = .managedInternal
        ZayitSearchFolderAccess.folder = nil
    }
}
