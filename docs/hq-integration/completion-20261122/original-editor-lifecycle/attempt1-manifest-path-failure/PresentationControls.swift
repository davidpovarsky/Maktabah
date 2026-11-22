import Foundation
import Observation
import Synchronization

import Foundation
import Synchronization

// Explicit presentation dependencies and filesystem destination probes.
// No actual Anytype, SQLite, CloudKit, Combine, SwiftUI or UIKit executes here.
enum ProbeFailure: Error { case invariant(String), envelopeTooLarge }
enum AnnotationLocalEditorError: Error { case retired, missingAnnotation, wrongOwner, invalidIntent }
@MainActor enum AnnotationOriginalEditorQualificationEntry {
    static let marker = "owned-local-only"
    static var isRequested: Bool { true }
}
struct Annotation: Sendable {
    let id: Int64?
    let ckRecordId: String?
    let note: String?
}
struct ProbeSource: Sendable { let digest: String }
struct ProbeVersion: Sendable { let payloadDigest: String }
struct AnnotationLocalEditorSnapshot: Sendable {
    let annotation: Annotation
    let annotationUUID: UUID
    let source: ProbeSource
    let revision: Int64
    let document: String?
    let version: ProbeVersion?
}
struct ProbeBinding: Sendable {
    let hostProfileID: String
    let objectID: String
    let spaceID: String
}
struct ProbeNativeSnapshot: Sendable {
    let nativeArchiveSHA256: String
    let bodyBytes: Data
    let exportedObjectCount: Int
}
struct AnytypeOriginalEditorSnapshotCapture: Sendable {
    let snapshot: ProbeNativeSnapshot
    let retainedDirectoryURL: URL
}
struct AnnotationExchangeCommit: Sendable {
    let revision: Int64
    let payloadDigest: String
    let replayed: Bool
}
struct ProbeCommitted: Sendable {
    let receipt: AnnotationExchangeCommit
    let snapshot: AnnotationLocalEditorSnapshot
}
enum AnnotationLocalEditorOutcome: Sendable {
    case committed(ProbeCommitted)
    case completedWithoutOwnership(AnnotationExchangeCommit)
}
@MainActor final class StudyWorkspaceNavigationAdapter {}
@MainActor final class AnnotationStore {
    static let shared = AnnotationStore()
    func loadAnnotationById(_ id: Int64) -> Annotation? { PresentationProbe.active.annotation }
}

struct QualificationFileManagerProbe: Sendable {
    static let `default` = QualificationFileManagerProbe()
    func url(for directory: Foundation.FileManager.SearchPathDirectory,
             in domain: Foundation.FileManager.SearchPathDomainMask,
             appropriateFor: URL?, create: Bool) throws -> URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["QUALIFICATION_PROBE_ROOT"]!, isDirectory: true)
    }
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try Foundation.FileManager.default.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }
}
typealias FileManager = QualificationFileManagerProbe

