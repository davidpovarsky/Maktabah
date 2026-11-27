import Foundation
import Observation
import Synchronization

// Explicit executable source boundary. These values stand for the existing
// SwiftUI/UIKit/app feature owners. They are NOT an app, React runtime, native
// witness, Core authority or acceptance receipt. The generator inserts exact
// production root/latch/setter/readiness/wait bodies beside these inputs.
struct UIDestinationID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String
    init?(rawValue: String) { self.rawValue = rawValue }
}
struct UIStableID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String
    init?(rawValue: String) { self.rawValue = rawValue }
}
struct UIRouteError: Error {
    enum Status { case unavailable, staleState, failed, notSupported }
    let status: Status
    let reason: String
    init(_ status: Status, _ reason: String) { self.status = status; self.reason = reason }
}
enum AppMode { case viewer, search, history, annotations }
enum iOSTab: Equatable {
    case viewer, search, history, annotations
    var canonical: Self { self }
    var appMode: AppMode {
        switch self { case .viewer: .viewer; case .search: .search; case .history: .history; case .annotations: .annotations }
    }
}
@MainActor final class BooksData {}
@MainActor @Observable final class ReaderViewModel { var isPopoverPresented = false }
@MainActor @Observable final class DonationManager {
    static let shared = DonationManager()
    var showDonationSheet = false
}
@MainActor @Observable final class BoundaryOverview { var blocksRouting = false }
@MainActor final class ReaderSidebarPageCoordinator { let overview = BoundaryOverview() }
struct Transaction { var marker = 0 }
@MainActor struct Binding<Value> {
    private let read: () -> Value
    private let write: (Value, Transaction) -> Void
    private var suppliedTransaction = Transaction()
    init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) { read = get; write = set }
    var wrappedValue: Value {
        get { read() }
        nonmutating set { write(newValue, suppliedTransaction) }
    }
    func transaction(_ transaction: Transaction) -> Self {
        var copy = self; copy.suppliedTransaction = transaction; return copy
    }
}
@MainActor final class OriginalRootState {
    var tab = iOSTab.viewer
    var settings = false
    var lastTransaction = Transaction()
}
@MainActor @Observable final class BoundaryNoteEditorOwner {
    var current: String?
    var presentationActive = false
}

struct NativeSurfaceState: Equatable, Sendable {
    let destination: UIDestinationID
    let stamp: Int
}
struct BoundaryInvocation: Sendable { let requestId: UUID }
struct BoundaryRoute: Sendable { let destination: UIDestinationID }
struct BoundaryValidatedRoute: Sendable { let route: BoundaryRoute }
struct UISceneCommand: Sendable {
    let invocation: BoundaryInvocation
    let route: BoundaryValidatedRoute
    init(request: UUID, destination: UIDestinationID) {
        invocation = .init(requestId: request); route = .init(route: .init(destination: destination))
    }
}
enum NativeSurfaceWitness {
    struct Evidence: Sendable {
        let sceneID: UIStableID
        let submissionID: UUID?
        let surface: NativeSurfaceState
        let isVisible: Bool
    }
}

/// A controlled asynchronous input, not a timer or a fabricated native result.
/// The test cannot complete it without an explicit resume or cancellation.
@MainActor final class BoundarySuspension {
    private(set) var started = false
    private(set) var cancelled = false
    private var continuation: CheckedContinuation<Void, any Error>?
    private var startup: CheckedContinuation<Void, Never>?
    func untilStarted() async {
        if started { return }
        await withCheckedContinuation { startup = $0 }
    }
    func wait() async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { value in
                continuation = value; started = true
                let prior = startup; startup = nil; prior?.resume()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }
    func succeed() { let value = continuation; continuation = nil; value?.resume() }
    func fail() {
        let value = continuation; continuation = nil
        value?.resume(throwing: UIRouteError(.staleState, "controlled-original-source-invalidation"))
    }
    func cancel() {
        cancelled = true
        let value = continuation; continuation = nil; value?.resume(throwing: CancellationError())
    }
}
@MainActor final class MaktabahNativeSefariaSurfaceBinding {
    static let destination = UIDestinationID(rawValue: "native.sefariaEmbedded")!
    struct PresentationFacets {
        var requested = false, mounted = false, visible = false, transitioning = false, ready = false
    }
    var isAvailable = true
    var presentationFacets = PresentationFacets()
    var continuingRequest: UUID?
    let originalWait = BoundarySuspension()
    private(set) var awaitCalls = 0
    func isContinuingAppliedRequest(requestID: UUID) -> Bool { continuingRequest == requestID }
    func awaitOriginalSurface(requestID: UUID) async throws {
        awaitCalls += 1
        try await originalWait.wait()
    }
}
@MainActor final class BoundaryWindowSource {
    var ready = true
    func isPresentationReady(in sceneID: UIStableID) -> Bool { ready }
}
@MainActor final class BoundaryPresentation {
    struct Observed { let surface: NativeSurfaceState }
    let markerWait = BoundarySuspension()
    private(set) var waitCalls = 0
    private(set) var reportCalls = 0
    private var observed: NativeSurfaceState?
    func report(_ state: NativeSurfaceState) {
        reportCalls += 1; observed = state; markerWait.succeed()
    }
    func wait(for command: UISceneCommand) async throws -> Observed {
        waitCalls += 1
        if observed == nil { try await markerWait.wait() }
        guard let observed else { throw UIRouteError(.unavailable, "controlled-marker-absent") }
        return .init(surface: observed)
    }
}
