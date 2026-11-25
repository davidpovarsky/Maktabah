#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import SwiftUI
import Observation
import CryptoKit
import AnytypeOriginalEditor

enum AnnotationOriginalEditorManagedType: String, CaseIterable, Identifiable {
    case annotation, chiddush, article, research
    var id: String { rawValue }
    var documentRole: AnytypeOriginalAnnotationDocumentRole? {
        switch self {
        case .annotation: nil
        case .chiddush: .chiddush
        case .article: .article
        case .research: .research
        }
    }
    var title: String {
        switch self {
        case .annotation: String(localized: "Annotation", table: "OriginalAnnotationEditor")
        case .chiddush: String(localized: "Chiddush", table: "OriginalAnnotationEditor")
        case .article: String(localized: "Article", table: "OriginalAnnotationEditor")
        case .research: String(localized: "Research", table: "OriginalAnnotationEditor")
        }
    }
    var choices: [AnnotationOriginalEditorLifecycleChoice] {
        self == .annotation ? [.archive, .restore, .promoteChiddush, .promoteArticle, .promoteResearch]
            : [.archive, .restore, .revertPromotion, .replaceDocument]
    }
}

enum AnnotationOriginalEditorLifecycleChoice: String, Identifiable {
    case archive, restore, promoteChiddush, promoteArticle, promoteResearch, revertPromotion, replaceDocument
    var id: String { rawValue }
    var action: AnytypeOriginalAnnotationLifecycleAction {
        switch self {
        case .archive: .archive
        case .restore: .restore
        case .promoteChiddush: .promote(.chiddush)
        case .promoteArticle: .promote(.article)
        case .promoteResearch: .promote(.research)
        case .revertPromotion: .revertPromotion
        case .replaceDocument: .replacePromotedDocument
        }
    }
    var promotionRole: AnytypeOriginalAnnotationDocumentRole? {
        switch self {
        case .promoteChiddush: .chiddush
        case .promoteArticle: .article
        case .promoteResearch: .research
        default: nil
        }
    }
    var title: String {
        switch self {
        case .archive: String(localized: "Archive this copy", table: "OriginalAnnotationEditor")
        case .restore: String(localized: "Restore this copy", table: "OriginalAnnotationEditor")
        case .promoteChiddush: String(localized: "Turn into a chiddush", table: "OriginalAnnotationEditor")
        case .promoteArticle: String(localized: "Turn into an article", table: "OriginalAnnotationEditor")
        case .promoteResearch: String(localized: "Turn into research", table: "OriginalAnnotationEditor")
        case .revertPromotion: String(localized: "Return to an annotation", table: "OriginalAnnotationEditor")
        case .replaceDocument: String(localized: "Update this document from the saved note", table: "OriginalAnnotationEditor")
        }
    }
}

/// Each management action uses a fresh saved-row owner, the original selected
/// account/Space, a closed native read and one explicit confirmation. A type
/// choice is a request to validate; it never grants access or fabricates a token.
@MainActor @Observable
final class AnnotationOriginalEditorLifecyclePresentation: Identifiable {
    enum Stage {
        case opening, authenticating, choosing, reading, reviewing, applying, applied
        case conflict, unverified, noMapping, changed, failed, closing, closeFailed, closed
    }
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
    private var received: AnytypeOriginalAnnotationLifecycleObservation?
    private var lifecycleAttempt: AnnotationOriginalEditorLifecycleAttempt?
    private var allMappings: [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] = []
    private var operation: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var began = false
    private(set) var stage = Stage.opening
    private(set) var mappings: [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] = []
    private(set) var reviewedChoice: AnnotationOriginalEditorLifecycleChoice?
    private(set) var retainedHistoryURL: URL?
    private(set) var outcome: AnnotationOriginalEditorLifecycleOutcome?
    private(set) var localChangedSinceShare = false
    private(set) var localStopNeedsRetry = false
    var selectedMappingID: String?
    var selectedType = AnnotationOriginalEditorManagedType.annotation
    var selectedChoice = AnnotationOriginalEditorLifecycleChoice.archive

    var controller: UIViewController? { presentation?.viewController }
    var remotePreview: String { received?.textPreview ?? "" }
    var localPreview: String { snapshot?.annotation.note ?? "" }
    var isArchived: Bool { received?.isArchived == true }
    var observedTypeTitle: String {
        received?.documentRole.flatMap { AnnotationOriginalEditorManagedType(rawValue: $0.rawValue) }?.title
            ?? AnnotationOriginalEditorManagedType.annotation.title
    }
    var canClose: Bool { stage != .applying && stage != .closing && stage != .closed }
    var canApply: Bool {
        guard stage == .reviewing, let choice = reviewedChoice else { return false }
        return !isArchived || choice == .archive || choice == .restore
    }

