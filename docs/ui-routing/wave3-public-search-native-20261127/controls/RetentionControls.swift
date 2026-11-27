import Foundation
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

// ACTUAL_RETENTION_INSERTION

// Read-only test accessor. No reset/rearm accessor is compiled. Each case is
// a separate process so the real one-process capture rule remains intact.
extension MaktabahNativePublicSearchProbeReturn {
    static var testOnlyCaptured: MaktabahNativePublicSearchProbeReturn? { retained }
}

@main struct PublicReturnRetentionControls {
    enum ExpectedFailure: Error { case checkpoint, envelope }
    @MainActor static func main() throws {
        typealias Service = NativeSearchContinuationIntentService
        let name = CommandLine.arguments[1]
        let snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 7)
        let source = Service.Source(sceneID: "original-window", snapshot: snapshot, sessionID: UUID(), modelID: UUID(),
            generation: 3, sourceRevision: 4, submissionRevision: 5, cancellationRevision: 6,
            paginationRevision: 7, pageRevision: 8, configuration: Data([0, 255, 7]))
        let hit = Service.Hit(stableID: "original-hit", locator: "otzaria|book:3891|line:523",
            versionTitle: nil, language: "he", identity: Data([0, 255, 3, 4]))
        let target = Service.Target(reference: .init(backend: .otzaria, kind: .result, metadataID: UUID()),
            title: "Original result", source: source, hit: hit)
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: snapshot, deadlineUptimeNanoseconds: 5_000_000_001)
        let request = Service.OpenRequest(target: target, invocation: invocation, origin: .appIntent)
        let original = ActionSearchContinuationSource(observationID: UUID(), sceneID: source.sceneID,
            snapshot: snapshot, sessionID: source.sessionID, modelID: source.modelID, generation: source.generation,
            sourceRevision: source.sourceRevision, submissionRevision: source.submissionRevision,
            cancellationRevision: source.cancellationRevision, paginationRevision: source.paginationRevision,
            pageRevision: source.pageRevision, configuration: source.configuration)
        let originalHit = ActionLoadedSearchHit(token: UUID(), stableID: hit.stableID, locator: hit.locator,
            versionTitle: hit.versionTitle, language: hit.language, identity: hit.identity)
        let command = ActionSearchContinuationCommand(source: original,
            operation: .revealLoadedHit(token: originalHit.token), invocation: invocation)
        let refusal = ActionSearchContinuationOutcome.refused(.init(requestID: invocation.requestId,
            reason: .staleSource, effects: [.hitSelectionApplied(originalHit)], source: original, operation: command.operation))
        let execution = Service.Execution(command: command, outcome: .unqualified(command: command, originalResponse: refusal))
        var failures: [String] = []
        func require(_ value: Bool, _ label: String) { if !value { failures.append(label) } }
        func sameReturn(_ retained: MaktabahNativePublicSearchProbeReturn?) -> Bool {
            retained?.request.target == request.target && retained?.request.invocation == invocation
                && retained?.execution.command == execution.command && retained?.execution.outcome == execution.outcome
        }
        let token = UUID()
        switch name {
        case "checkpoint-failure-keeps-raw-partial-return":
            let captured = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: token, request: request, execution: execution)
            var envelopeCalls = 0
            do { try captured.publish(checkpoint: { _, _ in throw ExpectedFailure.checkpoint }, envelope: { _ in envelopeCalls += 1 }); failures.append("missing checkpoint error") }
            catch ExpectedFailure.checkpoint {} catch { failures.append("wrong error") }
            require(sameReturn(MaktabahNativePublicSearchProbeReturn.testOnlyCaptured), "process must retain exact original partial return after I/O failure")
            require(captured.checkpointReference == nil && envelopeCalls == 0, "failed checkpoint must not manufacture envelope")
        case "envelope-failure-keeps-checkpoint-and-return":
            let captured = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: token, request: request, execution: execution)
            do { try captured.publish(checkpoint: { _, _ in ["sha256": "explicit-writer-boundary"] }, envelope: { _ in throw ExpectedFailure.envelope }); failures.append("missing envelope error") }
            catch ExpectedFailure.envelope {} catch { failures.append("wrong error") }
            require(sameReturn(MaktabahNativePublicSearchProbeReturn.testOnlyCaptured), "actual return survives later encoding failure")
            require(captured.checkpointReference?["sha256"] as? String == "explicit-writer-boundary", "real completed checkpoint reference survives")
        case "duplicate-publication-never-retries-writer":
            let captured = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: token, request: request, execution: execution)
            var calls = 0
            do { try captured.publish(checkpoint: { _, _ in calls += 1; throw ExpectedFailure.checkpoint }, envelope: { _ in calls += 100 }) } catch {}
            do { try captured.publish(checkpoint: { _, _ in calls += 1; return [:] }, envelope: { _ in calls += 100 }); failures.append("publication rearmed") } catch {}
            require(calls == 1, "failed writer is not retried as new evidence")
        case "nested-callback-cannot-recapture-or-republish":
            let captured = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: token, request: request, execution: execution)
            var rejected = 0
            try captured.publish(checkpoint: { _, actual in
                require(actual.outcome == execution.outcome, "checkpoint receives exact recursive original return")
                do { _ = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: UUID(), request: request, execution: execution) } catch { rejected += 1 }
                do { try captured.publish(checkpoint: { _, _ in [:] }, envelope: { _ in failures.append("nested writer") }) } catch { rejected += 1 }
                return ["bytes": 3]
            }, envelope: { _ in require(sameReturn(MaktabahNativePublicSearchProbeReturn.testOnlyCaptured), "retained before every external reporting callback") })
            require(rejected == 2, "both nested operations must reject")
        case "second-invocation-cannot-replace-first":
            _ = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: token, request: request, execution: execution)
            do { _ = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: UUID(), request: request, execution: execution); failures.append("second capture allowed") } catch {}
            require(MaktabahNativePublicSearchProbeReturn.testOnlyCaptured?.token == token, "first nonce identity must remain")
            require(sameReturn(MaktabahNativePublicSearchProbeReturn.testOnlyCaptured), "first actual execution remains process-lived")
        case "old-or-mismatched-kind-does-not-capture":
            for kind in ["search-continuation-hit", "search-continuation-page", "search-public-page", "anything"] {
                do { _ = try MaktabahNativePublicSearchProbeReturn.capture(kind: kind, token: token, request: request, execution: execution); failures.append("invalid kind captured") } catch {}
            }
            require(!MaktabahNativePublicSearchProbeReturn.hasCaptured, "invalid diagnostic configuration has no capture effect")
            _ = try MaktabahNativePublicSearchProbeReturn.capture(kind: "search-public-hit", token: token, request: request, execution: execution)
            require(sameReturn(MaktabahNativePublicSearchProbeReturn.testOnlyCaptured), "valid kind captures only its matching return")
        default: fatalError("Unknown fixed control")
        }
        let report: [String: Any] = ["case": name, "pass": failures.isEmpty, "failures": failures,
            "scope": "Actual retention class and actual Core/Host value types; reporting closures are explicit I/O/encoder substitutes; no app/native/Core invocation"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        if !failures.isEmpty { exit(1) }
    }
}
