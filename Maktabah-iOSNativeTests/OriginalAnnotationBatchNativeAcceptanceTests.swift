import XCTest
import Foundation
import CryptoKit
import Darwin
import AnytypeOriginalEditor
@testable import Maktabah

/// Runs only in the genuine iOS application host. It uses the closed production
/// batch factory, original native materialization/export, and the original Host
/// lifetime bridge. It creates no SQLite note rows, mounts no substitute editor,
/// and claims no ordinary UI, CloudKit transport, or remote delivery acceptance.
final class OriginalAnnotationBatchNativeAcceptanceTests: XCTestCase {
    @MainActor
    func test01NativeBatchCapturesFullTextWithoutMountingEditor() async throws {
        executionTimeAllowance = 900
        try await runScenario("full-text-no-mount") { run in
            let fixtures = [
                "Original saved note\nהערה מקורית — מקור 📖\nLast line",
                String(repeating: "א", count: 4_095) + "📖" + " unchanged suffix",
                String(repeating: "א", count: 524_288)
            ]
            for (index, text) in fixtures.enumerated() {
                _ = try await run.capture(index: index, text: text)
            }
            try require(run.observedSpaces.count == 1, "batch-created-more-than-one-space")
            try require(run.observedRoots.count == fixtures.count, "distinct-native-roots-required")

            let tooLarge = String(repeating: "א", count: 524_288) + "x"
            let rejected = try run.row(index: 4, text: tooLarge)
            defer { rejected.retire() }
            let batch = try run.requireBatch()
            do {
                let unexpected = try await batch.openPlainAnnotation(
                    sourceLifetime: rejected.lifetime, text: tooLarge,
                    sourceIsCurrent: { $0 == rejected.source && rejected.owner.isCurrent }
                )
                unexpected.retire()
                throw BatchFailure.violation("oversize-plain-seed-was-admitted")
            } catch let failure as BatchFailure {
                throw failure
            } catch {
                try require(error as? AnytypeOriginalEditorLocalAnnotationError == .canonicalBodyMismatch,
                            "oversize-refusal-was-not-the-original-size-guard")
                try run.evidence.event("oversize-refused", values: [
                    "utf8Bytes": tooLarge.utf8.count,
                    "sourceSHA256": digest(Data(tooLarge.utf8)),
                    "error": String(describing: error)
                ])
            }
        }
    }

    @MainActor
    func test02NativeBatchParentRetirementClosesRetainedCapturedChildAndStops() async throws {
        executionTimeAllowance = 600
        try await runScenario("parent-retirement-retained-child") { run in
            let text = "retained child — הערה"
            let row = try run.row(index: 0, text: text)
            let began = ProcessInfo.processInfo.systemUptime
            let child = try await run.open(row, text: text)
            let opened = ProcessInfo.processInfo.systemUptime
            let capture = try await child.captureNativeSnapshot(maximumBodyBytes: run.bodyLimit)
            let captured = ProcessInfo.processInfo.systemUptime
            try run.recordCapture(index: 0, text: text, row: row, child: child, actual: capture,
                                  openSeconds: opened - began, captureSeconds: captured - opened)
            try require(row.lifetime.isCurrent, "row-retired-before-parent-control")
            run.profileGeneration.retire()
            // The row source deliberately remains live. This checks the actual
            // batch capture in the original native admission, beyond a polling
            // closure or an independently retired child token.
            try require(!run.batchLifetime.isCurrent, "host-profile-retirement-did-not-close-batch")
            try require(row.lifetime.isCurrent, "control-did-not-retain-child-source")
            try refuse("parent-retired-capture", evidence: run.evidence) {
                try child.validateCapturedSource(capture)
            }
            try refuse("parent-retired-editor", evidence: run.evidence) {
                _ = try child.makeViewController()
            }

            // Do not explicitly retire this retained child before Stop. The
            // production runtime must observe the retired parent and drain it.
            try await run.stopWhileRetainingChild()
            try refuse("stopped-capture", evidence: run.evidence) {
                try child.validateCapturedSource(capture)
            }
            withExtendedLifetime(child) {}
            row.retire()
        }
    }

