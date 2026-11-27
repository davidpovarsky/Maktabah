#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import SwiftUI
import Observation
import CryptoKit
import AnytypeOriginalEditor

/// Explicit receive uses the original account/Space read and the existing local
/// editor transaction. Historical mappings choose data, never native authority.
@MainActor @Observable
final class AnnotationOriginalEditorReceivePresentation: Identifiable {
    enum OperationKind { case receive, update, synchronize }
    enum Stage { case opening, authenticating, discovering, choosing, reading, reviewing, saving, saved, updating, updated, synchronized, waiting, conflict, unverified, noMapping, changed, failed, closing, closeFailed, closed }
    let operationKind: OperationKind
    let id = UUID()
    let annotation: Annotation
    private let inspected: AnnotationLocalEditorSnapshot
    private let workspace: StudyWorkspaceNavigationAdapter
    private let lifetime = AnnotationLocalEditorLifetime()
    private var local: AnnotationLocalEditorSession?
    private var observation: AnnotationOriginalEditorSourceObservation?
    private var snapshot: AnnotationLocalEditorSnapshot?
    private var presentation: AnytypeOriginalEditorAccountSession.Presentation?
    private var account: AnytypeOriginalEditorAccountSession?
    private var nativeSource: AnytypeOriginalEditorSourceLifetime?
    private var received: AnytypeOriginalAnnotationReadReceipt?
    private var linkedState: AnnotationLocalEditorLinkedState?
    var keepLinked = false
    private var revisionAttempt: AnnotationOriginalEditorRevisionAttempt?
    private(set) var revisionOutcome: AnnotationOriginalEditorRevisionOutcome?
    private var allMappings: [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] = []
    private var operation: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var began = false
    private(set) var stage = Stage.opening
    enum CopyChoice: Identifiable {
        case historical(AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping)
        case discovered(AnytypeOriginalAnnotationDiscoveredCopy)
        case linked(AnnotationExchangeNativeLink)
        var accountID: String {
            switch self { case .historical(let value): value.accountID; case .discovered(let value): value.accountID; case .linked(let value): value.destination.account }
        }
        var spaceID: String {
            switch self { case .historical(let value): value.spaceID; case .discovered(let value): value.spaceID; case .linked(let value): value.destination.space }
        }
        var objectID: String {
            switch self { case .historical(let value): value.objectID; case .discovered(let value): value.objectID; case .linked(let value): value.objectID }
        }
        var id: String { accountID + ":" + spaceID + ":" + objectID }
        var sharedBodyDigest: String? {
            if case .historical(let value) = self { return value.bodyDigest }
            return nil
        }
    }
    private(set) var mappings: [CopyChoice] = []
    var selectedMappingID: String?
    private(set) var retainedHistoryURL: URL?
    private(set) var localChangedSinceShare = false
    private(set) var committedOutcome: AnnotationLocalEditorOutcome?
    private(set) var localStopNeedsRetry = false
    var controller: UIViewController? { presentation?.viewController }
    var remotePreview: String { received?.capture.textPreview ?? "" }
    var localPreview: String { snapshot?.annotation.note ?? "" }
    var canClose: Bool { stage != .saving && stage != .updating && stage != .closing && stage != .closed }

    init(annotation: Annotation, inspected: AnnotationLocalEditorSnapshot,
         workspace: StudyWorkspaceNavigationAdapter, operationKind: OperationKind = .receive) {
        self.operationKind = operationKind
        self.annotation = annotation; self.inspected = inspected; self.workspace = workspace
    }

