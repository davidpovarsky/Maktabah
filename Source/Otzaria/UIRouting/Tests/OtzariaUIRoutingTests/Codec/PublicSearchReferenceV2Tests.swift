import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

/// Actual codec/registry/Core tests. The existing native-host fixture remains
/// explicitly synthetic; decoding/discovery is not original UI acceptance.
final class PublicSearchReferenceV2Tests: XCTestCase, @unchecked Sendable {
    private let reference = "3c4cd30f-a6d7-4193-94b3-75332255b264"
    private func descriptor(_ kind: UIPublicSearchReferenceKindV2) -> UIDestinationDescriptor {
        .init(id: kind.destination, title: kind.rawValue, implementation: .implemented,
              supportedBackends: ActionBackendID.allCases, presentations: [.currentTab],
              publicNavigationV2: .init(rules: [.init(presentation: .currentTab, allowsRoot: false)],
                                        searchReferenceKind: kind))
    }
    private func registry() throws -> UIDestinationRegistry {
        try .init(descriptors: UIPublicSearchReferenceKindV2.allCases.map(descriptor))
    }
    private func input(_ kind: UIPublicSearchReferenceKindV2 = .result,
                       backend: ActionBackendID = .otzaria) -> PublicNavigationSpecV2 {
        .init(destination: kind.destination, backend: backend, searchReference: reference)
    }
    private func wire(_ fields: ActionObject) throws -> Data { try JSONEncoder().encode(ActionJSON.object(fields)) }

