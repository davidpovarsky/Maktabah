import Foundation
import SwiftUI
import TorahInspectorCore
#if INSPECTOR_HOST_TYPECHECK
import TorahInspectorUI
#endif

// Explicit host boundaries for cache/generation controls. The complete app
// adapter, host, LibraryBackendModels, and pinned Kit sources compile unchanged.
// This file supplies deterministic provider payloads; it is not SQL/UI evidence.
@MainActor final class ProviderGate {
    var suspended = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            suspended = true
        }
    }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor final class BackendCoordinator: ObservableObject {
    static let shared = BackendCoordinator()
    @Published var generation: UInt64 = 0
    var activeBackendID = BackendID.sefaria
    var payload = "generation-A"
    var gate: ProviderGate?
    var gateKind = ""
    var sectionCalls = 0
    var linkCalls = 0
    var topicCalls = 0
    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        sectionCalls += 1
        let snapshot = makeSection(locator, text: payload)
        if gateKind == "document" { await gate?.wait() }
        return snapshot
    }
    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        linkCalls += 1
        let snapshot = [makeSource(locator, text: payload)]
        if gateKind == "links" { await gate?.wait() }
        return snapshot
    }
    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        topicCalls += 1
        let snapshot = [LibraryRelatedTopic(slug: payload, titleHe: nil, titleEn: payload)]
        if gateKind == "topics" { await gate?.wait() }
        return snapshot
    }
}

func makeSection(_ locator: TextLocator, text: String) -> LibraryTextSection {
    .init(locator: locator, displayRef: "Fixture 1", heRef: "Fixture Hebrew 1",
          segments: [.init(locator: locator, heRef: "Fixture Hebrew 1", primaryText: text, translation: "translation:" + text)],
          previous: nil, next: nil,
          versions: [.init(title: "fixture-source", language: "he", actualLanguage: "he", sourceURL: nil,
                           license: nil, notes: nil, isPrimary: true),
                     .init(title: "fixture-translation", language: "en", actualLanguage: "en", sourceURL: nil,
                           license: nil, notes: nil, isPrimary: false)], links: [], origin: .offline)
}
func makeSource(_ locator: TextLocator, text: String) -> LibraryRelatedSource {
    .init(locator: locator, displayRef: "Fixture commentary", heRef: text, category: "Commentary",
          type: "commentary", collectiveTitle: "Fixture author", heCollectiveTitle: nil,
          primaryText: text, translation: nil, versionTitle: nil, heVersionTitle: nil, license: nil)
}

