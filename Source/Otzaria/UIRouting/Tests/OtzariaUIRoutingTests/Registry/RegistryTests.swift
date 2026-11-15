import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class RegistryTests: XCTestCase {
    private func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }
    private func ref(_ backend: ActionBackendID = .otzaria, key: String = "fixture:work", line: Int64 = 42) -> ActionTextRef {
        .init(backend: backend, workKey: key, position: backend == .otzaria ? .legacyLine(line) : .canonicalRef("Fixture 1:\(line)"))
    }
    private func route(backend: ActionBackendID? = nil, content: ActionReaderDestination? = nil,
                       presentation: PresentationSpec = .init(), state: UIStateSpec = .init(), focus: FocusSpec? = nil,
                       scene: SceneTarget = .init(), snapshot: ActionBackendSnapshot? = nil) -> RouteSpec {
        .init(destination: id("fixture.reader"), backend: backend, content: content ?? .init(sectionLocator: ref()),
              presentation: presentation, state: state, focus: focus, scene: scene, expectedBackendSnapshot: snapshot)
    }
    func testAllBackendReferencesAndPresentationVariants() throws {
        let registry = try UIDestinationRegistry.fixtures()
        for backend in ActionBackendID.allCases {
            for kind in PresentationSpec.Kind.allCases {
                let creates = kind == .newTab || kind == .newWindow
                let content = ActionReaderDestination(sectionLocator: ref(backend), focusLocator: ref(backend, line: 43), presentationMode: creates ? .newTab : .sameTab)
                let value = route(content: content, presentation: .init(kind: kind),
                                  focus: .init(kind: .content, locator: content.focusLocator), scene: .init(kind: kind == .newWindow ? .newWindow : .current))
                let validated = try registry.validate(value)
                XCTAssertEqual(validated.route.backend, backend)
                XCTAssertEqual(validated.route.content, content)
                XCTAssertEqual(try UIRouteCodec.decodePrivate(UIRouteCodec.encodePrivate(value, registry: registry), registry: registry).route, validated)
            }
        }
    }
    func testConflictingBackendsAndFocusNeverGuess() throws {
        let registry = try UIDestinationRegistry.fixtures()
        XCTAssertThrowsError(try registry.validate(route(backend: .sefaria)))
        XCTAssertThrowsError(try registry.validate(route(content: .init(sectionLocator: ref(), focusLocator: ref(.sefaria)))))
        XCTAssertThrowsError(try registry.validate(route(content: .init(sectionLocator: ref(), focusLocator: ref(key: "other:work")))))
        XCTAssertThrowsError(try registry.validate(route(snapshot: .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 4))))
        XCTAssertThrowsError(try registry.validate(route(focus: .init(kind: .content, locator: ref(line: 99)))))
        XCTAssertThrowsError(try registry.validate(route(focus: .init(kind: .component, anchor: id("unknown.anchor")))))
        XCTAssertThrowsError(try registry.validate(route(focus: .init(kind: .component, locator: ref(), anchor: id("fixture.reader.text")))))
        XCTAssertThrowsError(try registry.validate(route(state: .init(scrollAnchor: ref(line: 99)))))
        XCTAssertThrowsError(try registry.validate(route(presentation: .init(kind: .newTab))))
        XCTAssertThrowsError(try registry.validate(route(scene: .init(kind: .newWindow))))
    }
    func testCompleteStateAndBoundedSelection() throws {
        let registry = try UIDestinationRegistry.fixtures()
        let text = id("fixture.reader.text"), toc = id("fixture.reader.toc")
        let state = UIStateSpec(workspaceID: .init(rawValue: "workspace-1"), profileID: .init(rawValue: "profile-1"), selectedItemID: .init(rawValue: "item-1"),
                                visibleComponents: [text, toc], expandedComponents: [toc], sidebarVisible: true, inspectorVisible: true,
                                sheet: id("fixture.reader.noteSheet"), scrollAnchor: ref())
        let value = route(state: state, focus: .init(kind: .selection, locator: ref(), range: .init(location: 3, length: 4)))
        XCTAssertEqual(try registry.validate(value).route.state, state)
        for range in [UIUTF16Range(location: UInt64.max, length: 1), .init(location: 1_000_000_000, length: 1), .init(location: 0, length: 10_001)] {
            XCTAssertThrowsError(try registry.validate(route(focus: .init(kind: .selection, locator: ref(), range: range))))
        }
        XCTAssertThrowsError(try registry.validate(route(focus: .init(kind: .selection, locator: ref()))))
        XCTAssertThrowsError(try registry.validate(route(focus: .init(kind: .content, locator: ref(), range: .init(location: 0, length: 0)))))
        XCTAssertThrowsError(try registry.validate(route(state: .init(visibleComponents: [id("unknown.anchor")]))))
        XCTAssertThrowsError(try registry.validate(route(state: .init(visibleComponents: [text, text]))))
        XCTAssertThrowsError(try registry.validate(route(state: .init(privateState: .init(selectedText: "private")))))
    }
    func testPrivateSearchReusesCoreSchemaAndDraftNeverPersists() throws {
        let descriptor = UIDestinationDescriptor(id: id("fixture.search"), title: "Synthetic search", implementation: .fixture,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: ["search.query"], allowsPrivateState: true)
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let query = ActionSearchQuery(backend: .otzaria, text: "שלום", scopeWorkRefs: [.init(backend: .otzaria, workKey: "fixture:work")], wordDistance: 4, offset: 5, limit: 1)
        let value = RouteSpec(destination: descriptor.id, state: .init(privateState: .init(search: query)))
        let decoded = try UIRouteCodec.decodePrivate(UIRouteCodec.encodePrivate(value, registry: registry), registry: registry)
        XCTAssertEqual(decoded.route.route.state.privateState?.search, query)
        XCTAssertEqual(decoded.route.route.backend, .otzaria)
        XCTAssertThrowsError(try registry.validate(.init(destination: descriptor.id, state: .init(privateState: .init(draftNote: "not authorized")))))
        let mixed = ActionSearchQuery(backend: .otzaria, text: "x", scopeWorkRefs: [.init(backend: .sefaria, workKey: "fixture:work")])
        XCTAssertThrowsError(try registry.validate(.init(destination: descriptor.id, state: .init(privateState: .init(search: mixed)))))
        let invalid = ActionSearchQuery(backend: .otzaria, text: "x", limit: 0)
        XCTAssertThrowsError(try registry.validate(.init(destination: descriptor.id, state: .init(privateState: .init(search: invalid)))))
        let notes = try UIDestinationRegistry.fixtures()
        let draft = RouteSpec(destination: id("fixture.notes"), content: .init(sectionLocator: ref()), state: .init(privateState: .init(draftNote: "טיוטה", selectedText: "קטע")))
        XCTAssertEqual(try notes.validate(draft).route.state.privateState?.draftNote, "טיוטה")
    }
    func testRegistryDefinitionFailsClosed() throws {
        let fixture = try UIDestinationRegistry.fixtures().descriptors[0]
        XCTAssertEqual(try UIDestinationRegistry().descriptors.count, 0)
        XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [fixture, fixture]))
        XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [fixture], migrations: [.init(fromVersion: 0, from: fixture.id, to: nil)]))
        XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [fixture], migrations: [.init(fromVersion: 0, from: id("old.reader"), to: id("missing.reader"))]))
        XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [fixture], migrations: [.init(fromVersion: 1, from: id("old.reader"), to: fixture.id)]))
        let unbacked = UIDestinationDescriptor(id: id("fixture.unbacked"), title: "Unbacked", implementation: .implemented, supportedBackends: [.otzaria], presentations: [.currentTab])
        XCTAssertNoThrow(try UIDestinationRegistry(descriptors: [unbacked]))
        // Registration alone is structural; execution requires Core's one-use
        // live-authority navigation preparation and the synchronous guard.
        let pureRegistry = try UIDestinationRegistry(descriptors: [unbacked])
        XCTAssertThrowsError(try pureRegistry.validate(.init(destination: unbacked.id, content: .init(sectionLocator: ref()))))
        for mutates in [true, false] {
            let unsafe = UIDestinationDescriptor(id: id("fixture.unsafe"), title: "Unsafe", implementation: .fixture, supportedBackends: [.otzaria], presentations: [.currentTab], riskTier: mutates ? 2 : 3, mutatesUserData: mutates)
            XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [unsafe]).validate(.init(destination: unsafe.id)))
        }
        XCTAssertNil(UIDestinationID(rawValue: "fixture.reader\n"))
        XCTAssertNil(UIStableID(rawValue: "scene-1\n"))
    }
}