    func testFiniteReferenceRoundTripAllOriginalBackends() throws {
        let registry = try registry()
        for backend in ActionBackendID.allCases {
            for kind in UIPublicSearchReferenceKindV2.allCases {
                let original = input(kind, backend: backend)
                let encoded = try UIRouteCodec.encodePublicV2(original, registry: registry)
                XCTAssertEqual(try UIRouteCodec.decodePublicV2(encoded, registry: registry), original)
                let keys = Set(try ActionWireCodec.decodeObject(encoded).keys)
                XCTAssertEqual(keys, ["version", "destination", "backend", "presentation", "searchReference"])
                XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("query"))
                XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("token"))
            }
        }
    }

    func testReferenceRequiresBackendCanonicalIDAndCurrentTab() throws {
        let registry = try registry(), kind = UIPublicSearchReferenceKindV2.result
        var invalid = [PublicNavigationSpecV2(destination: kind.destination, searchReference: reference),
                       .init(destination: kind.destination, backend: .otzaria)]
        for value in ["", reference.uppercased(), " " + reference, reference + "\n", "{" + reference + "}",
                      String(repeating: "x", count: 4096), "../../secret", "query=private", "a6d7", reference + "%00"] {
            invalid.append(.init(destination: kind.destination, backend: .otzaria, searchReference: value))
        }
        for presentation in PublicNavigationSpecV2.Presentation.allCases where presentation != .currentTab {
            invalid.append(.init(destination: kind.destination, backend: .otzaria,
                                 presentation: presentation, searchReference: reference))
        }
        for value in invalid { XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(value, registry: registry)) }
    }

    func testReferenceCannotMixReaderContentComponentsOrUnknownState() throws {
        let registry = try registry(), original = input()
        let content = ActionReaderDestination(sectionLocator: .init(backend: .otzaria,
            workKey: "3891", position: .legacyLine(523)))
        XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: original.destination,
            backend: .otzaria, content: content, searchReference: reference), registry: registry))
        XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: original.destination,
            backend: .otzaria, component: .init(rawValue: "native.search.query"), searchReference: reference), registry: registry))
        let base = try ActionWireCodec.decodeObject(UIRouteCodec.encodePublicV2(original, registry: registry))
        for key in ["query", "cursor", "offset", "selectedHit", "scene", "sceneID", "sessionID", "window", "token",
                    "authority", "permission", "state", "requestId", "source", "configuration", "search"] {
            var fields = base; fields[key] = .string("private")
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(wire(fields), registry: registry), key)
        }
        for value: ActionJSON in [.null, .bool(true), .integer(3), .array([.string(reference)]), .object(["id": .string(reference)])] {
            var fields = base; fields["searchReference"] = value
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(wire(fields), registry: registry))
        }
        let encoded = String(decoding: try UIRouteCodec.encodePublicV2(original, registry: registry), as: UTF8.self)
        for key in ["searchReference", "search\\u0052eference"] {
            let duplicated = "{\"" + key + "\":\"" + reference + "\"," + encoded.dropFirst()
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(Data(duplicated.utf8), registry: registry))
        }
    }

    func testEveryExistingDestinationRejectsReferenceAndOldBytesStayExact() throws {
        let originalTests = PublicNavigationV2Tests(name: "original-fixtures", testClosure: { _ in })
        let registry = try originalTests.registry()
        for descriptor in registry.descriptors {
            let content = descriptor.requiresContent ? originalTests.content(.otzaria) : nil
            XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: descriptor.id,
                backend: .otzaria, content: content, searchReference: reference), registry: registry))
        }
        let settings = try UIRouteCodec.decodePublicV2(originalTests.fixture("public-settings-v2"), registry: registry)
        let expected = #"{"component":"test.settings.fontSize","destination":"test.settings","presentation":"sheet","version":2}"#
        XCTAssertEqual(try UIRouteCodec.encodePublicV2(settings, registry: registry), Data(expected.utf8))
        XCTAssertNil(settings.searchReference)
        for name in ["public-settings-v2", "public-inspector-v2"] {
            let value = try UIRouteCodec.decodePublicV2(originalTests.fixture(name), registry: registry)
            let bytes = try UIRouteCodec.encodePublicV2(value, registry: registry)
            XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("searchReference"))
            XCTAssertEqual(try UIRouteCodec.decodePublicV2(bytes, registry: registry), value)
        }
    }

    func testTrustedPolicyCannotAdvertiseDifferentDestinationOrSurfaceVariant() throws {
        func value(id: UIDestinationID = .init(rawValue: "native.search.result")!,
                   kind: UIPublicSearchReferenceKindV2 = .result, allowsRoot: Bool = false,
                   presentation: PublicNavigationSpecV2.Presentation = .currentTab,
                   anchors: [UIDestinationID] = [], actions: [String] = [], content: Bool = false,
                   privateState: Bool = false) -> UIDestinationDescriptor {
            .init(id: id, title: "Unqualified reference policy", implementation: .implemented,
                  supportedBackends: [.otzaria], presentations: [.currentTab, .sheet], anchors: anchors,
                  requiredCoreActions: actions, requiresContent: content, allowsPrivateState: privateState,
                  publicNavigationV2: .init(rules: [.init(presentation: presentation, allowsRoot: allowsRoot,
                                                        components: anchors)], searchReferenceKind: kind))
        }
        let variants = [value(id: .init(rawValue: "native.fake")!), value(kind: .nextPage), value(allowsRoot: true),
                        value(presentation: .sheet), value(anchors: [.init(rawValue: "native.search.query")!]),
                        value(actions: ["reader.open"], content: true), value(privateState: true)]
        for invalid in variants { XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [invalid])) }
        // Even the finite destination may not quietly gain another presentation.
        XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [value()]))
        XCTAssertNoThrow(try registry())
    }

    func testPrivateAndV1GenericPlansCannotEraseRequiredSelection() throws {
        let registry = try registry()
        for kind in UIPublicSearchReferenceKindV2.allCases {
            for backend in ActionBackendID.allCases {
                let route = RouteSpec(destination: kind.destination, backend: backend)
                XCTAssertThrowsError(try registry.validate(route)) {
                    XCTAssertEqual(($0 as? UIRouteError)?.code, "typed_search_continuation_required")
                }
                XCTAssertThrowsError(try UIRouteCodec.encodePublic(.init(destination: kind.destination, backend: backend), registry: registry))
            }
        }
    }

    @MainActor func testGenericBindingRejectsBeforeOriginalAuthorityOrHostObservation() async throws {
        let original = PublicNavigationV2Tests(name: "original-fixtures", testClosure: { _ in })
        let registry = try registry()
        for backend in ActionBackendID.allCases {
            let source = original.source(backend), host = PublicV2TestHost(source), core = try original.core(source)
            var stateReads = 0, bindingReads = 0
            source.onNavigationStateRead = { stateReads += 1 }; host.onObserve = { bindingReads += 1 }
            for kind in UIPublicSearchReferenceKindV2.allCases {
                do {
                    _ = try await registry.bindPublicV2(input(kind, backend: backend), scene: source.scene,
                        context: source.context, invocation: original.invocation(source), core: core, host: host)
                    XCTFail("Reference was treated as generic root visibility")
                } catch { XCTAssertEqual((error as? UIRouteError)?.code, "typed_search_continuation_required") }
            }
            XCTAssertEqual(stateReads, 0); XCTAssertEqual(bindingReads, 0); XCTAssertEqual(host.sceneReads, 0)
            XCTAssertEqual(source.effects, 0); XCTAssertEqual(source.searches, 0); XCTAssertEqual(source.readerCalls, 0)
        }
    }

    @MainActor func testGenericDiscoveryOmitsUnresolvedReferencesWithoutChangingOldDestinations() async throws {
        let original = PublicNavigationV2Tests(name: "original-fixtures", testClosure: { _ in })
        let old = try original.registry()
        let combined = try UIDestinationRegistry(descriptors: old.descriptors + UIPublicSearchReferenceKindV2.allCases.map(descriptor))
        for backend in ActionBackendID.allCases {
            let source = original.source(backend), host = PublicV2TestHost(source), core = try original.core(source)
            let invocation = original.invocation(source)
            let before = try await old.discover(scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
            let after = try await combined.discover(scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
            XCTAssertEqual(after, before)
            let oldVariants = try await old.discoverPublicV2(scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
            let newVariants = try await combined.discoverPublicV2(scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
            XCTAssertEqual(newVariants, oldVariants)
            XCTAssertFalse(after.contains { $0.id == UIPublicSearchReferenceKindV2.result.destination || $0.id == UIPublicSearchReferenceKindV2.nextPage.destination })
            XCTAssertEqual(source.effects, 0); XCTAssertEqual(source.searches, 0)
        }
    }
}
