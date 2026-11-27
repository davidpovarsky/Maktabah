#if os(iOS)
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Scene-owned, bounded metadata for the ORIGINAL submitted Search. Public
/// references select an entry here; they never authorize the original effect.
/// Only the unchanged Core preparation/source claim may do that later.
@MainActor
final class MaktabahNativeSearchContinuationCatalog {
    typealias Service = NativeSearchContinuationIntentService
    typealias Metadata = MaktabahNativeSearchContinuationBinding.Metadata
    typealias Capture = @MainActor () throws -> Captured

    struct Captured {
        let metadata: Metadata
        let windowTitle: String
    }

    /// A metadata selection is consumed BEFORE any callback/await. Its phase
    /// can advance once to a fresh original observation; there is no rearm,
    /// replacement target lookup, grant or executable closure in the wire ID.
    @MainActor final class Selection {
        fileprivate enum Phase { case reserved, joining, joined, finished }
        let request: Service.OpenRequest
        fileprivate let publication: Publication
        fileprivate weak var owner: MaktabahNativeSearchContinuationCatalog?
        fileprivate var phase = Phase.reserved
        fileprivate var valid = true
        fileprivate init(request: Service.OpenRequest, publication: Publication,
                         owner: MaktabahNativeSearchContinuationCatalog) {
            self.request = request; self.publication = publication; self.owner = owner
        }
        func validateBefore() throws {
            guard phase == .reserved, let owner else { throw ActionPortError.staleState }
            try owner.validate(self, before: true)
        }
        /// Used by the SAME original authority callback before/after every
        /// await/effect. Once joined, an owned page may change its results but
        /// the foreign inputs, scene, original window and owner stay fixed.
        func validate() throws {
            guard let owner else { throw ActionPortError.staleState }
            switch phase {
            case .reserved: try owner.validate(self, before: true)
            case .joined: try owner.validate(self, before: false)
            case .joining, .finished: throw ActionPortError.staleState
            }
        }
        func choose(_ observation: ActionSearchContinuationObservation) throws -> ActionSearchContinuationOperation {
            guard phase == .reserved, let owner else { throw ActionPortError.staleState }
            return try owner.choose(observation, for: self)
        }
        func finish() { owner?.finish(self) }
    }

    @MainActor fileprivate final class Publication {
        let metadata: Metadata
        let ordered: [Service.Target]
        let entries: [UUID: Service.Target]
        var consumed: Set<UUID> = []
        init(metadata: Metadata, ordered: [Service.Target]) {
            self.metadata = metadata; self.ordered = ordered
            entries = Dictionary(uniqueKeysWithValues: ordered.map { ($0.reference.metadataID, $0) })
        }
    }

    let sceneID: UIStableID
    private let capture: Capture
    private let now: @MainActor () -> UInt64
    private var publication: Publication?
    private var pending: Selection?
    private var capturing = false
    private var revision: UInt64? = 0
    private var mounted = true

    init(sceneID: UIStableID, capture: @escaping Capture,
         now: @escaping @MainActor () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        self.sceneID = sceneID; self.capture = capture; self.now = now
    }

    func targets(_ query: Service.Query) throws -> [Service.Target] {
        try Task.checkCancellation()
        guard mounted, pending == nil, !capturing else { return [] }
        let source = try currentPublication()
        guard query.snapshot == source.metadata.source.snapshot,
              Data(source.metadata.source.sceneID.utf8) == Data(sceneID.rawValue.utf8) else { return [] }
        var values: [Service.Target] = []
        for target in source.ordered {
            guard !source.consumed.contains(target.reference.metadataID),
                  query.kind == nil || query.kind == target.reference.kind,
                  query.references == nil || query.references!.contains(target.reference),
                  query.matching == nil || query.matching!.isEmpty
                    || target.title.localizedCaseInsensitiveContains(query.matching!) else { continue }
            values.append(target)
            if values.count == query.maximumResults { break }
        }
        try source.metadata.validateBefore()
        guard mounted, publication === source, pending == nil, !capturing else { throw ActionPortError.staleState }
        try Task.checkCancellation()
        return values
    }

    /// Execution cannot refresh an old reference into a new source. The exact
    /// publication must already exist from genuine discovery/link resolution.
    func retain(_ request: Service.OpenRequest) throws -> Selection {
        try Task.checkCancellation()
        guard mounted, !capturing, pending == nil, let source = publication,
              request.target.source.snapshot == request.invocation.snapshot,
              request.target.source.sceneID == sceneID.rawValue,
              source.entries[request.target.reference.metadataID] == request.target,
              !source.consumed.contains(request.target.reference.metadataID),
              now() < request.invocation.deadlineUptimeNanoseconds else {
            throw ActionPortError.staleState
        }
        if case .deepLink(let receivingScene) = request.origin, receivingScene != sceneID {
            throw ActionPortError.staleState
        }
        let selection = Selection(request: request, publication: source, owner: self)
        source.consumed.insert(request.target.reference.metadataID)
        pending = selection
        do { try validate(selection, before: true); return selection }
        catch { finish(selection); throw error }
    }

