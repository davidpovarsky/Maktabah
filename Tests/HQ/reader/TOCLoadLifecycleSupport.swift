// Test-only transport and database boundaries. The entire production
// BookTOCViewModel and TOCNode compile unchanged against real Apple frameworks.
import Foundation
import OSLog

extension Logger {
    static let reader = Logger(subsystem: "Otzaria.TOCLoadLifecycle", category: "reader")
}

struct TextLocator: Equatable, Hashable, Sendable {
    enum Backend: String, Sendable { case otzaria, sefaria, sefariaEmbedded }
    let backend: Backend
    let workKey: String
    let reference: String
}
struct BooksData: Sendable {
    let id: Int
    let book: String
    let backendLocator: TextLocator?
}
struct BookConnection: Sendable {}
struct LibraryWork: Sendable {
    let locator: TextLocator
    let title: String
    let heTitle: String?
    let categories: [String]
    let description: String?
}
struct LibraryTOCNode: Sendable {
    let locator: TextLocator
    let title: String
    let children: [LibraryTOCNode]
}
struct LibraryNavigationStructure: Sendable {
    let id: String
    let title: String
    let nodes: [LibraryTOCNode]
}
struct LibraryNavigationItem: Sendable {
    let locator: TextLocator
    let title: String
    let index: Int
}
enum LibraryBackendError: Error { case unavailableOffline, corruptData(String), invalidResponse(String) }
struct TOC: Sendable {
    let bab: String
    let level: Int
    let sub: Int
    let id: Int
    var entryId: Int { id }
    var parentId: Int? { nil }
}
extension String { func convertToArabicDigits() -> String { self } }
struct FlattenedTOCItem {
    let id: Int
    let title: String
    let level: Int
    let locator: TextLocator?
}
enum TOCReadingLocationTracker {
    static func findMatchingNodeID(for locator: TextLocator, in nodes: [FlattenedTOCItem]) -> Int? {
        nodes.first { $0.locator == locator }?.id
    }
}
final class LegacyIdentityRegistry: @unchecked Sendable {
    private let lock = NSLock()
    static let shared = LegacyIdentityRegistry()
    private var ids: [TextLocator: Int] = [:]
    func id(for locator: TextLocator) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let id = ids[locator] { return id }
        let id = ids.count + 1_000
        ids[locator] = id
        return id
    }
}

// Continuations deliberately ignore cancellation until the fixture resolves
// them. This reproduces a completed/cancelled earlier request reaching its
// defer while the next book is still loading; no sleep is injected in product.
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var structures: [String: CheckedContinuation<[LibraryNavigationStructure], Error>] = [:]
    var fallbacks: [String: CheckedContinuation<[LibraryTOCNode], Error>] = [:]
    var started: [String] = []
    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        started.append(work.locator.reference)
        return try await withCheckedThrowingContinuation { structures[work.locator.reference] = $0 }
    }
    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        return try await withCheckedThrowingContinuation { fallbacks[work.locator.reference] = $0 }
    }
    func finish(_ key: String, _ value: [LibraryNavigationStructure]) {
        structures.removeValue(forKey: key)!.resume(returning: value)
    }
    func fail(_ key: String, _ error: Error) {
        structures.removeValue(forKey: key)!.resume(throwing: error)
    }
    func finishFallback(_ key: String, _ value: [LibraryTOCNode]) {
        fallbacks.removeValue(forKey: key)!.resume(returning: value)
    }
}

actor NativeTOCBoundary {
    static let shared = NativeTOCBoundary()
    private var requests: [Int: CheckedContinuation<[TOCNode], Error>] = [:]
    private(set) var released: [Int] = []
    func load(_ id: Int) async throws -> [TOCNode] {
        try await withCheckedThrowingContinuation { requests[id] = $0 }
    }
    func has(_ id: Int) -> Bool { requests[id] != nil }
    func finish(_ id: Int, _ tree: [TOCNode]) { requests.removeValue(forKey: id)!.resume(returning: tree) }
    func fail(_ id: Int) { requests.removeValue(forKey: id)!.resume(throwing: LibraryBackendError.invalidResponse("fixture")) }
    func release(_ id: Int) { released.append(id) }
}
actor TOCLoaderRefCount {
    init(connFactory: @escaping @Sendable () -> BookConnection) {}
    func acquire(book: BooksData) -> Task<[TOCNode], Error> {
        Task { try await NativeTOCBoundary.shared.load(book.id) }
    }
    func release(bookId: Int) async { await NativeTOCBoundary.shared.release(bookId) }
}
