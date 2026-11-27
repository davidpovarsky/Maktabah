import Foundation
import Observation
import OtzariaActionCore

/// A portable scenario describes only public navigation and coaching text.
/// The mounted app issues the scene lifetime, authority, and deadlines.
public struct UIGuideDefinition: Sendable {
    public struct Step: Codable, Sendable, Equatable {
        public let destination: PublicNavigationSpecV2
        public let english: String
        public let hebrew: String

        public init(destination: PublicNavigationSpecV2, english: String, hebrew: String) {
            self.destination = destination
            self.english = english
            self.hebrew = hebrew
        }

        public func coachingText(language: String) -> String {
            switch language {
            case "he", "iw": hebrew
            default: english
            }
        }
    }

    public let steps: [Step]
    private struct Scenario: Decodable {
        let version: Int
        let steps: [Step]
    }

    public init(steps: [Step]) throws {
        let destinations: Set<String> = [
            "native.library", "native.history", "native.search", "native.reader", "native.reader.toc",
            "native.reader.inspector", "native.settings",
            "native.sefariaEmbedded.library", "native.sefariaEmbedded.topics",
            "native.sefariaEmbedded.learningSchedules", "native.sefariaEmbedded.dedication"
        ]
        guard (1...12).contains(steps.count), steps.allSatisfy({ step in
            let route = step.destination
            return route.version == 2 && destinations.contains(route.destination.rawValue)
                && [step.english, step.hebrew].allSatisfy { (1...1024).contains($0.utf8.count) && !$0.utf8.contains(0) }
        }) else { throw UIRouteError(.notSupported, "guide_definition_not_supported") }
        self.steps = steps
    }

    public init(json data: Data) throws {
        guard (1...24_576).contains(data.count) else { throw UIRouteError(.failed, "invalid_guide_size") }
        let decoded = try JSONDecoder().decode(Scenario.self, from: data)
        guard decoded.version == 1 else { throw UIRouteError(.notSupported, "unsupported_guide_version") }
        try self.init(steps: decoded.steps)
    }
}

/// A mounted scene owns one coordinator and provides its existing navigation
/// entry and its independently observed projection. Loss of that scene ends
/// the run. No retained route is replayed on a newly mounted scene.
@MainActor @Observable
public final class UIGuideRun {
    public enum Mode: Sendable, Equatable { case automatic, manual }
    public enum Phase: Sendable, Equatable {
        case ready, navigating, awaitingUser, coaching, exploring, blocked(ActionStatus), completed, stopped
    }

    public private(set) var phase: Phase = .ready
    public private(set) var stepIndex = 0
    public var step: UIGuideDefinition.Step { definition.steps[stepIndex] }
    public var stepCount: Int { definition.steps.count }
    public var isLastStep: Bool { stepIndex + 1 == stepCount }

    @ObservationIgnored private var definition: UIGuideDefinition
    @ObservationIgnored private let sceneID: UIStableID
    @ObservationIgnored private let clock: any ActionClock
    @ObservationIgnored private let observe: @MainActor () -> UISceneSnapshot?
    @ObservationIgnored private let verifyVisible: (@MainActor (UISceneReceipt) -> Bool)?
    @ObservationIgnored private let open: @MainActor (PublicNavigationSpecV2, UISceneSnapshot, UInt64) async throws -> UISceneAcknowledgement
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var attempt: UUID?
    @ObservationIgnored private var draining = false
    @ObservationIgnored private var mode: Mode = .automatic
    @ObservationIgnored private var deadline: UInt64 = 0
    @ObservationIgnored private var stepDeadline: UInt64 = 0
    @ObservationIgnored private var operations = 0
    @ObservationIgnored private var expectedScene: UISceneSnapshot?
    @ObservationIgnored private var coachingReceipt: UISceneReceipt?

    public init(definition: UIGuideDefinition, sceneID: UIStableID, clock: any ActionClock = SystemActionClock(),
                observe: @escaping @MainActor () -> UISceneSnapshot?,
                verifyVisible: (@MainActor (UISceneReceipt) -> Bool)? = nil,
                open: @escaping @MainActor (PublicNavigationSpecV2, UISceneSnapshot, UInt64) async throws -> UISceneAcknowledgement) {
        self.definition = definition
        self.sceneID = sceneID
        self.clock = clock
        self.observe = observe
        self.verifyVisible = verifyVisible
        self.open = open
    }

    /// A scenario may change only after the previous native child has joined.
    /// An active or draining run retains its exact original step/receipt binding.
    public func start(_ mode: Mode, definition: UIGuideDefinition? = nil) {
        guard [.ready, .completed, .stopped].contains(phase), task == nil else { return }
        if let definition { self.definition = definition }
        self.mode = mode
        stepIndex = 0
        operations = 0
        deadline = clock.now() + 180_000_000_000
        beginStep()
    }

    public func next() {
        revalidateCoaching()
        guard phase == .coaching else { return }
        guard stepIndex + 1 < definition.steps.count else {
            coachingReceipt = nil
            phase = .completed
            return
        }
        stepIndex += 1
        beginStep()
    }

    public func back() {
        revalidateCoaching()
        guard stepIndex > 0, task == nil, [.coaching, .awaitingUser].contains(phase) else { return }
        stepIndex -= 1
        beginStep()
    }

    public func explore() async {
        guard phase != .ready, phase != .stopped, phase != .completed else { return }
        await interrupt(.exploring)
    }

    public func resume() { resume(mode) }

    public func replay() { start(mode) }