    /// Nonrecursive identity facet for the scene's already-retained operation.
    /// It permits no work; the original owner and Selection.validate still
    /// independently validate every actual boundary.
    func ownsSelection(requestID: UUID) -> Bool {
        guard mounted, let pending, pending.valid, pending.owner === self,
              pending.phase != .finished,
              pending.request.invocation.requestId == requestID,
              publication === pending.publication,
              now() < pending.request.invocation.deadlineUptimeNanoseconds else { return false }
        return true
    }

    /// Original State/window/source invalidation is synchronous and final for
    /// this publication. A later valid source gets fresh metadata IDs only.
    func retire() {
        if let current = revision { revision = current < .max ? current + 1 : nil }
        pending?.valid = false; pending?.phase = .finished; pending = nil
        publication?.metadata.retire(); publication = nil
    }
    func unmount() { mounted = false; retire() }

    private func currentPublication() throws -> Publication {
        guard mounted, pending == nil, !capturing, let revision else { throw ActionPortError.staleState }
        if let current = publication {
            do {
                try current.metadata.validateBefore()
                guard mounted, self.revision == revision, publication === current, pending == nil else {
                    throw ActionPortError.staleState
                }
                return current
            } catch {
                // Retire only the publication actually inspected. A callback
                // cannot replace it and have that replacement adopted here.
                guard mounted, self.revision == revision, publication === current, pending == nil else { throw error }
                current.metadata.retire(); publication = nil
            }
        }
        capturing = true
        defer { capturing = false }
        let captured = try capture()
        do {
            try captured.metadata.validateBefore()
            guard mounted, self.revision == revision, publication == nil, pending == nil,
                  Data(captured.metadata.source.sceneID.utf8) == Data(sceneID.rawValue.utf8),
                  !captured.windowTitle.isEmpty, captured.windowTitle.utf8.count <= 512,
                  captured.metadata.hits.count <= 10_000 else { throw ActionPortError.staleState }
            let hits = captured.metadata.hits
            guard Set(hits.map { $0.hit.identity }).count == hits.count,
                  Set(hits.map { $0.hit.stableID }).count == hits.count else { throw ActionPortError.invalidResponse }
            var records = hits.map { hit in
                Service.Target(reference: .init(backend: captured.metadata.source.snapshot.backend,
                    kind: .result, metadataID: UUID()), title: hit.title + " — " + captured.windowTitle,
                    source: captured.metadata.source, hit: hit.hit)
            }
            if captured.metadata.hasNextPage {
                records.append(.init(reference: .init(backend: captured.metadata.source.snapshot.backend,
                    kind: .nextPage, metadataID: UUID()),
                    title: NSLocalizedString("Next search page", comment: "Original Search continuation target") + " — " + captured.windowTitle,
                    source: captured.metadata.source, hit: nil))
            }
            guard records.count <= 10_001, Set(records.map(\.id)).count == records.count,
                  records.allSatisfy({ !$0.title.isEmpty && $0.title.utf8.count <= 2_048 }) else {
                throw ActionPortError.unavailable
            }
            let next = Publication(metadata: captured.metadata, ordered: records)
            try captured.metadata.validateBefore()
            guard mounted, self.revision == revision, publication == nil, pending == nil else {
                throw ActionPortError.staleState
            }
            publication = next
            return next
        } catch { captured.metadata.retire(); throw error }
    }

    private func validate(_ selection: Selection, before: Bool) throws {
        func membership() throws {
            guard mounted, selection.valid, selection.owner === self,
                  pending === selection, publication === selection.publication,
                  selection.publication.entries[selection.request.target.reference.metadataID] == selection.request.target,
                  selection.publication.consumed.contains(selection.request.target.reference.metadataID),
                  now() < selection.request.invocation.deadlineUptimeNanoseconds else { throw ActionPortError.staleState }
            try Task.checkCancellation()
        }
        try membership()
        if before { try selection.publication.metadata.validateBefore() }
        else { try selection.publication.metadata.validateForeign() }
        try membership()
    }

