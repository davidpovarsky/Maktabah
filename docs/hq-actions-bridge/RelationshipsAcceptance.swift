import Foundation
import OtzariaActionCore

extension IntegrationAcceptance {
    @MainActor static func relationshipsChecks() async throws {
        typealias Adapter = SefariaEmbeddedRelationshipsAdapter
        func refuses(_ name: String, _ body: () throws -> Void) {
            do { try body(); fatalError("accepted: " + name) }
            catch { check(true, name) }
        }
        let error = SefariaRPCError(code: "SOURCE_FAILED", message: "fixture source failure", retryable: true)
        do {
            _ = try Adapter.decodeResponse(.init(requestID: "fixture", status: "error", error: error))
            fatalError("source error became empty")
        } catch let actual as SefariaRPCError { check(actual == error, "original related RPC error preserved") }
        for payload in [String?.none, "{malformed"] {
            refuses("missing/malformed related JSON is an error") {
                _ = try Adapter.decodeResponse(.init(requestID: "fixture", status: "success", resultJson: payload))
            }
        }
        let keys: Set<String> = ["Genesis", "Rashi on Genesis"]
        check(try Adapter.decodeLinks(.array([]), catalogWorkKeys: keys).isEmpty, "actual links array proves zero")
        check(try Adapter.decodeTopics(.object(["topics": .array([])])).isEmpty, "actual topics array proves zero")
        refuses("links-only payload is not proof of zero topics") { _ = try Adapter.decodeTopics(.array([])) }
        refuses("missing links field is not empty") { _ = try Adapter.decodeLinks(.object([:]), catalogWorkKeys: keys) }
        refuses("partial malformed rows cannot disappear through compactMap") {
            _ = try Adapter.decodeLinks(.array([.object([:])]), catalogWorkKeys: keys)
        }
        var row: ActionObject = ["sourceRef": .string("Rashi on Genesis 1:1"),
            "sourceWorkKey": .string("Rashi on Genesis"), "he": .string("פירוש"),
            "anchorRef": .string("Genesis 1:1"), "category": .string("Commentary")]
        let valid = try Adapter.decodeLinks(.array([.object(row)]), catalogWorkKeys: keys)
        check(valid.count == 1 && valid[0].locator.workKey == "Rashi on Genesis", "source locator uses genuine catalog work, not full ref")
        check(valid[0].locator.position == .canonicalRef("Rashi on Genesis 1:1"), "exact source ref retained")
        check(valid[0].primaryText == "פירוש" && valid[0].anchorRefs == ["Genesis 1:1"], "source text and anchor retained for Inspector/Notes")
        row["sourceWorkKey"] = .string("Genesis")
        refuses("same ref cannot be relabelled as a foreign work") { _ = try Adapter.decodeLinks(.array([.object(row)]), catalogWorkKeys: keys) }
        row["sourceWorkKey"] = .string("Rashi on Genesis"); row["backend"] = .string("otzaria")
        refuses("foreign backend cannot be relabelled Embedded") { _ = try Adapter.decodeLinks(.array([.object(row)]), catalogWorkKeys: keys) }
        row.removeValue(forKey: "backend"); row.removeValue(forKey: "sourceWorkKey")
        refuses("old bundle without native-work evidence fails closed") { _ = try Adapter.decodeLinks(.array([.object(row)]), catalogWorkKeys: keys) }
        let foreign = TextLocator(backend: .otzaria, workKey: "book:7", position: .canonicalRef("Genesis 1:1"))
        do { _ = try await Adapter.shared.links(for: foreign); fatalError("foreign input reached runtime") }
        catch { check(true, "foreign input backend rejected before runtime startup") }
        let invented = TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .legacyLine(1))
        do { _ = try await Adapter.shared.links(for: invented); fatalError("legacy line silently became a whole work") }
        catch { check(true, "unsupported position cannot become whole-work reference") }
        let runtime = SefariaRuntimeManager.shared, rpc = SefariaJSRPCBridge.shared
        await runtime.reset()
        let transport = RuntimeFixtureTransport()
        await rpc.setTransport(transport)
        await rpc.notifyListenersActive(true)
        await rpc.handleIncomingEvent(jsonString: String(decoding: try JSONEncoder().encode(SefariaRPCEvent(event: "ready", sequence: 1)), as: UTF8.self))
        try await runtime.ensureCatalogReady(timeoutSeconds: 1)
        await transport.hold("updates.download")
        let mutation = Task { try await rpc.call(method: "updates.download", timeoutMs: 20) }
        await transport.waitForHeldRequest()
        do { _ = try await mutation.value; fatalError("held resource operation did not time out") }
        catch { check(true, "native resource timeout can occur before the JS promise settles") }
        check(await rpc.resourcesAreStable, "regression precondition: native deferred flag cleared while JS promise is still active")
        let input = TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
        do { _ = try await Adapter.shared.links(for: input); fatalError("busy JS resources were treated as stable/zero") }
        catch { check(true, "direct related reads require actual JS stability after native timeout") }
        check(await transport.relatedCalls == 0, "busy promise proof rejects related reads before provider dispatch")
        try await transport.release()
        let genuineZero = try await Adapter.shared.links(for: input)
        check(genuineZero.isEmpty, "settled resource promise plus actual empty links permits genuine zero without search readiness")
        await transport.setBusyAfterRelated(true)
        do { _ = try await Adapter.shared.links(for: input); fatalError("resource promise starting during related fetch accepted") }
        catch { check(true, "post-fetch fresh nonce proof rejects JS resource drift even without native epoch change") }
        await runtime.reset()
        await rpc.setTransport(nil)
    }
}