    @MainActor
    func test03NativeBatchRunRetirementDuringPendingChildAdmission() async throws {
        executionTimeAllowance = 600
        try await pendingAdmissionControl(.runGeneration)
    }

    @MainActor
    func test04NativeBatchProfileRetirementDuringPendingChildAdmission() async throws {
        executionTimeAllowance = 600
        try await pendingAdmissionControl(.profileGeneration)
    }

    @MainActor
    func test05NativeBatchCancellationDuringPendingChildAdmission() async throws {
        executionTimeAllowance = 600
        try await pendingAdmissionControl(.cancellation)
    }

    @MainActor
    func test06FiveThousandOriginalNativeAnnotationsInOnePrivateBatch() async throws {
        executionTimeAllowance = 14_400
        try await runScenario("native-5000") { run in
            try require(AnytypeOriginalEditorLocalAnnotationBatchSession.maximumAnnotations == 5_000,
                        "required-native-batch-cap-differs")
            var samples: [(Int, String, AnytypeOriginalEditorLocalAnnotationCapture)] = []
            for index in 0..<5_000 {
                try Task.checkCancellation()
                let text: String
                if index.isMultiple(of: 250) {
                    text = "הערה \(index)\n" + String(repeating: "א", count: 4_200)
                        + "\nComplete saved suffix 📖 \(index)"
                } else {
                    text = "Original note \(index)\nהערה \(index) — source \(index % 31)\nSaved content 📖"
                }
                let capture = try await run.capture(index: index, text: text)
                if [0, 2_499, 4_999].contains(index) { samples.append((index, text, capture)) }
                if (index + 1).isMultiple(of: 50) {
                    try run.evidence.progress(captured: run.captures,
                        residentBytes: residentBytes(), nativeRoots: run.observedRoots.count,
                        nativeSpaces: run.observedSpaces.count)
                    await Task.yield()
                }
            }
            try require(run.captures == 5_000 && run.observedRoots.count == 5_000,
                        "five-thousand-distinct-native-captures-required")
            try require(run.observedSpaces.count == 1 && run.observedAccounts.count == 1,
                        "one-actual-private-batch-account-and-space-required")

            let extra = try run.row(index: 5_000, text: "must not be admitted")
            defer { extra.retire() }
            do {
                let child = try await run.requireBatch().openPlainAnnotation(
                    sourceLifetime: extra.lifetime, text: "must not be admitted",
                    sourceIsCurrent: { $0 == extra.source && extra.owner.isCurrent }
                )
                child.retire()
                throw BatchFailure.violation("five-thousand-and-first-admission-succeeded")
            } catch let failure as BatchFailure {
                throw failure
            } catch {
                try require(error as? AnytypeOriginalEditorLocalAnnotationError == .sourceAlreadyUsed,
                            "capacity-refusal-was-not-the-original-bound")
                try run.evidence.event("capacity-refused", values: [
                    "captured": run.captures, "error": String(describing: error)
                ])
            }

            // Release the genuine batch through AccountStop before reopening
            // selected immutable original exports using the ordinary factory.
            // These are native-runtime reopens in this SAME app process, not
            // evidence that a new operating-system process recovered the data.
            try await run.closeBatchForReopen()
            for (index, text, saved) in samples {
                try await run.reopen(index: index, text: text, saved: saved)
            }
            try require(run.reopened == 3, "three-actual-native-reopens-required")
        }
    }