    public func resume(_ mode: Mode) {
        guard phase == .exploring, task == nil else { return }
        self.mode = mode
        beginStep()
    }

    public func stop() async {
        await interrupt(.stopped)
    }

    /// The practice button invokes the same real native action as automatic
    /// navigation. A tap becomes coaching only after the actual receipt.
    public func performManualNavigation() {
        guard phase == .awaitingUser, clock.now() < stepDeadline else {
            if phase == .awaitingUser { phase = .blocked(.cancelled) }
            return
        }
        guard let scene = observe(), let expectedScene,
              scene.sceneID == sceneID, scene.backendSnapshot == expectedScene.backendSnapshot else {
            phase = .blocked(.staleState)
            return
        }
        dispatch(step.destination, from: scene)
    }

    public func revalidateCoaching() {
        guard phase == .coaching, let coachingReceipt else { return }
        guard let scene = observe(), confirmsPresentation(coachingReceipt, in: scene) else {
            self.coachingReceipt = nil
            phase = .blocked(.staleState)
            return
        }
    }

    /// Called by a mounted app action that can supply the original receipt.
    /// Merely pressing Next or rendering a coach mark cannot advance practice.
    public func observeManualNavigation(_ receipt: UISceneReceipt) {
        guard phase == .awaitingUser else { return }
        if clock.now() >= stepDeadline { phase = .blocked(.cancelled); return }
        if let expectedScene, receipt.basedOnSceneRevision >= expectedScene.revision,
           receipt.sceneID == sceneID, matchesIntent(receipt.route) {
            finish(.acknowledged(receipt))
        }
    }

    private func beginStep() {
        coachingReceipt = nil
        guard clock.now() < deadline, operations < 24 else { phase = .blocked(.cancelled); return }
        guard let scene = observe(), scene.sceneID == sceneID else { phase = .blocked(.requiresForeground); return }
        if let backend = step.destination.backend, backend != scene.backendSnapshot.backend {
            phase = .blocked(.requiresBackendSwitch)
            return
        }
        operations += 1
        expectedScene = scene
        stepDeadline = min(deadline, clock.now() + 15_000_000_000)
        if mode == .manual { phase = .awaitingUser; return }
        dispatch(step.destination, from: scene)
    }

    private func dispatch(_ intent: PublicNavigationSpecV2, from scene: UISceneSnapshot) {
        let key = UUID(), end = stepDeadline
        attempt = key
        phase = .navigating
        task = Task { [weak self, open] in
            let outcome: Result<UISceneAcknowledgement, UIRouteError>
            do { outcome = .success(try await open(intent, scene, end)) }
            catch let error as UIRouteError { outcome = .failure(error) }
            catch is CancellationError { outcome = .success(.cancelled) }
            catch { outcome = .failure(.init(.failed, "guide_navigation_failed")) }
            guard let self, self.attempt == key else { return }
            self.task = nil
            self.attempt = nil
            switch outcome {
            case .success(let reply): self.finish(reply)
            case .failure(let error): self.phase = .blocked(error.status)
            }
        }
    }

    private func interrupt(_ target: Phase) async {
        attempt = nil
        expectedScene = nil
        coachingReceipt = nil
        phase = target
        guard let running = task, !draining else { return }
        draining = true
        running.cancel()
        await running.value
        task = nil
        draining = false
    }

    private func finish(_ result: UISceneAcknowledgement) {
        guard clock.now() < stepDeadline else { phase = .blocked(.cancelled); return }
        switch result {
        case .acknowledged(let receipt):
            guard let initial = expectedScene, let actual = observe(),
                  receipt.sceneID == sceneID, receipt.backendSnapshot == initial.backendSnapshot,
                  receipt.basedOnSceneRevision >= initial.revision,
                  receipt.appliedSceneRevision > receipt.basedOnSceneRevision,
                  matchesIntent(receipt.route), confirmsPresentation(receipt, in: actual) else {
                phase = .blocked(.staleState)
                return
            }
            coachingReceipt = receipt
            phase = .coaching
        case .queued: phase = .blocked(.uiQueued)
        case .requiresForeground: phase = .blocked(.requiresForeground)
        case .requiresBackendSwitch: phase = .blocked(.requiresBackendSwitch)
        case .notSupported: phase = .blocked(.notSupported)
        case .unavailable: phase = .blocked(.unavailable)
        case .staleState: phase = .blocked(.staleState)
        case .needsDisambiguation: phase = .blocked(.needsDisambiguation)
        case .requiresConfirmation: phase = .blocked(.requiresConfirmation)
        case .cancelled: phase = .blocked(.cancelled)
        case .failed: phase = .blocked(.failed)
        }
    }

    private func confirmsPresentation(_ receipt: UISceneReceipt, in scene: UISceneSnapshot) -> Bool {
        guard scene.sceneID == sceneID, scene.backendSnapshot == receipt.backendSnapshot,
              scene.revision >= receipt.appliedSceneRevision else { return false }
        // A native host can recheck its current presentation after the request-scoped witness is retired.
        if let verifyVisible { return verifyVisible(receipt) }
        return scene.revision == receipt.appliedSceneRevision && scene.visibleRoute == receipt.route
    }

    private func matchesIntent(_ route: RouteSpec) -> Bool {
        let intent = step.destination
        guard route.destination == intent.destination, route.presentation.kind == intent.presentation.nativeKind,
              route.content == intent.content, intent.backend == nil || route.backend == intent.backend else { return false }
        guard let component = intent.component else { return true }
        return route.focus?.anchor == component && route.state.visibleComponents.contains(component)
    }
}
