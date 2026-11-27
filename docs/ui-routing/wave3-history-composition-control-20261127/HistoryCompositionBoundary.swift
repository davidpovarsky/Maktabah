import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit app/window/generic-open boundary. The actual Composition method,
// actual History catalog/source, original identities/resolver/Observation and
// actual portable service/deadline are compiled separately without edits.
// These classes do not implement UIKit, native/Core authorization or an app.
@MainActor final class MethodManager {}
@MainActor final class MethodWindow {
    var mounted = true
    var foreground = true
    var revision: UInt64 = 0
    var captures = 0
    var validations = 0
    var completions: [UISceneReceipt] = []
    var failCompletion = false
    var log: (String) -> Void = { _ in }
    func captureHistoryReaderWindow() throws -> @MainActor () throws -> Void {
        captures += 1; log("window-captured")
        let captured = revision
        return { [self] in
            validations += 1; log("window-revalidated")
            guard revision == captured else { throw UIRouteError(.staleState, "fixture_window_changed") }
        }
    }
    func validateCompletedJourneySurface(_ receipt: UISceneReceipt) throws {
        completions.append(receipt); log("native-completion-checked")
        if failCompletion { throw UIRouteError(.staleState, "fixture_actual_witness_failed") }
    }
}
@MainActor final class MethodBackend {
    unowned let fixture: SourceFixture
    init(_ fixture: SourceFixture) { self.fixture = fixture }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { fixture.snapshot }
}
@MainActor final class HistoryCompositionHarness {
    typealias Service = NativeHistoryReaderIntentService
    struct SceneEntry {
        let session: MethodWindow
        weak var manager: MethodManager?
        let managerID: ObjectIdentifier
    }
    enum Mode { case success, refuseAfterReport, throwAfterReport, noReportRefusal, coreOnlyRefusal, duplicateReport, throwBeforeReport }
    let fixture = SourceFixture()
    let manager = MethodManager()
    let session = MethodWindow()
    lazy var backend = MethodBackend(fixture)
    var historyReaderCatalog: MaktabahNativeHistoryReaderCatalog?
    var scenes: [UIStableID: SceneEntry] = [:]
    var mode = Mode.success
    var events: [String] = []
    var activationCount = 0
    var openCount = 0
    var effectCount = 0
    var genericInput: PublicNavigationSpecV2?
    var genericDeadline: UInt64?
    var generatedCore: ActionResult?
    var generatedReceipt: UISceneReceipt?
    var input: Service.OpenRequest?
    var retainedAtOpen: MaktabahNativeHistoryReaderSource?
    var methodReturned: Service.Execution?
    var methodError: (any Error)?
    var beforeMethod: (() -> Void)?
    var duringActivation: (() -> Void)?
    var afterReport: (() -> Void)?
    var activatedScene: UIStableID?
    var entityCopies = 1
    init() {
        historyReaderCatalog = fixture.catalog
        scenes[fixture.window.sceneID] = .init(session: session, manager: manager,
            managerID: ObjectIdentifier(manager))
        session.log = { [weak self] in self?.events.append($0) }
    }
    func intentRootEntities() throws -> [NativeIntentService.Destination] {
        events.append("window-discovery")
        return Array(repeating: fixture.window, count: entityCopies)
    }
    func waitForMount(managerID: ObjectIdentifier) async throws -> UIStableID {
        activationCount += 1; events.append("activation-start")
        try insist(managerID == ObjectIdentifier(manager), "original manager requested")
        try insist(session.captures == 1, "window captured before first activation")
        await Task.yield()
        duringActivation?()
        events.append("activation-return")
        return activatedScene ?? fixture.window.sceneID
    }
    func invoke(newTab: Bool = true) async -> Result<Service.Execution, any Error> {
        let service = Service(snapshot: { self.fixture.snapshot },
            catalog: { try self.fixture.catalog.records($0) },
            windows: { [self.fixture.window] }, navigate: { request in
                self.input = request; self.beforeMethod?()
                do {
                    let value = try await self.openHistoryReading(request)
                    self.methodReturned = value
                    return value
                } catch { self.methodError = error; throw error }
            })
        do {
            let record = try fixture.records()[0]
            return .success(try await service.open(identifier: record.id,
                windowIdentifier: fixture.window.id, newTab: newTab))
        } catch { return .failure(error) }
    }

    // This is the explicitly substituted existing generic-open boundary.
    // Receipts/Core results below are test values, not accepted native proof.
    private func open(public intent: PublicNavigationSpecV2, sceneID: UIStableID,
                      managerID: ObjectIdentifier, expectedSnapshot: ActionBackendSnapshot?,
                      origin: ActionOrigin, until end: UInt64, requestID: UUID,
                      historySource: MaktabahNativeHistoryReaderSource?,
                      didObserveReader: (@MainActor (ActionResult?, UISceneReceipt?) -> Void)?) async throws
        -> UISceneAcknowledgement {
        openCount += 1; events.append("generic-open")
        genericInput = intent; genericDeadline = end; retainedAtOpen = historySource
        let request = try requireInput()
        try insist(requestID == request.invocation.requestId && end == request.invocation.deadlineUptimeNanoseconds,
                   "same request and exact absolute deadline")
        try insist(sceneID == fixture.window.sceneID && managerID == ObjectIdentifier(manager) &&
            expectedSnapshot == request.invocation.snapshot && origin == .appIntent,
            "same captured original window/backend/origin")
        guard let historySource, let content = intent.content else { throw SourceControlFailure(message: "source/content missing") }
        if mode == .throwBeforeReport { throw UIRouteError(.unavailable, "fixture_generic_failed_before_report") }
        if mode == .noReportRefusal { return .requiresForeground }
        try historySource.performOriginalApply { effectCount += 1 }
        let route = RouteSpec(requestId: requestID, destination: .init(rawValue: "native.reader")!,
            backend: request.invocation.snapshot.backend, content: content,
            presentation: .init(kind: request.newTab ? .newTab : .currentTab),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: 8),
            expectedBackendSnapshot: request.invocation.snapshot)
        let native = ActionUIReceipt(requestId: requestID, snapshot: request.invocation.snapshot,
            sceneID: sceneID.rawValue, destination: content)
        let receipt = UISceneReceipt(requestId: requestID, route: route,
            backendSnapshot: request.invocation.snapshot, sceneID: sceneID,
            basedOnSceneRevision: 8, appliedSceneRevision: 9, coreReceipt: native)
        let core = ActionResult(request: .init(requestId: requestID, action: "reader.open"),
            status: .completed, backend: request.invocation.snapshot.backend,
            backendGeneration: request.invocation.snapshot.generation, effects: ["explicit-generic-open-fixture"])
        generatedCore = core; generatedReceipt = receipt
        didObserveReader?(core, mode == .coreOnlyRefusal ? nil : receipt)
        if mode == .duplicateReport { didObserveReader?(core, receipt) }
        afterReport?()
        if mode == .throwAfterReport { throw UIRouteError(.staleState, "fixture_generic_failed_after_report") }
        if mode == .refuseAfterReport || mode == .coreOnlyRefusal {
            return .staleState(.init(code: "fixture_generic_refused", message: "Explicit boundary refusal"))
        }
        return .acknowledged(receipt)
    }
    func requireInput() throws -> Service.OpenRequest {
        guard let input else { throw SourceControlFailure(message: "request absent") }
        return input
    }

    // ACTUAL_METHOD_INSERTION: generator inserts exact original helper/method bytes here.
}