    @MainActor
    private func pendingAdmissionControl(_ kind: RetirementKind) async throws {
        try await runScenario("pending-" + kind.rawValue) { run in
            let row = try run.row(index: 0, text: "pending native admission — טיוטה")
            defer { row.retire() }
            let progress = PendingAdmission()
            let batch = try run.requireBatch()
            let pending = Task { @MainActor in
                defer { progress.finished = true }
                return try await batch.openPlainAnnotation(
                    sourceLifetime: row.lifetime, text: "pending native admission — טיוטה"
                ) { source in
                    progress.sourceChecks += 1
                    progress.entered = true
                    return source == row.source && row.owner.isCurrent
                }
            }
            do {
                let deadline = ProcessInfo.processInfo.systemUptime + 20
                while !progress.entered && !progress.finished {
                    guard ProcessInfo.processInfo.systemUptime < deadline else {
                        throw BatchFailure.violation("pending-admission-was-not-observed")
                    }
                    try await Task.sleep(for: .milliseconds(1))
                }
                guard progress.entered && !progress.finished else {
                    // A race that finished before the control is not evidence that
                    // retirement occurred during a pending operation.
                    if let returned = try? await pending.value { returned.retire() }
                    throw BatchFailure.violation("admission-finished-before-retirement-control")
                }
                switch kind {
                case .runGeneration: run.runGeneration.retire()
                case .profileGeneration: run.profileGeneration.retire()
                case .cancellation:
                    pending.cancel()
                    run.runGeneration.retire()
                }
                try require(!run.batchLifetime.isCurrent, "pending-parent-retirement-not-synchronous")
                var refusal: String?
                do {
                    let child = try await pending.value
                    child.retire()
                } catch {
                    refusal = String(describing: error)
                }
                row.retire()
                try require(refusal != nil, "pending-admission-returned-an-authorized-child")
                try run.evidence.event("pending-admission-refused", values: [
                    "control": kind.rawValue, "observedPendingBeforeRetirement": true,
                    "publicSourceChecks": progress.sourceChecks, "error": refusal ?? "",
                    "taskCancellationRequested": kind == .cancellation,
                    "parentRetirementRequested": true, "cancellationOnlyControl": false
                ])
            } catch {
                pending.cancel()
                run.runGeneration.retire()
                row.retire()
                if let returned = try? await pending.value { returned.retire() }
                throw error
            }
            // runScenario joins the production AccountStop on an independent
            // task. A private possible-effect is never relabelled as zero writes.
        }
    }

    @MainActor
    private func runScenario(
        _ name: String,
        body: @MainActor (NativeBatchRun) async throws -> Void
    ) async throws {
        let evidence = try BatchEvidence(name: name)
        let run = try NativeBatchRun(evidence: evidence)
        var failure: Error?
        do {
            try require(Bundle.main.bundleIdentifier == "com.davidpovarsky.chavrusatext",
                        "test-is-not-hosted-by-the-real-ios-application")
            try require(Bundle.main.bundleURL.pathExtension == "app",
                        "host-is-not-an-application-bundle")
            try await run.start()
            try await body(run)
        } catch {
            failure = error
        }
        var stopFailure: Error?
        do { try await run.finish() }
        catch { stopFailure = error }
        let report = try evidence.finish(
            status: failure == nil && stopFailure == nil ? "PASS" : "FAILED",
            captured: run.captures, reopened: run.reopened,
            roots: run.observedRoots.count, spaces: run.observedSpaces.count,
            accounts: run.observedAccounts.count,
            bodyError: failure.map { String(describing: $0) },
            stopError: stopFailure.map { String(describing: $0) })
        let attachment = XCTAttachment(data: report, uniformTypeIdentifier: "public.json")
        attachment.name = "original-native-batch-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let failure { throw failure }
        if let stopFailure { throw stopFailure }
    }
}

private enum BatchFailure: Error {
    case violation(String)
}

private func require(_ value: @autoclosure () -> Bool, _ code: String) throws {
    guard value() else { throw BatchFailure.violation(code) }
}

private func digest(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}

private func exactPreview(_ text: String) -> String {
    var result = ""
    var remaining = 8_192
    for scalar in text.unicodeScalars {
        let count = String(scalar).utf8.count
        guard count <= remaining else { break }
        result.unicodeScalars.append(scalar)
        remaining -= count
    }
    return result
}

private func residentBytes() throws -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS, info.resident_size > 0 else {
        throw BatchFailure.violation("resident-memory-measurement-unavailable-kern-\(result)")
    }
    return UInt64(info.resident_size)
}

@MainActor
private func refuse(_ name: String, evidence: BatchEvidence,
                    _ operation: () throws -> Void) throws {
    var observed: String?
    do { try operation() } catch { observed = String(describing: error) }
    try require(observed != nil, name + "-was-admitted")
    try evidence.event(name, values: ["error": observed ?? ""])
}