@MainActor final class HeldAsyncProbe {
    var entered = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        await withCheckedContinuation { c in
            continuation = c
            entered = true
            for waiter in enteredWaiters { waiter.resume() }
            enteredWaiters = []
        }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }
    func resume() {
        let c = continuation
        continuation = nil
        c?.resume()
    }
}
final class CancellationProbe: Sendable {
    let count = Mutex(0)
    func record() { count.withLock { $0 += 1 } }
    var observed: Bool { count.withLock { $0 > 0 } }
}
@MainActor final class PresentationProbe {
    enum Position { case none, begin, save, afterCommit, reopen, envelopeFailure }
    static var active = PresentationProbe(.none)
    let position: Position
    let held = HeldAsyncProbe()
    let cancelled = CancellationProbe()
    let annotation = Annotation(id: 9, ckRecordId: "CCF9BF22-3B52-4DD4-8AC8-1894894E10AF", note: "")
    let profile = "9CE569BE-BA5C-4B53-BC8A-77A965D0DA54"
    var lifetime: AnnotationLocalEditorLifetime?
    var beginCalls = 0
    var saveCalls = 0
    var reopenCalls = 0
    var hostCreations = 0
    var commitReceipts = 0
    var reopenedRetired = false
    init(_ position: Position) { self.position = position }
    func snapshot(revision: Int64 = 0) -> AnnotationLocalEditorSnapshot {
        .init(annotation: annotation, annotationUUID: UUID(uuidString: annotation.ckRecordId!)!,
              source: .init(digest: String(repeating: "a", count: 64)), revision: revision,
              document: revision == 0 ? nil : "opaque",
              version: revision == 0 ? nil : .init(payloadDigest: String(repeating: "b", count: 64)))
    }
    var capture: AnytypeOriginalEditorSnapshotCapture {
        .init(snapshot: .init(nativeArchiveSHA256: String(repeating: "c", count: 64),
                             bodyBytes: Data([1, 2, 3]), exportedObjectCount: 1),
              retainedDirectoryURL: URL(fileURLWithPath: "C:/explicit-probe/retained-native-capture"))
    }
}
@MainActor final class AnnotationOriginalEditorMount {
    let probe: PresentationProbe
    let snapshot: AnnotationLocalEditorSnapshot
    let binding: ProbeBinding
    private(set) var retainedCapture: AnytypeOriginalEditorSnapshotCapture?
    var retainedFailureDirectory: URL?
    let isReopened: Bool
    init(_ probe: PresentationProbe, reopened: Bool = false) {
        self.probe = probe
        isReopened = reopened
        snapshot = probe.snapshot(revision: reopened ? 1 : 0)
        binding = .init(hostProfileID: probe.profile, objectID: reopened ? "restored" : "original",
                        spaceID: reopened ? "restore-space" : "original-space")
    }
    func save(textPreview: String) async throws -> AnnotationLocalEditorOutcome {
        probe.saveCalls += 1
        retainedCapture = probe.capture
        if probe.position == .envelopeFailure { throw ProbeFailure.envelopeTooLarge }
        let receipt = AnnotationExchangeCommit(revision: 1, payloadDigest: String(repeating: "b", count: 64), replayed: false)
        if probe.position == .afterCommit { probe.commitReceipts += 1 }
        let cancellation = probe.cancelled
        return try await withTaskCancellationHandler {
            if probe.position == .save || probe.position == .afterCommit { await probe.held.wait() }
            if probe.position == .afterCommit { return .completedWithoutOwnership(receipt) }
            try Task.checkCancellation()
            guard probe.lifetime?.isCurrent == true else { throw AnnotationLocalEditorError.retired }
            probe.commitReceipts += 1
            return .committed(.init(receipt: receipt, snapshot: probe.snapshot(revision: 1)))
        } onCancel: { cancellation.record() }
    }
    func retire() { if isReopened { probe.reopenedRetired = true } }
}
@MainActor final class AnnotationOriginalEditorQualification {
    let firstMount: AnnotationOriginalEditorMount
    let probe: PresentationProbe
    init(_ probe: PresentationProbe) {
        self.probe = probe
        firstMount = AnnotationOriginalEditorMount(probe)
    }
    static func begin(annotation: Annotation, store: AnnotationStore,
                      workspace: StudyWorkspaceNavigationAdapter,
                      presentationLifetime: AnnotationLocalEditorLifetime) async throws -> AnnotationOriginalEditorQualification {
        let probe = PresentationProbe.active
        probe.beginCalls += 1
        probe.lifetime = presentationLifetime
        if probe.position == .begin { await probe.held.wait() }
        // Explicit SDK-source callback probe: the real SDK is not present here.
        guard presentationLifetime.isCurrent else { throw AnnotationLocalEditorError.retired }
        probe.hostCreations += 1
        return .init(probe)
    }
    func reopen(annotation: Annotation, workspace: StudyWorkspaceNavigationAdapter) async throws -> AnnotationOriginalEditorMount {
        probe.reopenCalls += 1
        let cancellation = probe.cancelled
        return try await withTaskCancellationHandler {
            if probe.position == .reopen { await probe.held.wait() }
            // Return an already-created host deliberately, even after cancellation,
            // to test that presentation refuses delivery and retires it.
            return AnnotationOriginalEditorMount(probe, reopened: true)
        } onCancel: { cancellation.record() }
    }
    func retire() { probe.lifetime?.retire(); firstMount.retire() }
}

final class AnnotationLocalEditorLifetime: Sendable {
    private let retired = Mutex(false)
    func retire() { retired.withLock { $0 = true } }
    var isCurrent: Bool { retired.withLock { !$0 } }
    func requireCurrent() throws {
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
    }

    /// Internal DB completion boundary. Callers must already own their original
    /// SQLite lock and must not reenter this lifetime from `body`.
    func withCurrent<Value>(_ body: () throws -> Value) throws -> Value {
        try retired.withLock { value in
            guard !value else { throw AnnotationLocalEditorError.retired }
            return try body()
        }
    }
}

