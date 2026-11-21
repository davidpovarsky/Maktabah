import Foundation

@main struct RetirementControls {
    @MainActor static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw ProbeError.invariant(message) }
    }

    @MainActor static func make(_ probe: HeldWorkerProbe, annotationUUID: UUID = UUID()) async throws
        -> (AnnotationStore, AnnotationLocalEditorSession, AnnotationLocalEditorIntent) {
        let store = AnnotationStore(probe: probe)
        let annotation = Annotation(id: 7, ckRecordId: annotationUUID.uuidString, note: "probe")
        let session = try store.makeLocalAnnotationEditor(annotation: annotation, supportedFormats: [.init()])
        let snapshot = try await session.read()
        let intent = try session.prepareSave(snapshot: snapshot, mutationID: UUID(), body: .init(),
            textPreview: "probe", editorRevision: nil)
        return (store, session, intent)
    }

    @MainActor static func expectRetired(_ operation: () async throws -> Void) async throws {
        do { try await operation(); throw ProbeError.invariant("Expected retired rejection") }
        catch AnnotationLocalEditorError.retired {}
    }

    @MainActor static func receipt(_ outcome: AnnotationLocalEditorOutcome,
                                   expected: AnnotationLocalEditorIntent, withoutOwnership: Bool) throws {
        switch outcome {
        case .completedWithoutOwnership(let receipt):
            try check(withoutOwnership, "Unexpected suppressed delivery")
            try check(receipt.mutationID == expected.mutationID && receipt.revision == 1 && !receipt.replayed,
                      "Committed receipt identity changed")
        case .committed(let saved):
            try check(!withoutOwnership, "Stale session received committed snapshot")
            try check(saved.receipt.mutationID == expected.mutationID, "Committed snapshot receipt changed")
        }
    }

    @MainActor static func main() async throws {
        var passed: [String] = []
        do {
            let probe = HeldWorkerProbe(.none)
            let (store, session, intent) = try await make(probe)
            // This actual call compiles and executes off MainActor.
            await Task.detached { session.retire() }.value
            try check(!session.isCurrent, "Nonisolated retirement missed persistence owner")
            try await expectRetired { _ = try await session.save(intent) }
            try check(probe.state.withLock { $0.calls == 0 }, "Retired session admitted worker")
            try check(store.events.sent == 0, "Rejected save published an event")
            passed.append("retirement-before-worker-admission")
        }
        do {
            let probe = HeldWorkerProbe(.beforeCurrentness)
            let (store, session, intent) = try await make(probe)
            let save = Task { try await session.save(intent) }
            try await probe.waitUntilEntered()
            await Task.detached { session.retire() }.value
            probe.resume()
            try await expectRetired { _ = try await save.value }
            try check(probe.state.withLock { $0.calls == 1 && $0.committedReceipts == 0 }, "Retired held worker committed")
            try check(store.events.sent == 0, "Uncommitted held worker published")
            passed.append("held-worker-rechecks-same-retired-owner")
        }
        do {
            let probe = HeldWorkerProbe(.afterCommittedReceipt)
            let (store, session, intent) = try await make(probe)
            let uploadsBefore = CloudKitSyncManager.shared.uploads
            let save = Task { try await session.save(intent) }
            try await probe.waitUntilEntered()
            await Task.detached { session.retire() }.value
            probe.resume()
            try receipt(try await save.value, expected: intent, withoutOwnership: true)
            try check(probe.state.withLock { $0.committedReceipts == 1 }, "Already committed result was retried or rolled back")
            try check(store.events.sent == 1 && store.cacheInvalidations == 1, "Actual didCommit publication was lost")
            try check(CloudKitSyncManager.shared.uploads == uploadsBefore, "Retired commit admitted old-host upload")
            passed.append("committed-held-result-keeps-receipt-suppresses-delivery")
        }
        do {
            let probe = HeldWorkerProbe(.none)
            let (store, session, intent) = try await make(probe)
            store.events.listener = { _ in session.retire() }
            defer { store.events.listener = nil }
            let uploadsBefore = CloudKitSyncManager.shared.uploads
            try receipt(try await session.save(intent), expected: intent, withoutOwnership: true)
            try check(store.events.sent == 1 && !session.isCurrent, "Own invalidation did not retire actual local owner")
            try check(CloudKitSyncManager.shared.uploads == uploadsBefore + 1,
                      "Original pre-event upload admission changed")
            try check(probe.state.withLock { $0.committedReceipts == 1 }, "Own event caused retry")
            passed.append("own-treeInvalidated-preserves-real-commit-without-ownership")
        }
        do {
            let probe = HeldWorkerProbe(.none)
            let (store, session, intent) = try await make(probe)
            try receipt(try await session.save(intent), expected: intent, withoutOwnership: false)
            try check(session.isCurrent && store.events.sent == 1, "Default current save changed")
            session.retire()
            passed.append("unchanged-current-default-still-delivers-commit")
        }
        do {
            let sameUUID = UUID()
            let oldProbe = HeldWorkerProbe(.none)
            let (_, old, oldIntent) = try await make(oldProbe, annotationUUID: sameUUID)
            await Task.detached { old.retire() }.value
            let newProbe = HeldWorkerProbe(.none)
            let (_, reopened, newIntent) = try await make(newProbe, annotationUUID: sameUUID)
            try check(old.annotationUUID == reopened.annotationUUID && old.databaseURL == reopened.databaseURL,
                      "Probe failed to hold identities equal")
            try check(!old.isCurrent && reopened.isCurrent, "Same identity revived old owner")
            try await expectRetired { _ = try await old.save(oldIntent) }
            try receipt(try await reopened.save(newIntent), expected: newIntent, withoutOwnership: false)
            try check(oldProbe.state.withLock { $0.calls == 0 }, "Reopen admitted old worker")
            reopened.retire()
            passed.append("same-identities-new-session-cannot-revive-old-owner")
        }
        let result: [String: Any] = ["status": "PASS", "controls_passed": passed.count, "controls": passed,
            "executed": "Exact changed AnnotationLocalEditorSession and original lifetime with explicit persistence/event probes",
            "not_executed": ["SQLite transaction or rollback", "Combine source observation", "UIKit", "Native", "CloudKit network"]]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