private enum RetirementKind: String {
    case runGeneration = "run-generation"
    case profileGeneration = "profile-generation"
    case cancellation = "host-cancellation"
}

@MainActor
private final class PendingAdmission {
    var entered = false
    var finished = false
    var sourceChecks = 0
}

@MainActor
private final class NativeBatchRow {
    let owner = AnnotationLocalEditorLifetime()
    let source: AnytypeOriginalEditorLocalAnnotationSource
    let lifetime: AnytypeOriginalEditorLocalAnnotationSourceLifetime

    init(profile: String, uuid: UUID, revision: Int64, witness: String, payload: String?) throws {
        source = try .init(hostProfileID: profile, annotationUUID: uuid,
            expectedRevision: revision, sourceWitnessSHA256: witness, payloadSHA256: payload)
        lifetime = .init(source: source)
        try owner.bindLocalAnnotationRetirement(lifetime)
    }

    func retire() { owner.retire(); lifetime.retire() }
}

@MainActor
private final class NativeBatchRun {
    static let appGroup = "group.com.davidpovarsky.chavrusatext"
    let evidence: BatchEvidence
    let profileGeneration = AnnotationLocalEditorLifetime()
    let runGeneration = AnnotationLocalEditorLifetime()
    let batchLifetime: AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime
    let bodyLimit = TorahAnnotationPayloadLimits.maximumBodyBytes
    private var batch: AnytypeOriginalEditorLocalAnnotationBatchSession?
    private var activeRow: NativeBatchRow?
    private var activeChild: AnytypeOriginalEditorLocalAnnotationSession?
    private var runtimeRequested = false
    private var stopped = false
    private(set) var captures = 0
    private(set) var reopened = 0
    private(set) var observedRoots = Set<String>()
    private(set) var observedSpaces = Set<String>()
    private(set) var observedAccounts = Set<String>()

    init(evidence: BatchEvidence) throws {
        self.evidence = evidence
        let source = try AnytypeOriginalEditorLocalAnnotationBatchSource(
            hostProfileID: evidence.runID.uuidString, batchID: evidence.runID)
        batchLifetime = .init(source: source)
        // Use the product's exact weak-link/mutex bridge for both parents.
        // No synthetic native source owner or dispatch implementation is used.
        try profileGeneration.bindNativeBackfillRetirement(batchLifetime)
        try runGeneration.bindNativeBackfillRetirement(batchLifetime)
    }

    func start() async throws {
        runtimeRequested = true
        let expected = batchLifetime.source
        batch = try await AnytypeOriginalEditorModule.openLocalAnnotationBatch(
            appGroup: Self.appGroup, sourceLifetime: batchLifetime
        ) { [profileGeneration, runGeneration] actual in
            actual == expected && profileGeneration.isCurrent && runGeneration.isCurrent
        }
        try evidence.event("original-batch-opened", values: ["batchID": expected.batchID.uuidString])
    }

    func requireBatch() throws -> AnytypeOriginalEditorLocalAnnotationBatchSession {
        guard let batch else { throw BatchFailure.violation("missing-original-batch") }
        return batch
    }

    func row(index: Int, text: String) throws -> NativeBatchRow {
        let source = Data(("native-batch-fixture/1\n" + evidence.runID.uuidString
            + "\n" + String(index) + "\n").utf8) + Data(text.utf8)
        // The fixture witness is explicit test input. This harness does not
        // claim that a canonical Host SQLite row was saved or backfilled.
        return try NativeBatchRow(profile: evidence.runID.uuidString, uuid: UUID(),
                                  revision: 0, witness: digest(source), payload: nil)
    }

    func open(_ row: NativeBatchRow, text: String) async throws -> AnytypeOriginalEditorLocalAnnotationSession {
        try require(activeChild == nil && activeRow == nil, "overlapping-test-child")
        activeRow = row
        let child = try await requireBatch().openPlainAnnotation(
            sourceLifetime: row.lifetime, text: text,
            sourceIsCurrent: { $0 == row.source && row.owner.isCurrent })
        activeChild = child
        return child
    }

