// Complete production binding + actual RPC actor controls. Transport replies,
// domain state, UIKit evidence and canonical-receipt inputs are declared shells.
@MainActor private final class BindingControlTransport: SefariaJSTransport {
    var holdBeforeClaim = false; var holdAfterClaim = false; var omitClaim = false
    var wrongTarget = false; var calls = 0
    var originalRootCalls = 0
    var capturedClaim: SefariaEmbeddedSemanticClaim?
    private var navigationArrived = false; private var claimCompleted = false; private var deliveryCompleted = false
    private var navigationWaiter: CheckedContinuation<Void, Never>?
    private var claimWaiter: CheckedContinuation<Void, Never>?
    private var deliveryWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func waitForNavigation() async { if !navigationArrived { await withCheckedContinuation { navigationWaiter = $0 } } }
    func waitForClaim() async { if !claimCompleted { await withCheckedContinuation { claimWaiter = $0 } } }
    func waitForDelivery() async { if !deliveryCompleted { await withCheckedContinuation { deliveryWaiter = $0 } } }
    func release() { releaseWaiter?.resume(); releaseWaiter = nil }
    nonisolated func sendToJS(jsonString: String) async throws { try await receive(jsonString) }
    private func receive(_ json: String) async throws {
        let request = try JSONDecoder().decode(SefariaRPCEnvelope.self, from: Data(json.utf8))
        var result: String
        if request.method == "surface.awaitVisible" {
            originalRootCalls += 1
            let p = try JSONDecoder().decode([String: String].self, from: Data(request.paramsJson!.utf8))
            let proof = surface(surface: UUID(uuidString: p["surfaceID"]!)!, mount: UUID(uuidString: p["mountID"]!)!,
                                scene: p["sceneID"]!, epoch: request.sessionGeneration, nonce: UUID(uuidString: p["nonce"]!)!)
            result = String(decoding: try JSONEncoder().encode(proof), as: UTF8.self)
        } else if request.method == "surface.navigateOriginal" {
            let claim = try JSONDecoder().decode(SefariaEmbeddedSemanticClaim.self, from: Data(request.paramsJson!.utf8))
            capturedClaim = claim; navigationArrived = true; navigationWaiter?.resume(); navigationWaiter = nil
            if holdBeforeClaim { await withCheckedContinuation { releaseWaiter = $0 } }
            let claimed = !omitClaim && SefariaEmbeddedSemanticHandoffs.shared.claim(request.paramsJson!)
            if claimed { calls += 1 }
            claimCompleted = true; claimWaiter?.resume(); claimWaiter = nil
            if holdAfterClaim { await withCheckedContinuation { releaseWaiter = $0 } }
            let proof = SefariaEmbeddedSemanticProof(contract: "chavrusa.original-rn-target.v1", claim: claim,
                originalSurface: surface(surface: claim.surfaceID, mount: claim.mountID, scene: claim.sceneID,
                    epoch: claim.epoch, nonce: claim.nonce), originalMenu: wrongTarget ? "dedication" : claim.target.originalMenu,
                originalHeaderKey: claim.target.originalHeaderKey, interfaceLanguage: "english", originalRootSelection: true,
                originalInstanceRetained: true, observedAfterOriginalCall: true)
            result = String(decoding: try JSONEncoder().encode(proof), as: UTF8.self)
        } else { throw SefariaRPCError(code: "CONTROL_UNEXPECTED_METHOD", message: request.method) }
        let response = SefariaRPCResponse(requestID: request.requestID, status: "success", resultJson: result,
                                         sessionGeneration: request.sessionGeneration)
        await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: String(decoding: try JSONEncoder().encode(response), as: UTF8.self))
        if request.method == "surface.navigateOriginal" {
            deliveryCompleted = true; deliveryWaiter?.resume(); deliveryWaiter = nil
        }
    }
    private func surface(surface: UUID, mount: UUID, scene: String, epoch: UInt64, nonce: UUID) -> SefariaEmbeddedSurfaceProof {
        .init(contract: "chavrusa.original-rn-surface.v1", component: "ReaderApp", upstreamSHA: "2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c",
              surfaceID: surface, mountID: mount, sceneID: scene, epoch: epoch, nonce: nonce,
              layout: .init(width: 600, height: 800, revision: 1))
    }
}
@MainActor private final class BindingFixture {
    let sceneID = UIStableID(rawValue: "original-scene")!
    let manager = iOSNavigationManager(), owner = MaktabahNativeWorkspaceOwner()
    let workspace: StudyWorkspaceNavigationAdapter
    let binding: MaktabahNativeSefariaSurfaceBinding
    var host: SefariaEmbeddedNativeSurfaceController?
    let transport = BindingControlTransport()
    var parent = NativeComponentSourceObservation {}
    init() throws {
        workspace = StudyWorkspaceNavigationAdapter(sceneID: sceneID.rawValue, manager: manager)
        try owner.replace(with: workspace)
        binding = MaktabahNativeSefariaSurfaceBinding(sceneID: sceneID, manager: manager,
            workspaceSource: MaktabahNativeWorkspaceProjectionSource(owner: owner, legacyWorkspace: nil))
    }
    func ready() async throws {
        let bridge = SefariaJSRPCBridge.shared
        await bridge.setTransport(transport); await bridge.notifyListenersActive(true)
        let event = SefariaRPCEvent(event: "ready", sequence: 1)
        await bridge.handleIncomingEvent(jsonString: String(decoding: try JSONEncoder().encode(event), as: UTF8.self))
    }
    func start(target: SefariaEmbeddedSemanticTarget? = .library, validate: @escaping @MainActor () throws -> Void = {}) throws -> (UUID, Task<Void, any Error>) {
        let request = UUID()
        parent = NativeComponentSourceObservation {}
        try binding.retainSource(requestID: request, target: target, parentClaimObservation: target == nil ? nil : parent)
        try binding.begin(requestID: request, target: target,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000, validate: validate)
        try binding.apply(requestID: request)
        if host == nil {
            let actual = SefariaEmbeddedNativeSurfaceController(identity: binding.presentation!)
            actual.observer = binding; try binding.surfaceWillAttach(actual); host = actual
            binding.surfaceDidChange(actual)
        }
        return (request, Task { try await self.binding.awaitOriginalSurface(requestID: request) })
    }
    func receipt(_ request: UUID, target: SefariaEmbeddedSemanticTarget? = .library) -> UISceneReceipt {
        let destination = target.map { UIDestinationID(rawValue: $0.destinationID)! } ?? MaktabahNativeSefariaSurfaceBinding.destination
        return .init(requestId: request, sceneID: sceneID, route: .init(requestId: request, destination: destination,
            presentation: .init(kind: .sheet), content: nil, focus: nil))
    }
    func cleanup(_ request: UUID) { binding.finish(requestID: request, completed: false); binding.releaseSource(requestID: request); binding.unmount() }
}
private struct BindingFailure: Error { let detail: String }
@main private struct BindingControls {
    @MainActor static func main() async throws {
        var results: [[String: Any]] = []
        func expect(_ condition: @autoclosure () -> Bool, _ detail: String) throws { if !condition() { throw BindingFailure(detail: detail) } }
        func refused(_ task: Task<Void, any Error>) async -> Bool { do { try await task.value; return false } catch { return true } }
        func test(_ name: String, _ body: () async throws -> Void) async {
            do { try await body(); results.append(["name": name, "passed": true]) }
            catch { results.append(["name": name, "passed": false, "error": String(describing: error)]) }
        }
        await test("unchanged root target performs only original read-only RPC") {
            let f = try BindingFixture(); try await f.ready(); let (id, task) = try f.start(target: nil)
            defer { f.cleanup(id) }; try await task.value
            f.binding.finish(requestID: id, completed: true); f.binding.releaseSource(requestID: id)
            let actual = try f.binding.acceptanceEvidence(for: f.receipt(id, target: nil))
            try expect(actual.nativeReceiptID == id && f.transport.originalRootCalls == 1 && f.transport.calls == 0,
                       "root path mutated semantic state or lost original proof")
        }
        await test("semantic request requires actual claim and same-source visible proof") {
            let f = try BindingFixture(); try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; try await task.value
            f.binding.finish(requestID: id, completed: true); f.binding.releaseSource(requestID: id)
            let actual = try f.binding.semanticAcceptanceEvidence(for: f.receipt(id))
            try expect(actual.nativeReceiptID == id && actual.originalTarget.claim.requestID == id
                && f.transport.calls == 1 && f.binding.observedDestination?.rawValue == "native.sefariaEmbedded.library",
                "semantic reply did not retain original claim/proof")
        }
        await test("echoed selected state without native claim is refused") {
            let f = try BindingFixture(); f.transport.omitClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; let denied = await refused(task)
            try expect(denied && f.transport.calls == 0 && !f.binding.presentationFacets.ready, "unclaimed reply became evidence")
        }
        await test("wrong original selected state after claim is truthful failure") {
            let f = try BindingFixture(); f.transport.wrongTarget = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; let denied = await refused(task)
            try expect(denied && f.transport.calls == 1 && !f.binding.presentationFacets.ready, "wrong result became success or erased effect")
        }
        await test("actual cancellation before queued JS claim yields zero late effects") {
            let f = try BindingFixture(); f.transport.holdBeforeClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; await f.transport.waitForNavigation(); task.cancel()
            let denied = await refused(task)
            f.transport.release(); await f.transport.waitForDelivery()
            try expect(denied && f.transport.calls == 0 && !f.binding.presentationFacets.ready,
                       "late JS claim survived real Task cancellation")
        }
        await test("actual cancellation after claim preserves possible effect without receipt") {
            let f = try BindingFixture(); f.transport.holdAfterClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; await f.transport.waitForClaim(); task.cancel()
            let denied = await refused(task)
            f.transport.release(); await f.transport.waitForDelivery()
            try expect(denied && f.transport.calls == 1 && !f.binding.presentationFacets.ready, "claimed cancellation became success/rollback")
        }
        await test("actual original workspace replacement rejects queued JS effect") {
            let f = try BindingFixture(); f.transport.holdBeforeClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; await f.transport.waitForNavigation()
            try f.owner.replace(with: StudyWorkspaceNavigationAdapter(sceneID: f.sceneID.rawValue, manager: f.manager))
            f.transport.release(); let denied = await refused(task)
            try expect(denied && f.transport.calls == 0, "old workspace invoked original method")
        }
        await test("real one-shot backend publisher rejects ABA before JS claim") {
            let f = try BindingFixture(); f.transport.holdBeforeClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; await f.transport.waitForNavigation()
            BackendCoordinator.shared.isTransitioning = true; BackendCoordinator.shared.isTransitioning = false
            f.transport.release(); let denied = await refused(task)
            try expect(denied && f.transport.calls == 0, "backend transition revived source")
        }
        await test("early source membership release rejects queued JS effect") {
            let f = try BindingFixture(); f.transport.holdBeforeClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; await f.transport.waitForNavigation(); f.binding.releaseSource(requestID: id)
            f.transport.release(); let denied = await refused(task)
            try expect(denied && f.transport.calls == 0, "released membership performed a late effect")
        }
        await test("original host detach rejects queued JS effect") {
            let f = try BindingFixture(); f.transport.holdBeforeClaim = true; try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; await f.transport.waitForNavigation(); f.host!.detach()
            f.transport.release(); let denied = await refused(task)
            try expect(denied && f.transport.calls == 0, "detached original host retained claim")
        }
        await test("JS selected-state proof waits for independent actual target evidence") {
            let f = try BindingFixture(); try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; f.host!.semanticVisible = false
            let reached = AsyncStream<Void>.makeStream()
            f.host!.observing = { reached.continuation.yield(); reached.continuation.finish() }
            for await _ in reached.stream { break }
            try expect(f.transport.calls == 1 && !f.binding.presentationFacets.ready, "JS proof alone became ready")
            f.host!.semanticVisible = true; f.binding.surfaceDidChange(f.host!); try await task.value
            try expect(f.binding.presentationFacets.ready, "actual original visible publication did not resolve retained waiter")
        }
        await test("completed semantic evidence rejects later original mapping ABA") {
            let f = try BindingFixture(); try await f.ready(); let (id, task) = try f.start()
            defer { f.cleanup(id) }; try await task.value; f.binding.finish(requestID: id, completed: true); f.binding.releaseSource(requestID: id)
            _ = try f.binding.semanticAcceptanceEvidence(for: f.receipt(id))
            f.workspace.source.event += 1; f.workspace.source.event -= 1
            var rejected = false; do { _ = try f.binding.semanticAcceptanceEvidence(for: f.receipt(id)) } catch { rejected = true }
            try expect(rejected && f.binding.observedDestination == nil, "completed receipt revived after original mapping ABA")
        }
        await test("exact warm original host can reveal another finite target") {
            let f = try BindingFixture(); try await f.ready(); let (rootID, rootTask) = try f.start(target: nil)
            try await rootTask.value; f.binding.finish(requestID: rootID, completed: true); f.binding.releaseSource(requestID: rootID)
            let originalHost = f.host!, identity = f.binding.presentation
            let (id, task) = try f.start(target: .topics); defer { f.cleanup(id) }; try await task.value
            f.binding.finish(requestID: id, completed: true); f.binding.releaseSource(requestID: id)
            let actual = try f.binding.semanticAcceptanceEvidence(for: f.receipt(id, target: .topics))
            try expect(f.host === originalHost && f.binding.presentation == identity && actual.originalTarget.claim.target == .topics,
                       "warm finite target replaced original host or receipt source")
        }
        let failed = results.filter { $0["passed"] as? Bool != true }.count
        let data = try JSONSerialization.data(withJSONObject: ["scope": "Complete actual RN binding/runtime/RPC actor/lease/ticket over explicit domain/Combine/UIKit/Core-receipt inputs; SDK/native NOT_RUN",
            "passed": results.count - failed, "failed": failed, "results": results], options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self)); if failed > 0 { exit(1) }
    }
}
