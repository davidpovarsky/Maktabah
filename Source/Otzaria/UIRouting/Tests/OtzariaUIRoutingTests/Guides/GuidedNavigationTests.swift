import Foundation
import OtzariaActionCore
import XCTest
@testable import OtzariaUIRouting

@MainActor
final class GuidedNavigationTests: XCTestCase {
    func testAutomaticRequiresAVisibleMatchingNativeReceiptAndNavigatesBackFresh() async throws {
        let host = Host()
        let run = try host.run()
        run.start(.automatic)
        await settle(run)
        XCTAssertEqual(run.phase, .coaching)
        XCTAssertEqual(run.stepIndex, 0)
        run.next()
        await settle(run)
        XCTAssertEqual(run.phase, .coaching)
        XCTAssertEqual(run.stepIndex, 1)
        run.back()
        await settle(run)
        XCTAssertEqual(run.phase, .coaching)
        XCTAssertEqual(host.calls, [Host.library, Host.history, Host.library])
        XCTAssertEqual(Set(host.requests).count, 3)
    }

    func testManualIgnoresCoachingControlsAndUnrelatedReceiptThenResumesFresh() async throws {
        let host = Host()
        let run = try host.run()
        run.start(.manual)
        run.next()
        XCTAssertEqual(run.phase, .awaitingUser)
        XCTAssertEqual(run.stepIndex, 0)
        run.observeManualNavigation(host.acknowledge(.init(destination: Host.history)))
        XCTAssertEqual(run.phase, .awaitingUser)
        run.observeManualNavigation(host.acknowledge(.init(destination: Host.library)))
        XCTAssertEqual(run.phase, .coaching)
        await run.explore()
        XCTAssertEqual(run.phase, .exploring)
        run.resume(.automatic)
        await settle(run)
        XCTAssertEqual(run.phase, .coaching)
        XCTAssertEqual(host.calls, [Host.library])
    }

    func testManualButtonUsesTheRealPortAndAChangedSceneDropsCoaching() async throws {
        let host = Host()
        let run = try host.run()
        run.start(.manual)
        run.performManualNavigation()
        await settle(run)
        XCTAssertEqual(host.calls, [Host.library])
        XCTAssertEqual(run.phase, .coaching)
        _ = host.acknowledge(.init(destination: Host.history))
        run.revalidateCoaching()
        XCTAssertEqual(run.phase, .blocked(.staleState))
    }

    func testReturnedReceiptCannotSubstituteForCurrentSceneObservation() async throws {
        let host = Host()
        host.publishVisibleRoute = false
        let run = try host.run()
        run.start(.automatic)
        await settle(run)
        XCTAssertEqual(run.phase, .blocked(.staleState))
        run.next()
        XCTAssertEqual(run.stepIndex, 0)
    }

    func testRetiredRequestStillNeedsTheOriginalVisiblePresentation() async throws {
        let host = Host()
        host.publishVisibleRoute = false
        host.publishPassivePresentation = true
        let run = try host.run(verifyVisible: { host.passivePresentation == $0.route })
        run.start(.manual)
        run.performManualNavigation()
        await settle(run)
        XCTAssertNil(host.observation.visibleRoute)
        XCTAssertEqual(run.phase, .coaching)

        host.passivePresentation = nil
        run.next()
        XCTAssertEqual(run.phase, .blocked(.staleState))
        XCTAssertEqual(run.stepIndex, 0)
    }

    func testStopJoinsChildAndLateReceiptCannotAdvanceAReplacementRun() async throws {
        let host = Host()
        host.suspend = true
        let run = try host.run()
        run.start(.automatic)
        while host.pending == nil { await Task.yield() }
        let stop = Task { await run.stop() }
        while run.phase != .stopped { await Task.yield() }
        run.start(.manual)
        XCTAssertEqual(run.phase, .stopped)
        try XCTUnwrap(host.pending).resume()
        host.pending = nil
        await stop.value
        XCTAssertEqual(run.phase, .stopped)
        run.start(.manual)
        XCTAssertEqual(run.phase, .awaitingUser)
    }

    func testDefinitionBoundsAndLocalization() throws {
        let library = UIGuideDefinition.Step(destination: .init(destination: Host.library), english: "Library", hebrew: "ספרייה")
        XCTAssertEqual(library.coachingText(language: "he"), "ספרייה")
        XCTAssertEqual(library.coachingText(language: "en"), "Library")
        XCTAssertThrowsError(try UIGuideDefinition(steps: Array(repeating: library, count: 13)))
        XCTAssertThrowsError(try UIGuideDefinition(json: Data(#"{"version":2,"steps":[]}"#.utf8)))
    }

    private func settle(_ run: UIGuideRun) async {
        for _ in 0..<1000 {
            if run.phase != .navigating { return }
            await Task.yield()
        }
        XCTFail("The navigation did not settle")
    }

    @MainActor private final class Host {
        static let library = UIDestinationID(rawValue: "native.library")!
        static let history = UIDestinationID(rawValue: "native.history")!
        let scene = UIStableID(rawValue: "scene.guide")!
        let backend = ActionBackendSnapshot(backend: .otzaria, generation: 5)
        var calls = [UIDestinationID]()
        var requests = [UUID]()
        var publishVisibleRoute = true
        var publishPassivePresentation = false
        var passivePresentation: RouteSpec?
        var suspend = false
        var pending: CheckedContinuation<Void, Never>?
        var observation: UISceneSnapshot

        init() { observation = .init(sceneID: scene, revision: 1, backendSnapshot: backend) }

        func run(verifyVisible: (@MainActor (UISceneReceipt) -> Bool)? = nil) throws -> UIGuideRun {
            let definition = try UIGuideDefinition(steps: [
                .init(destination: .init(destination: Self.library), english: "Library", hebrew: "ספרייה"),
                .init(destination: .init(destination: Self.history), english: "History", hebrew: "היסטוריה")
            ])
            return .init(definition: definition, sceneID: scene, observe: { self.observation },
                         verifyVisible: verifyVisible) { intent, _, _ in
                self.calls.append(intent.destination)
                if self.suspend { await withCheckedContinuation { self.pending = $0 } }
                return .acknowledged(self.acknowledge(intent))
            }
        }

        func acknowledge(_ intent: PublicNavigationSpecV2) -> UISceneReceipt {
            let request = UUID(), revision = observation.revision
            requests.append(request)
            let route = RouteSpec(requestId: request, destination: intent.destination, backend: backend.backend,
                                  presentation: .init(kind: intent.presentation.nativeKind))
            if publishVisibleRoute {
                observation = .init(sceneID: scene, revision: revision + 1, backendSnapshot: backend, visibleRoute: route)
            } else if publishPassivePresentation {
                // The transaction has already ended and the scene revision advanced.
                observation = .init(sceneID: scene, revision: revision + 2, backendSnapshot: backend)
                passivePresentation = route
            }
            return .init(requestId: request, route: route, backendSnapshot: backend, sceneID: scene,
                         basedOnSceneRevision: revision, appliedSceneRevision: revision + 1)
        }
    }
}