    func capture(index: Int, text: String) async throws -> AnytypeOriginalEditorLocalAnnotationCapture {
        let row = try row(index: index, text: text)
        defer { retireChild(); row.retire() }
        let began = ProcessInfo.processInfo.systemUptime
        let child = try await open(row, text: text)
        let opened = ProcessInfo.processInfo.systemUptime
        let actual = try await child.captureNativeSnapshot(maximumBodyBytes: bodyLimit)
        let captured = ProcessInfo.processInfo.systemUptime
        try recordCapture(index: index, text: text, row: row, child: child, actual: actual,
                          openSeconds: opened - began, captureSeconds: captured - opened)
        return actual
    }

    func recordCapture(index: Int, text: String, row: NativeBatchRow,
                       child: AnytypeOriginalEditorLocalAnnotationSession,
                       actual: AnytypeOriginalEditorLocalAnnotationCapture,
                       openSeconds: Double, captureSeconds: Double) throws {
        try child.validateCapturedSource(actual)
        try require(actual.nativeCapture.snapshot.provenance.matchesCaptureBinding(child.binding),
                    "capture-provenance-differs-from-original-binding")
        try require(child.binding.annotationUUID == row.source.annotationUUID
            && child.binding.expectedRevision == row.source.expectedRevision
            && child.binding.sourceWitnessSHA256 == row.source.sourceWitnessSHA256
            && child.binding.hostProfileID.utf8.elementsEqual(row.source.hostProfileID.utf8),
                    "captured-host-source-identity-differs")
        try require(actual.fullPlainText.utf8.elementsEqual(text.utf8),
                    "native-full-text-differs-from-saved-fixture")
        try require(actual.textPreview.utf8.elementsEqual(exactPreview(text).utf8),
                    "native-preview-is-not-the-exact-bounded-scalar-prefix")
        try require(!actual.nativeCapture.snapshot.bodyBytes.isEmpty,
                    "missing-original-opaque-native-body")
        try require(observedRoots.insert(child.binding.objectID).inserted,
                    "native-root-was-reused-for-another-annotation")
        observedSpaces.insert(child.binding.spaceID)
        observedAccounts.insert(child.binding.accountID)
        captures += 1
        try evidence.capture(index: index, source: row.source, binding: child.binding,
            bodySHA256: digest(actual.nativeCapture.snapshot.bodyBytes),
            fullTextSHA256: digest(Data(actual.fullPlainText.utf8)),
            fullTextBytes: actual.fullPlainText.utf8.count,
            previewBytes: actual.textPreview.utf8.count,
            captureDirectory: actual.nativeCapture.retainedDirectoryURL.path,
            openSeconds: openSeconds, captureSeconds: captureSeconds)
    }

    func stopWhileRetainingChild() async throws {
        try require(!batchLifetime.isCurrent && activeChild != nil,
                    "retained-child-stop-control-was-not-established")
        let stop = Task { @MainActor in
            try await AnytypeOriginalEditorModule.suspendLocalAnnotationRuntime(appGroup: Self.appGroup)
        }
        try await stop.value
        stopped = true
        try evidence.event("actual-account-stop-with-retained-child", values: ["completed": true])
    }

    func closeBatchForReopen() async throws {
        retireChild()
        batch?.retire()
        batchLifetime.retire()
        try await stop()
        batch = nil
    }

