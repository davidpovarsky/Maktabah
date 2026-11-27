import Foundation
import XCTest
import HanlinChatCore
import HanlinHostContracts
import HanlinPlatformContracts
import HanlinPresentationKit
@testable import OtzariaHanlinConsumerStore
#if os(Windows)
import WinSDK
#endif

@MainActor
final class OtzariaHanlinConversationStoreTests: XCTestCase {
    @MainActor private final class Authority {
        var isCurrent = true
    }

    private func fixture() throws -> (URL, HanlinHostSession, OtzariaHanlinHistory) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("otzaria-owned-store-" + UUID().uuidString)
        let namespace = try HanlinConversationNamespace(app: "otzaria", account: UUID().uuidString,
            workspace: UUID().uuidString, space: "sefariaEmbedded")
        let identity = HanlinHostSession(conversationID: UUID(), context: .init(namespace: namespace, sceneID: UUID(), generation: UUID()))
        let reference = PresentationReference("test.original-profile")
        let descriptor = HostPresentationDescriptor(appID: "otzaria", defaultProfile: reference,
            availableProfiles: [.init(id: reference.id, shellID: "test.shell", catalogIDs: [.init("test.catalog")])],
            catalogProviders: [.init(reference: .init("test.catalog"), renderTargets: [.react, .swiftui],
                componentNames: ["Text", "Input"], modelInstructions: "Explicit test catalog")],
            shells: [.init(id: "test.shell", title: "Test")], hostCapabilities: [])
        let profile = try ProfileResolver.resolve(host: descriptor, conversationID: identity.conversationID)
        let user = HanlinChatMessage.user("שאלה מהמקור — genuine user history")
        let answer = HanlinChatMessage.assistant("Original answer")
        let snapshot = MessagePresentationSnapshot(identity: .init(appID: "otzaria", conversationID: identity.conversationID,
            messageID: answer.id), profile: profile, values: ["query": .string("בראשית"), "count": .number(2)])
        let history = OtzariaHanlinHistory(draft: "טיוטה אמיתית", selectedProfile: reference,
            messages: [user, answer], presentations: [answer.id: snapshot], activities: [],
            reasoning: [answer.id: "Actual stored reasoning"],
            sources: [.init(id: UUID(), messageID: answer.id,
                destination: URL(string: "maktabah://action/v2/native.reader?route=opaque-unit-record-only")!)])
        return (root, identity, history)
    }

    private func file(_ root: URL, _ identity: HanlinHostSession) -> URL {
        let namespace = identity.context.namespace
        return root.appendingPathComponent(namespace.account).appendingPathComponent(namespace.workspace)
            .appendingPathComponent(namespace.space).appendingPathComponent(identity.conversationID.uuidString + ".json")
    }
    private func metadata(_ identity: HanlinHostSession, revision: UInt64 = 0) -> HanlinConversationRecord {
        .init(namespace: identity.context.namespace, conversationID: identity.conversationID, revision: revision,
              model: .init(provider: "test", modelID: "test-model"),
              entries: [.init(runID: UUID(), step: 0, sequence: 0, payload: .text("SDK event only"))])
    }

    func testDiskReopenKeepsHostHistorySeparateFromOriginalSDKMetadata() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        XCTAssertEqual(try scoped.saveHistory(history, replacing: nil), 0)
        let original = metadata(identity)
        let port: any HanlinConversationStore = scoped
        try await port.save(original, replacing: nil)
        let reopened = OtzariaHanlinConversationStore(rootURL: root)
        XCTAssertEqual(try reopened.history(identity.conversationID, namespace: identity.context.namespace)?.0, history)
        XCTAssertEqual(try reopened.history(identity.conversationID, namespace: identity.context.namespace)?.1, 0)
        XCTAssertEqual(try reopened.loadMetadata(identity.conversationID, namespace: identity.context.namespace), original)
        XCTAssertEqual(original.draft, "", "User history must never be overloaded into SDK draft metadata")
        XCTAssertTrue(try Data(contentsOf: file(root, identity)).count > 100)

        // A permission change retires the old SDK lease and reopens the SAME
        // conversation under a fresh generation. Reading it must not rewrite
        // rich history, the Unicode draft, or the original SDK metadata.
        let beforeRotation = try Data(contentsOf: file(root, identity))
        scoped.revoke()
        let successor = HanlinHostSession(conversationID: identity.conversationID,
            context: .init(namespace: identity.context.namespace, sceneID: identity.context.sceneID,
                generation: UUID(), sourceRevision: "explicit-current-work-connection"))
        let resumed = OtzariaHanlinScopedConversationStore(identity: successor, store: reopened, validateOwner: {})
        XCTAssertEqual(try resumed.history()?.0, history)
        XCTAssertEqual(try resumed.load(successor.conversationID, namespace: successor.context.namespace), original)
        XCTAssertEqual(try Data(contentsOf: file(root, identity)), beforeRotation)
        XCTAssertThrowsError(try scoped.saveHistory(history, replacing: 0))
    }

    func testDraftHistoryHasItsOwnTitleAndMetadataOnlyRecordsStayHidden() async throws {
        let (root, identity, fullHistory) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let draft = OtzariaHanlinHistory(draft: fullHistory.draft,
            selectedProfile: fullHistory.selectedProfile, messages: [], presentations: [:],
            activities: [], reasoning: [:])
        _ = try store.saveHistory(draft, id: identity.conversationID,
            namespace: identity.context.namespace, replacing: nil)
        let metadataOnly = HanlinHostSession(conversationID: UUID(), context: identity.context)
        try store.saveMetadata(metadata(metadataOnly), replacing: nil)
        let reopened = OtzariaHanlinConversationStore(rootURL: root)
        let rows = try reopened.summaries(namespace: identity.context.namespace)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.id, identity.conversationID)
        XCTAssertEqual(rows.first?.title, draft.draft)
        XCTAssertNotNil(try reopened.loadMetadata(metadataOnly.conversationID, namespace: identity.context.namespace))
    }

    func testConcurrentSceneHistoryConflictPreservesTheWinningHistoryAndSDKRecord() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = OtzariaHanlinConversationStore(rootURL: root)
        let second = OtzariaHanlinConversationStore(rootURL: root)
        _ = try first.saveHistory(history, id: identity.conversationID, namespace: identity.context.namespace, replacing: nil)
        let readBySecond = try XCTUnwrap(second.history(identity.conversationID, namespace: identity.context.namespace))
        let original = metadata(identity)
        try first.saveMetadata(original, replacing: nil)
        var winner = history; winner.draft = "Winner from another native scene"
        _ = try first.saveHistory(winner, id: identity.conversationID, namespace: identity.context.namespace, replacing: 0)
        var stale = readBySecond.0; stale.draft = "Stale write must not replace winner"
        XCTAssertThrowsError(try second.saveHistory(stale, id: identity.conversationID,
            namespace: identity.context.namespace, replacing: readBySecond.1))
        XCTAssertEqual(try second.history(identity.conversationID, namespace: identity.context.namespace)?.0, winner)
        XCTAssertEqual(try second.loadMetadata(identity.conversationID, namespace: identity.context.namespace), original)
    }

    func testExactSessionRejectsForeignNamespaceConversationAndRevokedCallbacks() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        _ = try scoped.saveHistory(history, replacing: nil)
        try scoped.save(metadata(identity), replacing: nil)
        let before = try Data(contentsOf: file(root, identity))
        let foreign = try HanlinConversationNamespace(app: "otzaria", account: UUID().uuidString,
            workspace: identity.context.namespace.workspace, space: identity.context.namespace.space)
        XCTAssertThrowsError(try scoped.load(identity.conversationID, namespace: foreign))
        XCTAssertThrowsError(try scoped.load(UUID(), namespace: identity.context.namespace))
        XCTAssertThrowsError(try scoped.save(.init(namespace: foreign, conversationID: identity.conversationID, revision: 0), replacing: nil))
        scoped.revoke()
        XCTAssertThrowsError(try scoped.saveHistory(history, replacing: 0))
        XCTAssertThrowsError(try scoped.save(metadata(identity, revision: 1), replacing: 0))
        XCTAssertThrowsError(try scoped.delete(identity.conversationID, namespace: identity.context.namespace, replacing: 0))
        XCTAssertEqual(try Data(contentsOf: file(root, identity)), before)
        XCTAssertTrue(try store.summaries(namespace: foreign).isEmpty)
    }

    func testAuthorityChangeBeforeOriginalAsyncPortCallPreventsTheWrite() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let authority = Authority()
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store) {
            guard authority.isCurrent else { throw HanlinHostError.staleContext }
        }
        _ = try scoped.saveHistory(history, replacing: nil)
        let before = try Data(contentsOf: file(root, identity))
        let port: any HanlinConversationStore = scoped
        authority.isCurrent = false
        do { try await port.save(metadata(identity), replacing: nil); XCTFail("Stale callback must fail") }
        catch { XCTAssertEqual(error as? HanlinHostError, .staleContext) }
        XCTAssertEqual(try Data(contentsOf: file(root, identity)), before)
    }

    func testExplicitHistoryDeletionCannotBeResurrectedByDelayedFirstSDKSave() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        _ = try store.saveHistory(history, id: identity.conversationID, namespace: identity.context.namespace, replacing: nil)
        let row = try XCTUnwrap(store.summaries(namespace: identity.context.namespace).first)
        try store.deleteConversation(row, namespace: identity.context.namespace)
        let reopened = OtzariaHanlinConversationStore(rootURL: root)
        XCTAssertNil(try reopened.history(identity.conversationID, namespace: identity.context.namespace))
        XCTAssertNil(try reopened.loadMetadata(identity.conversationID, namespace: identity.context.namespace))
        XCTAssertThrowsError(try reopened.saveMetadata(metadata(identity), replacing: nil))
        XCTAssertTrue(try reopened.summaries(namespace: identity.context.namespace).isEmpty)
        let bytes = try String(contentsOf: file(root, identity), encoding: .utf8)
        XCTAssertFalse(bytes.contains("genuine user history"))
        XCTAssertFalse(bytes.contains("Original answer"))
        XCTAssertFalse(bytes.contains("SDK event only"))
    }

    func testStaleDeleteCannotEraseNewSDKMetadataOrHostHistory() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        _ = try store.saveHistory(history, id: identity.conversationID, namespace: identity.context.namespace, replacing: nil)
        try store.saveMetadata(metadata(identity), replacing: nil)
        let stale = try XCTUnwrap(store.summaries(namespace: identity.context.namespace).first)
        let latest = metadata(identity, revision: 1)
        try store.saveMetadata(latest, replacing: 0)
        XCTAssertThrowsError(try store.deleteConversation(stale, namespace: identity.context.namespace))
        XCTAssertEqual(try store.loadMetadata(identity.conversationID, namespace: identity.context.namespace), latest)
        XCTAssertEqual(try store.history(identity.conversationID, namespace: identity.context.namespace)?.0, history)
    }

    func testActualFilesystemWriteFailurePreservesOriginalBytesAndRevision() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        _ = try store.saveHistory(history, id: identity.conversationID, namespace: identity.context.namespace, replacing: nil)
        let path = file(root, identity)
        let before = try Data(contentsOf: path)
        #if os(Windows)
        let handle = path.path.withCString(encodedAs: UTF16.self) {
            CreateFileW($0, DWORD(GENERIC_READ), DWORD(FILE_SHARE_READ), nil, DWORD(OPEN_EXISTING), DWORD(FILE_ATTRIBUTE_NORMAL), nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else { XCTFail("Actual Windows read-only sharing lock was not acquired"); return }
        defer { CloseHandle(handle) }
        #else
        let parent = path.deletingLastPathComponent().path
        let permissions = try FileManager.default.attributesOfItem(atPath: parent)[.posixPermissions]!
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent)
        defer { try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: parent) }
        #endif
        var changed = history; changed.draft = "This failed write must not be acknowledged"
        XCTAssertThrowsError(try store.saveHistory(changed, id: identity.conversationID,
            namespace: identity.context.namespace, replacing: 0))
        XCTAssertEqual(try Data(contentsOf: path), before)
        XCTAssertEqual(try store.history(identity.conversationID, namespace: identity.context.namespace)?.1, 0)
    }

    func testCorruptAndFutureGenerationsArePreservedAndNeverTreatedAsMissing() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        _ = try store.saveHistory(history, id: identity.conversationID, namespace: identity.context.namespace, replacing: nil)
        let path = file(root, identity)
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        value["formatVersion"] = 999
        let future = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        try future.write(to: path, options: .atomic)
        XCTAssertThrowsError(try store.history(identity.conversationID, namespace: identity.context.namespace))
        XCTAssertThrowsError(try store.saveMetadata(metadata(identity), replacing: nil))
        XCTAssertEqual(try Data(contentsOf: path), future)
        let corrupt = Data("{truncated".utf8)
        try corrupt.write(to: path, options: .atomic)
        XCTAssertThrowsError(try store.saveHistory(history, id: identity.conversationID,
            namespace: identity.context.namespace, replacing: nil))
        XCTAssertEqual(try Data(contentsOf: path), corrupt)
    }

    func testForeignMessagePresentationIdentityNeverReachesDisk() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        var foreign = history
        let id = try XCTUnwrap(history.messages.last?.id)
        let original = try XCTUnwrap(history.presentations[id])
        foreign.presentations[id] = .init(identity: .init(appID: "anytype", conversationID: UUID(), messageID: id),
            profile: original.profile, values: original.values)
        XCTAssertThrowsError(try store.saveHistory(foreign, id: identity.conversationID,
            namespace: identity.context.namespace, replacing: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(root, identity).path))
        var wrongSource = history
        wrongSource.sources = [.init(id: UUID(), messageID: UUID(), destination: history.sources[0].destination)]
        XCTAssertThrowsError(try store.saveHistory(wrongSource, id: identity.conversationID,
            namespace: identity.context.namespace, replacing: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(root, identity).path))
    }

    func testOriginalMessageStateAndDisclosureChangesSurviveHostAndSDKUpdates() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        var current = history
        var revision: UInt64? = try scoped.saveHistory(current, replacing: nil)
        let id = try XCTUnwrap(history.messages.last?.id)
        let state = MessageOpenUIStateStore(snapshot: try XCTUnwrap(history.presentations[id]))
        state.merge(["fieldA": .string("native value")])
        state.mergeRendererState(["fieldB": .string("React value")], previous: [:])
        state.setExpanded(true, activityID: "reasoning")
        current.presentations[id] = state.snapshot
        revision = try scoped.saveHistory(current, replacing: revision)
        try scoped.save(metadata(identity), replacing: nil)
        let reopened = OtzariaHanlinConversationStore(rootURL: root)
        let saved = try XCTUnwrap(reopened.history(identity.conversationID, namespace: identity.context.namespace))
        XCTAssertEqual(saved.1, revision)
        XCTAssertEqual(saved.0.presentations[id]?.values["fieldA"], .string("native value"))
        XCTAssertEqual(saved.0.presentations[id]?.values["fieldB"], .string("React value"))
        XCTAssertEqual(saved.0.presentations[id]?.expandedActivityIDs, ["reasoning"])
        XCTAssertEqual(saved.0.messages, history.messages)
    }
}


