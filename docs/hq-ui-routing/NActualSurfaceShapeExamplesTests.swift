import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

final class NActualSurfaceShapeExamplesTests: XCTestCase, @unchecked Sendable {
    func testActualShapedLocalStateExamplesOnAllThreeBackends() throws {
        let workspace = UIStableID(rawValue: "11111111-1111-4111-8111-111111111111")!
        let profile = UIStableID(rawValue: "22222222-2222-4222-8222-222222222222")!
        let tab = UIStableID(rawValue: "33333333-3333-4333-8333-333333333333")!
        var examples: [ActionJSON] = []
        for backend in ActionBackendID.allCases {
            let sceneID = UIStableID(rawValue: "N.fixture.scene." + backend.rawValue)!
            let snapshot = ActionBackendSnapshot(backend: backend, generation: 101, rpcEpoch: backend == .sefariaEmbedded ? 17 : nil)
            var readerPublicBytes: Data?
            for shape in ["history", "settings", "reader-inspector-closed", "reader-inspector-open"] {
                let isReader = shape.hasPrefix("reader"), isSettings = shape == "settings"
                let destination = UIDestinationID(rawValue: isReader ? "native.reader" : "native." + shape)!
                let kind: PresentationSpec.Kind = isSettings ? .sheet : .currentTab
                let publicKind: PublicNavigationSpecV2.Presentation = isSettings ? .sheet : .currentTab
                let actualContent: ActionReaderDestination? = isReader ? .init(sectionLocator: .init(backend: backend,
                    workKey: "fixture:work." + backend.rawValue,
                    position: backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1")), presentationMode: .sameTab) : nil
                let inspector: Bool? = isReader ? shape == "reader-inspector-open" : nil
                // Exact shape of existing MaktabahNativeSceneProjection.surface:
                // root state is workspace/profile; reader also projects actual
                // inspector Boolean and actual currentTab identity. Identity's
                // unrelated sidebar/sheet fields are NOT part of this surface.
                let actual = NativeSurfaceState(destination: destination, presentation: .init(kind: kind, tabID: isReader ? tab : nil),
                    content: actualContent, state: .init(workspaceID: workspace, profileID: profile, inspectorVisible: inspector), focus: nil)
                let descriptor = UIDestinationDescriptor(id: destination, title: "Synthetic shape fixture", implementation: .implemented,
                    supportedBackends: [backend], presentations: isReader ? [.currentTab, .inspector] : [kind],
                    requiredCoreActions: isReader ? ["reader.open"] : [], requiresContent: isReader,
                    publicNavigationV2: .init(rules: [.init(presentation: publicKind)]))
                let registry = try UIDestinationRegistry(descriptors: [descriptor])
                let publicIntent = PublicNavigationSpecV2(destination: destination, backend: backend, content: actualContent, presentation: publicKind)
                let bytes = try UIRouteCodec.encodePublicV2(publicIntent, registry: registry)
                let publicFields = try ActionWireCodec.decodeObject(bytes)
                for key in ["requestId", "scene", "state", "profileID", "workspaceID", "tabID", "context", "inspectorVisible"] { XCTAssertNil(publicFields[key]) }
                if isReader {
                    if let readerPublicBytes { XCTAssertEqual(bytes, readerPublicBytes, "Same public intent must preserve different observed local inspector states") }
                    else { readerPublicBytes = bytes }
                }
                let invocation = ActionPortInvocation(requestId: UUID(), snapshot: snapshot, deadlineUptimeNanoseconds: UInt64.max)
                let route = RouteSpec(requestId: invocation.requestId, destination: destination, backend: backend,
                    content: actualContent, presentation: actual.presentation, state: actual.state,
                    scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: 20), expectedBackendSnapshot: snapshot)
                let command = try UISceneCommand(route: registry.validate(route), invocation: invocation,
                    scene: .init(sceneID: sceneID, revision: 20, backendSnapshot: snapshot))
                let projected = actual.observedRoute(for: command, backend: snapshot)
                XCTAssertEqual(projected, route)
                XCTAssertEqual(projected.state.inspectorVisible, inspector)
                XCTAssertNil(projected.state.sidebarVisible); XCTAssertNil(projected.state.sheet)
                XCTAssertNil(projected.state.privateState); XCTAssertNil(projected.focus)
                examples.append(.object([
                    "exampleID": .string(backend.rawValue + "." + shape),
                    "sourceShape": .string("Existing N projection shape; synthetic identities/references, no UIKit execution"),
                    "publicIntent": .object(publicFields),
                    "expectedIndependentPrivateSurface": try .encoded(projected)
                ]))
            }
        }
        XCTAssertEqual(examples.count, 12)
        let payload: ActionJSON = .object([
            "status": .string("SYNTHETIC_ACTUAL_SHAPED_EXAMPLES_NOT_NATIVE_EVIDENCE"),
            "shapeSourceCommit": .string("13e40d1daa4a53799c94cd8ed5170f1343b9b1e8"),
            "shapeSource": .string("Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift"),
            "notInstalledPublicV2": .bool(true), "examples": .array(examples)
        ])
        let output = try XCTUnwrap(ProcessInfo.processInfo.environment["N_SHAPE_EXAMPLES_OUTPUT"])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(payload).write(to: URL(fileURLWithPath: output), options: .atomic)
        print("Generated 12 exact-shaped independent local-surface examples; no grants, receipts or native success fabricated")
    }
}
