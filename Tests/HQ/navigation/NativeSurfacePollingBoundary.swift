import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit UIKit geometry/lifecycle doubles. This fixture does not render a
// native window. The driver inserts complete production methods below, without
// changing their geometry predicate, observation loop, cancellation or deadline.
@MainActor class UIView {
    var bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    var convertedBounds = CGRect(x: 120, y: 0, width: 100, height: 100)
    var isHidden = false
    var alpha: CGFloat = 1
    weak var superview: UIView?
    weak var attachedWindow: UIWindow?
    var window: UIWindow? { attachedWindow ?? superview?.window }
    func convert(_ value: CGRect, to window: UIWindow) -> CGRect { convertedBounds }
    func isDescendant(of ancestor: UIView) -> Bool {
        var current: UIView? = self
        while let value = current {
            if value === ancestor { return true }
            current = value.superview
        }
        return false
    }
}
@MainActor final class UIWindow: UIView {
    var windowScene: FixtureWindowScene?
    var rootViewController: UIViewController?
}
@MainActor final class UIViewController {
    let view: UIView
    var presentedViewController: UIViewController?
    init(view: UIView) { self.view = view }
}
@MainActor final class FixtureWindowScene {
    enum Activation: Int { case foregroundActive = 0, background = 2 }
    struct Session { var persistentIdentifier: String }
    var activationState = Activation.foregroundActive
    var session: Session
    init(id: String) { session = .init(persistentIdentifier: id) }
}

enum NativeSurfaceWitness {
    // ACTUAL_WITNESS_EVIDENCE
}
@MainActor final class FixtureMarker: UIView {
    typealias Evidence = NativeSurfaceWitness.Evidence
    var surface: NativeSurfaceState?
    var submissionID: UUID?
    var hasAppeared = true
    var diagnose: (@MainActor (String) -> Void)?
    private var previousDiagnostic: String?
    // ACTUAL_WITNESS_CURRENT_EVIDENCE
    // ACTUAL_WITNESS_DIAGNOSTIC
    func readActualEvidence() -> NativeSurfaceWitness.Evidence? { currentEvidence() }
}

@MainActor final class OtzariaFileLogger {
    static let shared = OtzariaFileLogger()
    private(set) var messages: [String] = []
    func log(_ value: String) { messages.append(value) }
}
@MainActor final class FixtureReaderProjection {
    var rendered = true
    func hasRenderedReaderEvidence(sceneID: UIStableID) -> Bool { rendered }
}
@MainActor final class FixtureNoteOwner {
    var visible = true
    func validateVisible() throws {
        guard visible else { throw UIRouteError(.unavailable, "fixture_note_not_visible") }
    }
}

// Boundary state is explicit. Complete actual wait/observe/end methods are
// inserted, while public Core/Registry/Host packages are compiled unchanged.
@MainActor final class PollingSceneFixture {
    let sceneID: UIStableID
    let presentation: NativePresentationObserver
    var submissionID: UUID?
    var mounted = true
    var foreground = true
    var isPresentationReady = true
    var command: UISceneCommand?
    var visible: [UIDestinationID: NativeSurfaceWitness.Evidence] = [:]
    var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    let readerProjection = FixtureReaderProjection()
    var project: @MainActor () throws -> FixtureReaderProjection { { self.readerProjection } }
    var noteDraftBinding: FixtureNoteOwner? = FixtureNoteOwner()
    var retainedSearchField: AnyObject?
    var inspectorBinding: AnyObject?
    private(set) var observationRevisions = 0

    init(sceneID: UIStableID) {
        self.sceneID = sceneID
        presentation = NativePresentationObserver(sceneID: sceneID)
    }
    func nativeStateChanged() throws { observationRevisions += 1 }
    func beginFixtureSubmission(_ value: UISceneCommand) throws {
        try presentation.begin(value)
        command = value
        submissionID = value.invocation.requestId
    }
    // ACTUAL_SESSION_OBSERVE_VISIBILITY
    // ACTUAL_SESSION_OBSERVE
    // ACTUAL_SESSION_WAIT
    // ACTUAL_SESSION_END
}

@MainActor final class SurfacePollingScenario {
    let destination: UIDestinationID
    let sceneID = UIStableID(rawValue: "surface-polling.scene")!
    let session: PollingSceneFixture
    let window = UIWindow()
    let rootView = UIView()
    let ancestor = UIView()
    let marker = FixtureMarker()
    let command: UISceneCommand
    let expected: NativeSurfaceState
    private(set) var reads = 0
    private(set) var callbacks = 0
    var diagnostics: [String] = []

    init(_ raw: String, deadlineMilliseconds: UInt64 = 700) throws {
        destination = UIDestinationID(rawValue: raw)!
        session = PollingSceneFixture(sceneID: sceneID)
        let state = UIStateSpec(workspaceID: .init(rawValue: "original.workspace")!,
                                profileID: .init(rawValue: "original.profile")!)
        let route = RouteSpec(destination: destination, backend: .otzaria, state: state)
        let registry = try UIDestinationRegistry(descriptors: [
            .init(id: destination, title: "Boundary surface", implementation: .implemented,
                  supportedBackends: [.otzaria], presentations: [.currentTab]),
        ])
        let snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 7)
        command = try UISceneCommand(route: registry.validate(route),
            invocation: .init(requestId: route.requestId, snapshot: snapshot,
                              deadlineUptimeNanoseconds: SystemActionClock().now() + deadlineMilliseconds * 1_000_000),
            scene: .init(sceneID: sceneID, revision: 10, backendSnapshot: snapshot))
        // Independent observed model fixture; this is not rebuilt by a poll.
        expected = .init(destination: destination, presentation: .init(), content: nil, state: state, focus: nil)
        window.windowScene = .init(id: sceneID.rawValue)
        rootView.attachedWindow = window
        window.rootViewController = .init(view: rootView)
        ancestor.superview = rootView
        marker.superview = ancestor
        marker.surface = expected
        marker.submissionID = command.invocation.requestId
        marker.diagnose = { [weak self] in self?.diagnostics.append($0) }
        session.observeVisibility(for: destination) { [weak self] in
            guard let self else { return nil }
            reads += 1
            return marker.readActualEvidence()
        }
        try session.beginFixtureSubmission(command)
    }

    func layoutCallback() {
        callbacks += 1
        reads += 1
        if let evidence = marker.readActualEvidence() { session.observe(evidence) }
    }
    func makeGeometryVisible() { marker.convertedBounds = CGRect(x: 0, y: 0, width: 100, height: 100) }
    func startWait() -> Task<NativeSurfaceState, any Error> {
        Task { @MainActor in try await session.waitUntilVisible(command) }
    }
    func finishOriginal() { session.endObservation(requestID: command.invocation.requestId) }
}