    init(annotation: Annotation, inspected: AnnotationLocalEditorSnapshot,
         workspace: StudyWorkspaceNavigationAdapter) {
        self.annotation = annotation; self.inspected = inspected; self.workspace = workspace
    }

    func selectedTypeChanged() {
        guard stage == .choosing else { return }
        if !selectedType.choices.contains(selectedChoice) { selectedChoice = .archive }
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
            allMappings = try await Task.detached {
                try AnnotationOriginalEditorNativeReceiptFile.mappings(
                    annotationUUID: captured.annotationUUID, capturedDatabaseURL: captured.databaseURL)
            }.value
            try observed.requireCurrent()
            guard !allMappings.isEmpty else { stage = .noMapping; return }
            localStopNeedsRetry = true
            try await AnytypeOriginalEditorModule.suspendLocalAnnotationRuntime(
                appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
            localStopNeedsRetry = false
            try observed.requireCurrent(); try Task.checkCancellation()
            try presentAccount()
        } catch { fail() }
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
            mappings = allMappings.filter {
                $0.accountID.utf8.elementsEqual(session.identity.accountID.utf8)
                    && $0.spaceID.utf8.elementsEqual(session.identity.spaceID.utf8)
            }
            selectedMappingID = mappings.count == 1 ? mappings[0].id : nil
            stage = mappings.isEmpty ? .noMapping : .choosing
        } catch { fail() }
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
        guard stage == .choosing, operation == nil, selectedType.choices.contains(selectedChoice),
              let mapping = mappings.first(where: { $0.id == selectedMappingID }),
              let local, let observation, let snapshot, let account else { return }
        let kind = selectedType, choice = selectedChoice
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
                let actual: AnytypeOriginalAnnotationLifecycleObservation
                if let role = kind.documentRole {
                    actual = try await account.readOriginalPromotedDocument(binding: binding,
                        documentRole: role, sourceLifetime: source,
                        maximumBodyBytes: TorahAnnotationPayloadLimits.maximumBodyBytes
                    ) { [observation, local] candidate in
                        candidate == binding && observation.isCurrent && local.isCurrent
                    }
                } else {
                    actual = try await account.readOriginalAnnotationLifecycle(binding: binding,
                        sourceLifetime: source, promotionRole: choice.promotionRole,
                        maximumBodyBytes: TorahAnnotationPayloadLimits.maximumBodyBytes
                    ) { [observation, local] candidate in
                        candidate == binding && observation.isCurrent && local.isCurrent
                    }
                }
                received = actual
                let readID = id
                retainedHistoryURL = try await Task.detached {
                    try AnnotationOriginalEditorLifecycleFile.persistRead(actual,
                        captured: snapshot, readID: readID)
                }.value
                try observation.requireCurrent()
                try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
                try observation.requireCurrent(); try account.validateCurrent()
                guard selectedType == kind, selectedChoice == choice,
                      actual.documentRole == kind.documentRole else { throw AnnotationLocalEditorError.wrongOwner }
                let current = try AnnotationOriginalEditorMount.nativeBody(in: snapshot)
                localChangedSinceShare = current.map {
                    SHA256.hash(data: $0.bodyBytes).map { String(format: "%02x", $0) }.joined()
                        != mapping.bodyDigest
                } ?? true
                reviewedChoice = choice
                stage = .reviewing
            } catch {
                if stage != .closing && stage != .closed { stage = retainedHistoryURL == nil ? .failed : .changed }
            }
        }
    }

    func applyReviewedChoice() {
        guard canApply, operation == nil, let choice = reviewedChoice,
              let actual = received, let readSource = nativeSource,
              let historyURL = retainedHistoryURL, let local, let observation,
              let snapshot, let account else { return }
        stage = .applying
        operation = Task { [self] in
            defer { operation = nil }
            do {
                let prepared = try await AnnotationOriginalEditorLifecycleAttempt.prepare(
                    local: local, snapshot: snapshot, observation: observation,
                    readSource: readSource, read: actual, action: choice.action,
                    retainedReadURL: historyURL, account: account)
                switch prepared {
                case .recordedWithoutOwnership:
                    if stage != .closing && stage != .closed { stage = .changed }
                case .prepared(let attempt):
                    lifecycleAttempt = attempt
                    let invoked = try await attempt.invoke()
                    switch invoked {
                    case .recordedWithoutOwnership:
                        if stage != .closing && stage != .closed { stage = .unverified }
                    case .nativeAwaitReturned:
                        applyOutcome(try await attempt.history.durableOutcome())
                    }
                }
            } catch {
                if let attempt = lifecycleAttempt,
                   let actualOutcome = try? await attempt.history.recordedOutcomeIfDrained() {
                    applyOutcome(actualOutcome)
                } else if stage != .closing && stage != .closed {
                    stage = lifecycleAttempt?.history.dispatch == nil ? .changed : .unverified
                }
            }
        }
    }

    private func applyOutcome(_ value: AnnotationOriginalEditorLifecycleOutcome) {
        outcome = value
        guard stage != .closing && stage != .closed else { return }
        switch value.kind {
        case .verified: stage = .applied
        case .conflict: stage = .conflict
        case .unverified: stage = .unverified
        }
    }

    func close(retrying: Bool = false) {
        guard canClose || (retrying && stage == .closeFailed), closeTask == nil else { return }
        lifetime.retire(); observation?.retire(); local?.retire(); nativeSource?.retire()
        lifecycleAttempt?.retire()
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
        lifecycleAttempt?.requestCancellation()
        operation?.cancel()
        if stage == .applying { stage = .unverified }
        close()
    }

    isolated deinit {
        lifecycleAttempt?.retire()
        lifetime.retire(); observation?.retire(); local?.retire(); nativeSource?.retire()
    }
}

