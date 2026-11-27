// Joined after the actual attempt-4 runtime/ticket/source types and the
// VERBATIM original WorkspaceOwner/ProjectionSource. The workspace adapter and
// observer callback below are explicit domain/lifecycle boundary objects.
@MainActor final class StudyWorkspaceNavigationAdapter {}
@MainActor private final class WorkspacePublicationObserver: MaktabahNativeWorkspaceOwnerObserver {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    func workspaceOwnerWillChange() { action() }
}
@MainActor private final class WorkspaceClaimFixture {
    let base: SemanticFixture
    let projection: MaktabahNativeWorkspaceProjectionSource
    let observation: NativeComponentSourceObservation
    let ticket: SefariaEmbeddedSemanticTicket
    let json: String
    init(owner: MaktabahNativeWorkspaceOwner) throws {
        base = try SemanticFixture()
        projection = MaktabahNativeWorkspaceProjectionSource(owner: owner, legacyWorkspace: nil)
        let projection = self.projection
        // The baseline is the current RN source read; the proposed variant
        // additionally registers the closed original owner publication here.
        observation = NativeComponentSourceObservation { _ = try? projection.read() }
        ticket = try .init(requestID: UUID(), identity: base.identity, target: .library,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 20_000_000_000,
            runtime: base.runtime, rootSource: base.root, originalSource: observation)
        try base.registry.register(ticket)
        precondition(ticket.arm(originalHostToken: base.host))
        json = String(decoding: try JSONEncoder().encode(ticket.claim), as: UTF8.self)
    }
    func claim() -> Bool { base.registry.claim(json) }
}
@main private struct WorkspacePublicationControls {
    @MainActor static func main() throws {
        var results: [[String: Any]] = []
        func check(_ name: String, _ action: () throws -> [String: Any]) {
            do {
                let detail = try action()
                results.append(["name": name, "passed": detail["passed"] as? Bool == true, "detail": detail])
            } catch {
                results.append(["name": name, "passed": false, "error": String(describing: error)])
            }
        }
        check("unchanged actual original workspace permits one claim") {
            let owner = MaktabahNativeWorkspaceOwner(), workspace = StudyWorkspaceNavigationAdapter()
            try owner.replace(with: workspace)
            let fixture = try WorkspaceClaimFixture(owner: owner)
            let first = fixture.claim(), second = fixture.claim()
            return ["passed": first && !second, "firstClaim": first, "secondClaim": second]
        }
        check("actual original prepublication observer cannot claim old workspace") {
            let owner = MaktabahNativeWorkspaceOwner(), workspace = StudyWorkspaceNavigationAdapter()
            try owner.replace(with: workspace)
            let fixture = try WorkspaceClaimFixture(owner: owner)
            var claim: Bool?, sourceBlocked = false
            let observer = WorkspacePublicationObserver {
                sourceBlocked = owner.isPublishing && owner.current == nil
                claim = fixture.claim()
            }
            let token = try owner.observe(observer)
            try owner.replace(with: StudyWorkspaceNavigationAdapter())
            owner.cancelObservation(token)
            return ["passed": sourceBlocked && claim == false, "sourceBlockedDuringCallback": sourceBlocked,
                    "claimDuringOriginalCallback": claim as Any, "wasClaimed": fixture.ticket.wasClaimed]
        }
        check("completed original workspace A B A remains retired") {
            let owner = MaktabahNativeWorkspaceOwner(), workspace = StudyWorkspaceNavigationAdapter()
            try owner.replace(with: workspace)
            let fixture = try WorkspaceClaimFixture(owner: owner)
            try owner.replace(with: StudyWorkspaceNavigationAdapter()); try owner.replace(with: workspace)
            let claim = fixture.claim()
            return ["passed": !claim && owner.current === workspace, "claimAfterABA": claim]
        }
        check("actual owner deinit callback cannot claim released source") {
            var owner: MaktabahNativeWorkspaceOwner? = MaktabahNativeWorkspaceOwner()
            try owner!.replace(with: StudyWorkspaceNavigationAdapter())
            let fixture = try WorkspaceClaimFixture(owner: owner!)
            var callbackClaim: Bool?
            let observer = WorkspacePublicationObserver { callbackClaim = fixture.claim() }
            _ = try owner!.observe(observer)
            owner = nil
            return ["passed": callbackClaim == false && !fixture.ticket.wasClaimed,
                    "claimDuringDeinitCallback": callbackClaim as Any, "wasClaimed": fixture.ticket.wasClaimed]
        }
        let failed = results.filter { $0["passed"] as? Bool != true }.count
        let report: [String: Any] = ["scope": "Actual original WorkspaceOwner methods and actual RN claim; domain/observer shells, no app/native execution",
            "passed": results.count - failed, "failed": failed, "results": results]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if failed > 0 { exit(1) }
    }
}