struct BookBoundary { var id: Int; var book: String; var backendLocator: TextLocator? }
@Observable @MainActor final class ReaderViewModel {
    var currentBook: BookBoundary?
    var currentContentId = 1
    var backendSection: LibraryTextSection?
    var selectedSegmentLocator: TextLocator?
    var selectedSegmentRange: NSRange?
    var otzariaSelectedLineAnchor: OtzariaLineAnchor?
    var currentAnnotations: [Annotation] = []
    var readerInspectorVisible = false
    var currentReaderTextMode = LibraryReaderTextMode.source
    var bookConnection = BookConnectionBoundary()
    func closeReaderInspector() { readerInspectorVisible = false }
    func updateContentState(with content: String) {}
}
struct BookConnectionBoundary { func getContent(bkid: String, contentId: Int) -> String? { nil } }
@MainActor final class LegacyIdentityRegistry {
    static let shared = LegacyIdentityRegistry()
    func locator(for id: Int) -> TextLocator? { nil }
}
@MainActor final class LibraryDataManager {
    static let shared = LibraryDataManager()
    var booksById: [Int: BookBoundary] = [:]
}
extension UserDefaults { var libraryReaderTextMode: LibraryReaderTextMode { .source } }
enum SefariaRef {
    static func canonicalInput(_ reference: String) -> String { reference }
    static func workKey(from reference: String, knownTitles: [String]) -> String? { nil }
}
enum OtzariaBackendActivation { static let isActive = true }
extension String { var otsariaPlainText: String { readerPlainText } }
struct Annotation: Sendable {
    var id: Int64?
    var createdAt = "fixture"
    var bkId: Int
    var backendLocator: TextLocator?
    var range: NSRange = .init(location: 0, length: 1)
    var rangeDiacritics: NSRange = .init(location: 0, length: 1)
    var note: String?
    var context = "fixture context"
    var tags: [String] = []
}
final class AnnotationManager: Sendable {
    static let shared = AnnotationManager()
    func loadAnnotations(bkId: Int) -> [Annotation] { [] }
}
struct OtzariaLinkedSource: Sendable { let source: LibraryRelatedSource }
final class OtzariaMaktabahBridge: @unchecked Sendable {
    static let shared = OtzariaMaktabahBridge()
    private let lock = NSLock()
    private var storedPayload = "generation-A"
    private var storedCalls = 0
    var currentReadingUnitMode = OtzariaUnitMode.chapter
    var payload: String {
        get { lock.withLock { storedPayload } }
        set { lock.withLock { storedPayload = newValue } }
    }
    var linkCalls: Int { lock.withLock { storedCalls } }
    func cachedReadingUnit(bookId: Int, contentId: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        getReadingUnit(bookId: bookId, containingLineIndex: contentId, mode: mode)
    }
    func getReadingUnit(bookId: Int, containingLineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let text = payload
        return .init(id: "stable-unit", bookId: bookId, mode: mode, tocEntryId: 1, title: "Fixture chapter", level: 1,
                     startLineIndex: 1, endLineIndex: 1, sourceLineIndices: [1],
                     lineAnchors: [.init(id: 1, bookId: bookId, lineIndex: 1, heRef: "Fixture 1", text: text,
                                         range: .init(location: 0, length: text.utf16.count))],
                     html: text, plainText: text, heRef: "Fixture 1")
    }
    func getLinksMetadataForReadingUnit(_ unit: OtzariaReadingUnit, includeContent: Bool) throws -> [OtzariaLinkedSource] {
        try getLinksMetadataForLineIndices(bookID: unit.bookId, sourceLineIndices: unit.sourceLineIndices, includeContent: includeContent)
    }
    func getLinksMetadataForLineIndices(bookID: Int, sourceLineIndices: [Int], includeContent: Bool) throws -> [OtzariaLinkedSource] {
        lock.withLock { storedCalls += 1 }
        return [.init(source: makeSource(.init(backend: .otzaria, workKey: "book:2", position: .legacyLine(1)), text: payload))]
    }
    func authorNames(forBookIds: [Int]) -> [Int: String] { [:] }
    func fetchSnippets(for sources: [TorahLinkedSource]) throws -> [TorahLinkedSource.ID: String] {
        Dictionary(uniqueKeysWithValues: sources.map { ($0.id, payload) })
    }
    struct Line { let content: String; let heRef: String? }
    func fetchLineContent(bookId: Int, lineIndex: Int) throws -> Line? { .init(content: payload, heRef: "Fixture 1") }
    struct Metadata { let title: String }
    func bookMetadata(for bookID: Int) -> Metadata? { .init(title: "Fixture book") }
    func getPreviousReadingUnitDescriptor(bookId: Int, beforeLineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnitDescriptor? { nil }
    func getNextReadingUnitDescriptor(bookId: Int, afterLineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnitDescriptor? { nil }
    func getAvailableReadingUnitModes(bookId: Int) -> [OtzariaUnitLevelOption] { [] }
}
enum OtzariaInspectorRelationshipsProvider {
    static func map(_ value: OtzariaLinkedSource) -> LibraryRelatedSource { value.source }
}
enum OtzariaInspectorDocumentMapper {
    static func section(from unit: OtzariaReadingUnit, previous: OtzariaReadingUnitDescriptor?, next: OtzariaReadingUnitDescriptor?) -> LibraryTextSection {
        makeSection(.init(backend: .otzaria, workKey: "book:\(unit.bookId)", position: .legacyLine(unit.startLineIndex)), text: unit.plainText)
    }
}
enum OtzariaCommentatorResolver {
    struct Identity {
        let collectiveTitle = "Fixture author"; let hebrewCollectiveTitle: String? = nil
        let commentatorID = "fixture-author"; let commentatorName = "Fixture author"
        let hebrewCommentatorName: String? = nil; let workTitle = "Fixture work"; let hebrewWorkTitle: String? = nil
    }
    static func resolve(bookID: Int?, bookTitle: String, heRef: String?, authorNameFromDB: String?) -> Identity { .init() }
}
enum OtzariaRelationshipClassifier {
    struct Classification { let relationshipKind = TorahRelationshipKind.commentary; let semanticCategory = TorahSourceCategory.commentary }
    static func classify(category: String, type: String) -> Classification { .init() }
}
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable { static let shared = Self(); func log(_ text: String) {} }

#if INSPECTOR_HOST_TYPECHECK
// Host routing and presentation boundaries for whole-source SwiftUI typecheck.
@MainActor final class iOSNavigationManager {
    func openTorahInspectorLocationInNewTab(_ locator: TextLocator) {}
}
struct MaktabahNativeRoutingSurface: ViewModifier {
    enum Kind { case inspector }
    let kind: Kind; let inspectorReader: ReaderViewModel
    func body(content: Content) -> some View { content }
}
struct NativeStudySheetContent { var isPeek = false }
struct NativeStudySheetPeek: View {
    let content: NativeStudySheetContent; let selectedTool: TorahStudyTool; let close: () -> Void
    var body: some View { EmptyView() }
}
enum ChavrusaTextReaderUI { static let isEnabled = true }

#endif
