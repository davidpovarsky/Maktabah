import Foundation

// Explicit transport double at the actual Swift/RN boundary. No real bundle,
// Hermes, network, user DB or installed packages are represented by this test.
actor RuntimeFixtureTransport: SefariaJSTransport {
    var searchReady = false
    var holdMethod: String?
    var held: SefariaRPCEnvelope?
    var waiter: CheckedContinuation<Void, Never>?

    func setSearchReady(_ value: Bool) { searchReady = value }
    func hold(_ method: String) { holdMethod = method; held = nil }
    func waitForHeldRequest() async {
        if held != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func sendToJS(jsonString: String) async throws {
        let envelope = try JSONDecoder().decode(SefariaRPCEnvelope.self, from: Data(jsonString.utf8))
        if envelope.method == holdMethod {
            held = envelope; waiter?.resume(); waiter = nil
            return
        }
        let body: String
        switch envelope.method {
        case "runtime.initialize": body = "{\"status\":\"initialized\"}"
        case "catalog.toc": body = "[{\"title\":\"Genesis\"}]"
        case "runtime.postInitSearch": body = "{\"searchReady\":\(searchReady)}"
        case "runtime.postInit": body = "{\"packagesReady\":false}"
        default: body = "{}"
        }
        try await deliver(envelope, body: body)
    }
    func release() async throws {
        if let held { try await deliver(held, body: "{}") }
        held = nil; holdMethod = nil
    }
    private func deliver(_ envelope: SefariaRPCEnvelope, body: String) async throws {
        let response = SefariaRPCResponse(requestID: envelope.requestID, status: "success",
            resultJson: body, sessionGeneration: envelope.sessionGeneration)
        let json = String(decoding: try JSONEncoder().encode(response), as: UTF8.self)
        await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: json)
    }
}

extension IntegrationAcceptance {
    @MainActor static func runtimeChecks() async throws {
        let bridge = SefariaJSRPCBridge.shared
        let runtime = SefariaRuntimeManager.shared
        await runtime.reset()
        let transport = RuntimeFixtureTransport()
        await bridge.setTransport(transport)
        await bridge.notifyListenersActive(true)
        let event = SefariaRPCEvent(event: "ready", sequence: 1)
        await bridge.handleIncomingEvent(jsonString: String(decoding: try JSONEncoder().encode(event), as: UTF8.self))
        let epoch = await bridge.sessionEpoch
        try await runtime.ensureCatalogReady(timeoutSeconds: 1)
        let catalog = await runtime.observedReadiness(for: epoch)
        check(catalog.hostReady && catalog.catalogReady, "actual runtime records catalog readiness for current transport")
        do { try await runtime.ensureSearchReady(); fatalError("false JS search readiness accepted") }
        catch { check(true, "success envelope with searchReady=false cannot advertise search") }
        let unavailable = await runtime.observedReadiness(for: epoch)
        check(!unavailable.searchReady, "search remains unavailable after false proof")
        await transport.setSearchReady(true)
        try await runtime.ensureSearchReady()
        let ready = await runtime.observedReadiness(for: epoch)
        check(ready.searchReady, "failed eager initialization is retryable with genuine positive response")
        check(!ready.packagesReady, "packagesReady=false is not converted to ready")
        await bridge.setTransport(transport)
        let repeatedEpoch = await bridge.sessionEpoch
        let repeatedReady = await bridge.isTransportReady
        check(repeatedEpoch == epoch && repeatedReady, "registering the identical transport preserves a valid handshake")

        // Resource methods use the real RPC actor but only the isolated transport
        // double. No download/remove operation is sent to a user's runtime.
        await transport.hold("downloads.install")
        let install = Task { try await bridge.call(method: "downloads.install", timeoutMs: 600_000) }
        await transport.waitForHeldRequest()
        check(await bridge.sessionEpoch != epoch, "resource operation invalidates prior snapshots before dispatch")
        check(await bridge.resourcesAreStable == false, "readiness cannot be observed during a resource operation")
        do { _ = try await bridge.call(method: "downloads.remove"); fatalError("overlapping resource mutation accepted") }
        catch { check(true, "concurrent resource mutations are refused") }
        let mutationEpoch = await bridge.sessionEpoch
        try await transport.release()
        _ = try await install.value
        check(await bridge.sessionEpoch != mutationEpoch, "resource completion revokes snapshots from the in-flight operation")
        check(await bridge.resourcesAreStable, "resource operation is no longer active after completion")
        let oldResources = await runtime.observedReadiness(for: epoch)
        check(!oldResources.catalogReady, "resource replacement revokes old catalog/search observations")
        // Existing host handshake remains valid; runtime reinitialization can
        // reobserve the new resources without requiring an impossible new JS mount.
        try await runtime.ensureCatalogReady(timeoutSeconds: 1)
        let refreshedEpoch = await bridge.sessionEpoch
        let refreshed = await runtime.observedReadiness(for: refreshedEpoch)
        check(refreshed.catalogReady, "resource change can recover through the existing live host")

        await transport.hold("diagnostic.echo")
        let pending = Task { try await bridge.call(method: "diagnostic.echo", generation: refreshedEpoch, timeoutMs: 2_000) }
        await transport.waitForHeldRequest()
        await bridge.setTransport(RuntimeFixtureTransport())
        do { _ = try await pending.value; fatalError("old request accepted across transport replacement") }
        catch { check(true, "transport replacement cancels old in-flight continuation") }
        try await transport.release()
        check(await bridge.sessionEpoch != epoch, "new transport receives a distinct epoch")
        check(await bridge.isTransportReady == false, "new host requires fresh listener and ready handshake")
        let stale = await runtime.observedReadiness(for: epoch)
        check(!stale.isFullyReady && !stale.catalogReady && !stale.searchReady, "cached runtime flags are revoked after transport replacement")
        do { _ = try await bridge.call(method: "diagnostic.echo", generation: epoch); fatalError("stale request dispatched") }
        catch { check(true, "explicit stale generation rejected before dispatch") }
        do { _ = try await bridge.call(method: "diagnostic.echo", timeoutMs: -1); fatalError("invalid timeout accepted") }
        catch { check(true, "negative timeout rejected without UInt64 trap") }
        let cancelled = Task { () -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try await bridge.call(method: "diagnostic.echo"); return false }
            catch is CancellationError { return true }
            catch { return false }
        }
        check(await cancelled.value, "already-cancelled RPC never dispatches")
        let beforeReset = await bridge.sessionEpoch
        await runtime.reset()
        check(await bridge.sessionEpoch != beforeReset, "runtime reset revokes epoch synchronously before returning")
        await bridge.setTransport(nil)
    }
}