// Value-only fixtures: these tests do not execute MCP, Skills or a model provider.
extension OtzariaHanlinConversationStoreTests {
    private func selectedCapability() -> HanlinCapabilityAttachment {
        .init(reference: .init(kind: .mcp, sourceID: "explicit-history-fixture",
            capabilityID: "echo", revision: "original-revision"),
            title: "Stored capability value", configuration: .object(["query": .string("שלום")]))
    }

    func testCapabilityHistoryReadsLegacyBytesWithoutRewritingThem() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        _ = try scoped.saveHistory(history, replacing: nil)
        let bytes = try Data(contentsOf: file(root, identity))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let prior = try XCTUnwrap(document["history"] as? [String: Any])
        XCTAssertNil(prior["draftCapabilities"]); XCTAssertNil(prior["messageCapabilities"])
        let reopened = OtzariaHanlinConversationStore(rootURL: root)
        let restored = try XCTUnwrap(reopened.history(identity.conversationID, namespace: identity.context.namespace))
        XCTAssertEqual(restored.0, history)
        XCTAssertNil(restored.0.draftCapabilities); XCTAssertNil(restored.0.messageCapabilities)
        XCTAssertEqual(try Data(contentsOf: file(root, identity)), bytes)
    }

    func testCapabilityHistoryFreezesSentSelectionAcrossDraftEditAndDiskReopen() async throws {
        let (root, identity, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        var history = original
        let user = try XCTUnwrap(history.messages.first { $0.role == "user" })
        let selection = selectedCapability()
        history.draftCapabilities = [selection]; history.messageCapabilities = [user.id: [selection]]
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        let revision = try scoped.saveHistory(history, replacing: nil)
        var edited = selection; edited.configuration = .object(["query": .string("טיוטה אחרת")])
        history.draftCapabilities = [edited]
        XCTAssertEqual(try scoped.saveHistory(history, replacing: revision), revision + 1)
        let reopened = OtzariaHanlinConversationStore(rootURL: root)
        let restored = try XCTUnwrap(reopened.history(identity.conversationID, namespace: identity.context.namespace))
        XCTAssertEqual(restored.0.draftCapabilities, [edited])
        XCTAssertEqual(restored.0.messageCapabilities?[user.id], [selection])
        XCTAssertNil(try reopened.loadMetadata(identity.conversationID, namespace: identity.context.namespace),
                     "Selection values must not fabricate SDK metadata or execution authority")
    }

    func testCapabilityHistoryRejectsDuplicateAndForeignMessageSelectionsWithoutChangingDisk() async throws {
        let (root, identity, history) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        let revision = try scoped.saveHistory(history, replacing: nil)
        let bytes = try Data(contentsOf: file(root, identity))
        let selected = selectedCapability()
        var cases: [OtzariaHanlinHistory] = []
        var invalid = history; invalid.messageCapabilities = [UUID(): [selected]]; cases.append(invalid)
        invalid = history
        let assistant = try XCTUnwrap(history.messages.first { $0.role == "assistant" })
        invalid.messageCapabilities = [assistant.id: [selected]]; cases.append(invalid)
        invalid = history; invalid.draftCapabilities = [selected, selected]; cases.append(invalid)
        var duplicate = selected; duplicate.id = UUID()
        invalid = history; invalid.draftCapabilities = [selected, duplicate]; cases.append(invalid)
        for value in cases {
            XCTAssertThrowsError(try scoped.saveHistory(value, replacing: revision))
            XCTAssertEqual(try Data(contentsOf: file(root, identity)), bytes)
        }
    }

    func testCapabilityHistoryCannotBypassExistingStoreByteLimit() async throws {
        let (root, identity, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OtzariaHanlinConversationStore(rootURL: root)
        let scoped = OtzariaHanlinScopedConversationStore(identity: identity, store: store, validateOwner: {})
        let revision = try scoped.saveHistory(original, replacing: nil)
        let bytes = try Data(contentsOf: file(root, identity))
        var oversized = original; var value = selectedCapability()
        value.configuration = .object(["query": .string(String(repeating: "a", count: OtzariaHanlinConversationStore.maximumBytes))])
        oversized.draftCapabilities = [value]
        XCTAssertThrowsError(try scoped.saveHistory(oversized, replacing: revision)) { error in
            XCTAssertEqual(error as? HanlinHostError, .storageLimitExceeded)
        }
        XCTAssertEqual(try Data(contentsOf: file(root, identity)), bytes)
    }
}
