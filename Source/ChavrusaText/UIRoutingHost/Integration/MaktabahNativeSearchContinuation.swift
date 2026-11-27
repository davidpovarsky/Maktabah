#if os(iOS)
import Combine
import Foundation
import SwiftUI
import UIKit
import OtzariaActionCore
import ChavrusaUIRoutingHost

/// Per-original-session publication and mounted-view ownership. It retains
/// metadata and weak view references only, never another SearchResultItem store.
@MainActor
final class MaktabahNativeSearchContinuationSource {
    let sessionID = UUID()
    let claims = OriginalSearchContinuationClaim()
    private(set) weak var session: UnifiedSearchSessionController?
    private(set) var inputRevision: UInt64? = 0
    private(set) var resultRevision: UInt64? = 0
    private(set) var presentationRevision: UInt64? = 0
    private var ownDispatch: UUID?
    private var ownPresentation: UUID?
    private var prefetchGuard: UUID?
    private var gestures: [ObjectIdentifier: MaktabahSearchContinuationGestureWitness] = [:]
    fileprivate var lists: [UUID: WeakList] = [:]
    fileprivate var rows: [UUID: WeakRow] = [:]

    func attach(_ session: UnifiedSearchSessionController) {
        guard self.session == nil else { return }
        self.session = session
    }
    func originalInputDidChange() {
        Self.advance(&inputRevision); claims.invalidate(); prefetchGuard = nil
    }
    func originalResultsDidPublish() { Self.advance(&resultRevision) }
    func originalPresentationWillChange() {
        Self.advance(&presentationRevision)
        if ownPresentation == nil { claims.invalidate() }
    }
    func originalPageWillDispatch() {
        if ownDispatch == nil { originalInputDidChange() }
    }
    private static func advance(_ value: inout UInt64?) {
        guard let current = value, current < .max else { value = nil; return }
        value = current + 1
    }

    /// Read synchronously inside the original row's onAppear callback. A Bool
    /// captured before claim is insufficient. After a programmatic reveal/page,
    /// only a real original scroll gesture or explicit original Load More/new
    /// input releases that local guard; delayed appearance cannot add a page.
    var permitsOriginalAutomaticPaging: Bool {
        claims.active == nil && prefetchGuard == nil
    }
    fileprivate func holdAutomaticPaging(_ claim: OriginalSearchContinuationClaim.Claim) {
        prefetchGuard = claim.id
    }
    fileprivate func finish(_ claim: OriginalSearchContinuationClaim.Claim, hadEffect: Bool) {
        claims.finish(claim)
        if !hadEffect, prefetchGuard == claim.id { prefetchGuard = nil }
    }
    fileprivate func dispatch(_ claim: OriginalSearchContinuationClaim.Claim, _ action: () throws -> Void) throws {
        try claims.validate(claim)
        guard ownDispatch == nil else { throw ActionPortError.staleState }
        ownDispatch = claim.id
        defer { ownDispatch = nil }
        try action()
    }
    fileprivate func select(_ claim: OriginalSearchContinuationClaim.Claim, _ action: () throws -> Void) throws {
        try claims.validate(claim)
        guard ownPresentation == nil else { throw ActionPortError.staleState }
        ownPresentation = claim.id
        defer { ownPresentation = nil }
        try action()
    }

    fileprivate final class WeakList { weak var value: MaktabahSearchContinuationListView?; init(_ v: MaktabahSearchContinuationListView) { value = v } }
    fileprivate final class WeakRow { weak var value: MaktabahSearchContinuationRowView?; init(_ v: MaktabahSearchContinuationRowView) { value = v } }
    /// Identity-only metadata for the original attached list. This deliberately
    /// does not attest foreground/visibility or permit any operation. The
    /// unchanged currentList predicate remains mandatory at execution/ACK.
    fileprivate func metadataList(scene: String) throws -> MaktabahSearchContinuationListView {
        let live = lists.values.compactMap(\.value).filter {
            $0.window?.windowScene?.session.persistentIdentifier == scene && $0.window != nil
        }
        guard live.count == 1, let list = live.first, list.hasSameAttachment else {
            throw ActionPortError.unavailable
        }
        return list
    }
    fileprivate func currentList(scene: String, requiresCurrentLayout: Bool = true) throws -> MaktabahSearchContinuationListView {
        lists = lists.filter { $0.value.value != nil }
        let live = lists.values.compactMap(\.value).filter {
            $0.window?.windowScene?.session.persistentIdentifier == scene && $0.window != nil
        }
        guard live.count == 1, let list = live.first, Self.visible(list, scene: scene), list.hasSameAttachment,
              (!requiresCurrentLayout || list.hasCurrentLayout),
              !gestures.values.contains(where: { $0.isInteracting }) else {
            throw ActionPortError.unavailable
        }
        return list
    }
    fileprivate func observeOriginalScroll(above view: UIView) {
        var parent = view.superview
        while let current = parent {
            if let scroll = current as? UIScrollView {
                let id = ObjectIdentifier(scroll)
                if gestures[id] == nil { gestures[id] = .init(source: self, scroll: scroll) }
                return
            }
            parent = current.superview
        }
    }
    fileprivate func removeList(_ list: MaktabahSearchContinuationListView) {
        lists.removeValue(forKey: list.id)
        originalInputDidChange()
        if lists.values.allSatisfy({ $0.value == nil }) {
            for witness in gestures.values { witness.detach() }
            gestures.removeAll()
        }
    }
    fileprivate func currentRow(identity: Data, group: String, scene: String) throws -> MaktabahSearchContinuationRowView {
        rows = rows.filter { $0.value.value != nil }
        let live = rows.values.compactMap(\.value).filter {
            $0.identity == identity && Data($0.group.utf8) == Data(group.utf8)
                && $0.expanded && $0.hasCurrentLayout && Self.visible($0, scene: scene)
        }
        guard live.count == 1, let row = live.first else { throw ActionPortError.unavailable }
        return row
    }

