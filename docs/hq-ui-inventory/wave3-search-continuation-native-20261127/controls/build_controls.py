from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parent.parent
controls = root / 'controls'
addition = (root / 'DEBUG_PROBE_ADDITION.swift').read_text()
start = addition.index('@MainActor\nprivate final class MaktabahNativeSearchContinuationProbeReturn')
end = addition.index('// DEBUG acceptance projection only.', start)
retention = addition[start:end]
ports = (controls / 'ActionPorts.original.swift').read_text()
types = ports[:ports.index('public struct ActionCapabilityAssessment')]
types += 'public enum ActionBackendID: String, Codable, CaseIterable, Sendable { case otzaria, sefaria, sefariaEmbedded }\n'
contract_path = root.parent / 'search-continuation-integration/donor/Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionSearchContinuation.swift'
contract = contract_path.read_text()
assert hashlib.sha256(contract.encode()).hexdigest() == '9bf5428034fe430f3367ab03a5232496b123ede009219c9d00b08c45ad08e250'
# Only the unused parent protocol is a declaration boundary. Actual contract
# structs, initializers, equality and recursive Outcome are included verbatim.
types += '\npublic protocol ActionUICommandSink: Sendable {}\n' + contract
cases = (controls / 'RETENTION_CASES.swift').read_text()
(controls / 'RetentionControls.swift').write_text(types + retention + cases)
old = (root / 'review/initial-reporting-loss-composition.swift').read_text()
old_start = old.index('                    let evidence = MaktabahNativeSearchContinuationProbeEvidence(probe)',
                      old.index('private func runSearchContinuationAcceptanceProbe'))
old_end = old.index('                    return\n', old_start) + len('                    return\n')
old_block = old[old_start:old_end]
catch_start = old.index('            if consumed || !(error is CancellationError)', old_end)
catch_end = old.index('\n        }\n    }\n}', catch_start)
old_catch = old[catch_start:catch_end]
baseline = types + (controls / 'BASELINE_BOUNDARY.swift').read_text()
fixture = '''
@MainActor private func oldReport() -> MaktabahNativeActionAcceptanceProbe {
    let probe = MaktabahNativeActionAcceptanceProbe(), search = ReportingSearchBoundary()
    let id = UUID(), snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 1)
    let source = ActionSearchContinuationSource(observationID: id, sceneID: "source", snapshot: snapshot,
        sessionID: id, modelID: id, generation: 1, sourceRevision: 1, submissionRevision: 1,
        cancellationRevision: 0, paginationRevision: 0, pageRevision: 1, configuration: Data([1]))
    let result = ActionSearchContinuationOutcome.refused(.init(requestID: id, reason: .deadlineExceeded,
        effects: [.pageRequested(attemptID: id)], source: source, operation: .revealLoadedHit(token: id)))
    let selectedObservation: ActionSearchContinuationObservation? = .init(source: source, loadedHits: [], nextPageToken: nil)
    let selectedOperation: ActionSearchContinuationOperation? = .revealLoadedHit(token: id)
    let beforeIDs = search.results.map(\\.stableID), beforeSubmission = 1, beforeCancellation = 0, beforePagination = 0
    let consumed = true
    func report() {
      do {
'''
baseline += fixture + old_block + '      } catch {\n' + old_catch + '\n      }\n    }\n    report()\n    return probe\n}\n'
baseline += '''
@main private struct BaselineMain {
    @MainActor static func main() {
        let probe = oldReport()
        let retained = probe.written.contains { $0["outcome"] != nil || $0["outcomeCheckpoint"] != nil }
        print("OBSERVED " + String(describing: probe.written))
        print(retained ? "PASS original return retained" : "FAIL original return lost after observation serialization failure")
        exit(retained ? 0 : 1)
    }
}
'''
(controls / 'BaselineControls.swift').write_text(baseline)
segments = {'retention':retention, 'original_reporting_block':old_block, 'original_reporting_catch':old_catch,
            'actual_snapshot_invocation':ports[:ports.index('public struct ActionCapabilityAssessment')],
            'actual_continuation_contract':contract}
for name, source in segments.items(): (controls / (name + '.swift')).write_text(source)
manifest = {name:{'bytes':len(source.encode()),'sha256':hashlib.sha256(source.encode()).hexdigest()} for name,source in segments.items()}
(controls / 'EXTRACTED_INPUTS.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest, indent=2))