@MainActor
struct AnnotationOriginalEditorLifecycleView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AnnotationOriginalEditorLifecyclePresentation
    @State private var confirmAction = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .opening, .reading, .applying, .closing:
                    ProgressView { Text("Finishing the original Anytype operation…", tableName: "OriginalAnnotationEditor") }
                case .authenticating:
                    if let controller = model.controller {
                        AnnotationOriginalEditorProductionController(controller: controller)
                            .accessibilityIdentifier("annotation-anytype-manage-account")
                    }
                case .choosing: choose
                case .reviewing: review
                case .applied:
                    ContentUnavailableView {
                        Label { Text("Change verified in Anytype", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "checkmark.circle") }
                    } description: {
                        Text("The copy was read back with the requested change. Its source links and object ID were preserved. Visibility on another device is checked separately.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-manage-verified")
                case .conflict:
                    ContentUnavailableView {
                        Label { Text("The Anytype copy changed", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "arrow.triangle.branch") }
                    } description: {
                        Text("The current content, archive status or type changed before this action. Nothing from this action was applied. Close and review the current copy again.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-manage-conflict")
                case .unverified:
                    ContentUnavailableView {
                        Label { Text("Check the Anytype version", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "exclamationmark.triangle") }
                    } description: {
                        Text("The operation has no verified readback. A change may already be present. Its history is retained and it will not retry automatically.", tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-manage-unverified")
                case .noMapping:
                    ContentUnavailableView {
                        Label { Text("No shared copy in this space", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "square.and.arrow.up") }
                    } description: {
                        Text("Share this saved note with Anytype first, then select that account and space to manage the copy.", tableName: "OriginalAnnotationEditor")
                    }
                case .changed:
                    ContentUnavailableView {
                        Label { Text("The local note changed", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "arrow.triangle.branch") }
                    } description: {
                        Text("Close and reopen the saved note before choosing this action again. The versions already read are retained.", tableName: "OriginalAnnotationEditor")
                    }
                case .failed:
                    ContentUnavailableView {
                        Label { Text("The Anytype copy could not be checked", tableName: "OriginalAnnotationEditor") }
                            icon: { Image(systemName: "exclamationmark.triangle") }
                    } description: {
                        Text("Close and check the selected account, space and current type of the copy before opening it again.", tableName: "OriginalAnnotationEditor")
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
            .navigationTitle(Text("Manage the Anytype copy", tableName: "OriginalAnnotationEditor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { model.close() } label: { Text("Close", tableName: "OriginalAnnotationEditor") }
                        .disabled(!model.canClose)
                        .accessibilityIdentifier("annotation-anytype-manage-close")
                }
            }
            .confirmationDialog(Text("Apply this change in Anytype?", tableName: "OriginalAnnotationEditor"),
                isPresented: $confirmAction, titleVisibility: .visible) {
                if let choice = model.reviewedChoice {
                    Button { model.applyReviewedChoice() } label: { Text(verbatim: choice.title) }
                        .accessibilityIdentifier("annotation-anytype-manage-confirm")
                }
                Button(role: .cancel) {} label: { Text("Cancel", tableName: "OriginalAnnotationEditor") }
            } message: {
                Text("Only the saved copy you reviewed will be changed. Your local note, source anchor and unsaved drafts stay as they are.", tableName: "OriginalAnnotationEditor")
            }
        }
        .task { await model.begin() }
        .onDisappear { model.removed() }
        .onChange(of: model.stage) { _, stage in if stage == .closed { dismiss() } }
    }

    private var choose: some View {
        Form {
            Section {
                Picker(selection: $model.selectedMappingID) {
                    Text("Choose the shared copy", tableName: "OriginalAnnotationEditor").tag(String?.none)
                    ForEach(Array(model.mappings.enumerated()), id: \.element.id) { index, mapping in
                        Text("Shared copy \(index + 1)", tableName: "OriginalAnnotationEditor").tag(Optional(mapping.id))
                    }
                } label: { Text("Anytype copy", tableName: "OriginalAnnotationEditor") }
                .accessibilityIdentifier("annotation-anytype-manage-copy")
                Picker(selection: $model.selectedType) {
                    ForEach(AnnotationOriginalEditorManagedType.allCases) { type in
                        Text(verbatim: type.title).tag(type)
                    }
                } label: { Text("Current type in Anytype", tableName: "OriginalAnnotationEditor") }
                .accessibilityIdentifier("annotation-anytype-manage-type")
                .onChange(of: model.selectedType) { _, _ in model.selectedTypeChanged() }
                Picker(selection: $model.selectedChoice) {
                    ForEach(model.selectedType.choices) { choice in
                        Text(verbatim: choice.title).tag(choice)
                    }
                } label: { Text("Action", tableName: "OriginalAnnotationEditor") }
                .accessibilityIdentifier("annotation-anytype-manage-action")
                Button { model.readSelected() } label: {
                    Text("Read and review this copy", tableName: "OriginalAnnotationEditor")
                }
                .disabled(model.selectedMappingID == nil)
                .accessibilityIdentifier("annotation-anytype-manage-read")
            } footer: {
                Text("Choose the current type of the copy in Anytype. Its actual content, type and archive status will be checked before you confirm a change.", tableName: "OriginalAnnotationEditor")
            }
        }
    }

    private var review: some View {
        Form {
            Section {
                LabeledContent { Text(verbatim: model.observedTypeTitle) }
                    label: { Text("Current type in Anytype", tableName: "OriginalAnnotationEditor") }
                LabeledContent {
                    if model.isArchived { Text("Archived", tableName: "OriginalAnnotationEditor") }
                    else { Text("Active", tableName: "OriginalAnnotationEditor") }
                } label: { Text("Status", tableName: "OriginalAnnotationEditor") }
                if let choice = model.reviewedChoice {
                    LabeledContent { Text(verbatim: choice.title) }
                        label: { Text("Requested action", tableName: "OriginalAnnotationEditor") }
                }
            }
            if model.reviewedChoice == .replaceDocument {
                Section { Text(model.localPreview).textSelection(.enabled) }
                    header: { Text("Saved on this device", tableName: "OriginalAnnotationEditor") }
                if model.localChangedSinceShare {
                    Section {
                        Text("Your saved note changed since it was shared. Review both versions before updating this document.", tableName: "OriginalAnnotationEditor")
                    }
                }
            }
            Section { Text(model.remotePreview).textSelection(.enabled) }
                header: { Text("Read from Anytype", tableName: "OriginalAnnotationEditor") }
            Section {
                Button { confirmAction = true } label: {
                    Text("Confirm the reviewed action", tableName: "OriginalAnnotationEditor")
                }
                .disabled(!model.canApply)
                .accessibilityIdentifier("annotation-anytype-manage-apply")
                Button { model.close() } label: {
                    Text("Keep both versions unchanged", tableName: "OriginalAnnotationEditor")
                }
                if !model.canApply {
                    Text("Restore this copy before changing its content or type.", tableName: "OriginalAnnotationEditor")
                }
            } footer: {
                Text("Archiving moves the copy to Anytype's archive. Changing its type keeps the same copy and source links. Return a document to an annotation before receiving it into this note.", tableName: "OriginalAnnotationEditor")
            }
        }
        .accessibilityIdentifier("annotation-anytype-manage-review")
    }
}
#endif