    func reopen(index: Int, text: String, saved: AnytypeOriginalEditorLocalAnnotationCapture) async throws {
        let snapshot = saved.nativeCapture.snapshot
        let row = try NativeBatchRow(profile: evidence.runID.uuidString,
            uuid: snapshot.provenance.annotationUUID, revision: 1,
            witness: digest(Data(("reopen/" + snapshot.provenance.annotationUUID.uuidString).utf8)),
            payload: digest(snapshot.bodyBytes))
        defer { retireChild(); row.retire() }
        runtimeRequested = true
        stopped = false
        activeRow = row
        let child = try await AnytypeOriginalEditorModule.openLocalAnnotation(
            appGroup: Self.appGroup, sourceLifetime: row.lifetime, body: .nativeSnapshot(snapshot),
            sourceIsCurrent: { $0 == row.source && row.owner.isCurrent })
        activeChild = child
        let actual = try await child.captureNativeSnapshot(maximumBodyBytes: bodyLimit)
        try child.validateCapturedSource(actual)
        try require(actual.nativeCapture.snapshot.provenance.annotationUUID == row.source.annotationUUID,
                    "reopened-annotation-identity-changed")
        try require(actual.fullPlainText.utf8.elementsEqual(text.utf8),
                    "reopened-original-rich-body-lost-full-text")
        try require(actual.nativeCapture.snapshot.provenance.matchesCaptureBinding(child.binding),
                    "reopened-original-provenance-mismatch")
        reopened += 1
        try evidence.event("original-native-body-reopened", values: [
            "index": index, "annotationUUID": row.source.annotationUUID.uuidString,
            "newPrivateDraftObjectID": child.binding.objectID,
            "bodySHA256": digest(actual.nativeCapture.snapshot.bodyBytes),
            "fullTextSHA256": digest(Data(actual.fullPlainText.utf8))
        ])
        retireChild()
        try await stop()
    }

    func finish() async throws {
        retireChild()
        batch?.retire()
        batchLifetime.retire()
        runGeneration.retire()
        profileGeneration.retire()
        try await stop()
        batch = nil
    }

    private func retireChild() {
        activeChild?.retire()
        activeRow?.retire()
        activeChild = nil
        activeRow = nil
    }

    private func stop() async throws {
        guard runtimeRequested && !stopped else { return }
        let stop = Task { @MainActor in
            try await AnytypeOriginalEditorModule.suspendLocalAnnotationRuntime(appGroup: Self.appGroup)
        }
        try await stop.value
        stopped = true
        try evidence.event("actual-account-stop", values: ["completed": true])
    }
}

@MainActor
private final class BatchEvidence {
    let runID = UUID()
    let directory: URL
    private let name: String
    private let handle: FileHandle
    private var eventCount = 0
    private var openSamples: [Double] = []
    private var captureSamples: [Double] = []
    private let began = ProcessInfo.processInfo.systemUptime
    private var peakObservedRSS: UInt64 = 0
    private let startRSS: UInt64