    private func choose(_ observation: ActionSearchContinuationObservation,
                        for selection: Selection) throws -> ActionSearchContinuationOperation {
        // Consume the phase before invoking a validator; a synchronous callback
        // cannot recursively choose another hit or reuse this selection.
        guard selection.phase == .reserved else { throw ActionPortError.staleState }
        selection.phase = .joining
        do {
            try validate(selection, before: true)
            guard selection.request.target.source.matches(observation.source) else { throw ActionPortError.staleState }
            let operation: ActionSearchContinuationOperation
            switch selection.request.target.reference.kind {
            case .result:
                guard let expected = selection.request.target.hit else { throw ActionPortError.invalidResponse }
                let matches = observation.loadedHits.filter { expected.matches($0) }
                guard matches.count == 1, let actual = matches.first else { throw ActionPortError.staleState }
                operation = .revealLoadedHit(token: actual.token)
            case .nextPage:
                guard selection.request.target.hit == nil, let actual = observation.nextPageToken,
                      selection.publication.metadata.hasNextPage else { throw ActionPortError.staleState }
                operation = .nextOriginalPage(token: actual)
            }
            try validate(selection, before: true)
            guard selection.phase == .joining else { throw ActionPortError.staleState }
            selection.phase = .joined
            try validate(selection, before: false)
            return operation
        } catch { finish(selection); throw error }
    }

    private func finish(_ selection: Selection) {
        selection.valid = false; selection.phase = .finished
        if pending === selection { pending = nil }
    }

    /// Read the actual original parent/workspace/window without retaining a
    /// Scene or manager through metadata. Callers supply weak scene accessors;
    /// the ordinary execution owner still requires foreground+UIKit readiness.
    static func captureOriginal(sceneID: UIStableID,
        readBindings: @escaping @MainActor () throws -> MaktabahNativeSceneBindings,
        workspaceSource: MaktabahNativeWorkspaceProjectionSource,
        window: MaktabahNativeWindowObservation,
        windowTitle: String,
        readForeign: @MainActor () -> Void,
        validateScene: @escaping @MainActor () throws -> Void,
        currentSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot) throws -> Captured {
        try validateScene()
        let bindings = try readBindings(), manager = bindings.manager
        let session = manager.unifiedSearchSession, model = manager.searchViewModel
        let parent = try MaktabahNativeSearchEntryParentTransition(bindings: bindings)
        guard parent.tab == .search, parent.mode == .search,
              workspaceSource.isAuthoritative, let workspace = try workspaceSource.read(),
              workspace.attached, !workspace.isSwitching, workspace.sceneID == sceneID.rawValue,
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.owner == ObjectIdentifier(manager), mapping.scene == sceneID.rawValue,
              mapping.coverage == .liveNativeSetters,
              mapping.source.event.phase == .available, mapping.source.event.epoch == mapping.epoch,
              session.searchViewModel === model, bindings.isPresentationReady,
              !bindings.showSettings.wrappedValue, manager.alertMessage == nil else { throw ActionPortError.unavailable }
        _ = try window.validate()
        let reader = manager.activeTabId.flatMap { id in manager.openTabs.first { $0.id == id }?.viewModel }
        let foreign = MaktabahNativeComponentSourceObservation {
            _ = try? workspaceSource.read(); _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.mappingOwnershipSource.event
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedContentId
            _ = manager.unifiedSearchSession; _ = manager.searchViewModel
            _ = manager.currentMode; _ = manager.selectedBook; _ = manager.selectedBookPresentationMode
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList; _ = manager.alertMessage
            _ = DonationManager.shared.showDonationSheet
            _ = reader?.currentBook; _ = reader?.currentDestination; _ = reader?.currentContentId
            _ = reader?.isPopoverPresented; _ = reader?.readerInspectorVisible
            readForeign()
        }
        let validateParent: MaktabahNativeSearchContinuationBinding.Check = {
            [weak manager, weak session, weak model, weak workspace] in
            try foreign.validate(); _ = try window.validate(); try validateScene()
            let current = try readBindings()
            guard let manager, let session, let model, let workspace,
                  workspaceSource.isAuthoritative, try workspaceSource.read() === workspace,
                  workspace.attached, !workspace.isSwitching, workspace.sceneID == sceneID.rawValue,
                  let live = workspace.mappingOwnershipObservation(),
                  live.source === mapping.source, live.owner == mapping.owner, live.scene == mapping.scene,
                  live.epoch == mapping.epoch, live.projection == mapping.projection,
                  live.coverage == .liveNativeSetters,
                  live.source.event.phase == .available, live.source.event.epoch == live.epoch,
                  current.manager === manager, manager.unifiedSearchSession === session,
                  manager.searchViewModel === model, session.searchViewModel === model,
                  current.selectedTab.wrappedValue == .search, manager.currentMode == .search,
                  !current.showSettings.wrappedValue, current.isPresentationReady,
                  manager.alertMessage == nil else { throw ActionPortError.staleState }
            try parent.validateBefore(current)
            try foreign.validate(); _ = try window.validate(); try validateScene()
        }
        let metadata = try MaktabahNativeSearchContinuationBinding.captureMetadata(sceneID: sceneID.rawValue,
            session: session, currentSnapshot: currentSnapshot, originalWindow: { try window.validate() },
            validateParent: validateParent)
        return Captured(metadata: metadata, windowTitle: windowTitle)
    }
}
#endif
