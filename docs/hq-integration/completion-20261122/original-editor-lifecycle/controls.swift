
@MainActor private func require(_ condition: @autoclosure () -> Bool, _ reason: String) throws {
    guard condition() else { throw ProbeFailure.invariant(reason) }
}
@MainActor private func waitFor(_ predicate: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while !predicate() {
        guard clock.now < deadline else { throw ProbeFailure.invariant("presentation completion timed out") }
        await Task.yield()
    }
}
@MainActor private func json(_ model: AnnotationOriginalEditorQualificationPresentation) throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: Data(model.reportJSON.utf8)) as! [String: Any]
}
@MainActor private func make(_ position: PresentationProbe.Position) -> (PresentationProbe, AnnotationOriginalEditorQualificationPresentation) {
    let probe = PresentationProbe(position)
    PresentationProbe.active = probe
    return (probe, .init(annotation: probe.annotation, workspace: StudyWorkspaceNavigationAdapter()))
}
@main struct PresentationControls {
    @MainActor static func main() async throws {
        var passed: [String] = []
        do {
            let (probe, model) = make(.none)
            await model.begin(); await model.begin()
            try require(probe.beginCalls == 1 && model.canSave, "original initial admission must be once")
            model.startSave(); model.startSave()
            try await waitFor { model.stage == "saved" }
            try require(probe.saveCalls == 1 && probe.commitReceipts == 1 && model.canReopen, "duplicate tap started another save")
            let report = try json(model)
            try require(report["commit_revision"] as? Int == 1, "durable receipt missing")
            try require(report["retained_capture_directory"] as? String == probe.capture.retainedDirectoryURL.path, "success recovery identity changed")
            model.retire()
            passed.append("single_begin_and_single_owned_save")
        }
        do {
            let (probe, model) = make(.begin)
            let opening = Task { await model.begin() }
            await probe.held.waitUntilEntered()
            model.retire()
            try require(probe.lifetime?.isCurrent == false, "opening authority not retired synchronously")
            probe.held.resume(); await opening.value
            try require(probe.hostCreations == 0 && !model.canSave && model.mount == nil, "retired opening delivered a host")
            passed.append("retire_during_initial_await_fences_source")
        }
        do {
            let (probe, model) = make(.save)
            await model.begin()
            model.startSave()
            await probe.held.waitUntilEntered()
            model.retire()
            try require(probe.cancelled.observed, "owned save did not receive cancellation")
            probe.held.resume()
            try await waitFor { model.stage == "failed" }
            try require(probe.commitReceipts == 0, "precommit cancellation fabricated a commit")
            let report = try json(model)
            try require(report["retained_capture_directory"] as? String == probe.capture.retainedDirectoryURL.path, "cancelled save lost capture recovery identity")
            passed.append("retire_cancels_owned_save_and_keeps_capture")
        }
        do {
            let (probe, model) = make(.afterCommit)
            await model.begin(); model.startSave()
            await probe.held.waitUntilEntered()
            try require(probe.commitReceipts == 1, "probe must have real admitted receipt before retirement")
            model.retire(); probe.held.resume()
            try await waitFor { model.stage == "committed-without-current-view" }
            model.startSave()
            let report = try json(model)
            try require(report["commit_delivery"] as? String == "completedWithoutOwnership", "committed receipt converted to failure")
            try require(probe.saveCalls == 1 && !model.canReopen, "retired committed owner revived")
            passed.append("already_committed_receipt_survives_retirement")
        }
        do {
            let (probe, model) = make(.envelopeFailure)
            await model.begin(); model.startSave()
            try await waitFor { model.stage == "failed" }
            let report = try json(model)
            try require(report["native_archive_sha256"] as? String == probe.capture.snapshot.nativeArchiveSHA256, "envelope refusal lost archive identity")
            try require(report["retained_capture_directory"] as? String == probe.capture.retainedDirectoryURL.path, "envelope refusal lost directory")
            try require(report["commit_revision"] == nil && probe.commitReceipts == 0, "envelope refusal invented commit")
            passed.append("post_capture_envelope_refusal_keeps_recovery")
        }
        do {
            let (probe, model) = make(.reopen)
            await model.begin(); model.startSave()
            try await waitFor { model.stage == "saved" }
            model.startReopen(); model.startReopen()
            await probe.held.waitUntilEntered()
            model.retire()
            try require(probe.cancelled.observed, "owned reopen did not receive cancellation")
            probe.held.resume()
            try await waitFor { model.stage == "failed" }
            try require(probe.reopenCalls == 1 && probe.reopenedRetired && model.mount == nil, "retired reopen delivered a host or duplicated")
            passed.append("retire_cancels_reopen_and_retires_late_host")
        }
        do {
            let (probe, model) = make(.none)
            model.retire(); await model.begin(); model.startSave(); model.startReopen()
            try require(probe.beginCalls == 0 && probe.saveCalls == 0 && probe.reopenCalls == 0, "retired presentation started work")
            passed.append("retired_presentation_never_adopts_new_work")
        }
        let result: [String: Any] = ["schema": 1, "passed": passed, "count": passed.count,
            "scope": "exact extracted presentation class and original lifetime; explicit SDK, filesystem and data probes; no Apple/Native/SQLite/CloudKit"]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
