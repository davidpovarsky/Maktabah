
// The outcome structs and retention/report helper above are actual source.
// Serializer/filesystem closures below are explicit failure-injection
// boundaries. They neither run Core nor model UIKit/native acceptance.
@MainActor
private enum ReportingControls {
    static var passed = 0
    static var failed = 0
    static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        if condition() { passed += 1; print("PASS " + name) }
        else { failed += 1; print("FAIL " + name) }
    }
    struct InjectedFailure: Error {}
    static let token = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    static let request = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    static let snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 9)
    static var source: ActionSearchContinuationSource {
        .init(observationID: token, sceneID: "original-scene", snapshot: snapshot,
              sessionID: token, modelID: request, generation: 7, sourceRevision: 4,
              submissionRevision: 1, cancellationRevision: 0, paginationRevision: 0,
              pageRevision: 1, configuration: Data([0, 255, 1]))
    }
    static var hit: ActionLoadedSearchHit {
        .init(token: token, stableID: "real-retained-identity", locator: "otzaria|book:3891|line:523",
              versionTitle: nil, language: "he", identity: Data([254, 0, 255]))
    }
    static var command: ActionSearchContinuationCommand {
        .init(source: source, operation: .revealLoadedHit(token: token),
              invocation: .init(requestId: request, snapshot: snapshot, deadlineUptimeNanoseconds: 5_000_000_000))
    }
    static var partial: ActionSearchContinuationOutcome {
        .refused(.init(requestID: request, reason: .deadlineExceeded,
            effects: [.pageRequested(attemptID: token), .hitSelectionApplied(hit)],
            source: source, operation: .revealLoadedHit(token: token)))
    }
    static var nested: ActionSearchContinuationOutcome {
        .unqualified(command: command, originalResponse: .unqualified(command: command,
            originalResponse: .refused(.init(requestID: token, reason: .invalidCompletion,
                effects: [.pageRequested(attemptID: request), .hitSelectionApplied(hit)]))))
    }
    static var reference: [String: Any] { ["file": "nonce-bound-outcome.json", "bytes": 27, "sha256": "checkpoint-digest"] }

    static func run(_ name: String) throws {
        if name == "invalid-kind" {
            do { _ = try MaktabahNativeSearchContinuationProbeReturn.reserve(kind: "arbitrary", token: token)
                 check(false, "foreign kind refuses") } catch { check(true, "foreign kind refuses") }
            let entry = try MaktabahNativeSearchContinuationProbeReturn.reserve(kind: "search-continuation-hit", token: token)
            check(entry.returned == nil, "invalid kind did not reserve a slot")
            return
        }
        let entry = try MaktabahNativeSearchContinuationProbeReturn.reserve(kind: "search-continuation-hit", token: token)
        check(entry.kind == "search-continuation-hit" && entry.token == token, "finite nonce-bound owner")
        let actual = name == "nested" ? nested : partial
        var projected: ActionSearchContinuationOutcome?, envelopeCalled = 0, checkpointCalled = 0
        var threw = false
        do {
            try entry.publish(actual, checkpoint: { value in
                checkpointCalled += 1
                check(entry.returned == actual, "exact typed return retained before checkpoint callback")
                projected = value
                if name == "checkpoint-budget" || name == "checkpoint-io" { throw InjectedFailure() }
                if name == "checkpoint-encoding" {
                    _ = try JSONSerialization.data(withJSONObject: ["invalid": NSObject()])
                }
                if name == "reentrant" {
                    do { try entry.publish(nested, checkpoint: { _ in reference }, envelope: { _ in })
                         check(false, "reentrant report refused") }
                    catch { check(true, "reentrant report refused") }
                    check(entry.returned == actual, "reentrant callback cannot replace actual return")
                }
                return reference
            }, envelope: { ref in
                envelopeCalled += 1
                check(entry.returned == actual, "exact typed return retained before envelope callback")
                check(entry.checkpointReference?["file"] as? String == reference["file"] as? String,
                      "checkpoint reference retained before envelope callback")
                if name == "envelope-budget" || name == "envelope-io" { throw InjectedFailure() }
                if name == "envelope-encoding" {
                    _ = try JSONSerialization.data(withJSONObject: ["invalid": NSObject()])
                }
            })
        } catch { threw = true }
        let checkpointFailure = name.hasPrefix("checkpoint-")
        let envelopeFailure = name.hasPrefix("envelope-")
        check(threw == (checkpointFailure || envelopeFailure), "reporting failure stays failure")
        check(entry.returned == actual && projected == actual, "partial/unqualified provenance and ordered effects preserved")
        check(checkpointCalled == 1, "one checkpoint attempt")
        check(envelopeCalled == (checkpointFailure ? 0 : 1), "no envelope after incomplete checkpoint")
        check((entry.checkpointReference != nil) == !checkpointFailure, "honest persisted checkpoint availability")
        if name == "same-nonce" || name == "foreign-nonce" {
            do {
                _ = try MaktabahNativeSearchContinuationProbeReturn.reserve(kind: "search-continuation-page",
                    token: name == "same-nonce" ? token : request)
                check(false, "second invocation refused")
            } catch { check(true, "second invocation refused") }
            check(entry.returned == actual, "another invocation cannot erase the original return")
        }
        if name == "duplicate" {
            do { try entry.publish(nested, checkpoint: { _ in checkpointCalled += 1; return reference },
                                   envelope: { _ in envelopeCalled += 1 })
                 check(false, "duplicate publication refused") }
            catch { check(true, "duplicate publication refused") }
            check(checkpointCalled == 1 && envelopeCalled == 1 && entry.returned == actual,
                  "duplicate cannot invoke writers or overwrite a completed checkpoint")
        }
    }
}

@main
private struct ReportingControlMain {
    @MainActor static func main() {
        do { try ReportingControls.run(CommandLine.arguments[1]) }
        catch { ReportingControls.check(false, "unexpected error: \(error)") }
        print("RESULT \(ReportingControls.passed) PASS / \(ReportingControls.failed) FAIL")
        exit(ReportingControls.failed == 0 ? 0 : 1)
    }
}