    fileprivate static func visible(_ view: UIView, scene: String) -> Bool {
        guard let window = view.window, window.isKeyWindow, !window.isHidden,
              window.windowScene?.activationState == .foregroundActive,
              Data((window.windowScene?.session.persistentIdentifier ?? "").utf8) == Data(scene.utf8) else { return false }
        let target = view.convert(view.bounds, to: window)
        let area = target.width * target.height
        guard target.width.isFinite, target.height.isFinite, area.isFinite, area > 1 else { return false }
        var visible = target.intersection(window.bounds), alpha: CGFloat = 1
        var current: UIView? = view
        while let value = current {
            guard !value.isHidden else { return false }
            alpha *= value.alpha
            if value.clipsToBounds { visible = visible.intersection(value.convert(value.bounds, to: window)) }
            if let scroll = value as? UIScrollView {
                // Same original component-witness viewport boundaries: safe
                // area/keyboard insets are not visible rows below the viewport.
                let viewport = scroll.bounds.inset(by: scroll.adjustedContentInset)
                visible = visible.intersection(scroll.convert(viewport, to: window))
                if scroll.isDragging || scroll.isDecelerating { return false }
            }
            current = value.superview
        }
        guard alpha >= 0.95, !visible.isNull, visible.width * visible.height >= area * 0.98 else { return false }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if let top, top !== window.rootViewController, !view.isDescendant(of: top.view) { return false }
        if let top, top.isBeingPresented || top.isBeingDismissed || top.transitionCoordinator != nil { return false }
        return true
    }
}

