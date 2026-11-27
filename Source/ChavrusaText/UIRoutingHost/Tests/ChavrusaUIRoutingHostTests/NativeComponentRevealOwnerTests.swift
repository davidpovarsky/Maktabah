import Foundation
import XCTest
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Contract tests for the actual source/lifecycle owner. Evidence fixtures below
/// are test doubles, not UIKit, VoiceOver, or end-to-end acceptance evidence.
@MainActor final class NativeComponentRevealOwnerTests: XCTestCase, @unchecked Sendable {
    private let destination = UIDestinationID(rawValue: "native.settings")!
    private let anchor = UIDestinationID(rawValue: "native.settings.appearance")!
    private let scene = UIStableID(rawValue: "scene.A")!

    private final class Source {
        var epoch = 1
        var available = true
        var live = true
        var captures = 0
        var blocked = false
        var evidence: NativeComponentEvidence?
        var reveals: [UIDestinationID] = []
    }
    private func owner(_ source: Source) -> NativeComponentRevealOwner {
        NativeComponentRevealOwner(destination: destination, presentation: .sheet,
            descriptors: [.init(anchor: anchor, title: "Appearance")],
            available: { [anchor] in $0 == anchor && source.available },
            captureSource: { _ in
                let epoch = source.epoch
                source.captures += 1
                return {
                    guard source.epoch == epoch else { throw UIRouteError(.staleState, "source_changed") }
                }
            })
    }
    private func begin(_ owner: NativeComponentRevealOwner, source: Source, id: UUID) throws {
        try owner.retainSource(requestID: id, anchor: anchor)
        try owner.begin(requestID: id, anchor: anchor) {
            guard source.live else { throw UIRouteError(.staleState, "original_admission_revoked") }
        }
    }

    func testColdMountRequiresRenderedExactVisibleTargetInOriginalScene() async throws {
        let source = Source(), owner = owner(source), id = UUID(), view = UUID()
        try begin(owner, source: source, id: id)
        try owner.apply(requestID: id)
        owner.render(viewID: view) { source.reveals.append($0) }
        XCTAssertTrue(source.reveals.isEmpty, "No original view has mounted")
        owner.attach(viewID: view, blocked: { false })
        owner.render(viewID: view) { source.reveals.append($0) }
        XCTAssertEqual(source.reveals, [anchor])
        XCTAssertNil(owner.actualFocus(in: scene), "A scroll request is not visible evidence")

        let token = UUID()
        source.evidence = NativeComponentEvidence(anchor: anchor, sceneID: scene, isVisible: false)
        owner.observe(anchor: anchor, token: token) { source.evidence }
        XCTAssertNil(owner.actualFocus(in: scene), "Clipped/offscreen controls cannot acknowledge")
        source.evidence = .init(anchor: anchor, sceneID: UIStableID(rawValue: "scene.B")!, isVisible: true)
        XCTAssertNil(owner.actualFocus(in: scene), "A different window cannot satisfy the request")
        source.evidence = .init(anchor: anchor, sceneID: scene, isVisible: true)
        XCTAssertEqual(owner.actualFocus(in: scene), .init(kind: .component, anchor: anchor))
        owner.finish(requestID: id, completed: true)
        owner.releaseSource(requestID: id)
        XCTAssertEqual(owner.actualFocus(in: scene)?.anchor, anchor)
        source.epoch += 1
        XCTAssertNil(owner.actualFocus(in: scene), "Completed evidence remains bound to its original source")
    }

    func testSourceIsCapturedOnceBeforeAwaitAndCannotDriftAtBegin() async throws {
        let source = Source(), owner = owner(source), id = UUID()
        try owner.retainSource(requestID: id, anchor: anchor)
        XCTAssertEqual(source.captures, 1)
        source.epoch += 1
        XCTAssertThrowsError(try owner.validateSource(requestID: id, anchor: anchor))
        XCTAssertThrowsError(try owner.begin(requestID: id, anchor: anchor, validate: {}))
        XCTAssertEqual(source.captures, 1, "Never refresh the captured source to rescue a stale request")
        XCTAssertTrue(source.reveals.isEmpty)
    }

    func testReplacementViewCannotInheritCommittedRequest() async throws {
        let source = Source(), owner = owner(source), id = UUID(), original = UUID(), replacement = UUID()
        var revoked = 0
        owner.install(changed: {}, invalidated: { revoked += 1 })
        owner.attach(viewID: original, blocked: { false })
        try begin(owner, source: source, id: id)
        try owner.apply(requestID: id)
        owner.attach(viewID: replacement, blocked: { false })
        owner.render(viewID: replacement) { source.reveals.append($0) }
        owner.render(viewID: original) { source.reveals.append($0) }
        XCTAssertTrue(source.reveals.isEmpty)
        XCTAssertEqual(revoked, 1)
    }