private enum AnnotationOriginalEditorQualificationUIError: LocalizedError {
    case unsaved, nonempty, pendingChanges, noWorkspace, closed, missingReceipt
    var errorDescription: String? {
        switch self {
        case .unsaved: "Save this blank note before opening the original editor."
        case .nonempty: "This qualification requires an already saved blank note."
        case .pendingChanges: "Keep the saved note, style and tags unchanged before opening the original editor."
        case .noWorkspace: "The original reader workspace is unavailable."
        case .closed: "The original editor has been closed."
        case .missingReceipt: "The original save did not provide a current durable receipt."
        }
    }
}

@MainActor @Observable
private final class AnnotationOriginalEditorQualificationPresentation: Identifiable {
    let id = UUID()
    let annotation: Annotation
    let workspace: StudyWorkspaceNavigationAdapter
    private let store = AnnotationStore.shared
    private var qualification: AnnotationOriginalEditorQualification?
    private let presentationLifetime = AnnotationLocalEditorLifetime()
    private var operation: Task<Void, Never>?
    private var started = false
    private var closed = false
    private var reportDirectory: URL?
    private(set) var mount: AnnotationOriginalEditorMount?
    private(set) var stage = "preparing"
    private(set) var message = "Opening the original editor…"
    private(set) var reportJSON = "{}"
    private var report: [String: Any] = [:]

    init(annotation: Annotation, workspace: StudyWorkspaceNavigationAdapter) {
        self.annotation = annotation
        self.workspace = workspace
    }

    var canSave: Bool { stage == "editing" && !closed }
    var canReopen: Bool { stage == "saved" && !closed }

    func begin() async {
        guard !started, !closed else { return }
        started = true
        do {
            guard AnnotationOriginalEditorQualificationEntry.isRequested else {
                throw AnnotationOriginalEditorQualificationUIError.closed
            }
            let opened = try await AnnotationOriginalEditorQualification.begin(
                annotation: annotation, store: store, workspace: workspace,
                presentationLifetime: presentationLifetime
            )
            guard !closed, !Task.isCancelled else {
                opened.retire()
                throw AnnotationOriginalEditorQualificationUIError.closed
            }
            qualification = opened
            mount = opened.firstMount
            let snapshot = opened.firstMount.snapshot
            guard let savedID = snapshot.annotation.id else { throw AnnotationLocalEditorError.missingAnnotation }
            report = [
                "schema": 1, "qualification": AnnotationOriginalEditorQualificationEntry.marker,
                "bundle_id": Bundle.main.bundleIdentifier ?? "",
                "annotation_id": savedID,
                "annotation_uuid": snapshot.annotationUUID.uuidString,
                "profile_id": opened.firstMount.binding.hostProfileID,
                "source_witness_sha256": snapshot.source.digest,
                "initial_revision": snapshot.revision,
                "initial_note_blank": (snapshot.annotation.note ?? "").isEmpty,
                "initial_rich_body_absent": snapshot.document == nil,
                "original_object_id": opened.firstMount.binding.objectID,
                "original_space_id": opened.firstMount.binding.spaceID,
                "preview_derived_from_native_body": false,
                "preview_qualification": "not-derived; original blank quick-note preview preserved"
            ]
            try publish(stage: "editing", message: "Type in the original editor, then capture and save.")
        } catch {
            fail(error)
        }
    }

    func startSave() {
        guard canSave, operation == nil else { return }
        operation = Task { [self] in
            defer { operation = nil }
            await save()
        }
    }

    private func save() async {
        guard canSave, let qualification else { return }
        stage = "saving"
        message = "Capturing the original blocks and saving this note…"
        do {
            // The qualification keeps the original blank preview. It neither
            // parses native blocks nor substitutes preview text for their body.
            let outcome = try await qualification.firstMount.save(textPreview: annotation.note ?? "")
            let receipt: AnnotationExchangeCommit
            let delivery: String
            switch outcome {
            case .committed(let saved):
                receipt = saved.receipt
                delivery = "committed"
                guard saved.snapshot.annotationUUID == qualification.firstMount.snapshot.annotationUUID,
                      saved.snapshot.annotation.id == annotation.id else {
                    throw AnnotationLocalEditorError.wrongOwner
                }
            case .completedWithoutOwnership(let committed):
                receipt = committed
                delivery = "completedWithoutOwnership"
            }
            // Record a real commit even if the presenting UI was retired while
            // its already-admitted original transaction completed.
            report["commit_delivery"] = delivery
            report["commit_revision"] = receipt.revision
            report["payload_digest"] = receipt.payloadDigest
            report["commit_replayed"] = receipt.replayed
            guard let capture = qualification.firstMount.retainedCapture else {
                throw AnnotationOriginalEditorQualificationUIError.missingReceipt
            }
            recordCapture(capture)
            // An own commit invalidation can retire the first local owner.
            // Either receipt is durable; explicit reopen obtains a NEW source
            // and saved-row session rather than reviving this retired Host.
            let deliverable = !closed
            try publish(stage: deliverable ? "saved" : "committed-without-current-view",
                        message: deliverable ? "The original body was saved. Reopen it through the current saved note to verify the blocks."
                            : "The body was saved. This editor no longer owns the source; close this sheet.")
        } catch {
            fail(error)
        }
    }