/// Passive target on the actual original scroll view's existing recognizer.
/// It changes no recognizer/delegate/gesture behavior and cannot synthesize a
/// user action. A manual scroll retires a retained operation even after ABA.
@MainActor
private final class MaktabahSearchContinuationGestureWitness: NSObject {
    weak var source: MaktabahNativeSearchContinuationSource?
    weak var scroll: UIScrollView?
    private var inGesture = false
    var isInteracting: Bool {
        guard let scroll, scroll.window != nil else { return false }
        return inGesture || scroll.isTracking || scroll.isDragging || scroll.isDecelerating
    }
    init(source: MaktabahNativeSearchContinuationSource, scroll: UIScrollView) {
        self.source = source; self.scroll = scroll
        super.init()
        scroll.panGestureRecognizer.addTarget(self, action: #selector(changed(_:)))
    }
    @objc private func changed(_ recognizer: UIPanGestureRecognizer) {
        guard let scroll, recognizer === scroll.panGestureRecognizer else { return }
        switch recognizer.state {
        case .began, .changed:
            if !inGesture { inGesture = true; source?.originalInputDidChange() }
        case .ended, .cancelled, .failed: inGesture = false
        default: break
        }
    }
    func detach() { scroll?.panGestureRecognizer.removeTarget(self, action: #selector(changed(_:))) }
}

/// Exact identity of the actual item used by the original row. String == and
/// SearchResultItem == are deliberately not identity authority (both can erase
/// distinctions, and the latter compares stableID only).
@MainActor
enum MaktabahSearchContinuationIdentity {
    private struct Value: Encodable {
        let archive: String; let table: String; let book: Int; let title: String
        let page: Int; let part: Int; let locator: TextLocator?; let displayRef: String?
        let version: String?; let language: String?; let providerHit: String?
        let stableID: String; let text: String; let highlightedTerms: [String]?
    }
    static func bytes(_ item: SearchResultItem) throws -> Data {
        let value = Value(archive: item.archive, table: item.tableName, book: item.bookId,
                          title: item.bookTitle, page: item.page, part: item.part,
                          locator: item.backendLocator, displayRef: item.locationDisplayText,
                          version: item.versionTitle, language: item.resultLanguage,
                          providerHit: item.backendHitID, stableID: item.stableID,
                          text: item.attributedText.string, highlightedTerms: item.highlightTerms)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    static func group(_ item: SearchResultItem) -> String {
        item.backendLocator?.persistenceKey ?? "\(item.archive):\(item.tableName):\(item.bookId):\(item.part):\(item.page)"
    }
    static func identities(_ items: [SearchResultItem]) throws -> [Data] {
        guard items.count <= 10_000 else { throw ActionPortError.unavailable }
        // The original List groups/deduplicates String IDs. A collision under
        // those exact semantics is ambiguous even if the UTF-8 differs.
        guard Set(items.map(\.stableID)).count == items.count else { throw ActionPortError.invalidResponse }
        return try items.map(bytes)
    }
}

@MainActor
final class MaktabahSearchContinuationListView: UIView {
    private(set) var id = UUID()
    weak var source: MaktabahNativeSearchContinuationSource?
    var identities: [Data] = []
    var pageRevision: UInt64?
    var apply: ((Data) throws -> String)?
    var readSelection: ((Data) -> Bool)?
    private(set) var contentRevision: UInt64 = 0
    private(set) var layoutRevision: UInt64 = 0
    private var laidOutContent: UInt64?
    private weak var originalWindow: UIWindow?
    private var attached = false
    private var hadWindow = false
    private var valid = true
    var hasSameAttachment: Bool { valid && attached && window === originalWindow }
    var hasCurrentLayout: Bool { hasSameAttachment && laidOutContent == contentRevision && layoutRevision > 0 }
    func update(source: MaktabahNativeSearchContinuationSource?, identities: [Data], pageRevision: UInt64?,
                apply: @escaping (Data) throws -> String, readSelection: @escaping (Data) -> Bool) {
        if self.source !== source {
            self.source?.removeList(self); self.source = source
            id = UUID(); laidOutContent = nil
            setNeedsLayout()
        }
        source?.lists[id] = .init(self)
        if self.identities != identities || self.pageRevision != pageRevision {
            guard contentRevision < .max else { valid = false; return }
            contentRevision += 1; self.identities = identities; self.pageRevision = pageRevision
            setNeedsLayout()
        }
        self.apply = apply; self.readSelection = readSelection
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            if hadWindow && (!attached || window !== originalWindow) {
                source?.removeList(self); id = UUID(); layoutRevision = 0; laidOutContent = nil; valid = true
            }
            originalWindow = window; attached = true; hadWindow = true
            source?.lists[id] = .init(self)
        } else if attached {
            source?.removeList(self); attached = false; originalWindow = nil; laidOutContent = nil
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard layoutRevision < .max else { valid = false; return }
        layoutRevision += 1; laidOutContent = contentRevision
    }
}

@MainActor
final class MaktabahSearchContinuationRowView: UIView {
    private(set) var id = UUID()
    weak var source: MaktabahNativeSearchContinuationSource?
    var identity: Data?
    var group = ""
    var expanded = false
    private(set) var layoutRevision: UInt64 = 0
    private var contentRevision: UInt64 = 0
    private var laidOutContent: UInt64?
    private weak var originalWindow: UIWindow?
    private var attached = false
    private var hadWindow = false
    private var valid = true
    var hasCurrentLayout: Bool { valid && attached && window === originalWindow && laidOutContent == contentRevision && layoutRevision > 0 }
    func update(source: MaktabahNativeSearchContinuationSource?, identity: Data?, group: String, expanded: Bool) {
        if self.source !== source {
            self.source?.rows.removeValue(forKey: id); self.source = source
            id = UUID(); laidOutContent = nil
            setNeedsLayout()
        }
        source?.rows[id] = .init(self)
        if self.identity != identity || Data(self.group.utf8) != Data(group.utf8) || self.expanded != expanded {
            guard contentRevision < .max else { valid = false; return }
            contentRevision += 1; self.identity = identity; self.group = group; self.expanded = expanded
            setNeedsLayout()
        }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            if hadWindow && (!attached || window !== originalWindow) {
                source?.rows.removeValue(forKey: id); id = UUID(); layoutRevision = 0; laidOutContent = nil; valid = true
            }
            originalWindow = window; attached = true; hadWindow = true
            source?.rows[id] = .init(self); source?.observeOriginalScroll(above: self)
        } else if attached {
            source?.rows.removeValue(forKey: id); attached = false; originalWindow = nil; laidOutContent = nil
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard layoutRevision < .max else { valid = false; return }
        layoutRevision += 1; laidOutContent = contentRevision
        source?.observeOriginalScroll(above: self)
    }
}

struct MaktabahSearchContinuationListHost: UIViewRepresentable {
    let source: MaktabahNativeSearchContinuationSource?
    let identities: [Data]
    let pageRevision: UInt64?
    let apply: (Data) throws -> String
    let readSelection: (Data) -> Bool
    func makeUIView(context: Context) -> MaktabahSearchContinuationListView {
        let view = MaktabahSearchContinuationListView(); view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false; view.backgroundColor = .clear; return view
    }
    func updateUIView(_ view: MaktabahSearchContinuationListView, context: Context) {
        view.update(source: source, identities: identities, pageRevision: pageRevision, apply: apply, readSelection: readSelection)
    }
    static func dismantleUIView(_ view: MaktabahSearchContinuationListView, coordinator: ()) {
        view.source?.removeList(view); view.apply = nil; view.readSelection = nil
    }
}
struct MaktabahSearchContinuationRowHost: UIViewRepresentable {
    let source: MaktabahNativeSearchContinuationSource?
    let identity: Data?
    let group: String
    let expanded: Bool
    func makeUIView(context: Context) -> MaktabahSearchContinuationRowView {
        let view = MaktabahSearchContinuationRowView(); view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false; view.backgroundColor = .clear; return view
    }
    func updateUIView(_ view: MaktabahSearchContinuationRowView, context: Context) {
        view.update(source: source, identity: identity, group: group, expanded: expanded)
    }
    static func dismantleUIView(_ view: MaktabahSearchContinuationRowView, coordinator: ()) {
        view.source?.rows.removeValue(forKey: view.id)
    }
}

/// Projection is metadata from this exact original List render. State remains
/// in the original SwiftUI dictionaries; the owner retains no result array.
@MainActor
enum MaktabahSearchContinuationListAdapter {
    private struct Coordinate {
        let identity: Data
        let group: String
        let index: Int
    }
    static func host(source: MaktabahNativeSearchContinuationSource, results: [SearchResultItem],
                     groups: [SearchResultGroup], selected: Binding<[String: Int]>,
                     expanded: Binding<Set<String>>, proxy: ScrollViewProxy) -> MaktabahSearchContinuationListHost {
        let coordinates = groups.flatMap { group in
            group.versions.enumerated().compactMap { index, item -> Coordinate? in
                guard let identity = try? MaktabahSearchContinuationIdentity.bytes(item) else { return nil }
                return Coordinate(identity: identity, group: group.id, index: index)
            }
        }
        let identities = (try? MaktabahSearchContinuationIdentity.identities(results)) ?? []
        return MaktabahSearchContinuationListHost(source: source, identities: identities,
            pageRevision: source.session?.nativeContinuationPageSnapshot?.pageRevision,
            apply: { identity in
                let matches = coordinates.filter { $0.identity == identity }
                guard matches.count == 1, let match = matches.first else { throw ActionPortError.invalidResponse }
                // These are the same original version/expansion State setters
                // used by the row. No filter, source, query or reader is changed.
                source.originalPresentationWillChange()
                selected.wrappedValue[match.group] = match.index
                source.originalPresentationWillChange()
                expanded.wrappedValue.insert(match.group)
                proxy.scrollTo(match.group, anchor: .center)
                return match.group
            }, readSelection: { identity in
                let matches = coordinates.filter { $0.identity == identity }
                guard matches.count == 1, let match = matches.first else { return false }
                return (selected.wrappedValue[match.group] ?? 0) == match.index && expanded.wrappedValue.contains(match.group)
            })
    }
}

/// Wave3 owns construction/wiring in its existing Scene/registry/Composition.
/// Both authority closures are mandatory: retained scene/workspace/parent
/// ownership at observation, and current invocation authority through awaits.
@MainActor
final class MaktabahNativeSearchContinuationBinding {
    typealias Check = @MainActor () throws -> Void
    let sceneID: String
    private let session: UnifiedSearchSessionController
    private let source: MaktabahNativeSearchContinuationSource
    private let currentSnapshot: @MainActor () throws -> ActionBackendSnapshot
    private let originalWindow: @MainActor () throws -> UIWindow
    private var retired = false
    private var retained: Retained?
    private var completed: Completed?

    struct MetadataHit {
        let title: String
        let hit: NativeSearchContinuationIntentService.Hit
    }
    /// One read-only original publication. Its live closures capture the
    /// original session/source weakly; no grant, claim token or result model is
    /// retained. Before/foreign checks deliberately have different jobs: an
    /// owned page may change results, but it may never change the original
    /// query, model, backend, scene/window or user-owned inputs.
    @MainActor final class Metadata {
        let source: NativeSearchContinuationIntentService.Source
        let hits: [MetadataHit]
        let hasNextPage: Bool
        private let before: Check
        private let foreign: Check
        private var active = true
        init(source: NativeSearchContinuationIntentService.Source, hits: [MetadataHit], hasNextPage: Bool,
             before: @escaping Check, foreign: @escaping Check) {
            self.source = source; self.hits = hits; self.hasNextPage = hasNextPage
            self.before = before; self.foreign = foreign
        }
        func validateBefore() throws {
            guard active else { throw ActionPortError.staleState }
            try before()
            guard active else { throw ActionPortError.staleState }
        }
        func validateForeign() throws {
            guard active else { throw ActionPortError.staleState }
            try foreign()
            guard active else { throw ActionPortError.staleState }
        }
        func retire() { active = false }
    }

    /// Capture original metadata without inventing an invocation or calling
    /// claims.observe. The caller's check is the actual original scene/parent
    /// identity, not a Core authorization. Foreground geometry is independently
    /// required by the original binding after the real command is admitted.
    static func captureMetadata(sceneID: String, session: UnifiedSearchSessionController,
        currentSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot,
        originalWindow: @escaping @MainActor () throws -> UIWindow,
        validateParent: @escaping Check) throws -> Metadata {
        try validateParent()
        let originalSource = session.nativeSearchContinuation
        let model = session.searchViewModel
        let inputs = MaktabahNativeComponentSourceObservation {
            _ = session.searchViewModel; _ = session.query; _ = session.scope
            _ = session.requestConfiguration; _ = session.selectedBookIds; _ = session.resultKitabFilter
            _ = session.showsBookFilterSheet; _ = session.showsSearchDataSheet; _ = session.showsAdvancedOptions
            _ = model?.selectedBookIds; _ = model?.filterText; _ = model?.query; _ = model?.searchMode
            _ = model?.nearDistance; _ = model?.sortKey; _ = model?.sortAscending; _ = model?.resultKitabFilter
            _ = model?.backendSearchOptions; _ = model?.backendSearchGeneration
        }
        let zayitInputs = NativeComponentSourceObservation(read: {})
        let queryChange = session.zayitSession.model.$query.dropFirst().sink { _ in zayitInputs.invalidate() }
        let modeChange = session.zayitSession.model.$matchMode.dropFirst().sink { _ in zayitInputs.invalidate() }
        let reader = Self(sceneID: sceneID, session: session, currentSnapshot: currentSnapshot, originalWindow: originalWindow)
        let stamp = try reader.readStamp(metadataOnly: true)
        // A catalog is bounded metadata. An unusually large current source is
        // unavailable to this adapter; its actual results/UI stay unchanged.
        guard stamp.all.reduce(0, { $0 + $1.count }) <= 8 * 1_024 * 1_024 else { throw ActionPortError.unavailable }
        let eligible = Set(stamp.filtered)
        let qualified = zip(session.results, stamp.all).filter { eligible.contains($0.1) }.map { item, identity in
            MetadataHit(title: [item.bookTitle, item.locationDisplayText, item.versionTitle, item.resultLanguage]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — "),
                hit: .init(stableID: item.stableID, locator: item.backendLocator?.persistenceKey,
                           versionTitle: item.versionTitle, language: item.resultLanguage, identity: identity))
        }
        let value = NativeSearchContinuationIntentService.Source(sceneID: sceneID, snapshot: stamp.snapshot,
            sessionID: originalSource.sessionID, modelID: stamp.page.ownerID, generation: stamp.page.generation,
            sourceRevision: stamp.inputRevision, submissionRevision: stamp.submission,
            cancellationRevision: stamp.cancellation, paginationRevision: stamp.pagination,
            pageRevision: stamp.page.pageRevision!, configuration: stamp.configuration)
        let foreign: Check = { [weak session, weak originalSource, weak model] in
            _ = queryChange; _ = modeChange
            try validateParent(); try inputs.validate(); try zayitInputs.validate()
            guard let session, let originalSource, session.nativeSearchContinuation === originalSource,
                  originalSource.session === session, session.searchViewModel === model,
                  originalSource.inputRevision == stamp.inputRevision,
                  session.nativeContinuationGeneration == stamp.unifiedGeneration,
                  session.submissionRevision == stamp.submission,
                  session.cancellationRevision == stamp.cancellation,
                  let page = session.nativeContinuationPageSnapshot,
                  page.ownerID == stamp.page.ownerID, page.generation == stamp.page.generation,
                  try currentSnapshot() == stamp.snapshot else { throw ActionPortError.staleState }
            let current = Self(sceneID: sceneID, session: session, currentSnapshot: currentSnapshot, originalWindow: originalWindow)
            guard try current.configurationBytes() == stamp.configuration,
                  let list = try? originalSource.metadataList(scene: sceneID), list.id == stamp.listID,
                  list.window.map(ObjectIdentifier.init) == stamp.windowID,
                  list.window === (try originalWindow()) else { throw ActionPortError.staleState }
            try inputs.validate(); try zayitInputs.validate(); try validateParent()
        }
        let before: Check = { [weak session] in
            try foreign()
            guard let session else { throw ActionPortError.staleState }
            let current = Self(sceneID: sceneID, session: session, currentSnapshot: currentSnapshot, originalWindow: originalWindow)
            guard try current.readStamp(metadataOnly: true) == stamp else { throw ActionPortError.staleState }
            try foreign()
        }
        try before()
        return Metadata(source: value, hits: qualified,
            hasNextPage: session.nativeContinuationHasMore && stamp.page.lastCommitted?.cursorAfter != nil,
            before: before, foreign: foreign)
    }

    private struct Stamp: Equatable {
        let snapshot: ActionBackendSnapshot
        let inputRevision: UInt64
        let resultRevision: UInt64
        let presentationRevision: UInt64
        let unifiedGeneration: Int
        let submission: Int; let cancellation: Int; let pagination: Int
        let configuration: Data
        let page: OriginalSearchPageLedger.Snapshot
        let all: [Data]; let filtered: [Data]
        let listID: UUID; let windowID: ObjectIdentifier
    }
    private final class Retained {
        let stamp: Stamp
        let tokens: OriginalSearchContinuationClaim.Observation
        let value: ActionSearchContinuationObservation
        let authority: Check
        init(stamp: Stamp, tokens: OriginalSearchContinuationClaim.Observation,
             value: ActionSearchContinuationObservation, authority: @escaping Check) {
            self.stamp = stamp; self.tokens = tokens; self.value = value; self.authority = authority
        }
    }
    private final class Completed {
        let receipt: ActionSearchContinuationReceipt
        let stamp: Stamp
        let authority: Check
        weak var list: MaktabahSearchContinuationListView?
        weak var row: MaktabahSearchContinuationRowView?
        init(receipt: ActionSearchContinuationReceipt, stamp: Stamp, authority: @escaping Check,
             list: MaktabahSearchContinuationListView, row: MaktabahSearchContinuationRowView?) {
            self.receipt = receipt; self.stamp = stamp; self.authority = authority; self.list = list; self.row = row
        }
    }
    init(sceneID: String, session: UnifiedSearchSessionController,
         currentSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot,
         originalWindow: @escaping @MainActor () throws -> UIWindow) {
        self.sceneID = sceneID; self.session = session; self.source = session.nativeSearchContinuation
        self.currentSnapshot = currentSnapshot; self.originalWindow = originalWindow
    }

    /// The exact owner retires only this binding. Original source claims and
    /// an in-flight original page keep their own finish/cancel/effect records.
    func retire() {
        retired = true; retained = nil; completed = nil
    }

    func observe(invocation: ActionPortInvocation, retainAuthority: () throws -> Check) throws -> ActionSearchContinuationObservation {
        try live(invocation)
        let authority = try retainedInputAuthority(outer: retainAuthority()); try authority()
        let stamp = try readStamp()
        guard stamp.snapshot == invocation.snapshot else { throw ActionPortError.staleState }
        if let retained, retained.stamp == stamp {
            do { try retained.authority(); return retained.value }
            catch {
                // A new qualified observation may replace an expired outer
                // scene lease. The old opaque tokens are retired, never rearmed.
                source.claims.invalidate(); self.retained = nil
            }
        }
        completed = nil
        let tokens = try source.claims.observe(source: Data(UUID().uuidString.utf8), hitIdentities: stamp.all,
                                              hasNextPage: session.nativeContinuationHasMore && stamp.page.lastCommitted?.cursorAfter != nil)
        let qualified = zip(tokens.hits, session.results).map { token, hit in
            ActionLoadedSearchHit(token: token.id, stableID: hit.stableID, locator: hit.backendLocator?.persistenceKey,
                                  versionTitle: hit.versionTitle, language: hit.resultLanguage, identity: token.identity!)
        }
        let value = ActionSearchContinuationObservation(source: actionSource(stamp, observationID: tokens.id),
                                                        loadedHits: qualified, nextPageToken: tokens.next?.id)
        try live(invocation); try authority()
        guard try readStamp() == stamp else { throw ActionPortError.staleState }
        retained = .init(stamp: stamp, tokens: tokens, value: value, authority: authority)
        return value
    }

    func perform(_ command: ActionSearchContinuationCommand, validateAuthority: @escaping Check) async -> ActionSearchContinuationOutcome {
        var effects: [ActionSearchContinuationEffect] = []
        var claimed: OriginalSearchContinuationClaim.Claim?
        var ownAttempt: OriginalSearchPageLedger.Attempt?
        var terminalCapture: OriginalSearchPageLedger.TerminalCapture?
        defer {
            if let claimed { source.finish(claimed, hadEffect: !effects.isEmpty) }
        }
        do {
            try live(command.invocation); try validateAuthority()
            guard let retained, retained.value.source == command.source else { throw ActionPortError.staleState }
            try retained.authority()
            guard try readStamp() == retained.stamp else { throw ActionPortError.staleState }
            let token: UUID, kind: OriginalSearchContinuationClaim.Kind
            switch command.operation {
            case .revealLoadedHit(let id): token = id; kind = .loadedHit
            case .nextOriginalPage(let id): token = id; kind = .nextPage
            }
            let claim = try source.claims.claim(tokenID: token, kind: kind,
                                               observationID: retained.tokens.id, source: retained.tokens.source)
            claimed = claim; completed = nil; source.holdAutomaticPaging(claim)
            try validateAuthority(); try retained.authority(); try live(command.invocation)

            switch command.operation {
            case .revealLoadedHit:
                guard let identity = claim.token.identity,
                      let hit = retained.value.loadedHits.first(where: { $0.token == token }),
                      retained.stamp.filtered.filter({ $0 == identity }).count == 1 else {
                    throw BindingRefusal.reason(.filteredHit)
                }
                let list = try source.currentList(scene: sceneID)
                guard list.id == retained.stamp.listID, list.identities == retained.stamp.filtered,
                      let apply = list.apply else { throw ActionPortError.staleState }
                var group = ""
                try source.select(claim) {
                    try validateAuthority(); try retained.authority(); try live(command.invocation)
                    group = try apply(identity)
                }
                effects.append(.hitSelectionApplied(hit))
                guard let appliedPresentation = source.presentationRevision else { throw ActionPortError.staleState }
                while true {
                    try checkRetainedBoundary(retained, claim: claim, invocation: command.invocation, authority: validateAuthority)
                    guard source.presentationRevision == appliedPresentation,
                          source.resultRevision == retained.stamp.resultRevision,
                          session.nativeContinuationPageSnapshot == retained.stamp.page,
                          session.paginationRevision == retained.stamp.pagination else { throw ActionPortError.staleState }
                    if let row = try? source.currentRow(identity: identity, group: group, scene: sceneID),
                       list.readSelection?(identity) == true {
                        let stamp = try readStamp()
                        guard stamp.all == retained.stamp.all, stamp.filtered == retained.stamp.filtered,
                              stamp.listID == retained.stamp.listID else { throw ActionPortError.staleState }
                        let visible = ActionSearchVisibleReceipt(witnessID: UUID(), listID: list.id, rowID: row.id,
                                                                layoutRevision: row.layoutRevision, identity: identity)
                        let receipt = ActionSearchContinuationReceipt(requestID: command.invocation.requestId,
                            before: command.source, after: command.source, operation: command.operation,
                            effects: effects, visible: visible)
                        completed = .init(receipt: receipt, stamp: stamp, authority: retained.authority, list: list, row: row)
                        try validateCompletion(command, receipt: receipt); try validateAuthority()
                        return .acknowledged(receipt)
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }

            case .nextOriginalPage:
                guard retained.tokens.next?.id == token, session.nativeContinuationHasMore,
                      let prior = retained.stamp.page.lastCommitted, let cursor = prior.cursorAfter,
                      retained.stamp.pagination < Int.max, prior.pageRevision < UInt64.max,
                      let originalLedger = session.nativeContinuationPageLedger,
                      originalLedger.ownerID == retained.stamp.page.ownerID else {
                    throw BindingRefusal.reason(.exhausted)
                }
                try source.dispatch(claim) {
                    try live(command.invocation); try validateAuthority(); try retained.authority()
                    session.loadNextPage()
                }
                // Retain the actual attempted source before any later refusal.
                // A replaced current model cannot erase this original effect.
                let dispatched = originalLedger.snapshot
                let actualAttempt: OriginalSearchPageLedger.Attempt?
                if let active = dispatched.active { actualAttempt = active }
                else {
                    switch dispatched.lastTerminal {
                    case .accepted(let page): actualAttempt = page.attempt
                    case .failed(let attempt), .cancelled(let attempt): actualAttempt = attempt
                    case nil: actualAttempt = nil
                    }
                }
                guard let beforeRevision = retained.stamp.page.revision, let afterRevision = dispatched.revision,
                      afterRevision > beforeRevision,
                      let attempt = actualAttempt, attempt.id != prior.attempt.id,
                      attempt.ownerID == retained.stamp.page.ownerID,
                      attempt.generation == retained.stamp.page.generation else { throw ActionPortError.staleState }
                ownAttempt = attempt
                terminalCapture = originalLedger.captureTerminal(for: attempt)
                effects.append(.pageRequested(attemptID: attempt.id))
                guard terminalCapture != nil, !attempt.replacing,
                      attempt.request.offset == cursor, attempt.cursorBefore == cursor,
                      attempt.request.configuration == prior.attempt.request.configuration,
                      session.paginationRevision == retained.stamp.pagination + 1 else {
                    throw ActionPortError.staleState
                }
                var accepted: OriginalSearchPageLedger.Commit?
                while true {
                    // Read source commit BEFORE the authority/cancellation check:
                    // if a real commit raced cancellation, retain that effect.
                    if accepted == nil, case .accepted(let page) = terminalCapture?.terminal,
                       page.attempt == attempt {
                        accepted = page; effects.append(.pageCommitted(pageReceipt(page)))
                    }
                    try checkRetainedBoundary(retained, claim: claim, invocation: command.invocation, authority: validateAuthority)
                    guard source.presentationRevision == retained.stamp.presentationRevision,
                          session.paginationRevision == retained.stamp.pagination + 1,
                          let current = session.nativeContinuationPageSnapshot,
                          current.ownerID == attempt.ownerID, current.generation == attempt.generation,
                          current.revision != nil else { throw ActionPortError.staleState }
                    if case .failed(let failed) = current.lastTerminal, failed == attempt { throw BindingRefusal.reason(.providerFailed) }
                    if case .cancelled(let cancelled) = current.lastTerminal, cancelled == attempt { throw BindingRefusal.reason(.cancelled) }
                    if let accepted {
                        guard current.active == nil, current.lastCommitted == accepted,
                              accepted.pageRevision == prior.pageRevision + 1,
                              accepted.attempt.request.configuration == prior.attempt.request.configuration else {
                            throw ActionPortError.staleState
                        }
                        if let stamp = try? readStamp(), stamp.page == current,
                           let list = try? source.currentList(scene: sceneID), list.id == retained.stamp.listID,
                           list.pageRevision == accepted.pageRevision, list.identities == stamp.filtered {
                            let visible = ActionSearchVisibleReceipt(witnessID: UUID(), listID: list.id, rowID: nil,
                                                                    layoutRevision: list.layoutRevision, identity: nil)
                            let receipt = ActionSearchContinuationReceipt(requestID: command.invocation.requestId,
                                before: command.source, after: actionSource(stamp, observationID: retained.tokens.id),
                                operation: command.operation, effects: effects, visible: visible)
                            completed = .init(receipt: receipt, stamp: stamp, authority: retained.authority, list: list, row: nil)
                            try validateCompletion(command, receipt: receipt); try validateAuthority()
                            return .acknowledged(receipt)
                        }
                    } else if current.active != attempt { throw ActionPortError.staleState }
                    try await Task.sleep(for: .milliseconds(20))
                }
            }
        } catch {
            if let attempt = ownAttempt {
                // Never cancel a replacement query, another owner's attempt, or
                // a completed page. Preserve an actual racing commit first.
                if case .accepted(let page) = terminalCapture?.terminal, page.attempt == attempt,
                   !effects.contains(where: { if case .pageCommitted = $0 { return true }; return false }) {
                    effects.append(.pageCommitted(pageReceipt(page)))
                }
                session.cancelNativeContinuationPageIfOwned(attempt)
            }
            let reason: ActionSearchContinuationRefusal
            if error is CancellationError { reason = .cancelled }
            else if case BindingRefusal.reason(let value) = error { reason = value }
            else if error as? OriginalSearchContinuationClaim.Refusal == .duplicate { reason = .duplicateToken }
            else if error as? OriginalSearchContinuationClaim.Refusal == .ambiguous { reason = .ambiguousHit }
            else { reason = .staleSource }
            return .refused(.init(requestID: command.invocation.requestId, reason: reason, effects: effects,
                                  source: command.source, operation: command.operation))
        }
    }

    func validateCompletion(_ command: ActionSearchContinuationCommand, receipt: ActionSearchContinuationReceipt) throws {
        try live(command.invocation)
        guard let completed, completed.receipt == receipt, receipt.requestID == command.invocation.requestId,
              receipt.before == command.source, receipt.operation == command.operation else { throw ActionPortError.staleState }
        try completed.authority()
        guard try readStamp() == completed.stamp,
              let list = completed.list, list === (try source.currentList(scene: sceneID)),
              list.id == receipt.visible.listID else { throw ActionPortError.staleState }
        if let rowID = receipt.visible.rowID {
            guard let row = completed.row, row.id == rowID, row.layoutRevision == receipt.visible.layoutRevision,
                  row.source === source, row.identity == receipt.visible.identity, row.hasCurrentLayout, row.expanded,
                  MaktabahNativeSearchContinuationSource.visible(row, scene: sceneID),
                  receipt.visible.identity.map({ list.readSelection?($0) == true }) == true else { throw ActionPortError.staleState }
        } else {
            guard list.layoutRevision == receipt.visible.layoutRevision, list.hasCurrentLayout else { throw ActionPortError.staleState }
        }
    }

    private enum BindingRefusal: Error { case reason(ActionSearchContinuationRefusal) }
    private func retainedInputAuthority(outer: @escaping Check) throws -> Check {
        let model = session.searchViewModel
        // Original Observation supplies a one-shot invalidation, including
        // value restoration. Read only INPUTS; an owned page may publish results
        // and loading normally without being mistaken for a foreign query.
        let inputs = MaktabahNativeComponentSourceObservation { [session] in
            _ = session.searchViewModel; _ = session.query; _ = session.scope
            _ = session.requestConfiguration; _ = session.selectedBookIds; _ = session.resultKitabFilter
            _ = session.showsBookFilterSheet; _ = session.showsSearchDataSheet; _ = session.showsAdvancedOptions
            _ = model?.selectedBookIds; _ = model?.filterText; _ = model?.query; _ = model?.searchMode
            _ = model?.nearDistance; _ = model?.sortKey; _ = model?.sortAscending; _ = model?.resultKitabFilter
            _ = model?.backendSearchOptions; _ = model?.backendSearchGeneration
        }
        let zayitInputs = NativeComponentSourceObservation(read: {})
        let queryChange = session.zayitSession.model.$query.dropFirst().sink { _ in zayitInputs.invalidate() }
        let modeChange = session.zayitSession.model.$matchMode.dropFirst().sink { _ in zayitInputs.invalidate() }
        return { [weak self, weak model] in
            _ = queryChange; _ = modeChange
            try outer(); try inputs.validate(); try zayitInputs.validate()
            guard let self, session.searchViewModel === model else { throw ActionPortError.staleState }
        }
    }
    private func live(_ invocation: ActionPortInvocation) throws {
        guard !retired else { throw ActionPortError.staleState }
        _ = try originalWindow()
        try Task.checkCancellation()
        guard DispatchTime.now().uptimeNanoseconds < invocation.deadlineUptimeNanoseconds else {
            throw BindingRefusal.reason(.deadlineExceeded)
        }
        guard try currentSnapshot() == invocation.snapshot else { throw ActionPortError.staleState }
    }
    private func checkRetainedBoundary(_ retained: Retained, claim: OriginalSearchContinuationClaim.Claim,
                                       invocation: ActionPortInvocation, authority: Check) throws {
        try live(invocation); try authority(); try retained.authority(); try source.claims.validate(claim)
        guard source.session === session, source.inputRevision == retained.stamp.inputRevision,
              session.nativeContinuationGeneration == retained.stamp.unifiedGeneration,
              session.submissionRevision == retained.stamp.submission,
              session.cancellationRevision == retained.stamp.cancellation,
              try configurationBytes() == retained.stamp.configuration,
              let list = try? source.currentList(scene: sceneID, requiresCurrentLayout: false), list.id == retained.stamp.listID,
              list.window.map(ObjectIdentifier.init) == retained.stamp.windowID,
              list.window === (try originalWindow()) else { throw ActionPortError.staleState }
    }
    private func configurationBytes() throws -> Data {
        guard let submitted = session.submittedConfiguration,
              submitted.map({ Data($0.utf8) }) == session.requestConfiguration.map({ Data($0.utf8) }) else {
            throw ActionPortError.staleState
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(submitted)
    }
    private func readStamp(metadataOnly: Bool = false) throws -> Stamp {
        guard source.session === session, session.nativeContinuationAcceptsUpdates,
              session.hasSubmitted, !session.wasCancelled, !session.resultsAreDirty,
              !session.isSearching, !session.isLoadingMore, !session.nativeContinuationIsBusy,
              !session.showsBookFilterSheet, !session.showsSearchDataSheet, !session.showsAdvancedOptions,
              let input = source.inputRevision, let result = source.resultRevision,
              let presentation = source.presentationRevision,
              let page = session.nativeContinuationPageSnapshot, page.revision != nil,
              page.pageRevision != nil, page.active == nil, page.lastCommitted != nil else { throw ActionPortError.unavailable }
        let all = try MaktabahSearchContinuationIdentity.identities(session.results)
        let original = try MaktabahSearchContinuationIdentity.identities(session.nativeContinuationOriginalResults)
        guard all == original else { throw ActionPortError.staleState }
        let filtered = try MaktabahSearchContinuationIdentity.identities(session.filteredResults)
        let list = try (metadataOnly ? source.metadataList(scene: sceneID) : source.currentList(scene: sceneID))
        guard list.identities == filtered, list.pageRevision == page.pageRevision, let window = list.window,
              window === (try originalWindow()) else {
            throw ActionPortError.unavailable
        }
        return Stamp(snapshot: try currentSnapshot(), inputRevision: input, resultRevision: result,
                     presentationRevision: presentation, unifiedGeneration: session.nativeContinuationGeneration,
                     submission: session.submissionRevision, cancellation: session.cancellationRevision,
                     pagination: session.paginationRevision, configuration: try configurationBytes(), page: page,
                     all: all, filtered: filtered, listID: list.id, windowID: ObjectIdentifier(window))
    }
    private func actionSource(_ stamp: Stamp, observationID: UUID) -> ActionSearchContinuationSource {
        .init(observationID: observationID, sceneID: sceneID, snapshot: stamp.snapshot,
              sessionID: source.sessionID, modelID: stamp.page.ownerID, generation: stamp.page.generation,
              sourceRevision: stamp.inputRevision, submissionRevision: stamp.submission,
              cancellationRevision: stamp.cancellation, paginationRevision: stamp.pagination,
              pageRevision: stamp.page.pageRevision!, configuration: stamp.configuration)
    }
    private func pageReceipt(_ page: OriginalSearchPageLedger.Commit) -> ActionSearchOriginalPageReceipt {
        .init(attemptID: page.attempt.id, modelID: page.attempt.ownerID, generation: page.attempt.generation,
              pageRevision: page.pageRevision, request: page.attempt.request.bytes,
              requestOffset: page.attempt.request.offset, requestLimit: page.attempt.request.limit,
              rawRowCount: page.rawCount, mappedRowCount: page.mappedCount,
              consumedBefore: page.attempt.consumedBefore, consumedAfter: page.consumedAfter,
              cursorBefore: page.attempt.cursorBefore, rawNextOffset: page.rawNextOffset,
              normalizedNextOffset: page.cursorAfter, hasMore: page.hasMore, sourceEvidence: page.sourceEvidence)
    }
}
#endif
