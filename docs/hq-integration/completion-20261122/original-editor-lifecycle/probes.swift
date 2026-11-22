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