    func begin() async {
        guard !began else { return }; began = true
        do {
            let observed = try AnnotationOriginalEditorSourceObservation(annotation: annotation,
                store: AnnotationStore.shared, workspace: workspace, presentationLifetime: lifetime)
            observation = observed
            let local = try AnnotationStore.shared.makeLocalAnnotationEditor(annotation: annotation,
                supportedFormats: AnnotationOriginalEditorMount.supportedFormats)
            self.local = local
            try observed.bindLocal(local)
            let captured = try await local.read()
            try observed.requireCurrent()
            guard captured.annotationUUID == inspected.annotationUUID,
                  captured.annotation.id == inspected.annotation.id,
                  captured.source == inspected.source, captured.revision == inspected.revision,
                  captured.version == inspected.version, captured.databaseURL == inspected.databaseURL,
                  try AnnotationOriginalEditorMount.nativeBody(in: captured) != nil else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            snapshot = captured
            linkedState = try await local.linkedState(snapshot: captured)
            allMappings = try await Task.detached {
                try AnnotationOriginalEditorNativeReceiptFile.mappings(
                    annotationUUID: captured.annotationUUID, capturedDatabaseURL: captured.databaseURL)
            }.value
            try observed.requireCurrent()
            localStopNeedsRetry = true
            try await AnytypeOriginalEditorModule.suspendLocalAnnotationRuntime(
                appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
            localStopNeedsRetry = false
            try observed.requireCurrent(); try Task.checkCancellation()
            try presentAccount()
        } catch { if stage != .closing && stage != .closed { stage = .failed } }
    }

    private func presentAccount() throws {
        presentation = try AnytypeOriginalEditorAccountSession.makePresentation(
            appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier,
            onReady: { [weak self] session in self?.selected(session) },
            onFailure: { [weak self] _ in self?.fail() })
        stage = .authenticating
    }

    private func selected(_ session: AnytypeOriginalEditorAccountSession) {
        guard stage == .authenticating else { return }
        do {
            guard let observation else { throw AnnotationLocalEditorError.retired }
            try observation.requireCurrent(); try session.validateCurrent()
            account = session
            if operationKind == .synchronize {
                mappings = (linkedState?.links ?? []).filter {
                    $0.destination.account == session.identity.accountID && $0.destination.space == session.identity.spaceID
                }.map(CopyChoice.linked)
                selectedMappingID = mappings.count == 1 ? mappings[0].id : nil
                stage = mappings.isEmpty ? .noMapping : .choosing
                if mappings.count == 1 { readSelected() }
                return
            }
            mappings = allMappings.filter {
                $0.accountID.utf8.elementsEqual(session.identity.accountID.utf8)
                    && $0.spaceID.utf8.elementsEqual(session.identity.spaceID.utf8)
            }.map(CopyChoice.historical)
            if mappings.isEmpty {
                discoverCopies(in: session)
            } else {
                selectedMappingID = mappings.count == 1 ? mappings[0].id : nil
                stage = .choosing
            }
        } catch { stage = .failed }
    }

    private func discoverCopies(in session: AnytypeOriginalEditorAccountSession) {
        guard operation == nil, let local, let observation, let snapshot else {
            fail(); return
        }
        stage = .discovering
        operation = Task { [self] in
            defer { operation = nil }
            var query: AnytypeOriginalEditorLocalAnnotationSourceLifetime?
            do {
                try observation.requireCurrent(); try session.validateCurrent()
                try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
                let descriptor = try AnytypeOriginalEditorLocalAnnotationSource(
                    hostProfileID: observation.profileID.uuidString,
                    annotationUUID: snapshot.annotationUUID, expectedRevision: snapshot.revision,
                    sourceWitnessSHA256: snapshot.source.digest,
                    payloadSHA256: snapshot.version?.payloadDigest)
                let source = AnytypeOriginalEditorLocalAnnotationSourceLifetime(source: descriptor)
                query = source
                // The existing original row/session/scene/presentation owners
                // fence this read before any original native search dispatch.
                try observation.bindLocalAnnotation(source, local: local, snapshot: snapshot)
                let copies = try await session.discoverOriginalAnnotationCopies(
                    sourceLifetime: source) { [observation, local] candidate in
                        candidate == descriptor && observation.isCurrent && local.isCurrent
                    }
                try observation.finishOriginalCopyDiscovery(source)
                query = nil
                try Task.checkCancellation()
                try observation.requireCurrent(); try session.validateCurrent()
                try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
                guard stage == .discovering else { return }
                mappings = copies.map(CopyChoice.discovered)
                selectedMappingID = mappings.count == 1 ? mappings[0].id : nil
                stage = mappings.isEmpty ? .noMapping : .choosing
            } catch {
                query?.retire()
                if stage != .closing && stage != .closed { stage = .failed }
            }
        }
    }

    func refreshSharedCopies() {
        guard stage == .noMapping, operation == nil, let account else { return }
        discoverCopies(in: account)
    }

    private func fail() {
        if stage != .closing && stage != .closed && stage != .closeFailed { stage = .failed }
    }

    func retryLocalStop() {
        guard stage == .failed, localStopNeedsRetry, presentation == nil, operation == nil else { return }
        stage = .opening
        operation = Task { [self] in
            defer { operation = nil }
            do {
                try await AnytypeOriginalEditorModule.retrySuspendLocalAnnotationRuntime(
                    appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
                localStopNeedsRetry = false
                guard let observation else { throw AnnotationLocalEditorError.retired }
                try observation.requireCurrent(); try Task.checkCancellation(); try presentAccount()
            } catch { fail() }
        }
    }

    func readSelected() {
        guard stage == .choosing, operation == nil,
              let mapping = mappings.first(where: { $0.id == selectedMappingID }),
              let local, let observation, let snapshot, let account else { return }
        stage = .reading
        operation = Task { [self] in
            defer { operation = nil }
            do {
                try observation.requireCurrent(); try account.validateCurrent()
                try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
                let binding = try AnytypeOriginalEditorBinding(accountID: mapping.accountID,
                    spaceID: mapping.spaceID, objectID: mapping.objectID,
                    hostProfileID: observation.profileID.uuidString, annotationUUID: snapshot.annotationUUID,
                    expectedRevision: snapshot.revision, sourceWitnessSHA256: snapshot.source.digest)
                let source = AnytypeOriginalEditorSourceLifetime(binding: binding)
                nativeSource = source
                try observation.bind(source)
                let actual = try await account.readOriginalAnnotation(binding: binding,
                    sourceLifetime: source, maximumBodyBytes: TorahAnnotationPayloadLimits.maximumBodyBytes
                ) { [observation, local] candidate in
                    candidate == binding && observation.isCurrent && local.isCurrent
                }
                // Preserve both complete versions before any later source/CAS
                // check. A source change cannot erase the genuine remote read.
                received = actual
                let readID = id
                retainedHistoryURL = try await Task.detached {
                    try AnnotationOriginalEditorReceiveHistory.persist(actual,
                        captured: snapshot, readID: readID)
                }.value
                try observation.requireCurrent()
                try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
                try observation.requireCurrent(); try account.validateCurrent()
                let current = try AnnotationOriginalEditorMount.nativeBody(in: snapshot)
                localChangedSinceShare = current.map {
                    SHA256.hash(data: $0.bodyBytes).map { String(format: "%02x", $0) }.joined()
                        != mapping.sharedBodyDigest
                } ?? true
                keepLinked = selectedLink != nil
                stage = .reviewing
                if operationKind == .synchronize { try await synchronizeObservedVersion() }
            } catch {
                if let pending = selectedDelivery, retainedHistoryURL == nil {
                    try? await local.deferLinkedRead(pending, snapshot: snapshot)
                }
                if stage != .closing && stage != .closed {
                    stage = retainedHistoryURL == nil ? .failed : .changed
                }
            }
        }
    }

    private var selectedLink: AnnotationExchangeNativeLink? {
        guard let mapping = mappings.first(where: { $0.id == selectedMappingID }) else { return nil }
        return linkedState?.links.first {
            $0.destination.account == mapping.accountID && $0.destination.space == mapping.spaceID && $0.objectID == mapping.objectID
        }
    }

    var isSelectedCopyLinked: Bool { selectedLink != nil }

    private var selectedDelivery: AnnotationExchangeLinkedDelivery? {
        guard let link = selectedLink else { return nil }
        return linkedState?.deliveries.last {
            $0.link.id == link.id && [.pending, .dispatchMayHaveOccurred, .needsReview].contains($0.state)
                && $0.delivery.revision == snapshot?.revision
        }
    }

    func unlinkSelectedCopy() {
        guard stage == .reviewing, operation == nil, let link = selectedLink,
              let snapshot, let local, let observation else { return }
        operation = Task { [self] in
            defer { operation = nil }
            do {
                try observation.requireCurrent()
                try await local.unlinkNativeCopy(link, snapshot: snapshot)
                linkedState = try await local.linkedState(snapshot: snapshot)
                keepLinked = false
            } catch { stage = .changed }
        }
    }

    private func synchronizeObservedVersion() async throws {
        guard let link = selectedLink, let actual = received, let local, let snapshot else { throw AnnotationExchangeError.receiptMismatch }
        linkedState = try await local.linkedState(snapshot: snapshot)
        let unsettled = linkedState?.deliveries.filter {
            $0.link.id == link.id && ($0.state == .dispatchMayHaveOccurred || $0.state == .needsReview)
        } ?? []
        if !unsettled.isEmpty { localChangedSinceShare = true; stage = .reviewing; return }
        if let delivery = selectedDelivery {
            guard delivery.link.nativeRootSHA256 == actual.observedNativeRevisionSHA256 else {
                try await local.requireLinkedReview(delivery, snapshot: snapshot)
                linkedState = try await local.linkedState(snapshot: snapshot)
                localChangedSinceShare = true; stage = .reviewing; return
            }
            guard Int64(Date().timeIntervalSince1970) >= delivery.notBefore else { stage = .waiting; return }
            await performUpdate(explicitReview: false)
        } else if link.nativeRootSHA256 != actual.observedNativeRevisionSHA256 {
            keepLinked = true
            await performReceive()
        } else {
            stage = .synchronized
        }
    }

    /// Explicit choice consumes the actual sealed read. Its origin and optional
    /// link consent commit atomically with the complete local rich body.
    func acceptReceivedVersion() {
        guard operationKind != .update, stage == .reviewing, operation == nil else { return }
        operation = Task { [self] in
            defer { operation = nil }
            await performReceive()
        }
    }

    private func performReceive() async {
        guard let actual = received, let history = retainedHistoryURL, let local,
              let observation, let snapshot, let account else { return }
        stage = .saving
        do {
            try observation.requireCurrent(); try account.validateCurrent()
            try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
            try observation.requireCurrent()
            let native = actual.capture.nativeCapture.snapshot
            let body = TorahAnnotationEnvelope.RichBody(format: AnytypeOriginalEditorSnapshot.format,
                formatVersion: AnytypeOriginalEditorSnapshot.formatVersion, bytes: native.bodyBytes)
            let intent = try local.prepareSave(snapshot: snapshot, mutationID: id,
                body: body, textPreview: actual.capture.textPreview, editorRevision: native.nativeArchiveSHA256)
            let outcome = try await local.saveReceived(intent, actual: actual, enableLink: keepLinked)
            committedOutcome = outcome
            let receipt: AnnotationExchangeCommit
            switch outcome {
            case .committed(let saved): receipt = saved.receipt
            case .completedWithoutOwnership(let saved): receipt = saved
            }
            _ = try? await Task.detached {
                try AnnotationOriginalEditorReceiveHistory.recordCommit(receipt, beside: history)
            }.value
            observation.retire(); local.retire()
            if stage != .closed && stage != .closing { stage = .saved }
        } catch {
            if stage != .closed && stage != .closing { stage = .changed }
        }
    }

    /// Explicit review may resolve prior uncertainty through a NEW original
    /// locked read and conditional revision. Automatic replay never does so.
    func updateExistingVersion() {
        guard operationKind != .receive, stage == .reviewing, operation == nil else { return }
        operation = Task { [self] in
            defer { operation = nil }
            await performUpdate(explicitReview: true)
        }
    }

    private func performUpdate(explicitReview: Bool) async {
        guard let actual = received, let readSource = nativeSource,
              let historyURL = retainedHistoryURL, let local, let observation,
              let snapshot, let account else { return }
        stage = .updating
        do {
            var delivery = selectedDelivery
            if let current = delivery, explicitReview {
                delivery = try await local.acceptLinkedReview(current, snapshot: snapshot, actual: actual)
                linkedState = try await local.linkedState(snapshot: snapshot)
            }
            let prepared = try await AnnotationOriginalEditorRevisionAttempt.prepare(
                local: local, snapshot: snapshot, observation: observation,
                readSource: readSource, read: actual, retainedReadURL: historyURL, account: account,
                linkedDelivery: delivery)
            switch prepared {
            case .recordedWithoutOwnership:
                stage = .changed
            case .prepared(let attempt):
                revisionAttempt = attempt
                switch try await attempt.invoke() {
                case .recordedWithoutOwnership: stage = .unverified
                case .nativeAwaitReturned: applyRevisionOutcome(try await attempt.history.durableOutcome())
                }
            }
        } catch {
            if let attempt = revisionAttempt, let outcome = try? await attempt.history.recordedOutcomeIfDrained() {
                applyRevisionOutcome(outcome)
            } else if stage != .closing && stage != .closed {
                stage = revisionAttempt?.history.dispatch == nil ? .changed : .unverified
            }
        }
    }

    private func applyRevisionOutcome(_ outcome: AnnotationOriginalEditorRevisionOutcome) {
        revisionOutcome = outcome
        guard stage != .closing && stage != .closed else { return }
        switch outcome.kind {
        case .verified: stage = .updated
        case .conflict: stage = .conflict
        case .unverified: stage = .unverified
        }
    }

    func close(retrying: Bool = false) {
        guard canClose || (retrying && stage == .closeFailed), closeTask == nil else { return }
        lifetime.retire(); observation?.retire(); local?.retire(); nativeSource?.retire()
        revisionAttempt?.retire()
        operation?.cancel(); stage = .closing
        closeTask = Task { [self] in
            defer { closeTask = nil }
            do {
                if let presentation {
                    if retrying { try await presentation.retryClose() }
                    else { try await presentation.close() }
                }
                account = nil; presentation = nil; stage = .closed
            } catch { stage = .closeFailed }
        }
    }

    func removed() {
        revisionAttempt?.requestCancellation()
        operation?.cancel()
        if stage == .saving { stage = .changed }
        if stage == .updating { stage = .unverified }
        close()
    }

    isolated deinit {
        revisionAttempt?.retire()
        lifetime.retire(); observation?.retire(); local?.retire(); nativeSource?.retire()
    }
}

@MainActor
struct AnnotationOriginalEditorReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AnnotationOriginalEditorReceivePresentation
    @State private var confirmReplacement = false
    @State private var confirmUpdate = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .opening, .discovering, .reading, .saving, .updating, .closing:
                    ProgressView { Text("Finishing the original Anytype operation…", tableName: "OriginalAnnotationEditor") }
                case .authenticating:
                    if let controller = model.controller {
                        AnnotationOriginalEditorProductionController(controller: controller)
                            .accessibilityIdentifier("annotation-anytype-receive-account")
                    }
                case .choosing:
                    Form {
                        Section {
                            Picker(selection: $model.selectedMappingID) {
                                Text("Choose the shared copy", tableName: "OriginalAnnotationEditor").tag(String?.none)
                                ForEach(model.mappings) { mapping in
                                    Text(mapping.objectID).tag(Optional(mapping.id))
                                }
                            } label: { Text("Anytype copy", tableName: "OriginalAnnotationEditor") }
                            Button { model.readSelected() } label: {
                                Text("Read saved changes", tableName: "OriginalAnnotationEditor")
                            }
                            .disabled(model.selectedMappingID == nil)
                            .accessibilityIdentifier("annotation-anytype-receive-read")
                        } footer: {
                            Text("The note will be read from the account and space you selected.", tableName: "OriginalAnnotationEditor")
                        }
                    }
                case .reviewing:
                    Form {
                        if model.localChangedSinceShare {
                            Section {
                                Label { Text("Both versions need review", tableName: "OriginalAnnotationEditor") }
                                    icon: { Image(systemName: "arrow.triangle.branch") }
                                Text("Both full saved versions are retained. Choose explicitly which version to keep here.", tableName: "OriginalAnnotationEditor")
                            }
                        }
                        Section { Text(model.localPreview).textSelection(.enabled) }
                            header: { Text("Saved on this device", tableName: "OriginalAnnotationEditor") }
                        Section { Text(model.remotePreview).textSelection(.enabled) }
                            header: { Text("Read from Anytype", tableName: "OriginalAnnotationEditor") }
                        if model.operationKind != .update {
                            Section {
                                Toggle(isOn: $model.keepLinked) {
                                    Text("Keep this note linked to this Anytype copy", tableName: "OriginalAnnotationEditor")
                                }
                                .accessibilityIdentifier("annotation-anytype-link-toggle")
                                .disabled(model.isSelectedCopyLinked)
                                if model.isSelectedCopyLinked {
                                    Button { model.unlinkSelectedCopy() } label: {
                                        Text("Unlink this copy", tableName: "OriginalAnnotationEditor")
                                    }
                                    .accessibilityIdentifier("annotation-anytype-unlink")
                                }
                            } footer: {
                                Text("Future saves are queued for this copy. Sync uses the selected original account. Unlink keeps both notes and their history.", tableName: "OriginalAnnotationEditor")
                            }
                        }
                        Section {
                            Button { confirmReplacement = true } label: {
                                if model.operationKind == .update {
                                    Text("Update this copy in Anytype", tableName: "OriginalAnnotationEditor")
                                } else {
                                    Text("Use the Anytype version here", tableName: "OriginalAnnotationEditor")
                                }
                            }
                            .accessibilityIdentifier(model.operationKind == .update ? "annotation-anytype-update-accept" : "annotation-anytype-receive-accept")
                            if model.operationKind == .synchronize {
                                Button { confirmUpdate = true } label: {
                                    Text("Update this copy in Anytype", tableName: "OriginalAnnotationEditor")
                                }
                                .accessibilityIdentifier("annotation-anytype-linked-review-update")
                            }
                            Button { model.close() } label: {
                                Text("Keep both versions unchanged", tableName: "OriginalAnnotationEditor")
                            }
                        } footer: {
                            Text("The preview is plain text. The complete original formatting, objects and files are kept when you save.", tableName: "OriginalAnnotationEditor")
                        }
                    }
                    .accessibilityIdentifier("annotation-anytype-receive-review")

                case .synchronized:
                    ContentUnavailableView {
                        Label { Text("Linked note is up to date", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "checkmark.circle") }
                    }
                    .accessibilityIdentifier("annotation-anytype-linked-current")
                case .waiting:
                    ContentUnavailableView {
                        Label { Text("Linked sync is waiting", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "clock") }
                    } description: {
                        Text("The saved queue is retained. Close and resume sync after the current retry delay.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-linked-waiting")
                case .updated:
                    ContentUnavailableView {
                        Label { Text("Update verified in Anytype", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "checkmark.circle") }
                    } description: {
                        Text("The original engine read back the saved rich note under the same object ID. Visibility on another device is verified separately.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-update-verified")
                case .conflict:
                    ContentUnavailableView {
                        Label { Text("The Anytype note changed", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "arrow.triangle.branch") }
                    } description: {
                        Text("Anytype refused this update before writing because its saved version changed. Both reviewed versions are retained. Close and review the current versions again.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-update-conflict")
                case .unverified:
                    ContentUnavailableView {
                        Label { Text("Check the Anytype version", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "exclamationmark.triangle") }
                    } description: {
                        Text("The operation has no verified readback. A change may already be present. Its history is retained and it will not retry automatically.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-update-unverified")
                case .saved:
                    ContentUnavailableView {
                        Label { Text("Anytype version saved locally", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "checkmark.circle") }
                    } description: {
                        Text("The same note ID and complete original body were saved. Reopen the expanded editor to continue privately.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-receive-saved")
                case .noMapping:
                    ContentUnavailableView {
                        Label { Text("No shared copy in this space", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "square.and.arrow.down") }
                    } description: {
                        Text("No shared copy of this note was found in the selected account and space. Check the selection or share the note from its original device.", tableName: "OriginalAnnotationEditor")
                    } actions: {
                        Button { model.refreshSharedCopies() } label: {
                            Text("Refresh shared copies", tableName: "OriginalAnnotationEditor")
                        }
                        .accessibilityIdentifier("annotation-anytype-refresh-copies")
                    }
                case .changed:
                    ContentUnavailableView {
                        Label { Text("The local note changed", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "arrow.triangle.branch") }
                    } description: {
                        Text("No older version was applied. The full received version is retained. Close and reopen the note to review again.", tableName: "OriginalAnnotationEditor")
                    }
                case .failed:
                    ContentUnavailableView {
                        Label { Text("The original read could not finish", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "exclamationmark.triangle") }
                    } actions: {
                        if model.localStopNeedsRetry {
                            Button { model.retryLocalStop() } label: {
                                Text("Retry closing the private editor", tableName: "OriginalAnnotationEditor")
                            }
                        }
                    }
                case .closeFailed:
                    Button { model.close(retrying: true) } label: {
                        Text("Retry closing Anytype", tableName: "OriginalAnnotationEditor")
                    }
                case .closed: EmptyView()
                }
            }
            .navigationTitle(model.operationKind == .update
                ? Text("Update in Anytype", tableName: "OriginalAnnotationEditor")
                : Text("Receive from Anytype", tableName: "OriginalAnnotationEditor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { model.close() } label: { Text("Close", tableName: "OriginalAnnotationEditor") }
                        .disabled(!model.canClose)
                        .accessibilityIdentifier("annotation-anytype-receive-close")
                }
            }
            .confirmationDialog(model.operationKind == .update
                ? Text("Update this existing Anytype note?", tableName: "OriginalAnnotationEditor")
                : Text("Replace the saved local version?", tableName: "OriginalAnnotationEditor"),
                isPresented: $confirmReplacement, titleVisibility: .visible) {
                Button {
                    if model.operationKind == .update { model.updateExistingVersion() }
                    else { model.acceptReceivedVersion() }
                } label: {
                    if model.operationKind == .update {
                        Text("Update this copy in Anytype", tableName: "OriginalAnnotationEditor")
                    } else {
                        Text("Use the Anytype version here", tableName: "OriginalAnnotationEditor")
                    }
                }
                Button(role: .cancel) {} label: { Text("Cancel", tableName: "OriginalAnnotationEditor") }
            } message: {
                if model.operationKind == .update {
                    Text("Only your saved rich note will update the reviewed Anytype object. The original engine will check its version again before writing. Both full versions are retained.", tableName: "OriginalAnnotationEditor")
                } else {
                    Text("Both complete versions are retained. Your note ID, source anchor, tags and local permissions stay with this note.", tableName: "OriginalAnnotationEditor")
                }
            }
        }
        .confirmationDialog(Text("Update this existing Anytype note?", tableName: "OriginalAnnotationEditor"),
                            isPresented: $confirmUpdate, titleVisibility: .visible) {
            Button { model.updateExistingVersion() } label: {
                Text("Update this copy in Anytype", tableName: "OriginalAnnotationEditor")
            }
            Button(role: .cancel) {} label: { Text("Cancel", tableName: "OriginalAnnotationEditor") }
        } message: {
            Text("Only your saved rich note will update the reviewed Anytype object. The original engine will check its version again before writing. Both full versions are retained.", tableName: "OriginalAnnotationEditor")
        }
        .task { await model.begin() }
        .onDisappear { model.removed() }
        .onChange(of: model.stage) { _, stage in if stage == .closed { dismiss() } }
    }
}

private enum AnnotationOriginalEditorReceiveHistory {
    private struct ReadRecord: Encodable {
        let schema = "otzaria.original.annotation.received.v1"
        let remoteDeviceAcknowledgement = false
        let readID: UUID
        let annotationUUID: UUID
        let capturedLocalRevision: Int64
        let capturedLocalSourceDigest: String
        let capturedLocalPayload: Data
        let receivedNativeBody: Data
        let receivedNativeBodySHA256: String
        let observedNativeRevisionSHA256: String
        let originHostProfileID: String
    }

    static func persist(_ actual: AnytypeOriginalAnnotationReadReceipt,
                        captured: AnnotationLocalEditorSnapshot, readID: UUID) throws -> URL {
        guard let payload = captured.version?.payload,
              actual.capture.nativeCapture.snapshot.provenance.annotationUUID == captured.annotationUUID,
              actual.capture.nativeCapture.snapshot.provenance.capturedAgainstRevision == captured.revision,
              actual.capture.nativeCapture.snapshot.provenance.sourceWitnessSHA256 == captured.source.digest else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        let body = actual.capture.nativeCapture.snapshot.bodyBytes
        let record = ReadRecord(readID: readID, annotationUUID: captured.annotationUUID,
            capturedLocalRevision: captured.revision, capturedLocalSourceDigest: captured.source.digest,
            capturedLocalPayload: payload, receivedNativeBody: body,
            receivedNativeBodySHA256: SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined(),
            observedNativeRevisionSHA256: actual.observedNativeRevisionSHA256,
            originHostProfileID: actual.originHostProfileID)
        let database = captured.databaseURL.standardizedFileURL.resolvingSymlinksInPath()
        let parent = database.deletingLastPathComponent()
            .appendingPathComponent(database.lastPathComponent + ".native-receive-history", isDirectory: true)
        let note = parent.appendingPathComponent(captured.annotationUUID.uuidString, isDirectory: true)
        for directory in [parent, note] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw AnnotationLocalEditorError.wrongOwner
            }
        }
        let url = note.appendingPathComponent(readID.uuidString + ".json")
        try write(record, to: url)
        return url
    }

    static func recordCommit(_ actual: AnnotationExchangeCommit, beside readURL: URL) throws {
        struct Commit: Encodable {
            let schema = "otzaria.original.annotation.received-local-commit.v1"
            let remoteDeviceAcknowledgement = false
            let mutationID: UUID
            let annotationUUID: UUID
            let revision: Int64
            let payloadDigest: String
        }
        try write(Commit(mutationID: actual.mutationID, annotationUUID: actual.annotationUUID,
            revision: actual.revision, payloadDigest: actual.payloadDigest),
            to: readURL.deletingPathExtension().appendingPathExtension("commit.json"))
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(value)
        if FileManager.default.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  values.fileSize == bytes.count, try Data(contentsOf: url) == bytes else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            return
        }
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        guard try Data(contentsOf: url) == bytes else { throw AnnotationLocalEditorError.wrongOwner }
    }
}
#endif