    func startReopen() {
        guard canReopen, operation == nil else { return }
        operation = Task { [self] in
            defer { operation = nil }
            await reopen()
        }
    }

    private func reopen() async {
        guard canReopen, let qualification, let id = annotation.id else { return }
        stage = "reopening"
        message = "Importing the saved body into the original editor…"
        do {
            // The original CAS clears its cache. Its original lookup supplies
            // the current row; reopen then re-reads and verifies the durable
            // revision, payload digest and exact opaque native bytes itself.
            guard let current = store.loadAnnotationById(id) else {
                throw AnnotationLocalEditorError.missingAnnotation
            }
            let reopened = try await qualification.reopen(annotation: current, workspace: workspace)
            guard !closed, !Task.isCancelled else {
                reopened.retire()
                throw AnnotationOriginalEditorQualificationUIError.closed
            }
            mount = reopened
            guard let savedID = reopened.snapshot.annotation.id,
                  let payloadDigest = reopened.snapshot.version?.payloadDigest else {
                throw AnnotationOriginalEditorQualificationUIError.missingReceipt
            }
            report["reopened_annotation_id"] = savedID
            report["reopened_annotation_uuid"] = reopened.snapshot.annotationUUID.uuidString
            report["reopened_revision"] = reopened.snapshot.revision
            report["reopened_payload_digest"] = payloadDigest
            report["reopened_object_id"] = reopened.binding.objectID
            report["reopened_space_id"] = reopened.binding.spaceID
            report["reopened_source_witness_sha256"] = reopened.snapshot.source.digest
            report["durable_body_verified_by_original_reopen"] = true
            try publish(stage: "reopened", message: "The original editor has reopened the saved blocks.")
        } catch {
            fail(error)
        }
    }

    func retire() {
        closed = true
        // This authority exists before the first native await. Source callbacks
        // refuse further native work even before begin() returns its session.
        presentationLifetime.retire()
        operation?.cancel()
        operation = nil
        qualification?.retire()
    }

    private func recordCapture(_ capture: AnytypeOriginalEditorSnapshotCapture) {
        report["native_archive_sha256"] = capture.snapshot.nativeArchiveSHA256
        report["native_body_bytes"] = capture.snapshot.bodyBytes.count
        report["native_exported_object_count"] = capture.snapshot.exportedObjectCount
        report["retained_capture_directory"] = capture.retainedDirectoryURL.path
    }

    private func publish(stage: String, message: String) throws {
        self.stage = stage
        self.message = message
        report["stage"] = stage
        let bytes = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .withoutEscapingSlashes])
        guard bytes.count <= 32_768, let json = String(data: bytes, encoding: .utf8) else {
            throw AnnotationLocalEditorError.invalidIntent
        }
        if reportDirectory == nil {
            let documents = try FileManager.default.url(for: .documentDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
            let root = documents.appendingPathComponent("original-editor-qualification", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let owned = root.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: false)
            reportDirectory = owned
        }
        if let reportDirectory {
            try bytes.write(to: reportDirectory.appendingPathComponent(stage + ".json"), options: .atomic)
        }
        reportJSON = json
    }

    private func fail(_ error: any Error) {
        qualification?.retire()
        mount = nil
        report["failure_type"] = String(reflecting: type(of: error))
        report["failure"] = String(String(describing: error).prefix(1_024))
        // Capture can succeed before the complete envelope/CAS refuses a save.
        // Its original archive remains recoverable and must be named on failure.
        if let capture = qualification?.firstMount.retainedCapture {
            recordCapture(capture)
        }
        if let directory = qualification?.firstMount.retainedFailureDirectory {
            report["retained_failure_directory"] = directory.path
        }
        do {
            try publish(stage: "failed", message: "Original editor qualification failed. Any captured evidence is retained.")
        } catch {
            stage = "failed"
            message = "Original editor qualification failed; its evidence report could not be written."
        }
    }

    isolated deinit {
        presentationLifetime.retire()
        operation?.cancel()
        qualification?.retire()
    }
}


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
