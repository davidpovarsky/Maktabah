import Foundation
import OSLog
import Synchronization

// Explicit unrelated UI/catalog/CloudKit boundaries for a Mac Foundation
// component gate. The original complete Annotation model, Repository, Store,
// SQLiteDatabase, SyncPendingStore, ledger, codec and new session are compiled.
// No CloudKit request, original Anytype renderer, Space, account or UI is tested.
extension Logger {
    static let annotations = Logger(subsystem: "org.otzaria.local-editor-acceptance", category: "annotations")
}
enum ReusableFunc {
    static func showAlert(title: String, message: String) {}
}
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
    func insertionIndex(for value: Element, by less: (Element, Element) -> Bool) -> Int {
        firstIndex(where: { !less($0, value) }) ?? count
    }
}
extension String { func convertToArabicDigits() -> String { self } }

struct TextLocator: Codable, Sendable, Equatable {
    enum Backend: String, Codable, Sendable { case otzaria, sefaria, fixture }
    let backend: Backend
    let workKey: String
}
struct LibraryDataManager: Sendable {
    struct Book: Sendable { let book: String }
    static let shared = Self()
    func getBook(_ ids: [Int]) -> [Book] { [] }
}
struct LegacyIdentityRegistry: Sendable {
    static let shared = Self()
    func locator(for id: Int) -> TextLocator? { nil }
    func title(for locator: TextLocator) -> String? { nil }
}
struct CrossBackendBookIdentityIndex: Sendable {
    static let shared = Self()
    func areEquivalent(_ a: TextLocator, _ b: TextLocator) -> Bool { a == b }
}
struct AnnotationManager: Sendable {}
struct PlatformColor: Sendable {
    static func effectiveAnnotationColor(hex: String, isUnderline: Bool) -> Self { Self() }
}
@MainActor final class TextViewState {
    static let shared = TextViewState()
    func pushRecentUnderlineColor(_ color: PlatformColor) {}
    func pushRecentHighlightColor(_ color: PlatformColor) {}
}

final class CloudKitSyncManager: Sendable {
    enum SyncTarget { case annotation }
    struct Observation: Sendable {
        var uploads: [Annotation] = []
        var trackPending: [Bool] = []
        var deletes: [String] = []
    }
    static let shared = CloudKitSyncManager()
    private let state = Mutex(Observation())
    func resetChangeToken() {}
    func resetObservation() { state.withLock { $0 = Observation() } }
    var observation: Observation { state.withLock { $0 } }
    func upload(annotations: [Annotation], debounce: Bool = true, trackPending: Bool = true) {
        state.withLock { $0.uploads += annotations; $0.trackPending += annotations.map { _ in trackPending } }
    }
    func delete(ckRecordIds: [String], target: SyncTarget, trackPending: Bool = true) {
        state.withLock { $0.deletes += ckRecordIds }
    }
}

// Explicit localization-only boundary for the unchanged AnnotationNode file.
// Xcode generates these names from the pinned original Annotation.xcstrings;
// this standalone Foundation package does not run that catalog-generation step.
// The five original English keys below are synthetic accessors, not a resource
// or localization acceptance result. No AnnotationNode declaration is doubled.
extension LocalizedStringResource {
    enum Annotation {
        static var today: LocalizedStringResource { "Today" }
        static var yesterday: LocalizedStringResource { "Yesterday" }
        static var thisWeek: LocalizedStringResource { "This Week" }
        static var thisMonth: LocalizedStringResource { "This Month" }
        static var lastMonth: LocalizedStringResource { "Last Month" }
    }
}