    init(name: String) throws {
        startRSS = try residentBytes()
        peakObservedRSS = startRSS
        self.name = name
        let documents = try FileManager.default.url(for: .documentDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        directory = documents.appendingPathComponent("OriginalNativeBatchAcceptance", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(runID.uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: directory.path), "existing-evidence-directory")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let events = directory.appendingPathComponent("observations.jsonl")
        try require(FileManager.default.createFile(atPath: events.path, contents: Data()),
                    "cannot-create-observation-log")
        handle = try FileHandle(forWritingTo: events)
        try event("host", values: [
            "mainBundleIdentifier": Bundle.main.bundleIdentifier ?? "",
            "mainBundleURL": Bundle.main.bundleURL.path,
            "processID": ProcessInfo.processInfo.processIdentifier,
            "runID": runID.uuidString, "bodyLimit": TorahAnnotationPayloadLimits.maximumBodyBytes,
            "editorUIAttachedToWindow": false, "hostSQLiteSavedRows": 0, "remoteDeliveryTests": 0
        ])
    }

    func event(_ event: String, values: [String: Any]) throws {
        var fields = values
        fields["event"] = event
        fields["sequence"] = eventCount
        fields["monotonicSeconds"] = ProcessInfo.processInfo.systemUptime - began
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys, .withoutEscapingSlashes])
        try handle.write(contentsOf: data + Data([10]))
        eventCount += 1
    }

    func capture(index: Int, source: AnytypeOriginalEditorLocalAnnotationSource,
                 binding: AnytypeOriginalEditorBinding, bodySHA256: String,
                 fullTextSHA256: String, fullTextBytes: Int, previewBytes: Int,
                 captureDirectory: String, openSeconds: Double, captureSeconds: Double) throws {
        openSamples.append(openSeconds)
        captureSamples.append(captureSeconds)
        peakObservedRSS = max(peakObservedRSS, try residentBytes())
        try event("actual-native-capture", values: [
            "index": index, "annotationUUID": source.annotationUUID.uuidString,
            "sourceWitnessSHA256": source.sourceWitnessSHA256,
            "accountID": binding.accountID, "spaceID": binding.spaceID, "objectID": binding.objectID,
            "bodySHA256": bodySHA256, "fullTextSHA256": fullTextSHA256,
            "fullTextBytes": fullTextBytes, "previewBytes": previewBytes,
            "originalRetainedCaptureDirectory": captureDirectory,
            "openSeconds": openSeconds, "captureSeconds": captureSeconds
        ])
    }

    func progress(captured: Int, residentBytes: UInt64, nativeRoots: Int, nativeSpaces: Int) throws {
        peakObservedRSS = max(peakObservedRSS, residentBytes)
        try event("progress", values: ["captured": captured, "residentBytes": residentBytes,
                                      "distinctNativeRoots": nativeRoots, "distinctNativeSpaces": nativeSpaces])
        try handle.synchronize()
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "RUNNING", "captured": captured, "runID": runID.uuidString,
            "elapsedSeconds": ProcessInfo.processInfo.systemUptime - began,
            "evidenceDirectory": directory.path
        ], options: [.sortedKeys])
        try data.write(to: directory.appendingPathComponent("PROGRESS.json"), options: .atomic)
    }

    func finish(status: String, captured: Int, reopened: Int, roots: Int, spaces: Int,
                accounts: Int, bodyError: String?, stopError: String?) throws -> Data {
        try event("completion", values: ["status": status, "captured": captured,
                                        "bodyError": bodyError ?? "", "stopError": stopError ?? ""])
        try handle.synchronize()
        try handle.close()
        let log = try Data(contentsOf: directory.appendingPathComponent("observations.jsonl"))
        let report: [String: Any] = [
            "schema": "otzaria.actual-hosted-native-batch.v1", "status": status, "scenario": name,
            "runID": runID.uuidString, "mainBundleIdentifier": Bundle.main.bundleIdentifier ?? "",
            "processID": ProcessInfo.processInfo.processIdentifier,
            "captured": captured, "originalNativeReopens": reopened,
            "nativeRuntimeReopensInSameProcess": reopened, "nativeProcessColdReopens": 0,
            "distinctNativeRoots": roots, "distinctNativeSpaces": spaces, "distinctNativeAccounts": accounts,
            "elapsedSeconds": ProcessInfo.processInfo.systemUptime - began,
            "startingResidentBytes": startRSS, "peakSampledResidentBytes": peakObservedRSS,
            "residentMeasurementPolicy": "Require successful nonzero original Mach TASK_BASIC_INFO; otherwise fail and drain",
            "openLatencySeconds": statistics(openSamples), "captureLatencySeconds": statistics(captureSamples),
            "observationsSHA256": digest(log), "observationCount": eventCount,
            "evidenceDirectory": directory.path, "bodyError": bodyError ?? "", "stopError": stopError ?? "",
            "editorUIAttachedToWindow": false, "hostSQLiteSavedRows": 0, "ordinaryUIJourneys": 0,
            "cloudKitTransportTests": 0, "remoteDeliveryTests": 0,
            "sourceScope": "Actual closed production localOnly batch and original native exports. Exact fixture data; no Host SQLite Save or distributed ACK claim."
        ]
        let data = try JSONSerialization.data(withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: directory.appendingPathComponent("RESULT.json"), options: .atomic)
        return data
    }

    private func statistics(_ values: [Double]) -> [String: Any] {
        guard !values.isEmpty else { return ["count": 0] }
        let ordered = values.sorted()
        let p95 = min(ordered.count - 1, Int(ceil(Double(ordered.count) * 0.95)) - 1)
        return ["count": ordered.count, "minimum": ordered[0], "median": ordered[ordered.count / 2],
                "p95": ordered[p95], "maximum": ordered[ordered.count - 1],
                "total": values.reduce(0, +)]
    }
}