    func testDetachAndReattachSameViewIdentityCannotReplay() async throws {
        let source = Source(), owner = owner(source), id = UUID(), view = UUID()
        owner.attach(viewID: view, blocked: { false })
        try begin(owner, source: source, id: id)
        try owner.apply(requestID: id)
        owner.detach(viewID: view)
        owner.attach(viewID: view, blocked: { false })
        owner.render(viewID: view) { source.reveals.append($0) }
        XCTAssertTrue(source.reveals.isEmpty)
        XCTAssertNil(owner.actualFocus(in: scene))
    }

    func testRevokedOriginalAdmissionCannotRenderAfterParentMount() async throws {
        let source = Source(), owner = owner(source), id = UUID(), view = UUID()
        try begin(owner, source: source, id: id)
        try owner.apply(requestID: id)
        source.live = false
        owner.attach(viewID: view, blocked: { false })
        owner.render(viewID: view) { source.reveals.append($0) }
        XCTAssertTrue(source.reveals.isEmpty)
        XCTAssertNil(owner.actualFocus(in: scene))
    }

    func testSourceABAAndConditionalAvailabilityAreRecheckedAtRender() async throws {
        for revokeSource in [false, true] {
            let source = Source(), owner = owner(source), id = UUID(), view = UUID()
            try begin(owner, source: source, id: id)
            try owner.apply(requestID: id)
            if revokeSource { source.epoch += 2 } else { source.available = false }
            owner.attach(viewID: view, blocked: { false })
            owner.render(viewID: view) { source.reveals.append($0) }
            XCTAssertTrue(source.reveals.isEmpty)
            XCTAssertNil(owner.actualFocus(in: scene))
        }
    }

    func testUnknownAnchorAndMissingSourceAreRejectedBeforePublication() async throws {
        let source = Source(), owner = owner(source), id = UUID()
        let unknown = UIDestinationID(rawValue: "native.settings.executeMutation")!
        XCTAssertThrowsError(try owner.retainSource(requestID: id, anchor: unknown))
        XCTAssertThrowsError(try owner.begin(requestID: id, anchor: anchor, validate: {}))
        XCTAssertThrowsError(try owner.apply(requestID: id))
        XCTAssertEqual(owner.renderRevision, 0)
        XCTAssertEqual(source.captures, 0)
    }

    func testOneApplyCannotBecomeDeferredReplay() async throws {
        let source = Source(), owner = owner(source), id = UUID(), view = UUID()
        owner.attach(viewID: view, blocked: { false })
        try begin(owner, source: source, id: id)
        XCTAssertThrowsError(try owner.apply(requestID: UUID()))
        try owner.apply(requestID: id)
        XCTAssertThrowsError(try owner.apply(requestID: id))
        owner.render(viewID: view) { source.reveals.append($0) }
        owner.render(viewID: view) { source.reveals.append($0) }
        XCTAssertEqual(source.reveals, [anchor])
        owner.finish(requestID: id, completed: false)
        XCTAssertNil(owner.actualFocus(in: scene))
    }

    func testStaleGeometryDismantleCannotEraseNewOriginalWitness() async throws {
        let source = Source(), owner = owner(source), id = UUID(), view = UUID()
        let oldToken = UUID(), newToken = UUID()
        owner.attach(viewID: view, blocked: { false })
        try begin(owner, source: source, id: id)
        try owner.apply(requestID: id)
        owner.render(viewID: view) { source.reveals.append($0) }
        owner.observe(anchor: anchor, token: oldToken) { nil }
        owner.observe(anchor: anchor, token: newToken) { [anchor, scene] in
            .init(anchor: anchor, sceneID: scene, isVisible: true)
        }
        owner.remove(anchor: anchor, token: oldToken)
        XCTAssertEqual(owner.actualFocus(in: scene)?.anchor, anchor)
        owner.remove(anchor: anchor, token: newToken)
        XCTAssertNil(owner.actualFocus(in: scene))
    }

    func testOriginalOverlayBlocksRevealAndVisibleFacet() async throws {
        let source = Source(), owner = owner(source), id = UUID(), view = UUID()
        owner.attach(viewID: view, blocked: { source.blocked })
        try begin(owner, source: source, id: id)
        try owner.apply(requestID: id)
        source.blocked = true
        owner.render(viewID: view) { source.reveals.append($0) }
        XCTAssertTrue(source.reveals.isEmpty)
        XCTAssertFalse(owner.isAvailable(anchor))
        XCTAssertNil(owner.actualFocus(in: scene))
    }
}
