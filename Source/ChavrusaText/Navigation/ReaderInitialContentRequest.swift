import Foundation

/// Read-only lifetime metadata for the ORIGINAL Reader content owner. A loaded
/// Reader with no pending initial work still has a stable observation. This is
/// neither a request nor authority to start or finish a load.
final class ReaderInitialContentSourceObservation: @unchecked Sendable {
    let ownerID: UUID
    let revision: UInt64
    let pendingRequestID: UUID?
    private weak var coordinator: ReaderContentLoadCoordinator?

    init(coordinator: ReaderContentLoadCoordinator, ownerID: UUID,
         revision: UInt64, pendingRequestID: UUID?) {
        self.coordinator = coordinator; self.ownerID = ownerID
        self.revision = revision; self.pendingRequestID = pendingRequestID
    }

    var isCurrent: Bool { coordinator?.isInitialContentSourceCurrent(self) == true }
}

/// Identity of one original invocation, including the interval BEFORE its
/// section token exists. The coordinator creates it before original callbacks
/// or suspension and issues at most one real ReaderContentRequestToken to it.
/// No Reader, view, executable callback, or serialized permission is retained.
final class ReaderInitialContentRequest: @unchecked Sendable {
    enum Input: Equatable, Sendable {
        case initial(Int?)
        case locator(TextLocator)
        case destination(LibraryReaderDestination)
    }
    struct Source: Equatable, Sendable {
        let reader: ObjectIdentifier
        let book: ObjectIdentifier
        let bookID: Int
        let bookLocator: TextLocator?
        let input: Input
        let backend: BackendID
        let backendGeneration: UInt64
        let originalDestination: LibraryReaderDestination?
    }
    enum Phase: Equatable, Sendable { case reserved, resolving, handingOff, issued, completed }
    struct State: Equatable, Sendable {
        let phase: Phase
        let destination: LibraryReaderDestination?
        let token: ReaderContentRequestToken?
    }

    let id: UUID
    let source: Source
    let sourceRevision: UInt64
    /// Nil for ordinary UI work. Native callers pass the existing invocation's
    /// absolute deadline; this type never creates or renews a time budget.
    let deadlineUptimeNanoseconds: UInt64?
    private weak var coordinator: ReaderContentLoadCoordinator?

    init(coordinator: ReaderContentLoadCoordinator, source: Source, revision: UInt64,
         deadlineUptimeNanoseconds: UInt64?) {
        id = UUID(); self.coordinator = coordinator; self.source = source
        sourceRevision = revision; self.deadlineUptimeNanoseconds = deadlineUptimeNanoseconds
    }
    var state: State? { coordinator?.initialContentState(for: self) }
    var isCurrent: Bool { state != nil }
    var issuedToken: ReaderContentRequestToken? { state?.token }
    func invalidate() { coordinator?.invalidateInitialContentRequest(self) }
}
