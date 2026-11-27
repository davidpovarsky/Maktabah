// Explicit synthetic runtime/library/UI boundary doubles for the ORIGINAL
// diagnostic runner's decision logic. No app, RN, network, or native UI PASS.
import Foundation
enum BackendID: String, Codable, Sendable { case sefariaEmbedded, otzaria, sefaria }
struct TextLocator: Codable, Hashable, Sendable {
    enum Position: Codable, Hashable, Sendable { case canonicalRef(String) }
    let backend: BackendID; let workKey: String; let position: Position
}
struct LibrarySearchRequest { let query: String; let offset: Int; let limit: Int }
struct LibrarySearchHit { let locator: TextLocator }
struct LibrarySearchPage { let hits: [LibrarySearchHit]; let total: Int }
struct DiagnosticSegment { let primaryText: String }
struct DiagnosticSection {
    enum Origin: String { case remote }
    let locator: TextLocator; let displayRef: String; let segments: [DiagnosticSegment]
    let origin: Origin = .remote
}
struct DiagnosticStructure { let id: String; let nodes: [Int] }
extension String { var readerPlainText: String { self } }
@MainActor enum Boundary {
    static var scenario = "healthy"
    static var nativeCalls = 0
    static var nativeLocators: [TextLocator] = []
    static var staleCalls = 0
    static var surfaceCalls = 0
    static var textLoads: [TextLocator] = []
    static let hit = TextLocator(backend: .sefariaEmbedded, workKey: "Exodus", position: .canonicalRef("Exodus 2:1"))
    static func reset(_ name: String) {
        scenario = name; nativeCalls = 0; nativeLocators = []; staleCalls = 0
        surfaceCalls = 0; textLoads = []
        BackendCoordinator.shared.activeBackendID = .sefariaEmbedded
    }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .sefariaEmbedded
    func commit(_ id: BackendID) { activeBackendID = id }
}
@MainActor final class SefariaEmbeddedCatalogAdapter {
    static let shared = SefariaEmbeddedCatalogAdapter()
    func rootNodes() async throws -> [Int] { [1] }
}
@MainActor final class SefariaEmbeddedTextAdapter {
    static let shared = SefariaEmbeddedTextAdapter()
    func section(at locator: TextLocator) async throws -> DiagnosticSection {
        Boundary.textLoads.append(locator)
        return .init(locator: locator, displayRef: locator.workKey,
            segments: [.init(primaryText: locator.workKey == "Berakhot" ? "מאימתי" : "בראשית")])
    }
}
@MainActor final class SefariaEmbeddedNavigationAdapter {
    static let shared = SefariaEmbeddedNavigationAdapter()
    func navigationStructures(for work: String) async throws -> [DiagnosticStructure] { [.init(id: "default", nodes: [1])] }
}
@MainActor final class SefariaEmbeddedSearchAdapter {
    static let shared = SefariaEmbeddedSearchAdapter()
    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        switch Boundary.scenario {
        case "search_error": throw SefariaRPCError(code: "REMOTE_UNAVAILABLE", message: "Synthetic live endpoint failure")
        case "search_cancelled": throw CancellationError()
        case "empty_search": return .init(hits: [], total: 0)
        case "invalid_total": return .init(hits: [.init(locator: Boundary.hit)], total: 0)
        case "wrong_backend_hit": return .init(hits: [.init(locator: .init(backend: .otzaria, workKey: "Exodus", position: .canonicalRef("Exodus 2:1")))], total: 1)
        case "empty_work_hit": return .init(hits: [.init(locator: .init(backend: .sefariaEmbedded, workKey: "", position: .canonicalRef("Exodus 2:1")))], total: 1)
        case "search_epoch_changed": _ = await SefariaJSRPCBridge.shared.bumpSessionEpoch()
        case "search_backend_changed": BackendCoordinator.shared.activeBackendID = .otzaria
        default: break
        }
        return .init(hits: [.init(locator: Boundary.hit)], total: 1)
    }
}

@MainActor final class SefariaExpoLifecycleAdapter { static let shared = SefariaExpoLifecycleAdapter(); func ensureHostStarted() {} }
