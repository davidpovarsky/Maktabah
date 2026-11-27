import Foundation
import Observation
import XCTest
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Actual Observation publications exercise retained-source cancellation.
/// These controls are not UIKit or end-to-end component acceptance evidence.
@MainActor final class NativeComponentSourceObservationTests: XCTestCase, @unchecked Sendable {
    @Observable fileprivate final class Model {
        var value = "A"
        var blocked = false
        var unrelated = 0
        var captures = 0
    }
    @Observable fileprivate final class Manager {
        var model = Model()
    }

    func testUnchangedOriginalSourceRemainsValid() async throws {
        let model = Model()
        let observation = NativeComponentSourceObservation { _ = model.value; _ = model.blocked }
        try observation.validate()
        await Task.yield()
        try observation.validate()
    }

    func testActualValueABAInvalidatesBeforeSuspensionResumes() async throws {
        let model = Model()
        let observation = NativeComponentSourceObservation { _ = model.value }
        model.value = "B"
        model.value = "A"
        XCTAssertEqual(model.value, "A", "Snapshot equality alone misses the intervening edit")
        XCTAssertThrowsError(try observation.validate()) { error in
            XCTAssertEqual((error as? UIRouteError)?.status, .staleState)
        }
        await Task.yield()
        XCTAssertThrowsError(try observation.validate())
    }

    func testOriginalModelReplacementAndRestoreCannotRevalidate() async throws {
        let manager = Manager(), original = Model()
        manager.model = original
        let observation = NativeComponentSourceObservation { _ = manager.model; _ = manager.model.value }
        manager.model = Model()
        manager.model = original
        XCTAssertTrue(manager.model === original)
        XCTAssertThrowsError(try observation.validate())
    }

    func testBlockingPresentationOpenCloseIsNotMissed() async throws {
        let model = Model()
        let observation = NativeComponentSourceObservation { _ = model.blocked }
        model.blocked = true
        model.blocked = false
        XCTAssertFalse(model.blocked)
        XCTAssertThrowsError(try observation.validate())
    }

    func testOnlyDeclaredSourceFieldsAreObserved() async throws {
        let model = Model()
        let observation = NativeComponentSourceObservation { _ = model.value }
        model.unrelated += 1
        try observation.validate()
        model.value = "B"
        XCTAssertThrowsError(try observation.validate())
    }

    func testOriginalPublisherCanInvalidateAcrossExecutors() async throws {
        let model = Model()
        let observation = NativeComponentSourceObservation { _ = model.value }
        await Task.detached { observation.invalidate() }.value
        XCTAssertThrowsError(try observation.validate())
        model.value = "B"; model.value = "A"
        XCTAssertThrowsError(try observation.validate())
    }

    func testInvalidationIsOneShotAcrossFurtherValues() async throws {
        let model = Model()
        let observation = NativeComponentSourceObservation { _ = model.value }
        for value in ["B", "A", "C", "A"] {
            model.value = value
            XCTAssertThrowsError(try observation.validate())
        }
    }

    func testRetainedOwnerRejectsABAWhileCoreIsSuspendedWithoutRecapture() async throws {
        let model = Model()
        let destination = UIDestinationID(rawValue: "native.library")!
        let anchor = UIDestinationID(rawValue: "native.library.contents")!
        let owner = NativeComponentRevealOwner(destination: destination, presentation: .currentTab,
            descriptors: [.init(anchor: anchor, title: "Library contents")],
            available: { _ in true }, captureSource: { _ in
                model.captures += 1
                let observation = NativeComponentSourceObservation { _ = model.value }
                return { try observation.validate() }
            })
        let request = UUID()
        try owner.retainSource(requestID: request, anchor: anchor)
        model.value = "B"; model.value = "A"
        await Task.yield()
        XCTAssertThrowsError(try owner.validateSource(requestID: request, anchor: anchor))
        XCTAssertThrowsError(try owner.begin(requestID: request, anchor: anchor, validate: {}))
        XCTAssertEqual(model.captures, 1)
        XCTAssertEqual(owner.renderRevision, 0)
    }

    func testCompletedFocusRemainsBoundToOriginalObservation() async throws {
        let model = Model()
        let destination = UIDestinationID(rawValue: "native.library")!
        let anchor = UIDestinationID(rawValue: "native.library.contents")!
        let scene = UIStableID(rawValue: "scene.original")!
        let owner = NativeComponentRevealOwner(destination: destination, presentation: .currentTab,
            descriptors: [.init(anchor: anchor, title: "Library contents")],
            available: { _ in true }, captureSource: { _ in
                let observation = NativeComponentSourceObservation { _ = model.value }
                return { try observation.validate() }
            })
        let request = UUID(), view = UUID()
        owner.attach(viewID: view, blocked: { false })
        try owner.retainSource(requestID: request, anchor: anchor)
        try owner.begin(requestID: request, anchor: anchor, validate: {})
        try owner.apply(requestID: request)
        owner.render(viewID: view) { _ in }
        owner.observe(anchor: anchor, token: UUID()) { .init(anchor: anchor, sceneID: scene, isVisible: true) }
        XCTAssertEqual(owner.actualFocus(in: scene)?.anchor, anchor)
        owner.finish(requestID: request, completed: true)
        owner.releaseSource(requestID: request)
        model.value = "B"; model.value = "A"
        XCTAssertNil(owner.actualFocus(in: scene), "A completed witness cannot float onto replacement state")
    }
}
