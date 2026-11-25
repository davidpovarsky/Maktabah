#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import SwiftUI
import Observation
import AnytypeOriginalEditor

/// Normal note editing can never replace an opaque rich body with its preview.
enum AnnotationOriginalEditorAvailability: Equatable {
    case checking, plain, rich, unavailable

    var allowsPlainEditing: Bool { self == .plain }
    var allowsExpansion: Bool { self == .plain || self == .rich }
}

/// Compare the mounted quick editor at the actual tap, including whitespace.
/// Static text from another window never grants ownership of this note.
struct AnnotationOriginalEditorEntryDraft {
    let text: String
    let nativeText: String?
    let nativeEditorIsMounted: Bool
    let selectedColorHex: String
    let isUnderline: Bool
    let tagsText: String

    func requireUnchanged(_ annotation: Annotation) throws {
        guard let id = annotation.id, id > 0,
              let recordID = annotation.ckRecordId, !recordID.isEmpty else {
            throw AnnotationOriginalEditorUIError.saveFirst
        }
        let originalColor = annotation.type == .underline
            && (annotation.colorHex.isEmpty || annotation.colorHex == "#000000")
            ? "#000000" : annotation.colorHex
        let originalText = annotation.note ?? ""
        guard nativeEditorIsMounted, let nativeText,
              text.utf8.elementsEqual(originalText.utf8),
              nativeText.utf8.elementsEqual(originalText.utf8),
              isUnderline == (annotation.type == .underline),
              selectedColorHex.utf8.elementsEqual(originalColor.utf8),
              tagsText.utf8.elementsEqual(annotation.tags.joined(separator: ", ").utf8) else {
            throw AnnotationOriginalEditorUIError.saveChangesFirst
        }
    }
}

private enum AnnotationOriginalEditorUIError: LocalizedError {
    case saveFirst, saveChangesFirst, unavailable, changed, closed
    var errorDescription: String? {
        switch self {
        case .saveFirst:
            String(localized: "Save this note before opening the expanded editor.", table: "OriginalAnnotationEditor")
        case .saveChangesFirst:
            String(localized: "Save your text, style and tag changes first.", table: "OriginalAnnotationEditor")
        case .unavailable:
            String(localized: "The expanded editor is unavailable for this note.", table: "OriginalAnnotationEditor")
        case .changed:
            String(localized: "This note changed. Close this sheet and open the note again.", table: "OriginalAnnotationEditor")
        case .closed:
            String(localized: "The editor has closed.", table: "OriginalAnnotationEditor")
        }
    }
}

@MainActor
struct AnnotationOriginalEditorProductionEntry: View {
    @Environment(\.exact9401Workspace) private var workspace
    let annotation: Annotation
    let draft: @MainActor () -> AnnotationOriginalEditorEntryDraft
    @Binding var availability: AnnotationOriginalEditorAvailability
    let closeOriginalSheet: @MainActor () -> Void

    @State private var inspected: AnnotationLocalEditorSnapshot?
    @State private var inspection: AnnotationLocalEditorSession?
    @State private var presentation: AnnotationOriginalEditorProductionPresentation?
    @State private var entryMessage: String?
    @State private var sharePresentation: AnnotationOriginalEditorSharePresentation?
    @State private var receivePresentation: AnnotationOriginalEditorReceivePresentation?

    static var qualificationOwnsEntry: Bool {
        #if DEBUG && targetEnvironment(simulator)
        AnnotationOriginalEditorQualificationEntry.isRequested
        #else
        false
        #endif
    }

    private var entryError: String? {
        do {
            try draft().requireUnchanged(annotation)
            guard workspace != nil, availability.allowsExpansion, inspected != nil else {
                throw AnnotationOriginalEditorUIError.unavailable
            }
            return nil
        } catch { return error.localizedDescription }
    }

    var body: some View {
        if !Self.qualificationOwnsEntry {
            ThemeSection {
                Button {
                    do {
                        try draft().requireUnchanged(annotation)
                        guard let workspace, let inspected, availability.allowsExpansion else {
                            throw AnnotationOriginalEditorUIError.unavailable
                        }
                        presentation = .init(annotation: annotation, inspected: inspected, workspace: workspace)
                    } catch { entryMessage = error.localizedDescription }
                } label: {
                    Label {
                        Text("Open expanded editor", tableName: "OriginalAnnotationEditor")
                    } icon: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
                .accessibilityIdentifier("annotation-expanded-editor-open")
                .disabled(entryError != nil)

                if availability == .rich {
                    Button {
                        do {
                            try draft().requireUnchanged(annotation)
                            guard let workspace, let inspected, availability == .rich else {
                                throw AnnotationOriginalEditorUIError.unavailable
                            }
                            sharePresentation = .init(annotation: annotation,
                                inspected: inspected, workspace: workspace)
                        } catch { entryMessage = error.localizedDescription }
                    } label: {
                        Label {
                            Text("Share saved note with Anytype", tableName: "OriginalAnnotationEditor")
                        } icon: { Image(systemName: "square.and.arrow.up") }
                    }
                    .accessibilityIdentifier("annotation-anytype-share-open")
                    .disabled(entryError != nil)

                    Button {
                        do {
                            try draft().requireUnchanged(annotation)
                            guard let workspace, let inspected, availability == .rich else {
                                throw AnnotationOriginalEditorUIError.unavailable
                            }
                            receivePresentation = .init(annotation: annotation,
                                inspected: inspected, workspace: workspace)
                        } catch { entryMessage = error.localizedDescription }
                    } label: {
                        Label {
                            Text("Receive saved changes from Anytype", tableName: "OriginalAnnotationEditor")
                        } icon: { Image(systemName: "square.and.arrow.down") }
                    }
                    .accessibilityIdentifier("annotation-anytype-receive-open")
                    .disabled(entryError != nil)
                }

                if availability == .checking {
                    ProgressView {
                        Text("Checking the saved note…", tableName: "OriginalAnnotationEditor")
                    }
                } else if availability == .rich {
                    Text("This note has rich formatting. Use the expanded editor to preserve it.",
                         tableName: "OriginalAnnotationEditor")
                        .font(.footnote)
                }
                if let message = entryMessage ?? entryError {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("annotation-expanded-editor-entry-status")
                }
            }
            .task { await inspectSavedNote() }
            .onDisappear {
                inspection?.retire()
                inspection = nil
            }
            .fullScreenCover(item: $receivePresentation, onDismiss: {
                closeOriginalSheet()
            }) { model in
                AnnotationOriginalEditorReceiveView(model: model)
                    .interactiveDismissDisabled(true)
            }
            .fullScreenCover(item: $sharePresentation, onDismiss: {
                closeOriginalSheet()
            }) { model in
                AnnotationOriginalEditorShareView(model: model)
                    .interactiveDismissDisabled(true)
            }
            .fullScreenCover(item: $presentation, onDismiss: {
                // Do not return to a stale plain Save action after native editing.
                closeOriginalSheet()
            }) { model in
                AnnotationOriginalEditorProductionView(model: model)
                    .interactiveDismissDisabled(true)
            }
        }
    }

    private func inspectSavedNote() async {
        inspection?.retire()
        inspection = nil
        inspected = nil
        entryMessage = nil
        guard let id = annotation.id, id > 0,
              let recordID = annotation.ckRecordId, !recordID.isEmpty else {
            availability = .plain
            return
        }
        availability = .checking
        do {
            guard let uuid = try AnnotationStore.shared.resolveAnnotationExchangeIdentity(annotation: annotation) else {
                availability = .plain
                return
            }
            let local = try AnnotationStore.shared.makeLocalAnnotationEditor(
                annotation: annotation, supportedFormats: AnnotationOriginalEditorMount.supportedFormats
            )
            inspection = local
            defer { local.retire() }
            let snapshot = try await local.read()
            try Task.checkCancellation()
            guard snapshot.annotation.id == annotation.id,
                  snapshot.annotationUUID == uuid,
                  snapshot.annotation.ckRecordId.map({ Array($0.utf8) }) == annotation.ckRecordId.map({ Array($0.utf8) }),
                  snapshot.annotation.bkId == annotation.bkId,
                  snapshot.annotation.contentId == annotation.contentId,
                  snapshot.annotation.backendLocator == annotation.backendLocator,
                  snapshot.annotation.context.utf8.elementsEqual(annotation.context.utf8),
                  (snapshot.annotation.note ?? "").utf8.elementsEqual((annotation.note ?? "").utf8),
                  snapshot.annotation.colorHex.utf8.elementsEqual(annotation.colorHex.utf8),
                  snapshot.annotation.type == annotation.type,
                  snapshot.annotation.tags.map({ Array($0.utf8) }) == annotation.tags.map({ Array($0.utf8) }) else {
                throw AnnotationOriginalEditorUIError.changed
            }
            let native = try AnnotationOriginalEditorMount.nativeBody(in: snapshot)
            inspected = snapshot
            availability = native == nil ? .plain : .rich
        } catch {
            guard !Task.isCancelled else { return }
            availability = .unavailable
            entryMessage = String(localized: "The saved note could not be checked. Close and reopen it before editing.",
                                  table: "OriginalAnnotationEditor")
        }
    }
}

@MainActor @Observable
private final class AnnotationOriginalEditorProductionPresentation: Identifiable {
    enum Stage { case opening, editing, saving, saved, failed, closed }

    let id = UUID()
    let annotation: Annotation
    private let inspected: AnnotationLocalEditorSnapshot
    private let workspace: StudyWorkspaceNavigationAdapter
    private let presentationLifetime = AnnotationLocalEditorLifetime()
    private var local: AnnotationLocalEditorSession?
    private var source: AnnotationOriginalEditorSourceObservation?
    private var operation: Task<Void, Never>?
    private var started = false
    private var closed = false
    private(set) var mount: AnnotationOriginalEditorMount?
    private(set) var stage: Stage = .opening

    init(annotation: Annotation, inspected: AnnotationLocalEditorSnapshot,
         workspace: StudyWorkspaceNavigationAdapter) {
        self.annotation = annotation
        self.inspected = inspected
        self.workspace = workspace
    }

    var canSave: Bool { stage == .editing && !closed }
    var canClose: Bool { stage != .saving }

    func begin() async {
        guard !started, !closed else { return }
        started = true
        do {
            let observation = try AnnotationOriginalEditorSourceObservation(
                annotation: annotation, store: AnnotationStore.shared, workspace: workspace,
                presentationLifetime: presentationLifetime
            )
            source = observation
            let local = try AnnotationStore.shared.makeLocalAnnotationEditor(
                annotation: annotation, supportedFormats: AnnotationOriginalEditorMount.supportedFormats
            )
            self.local = local
            try observation.bindLocal(local)
            let snapshot = try await local.read()
            try observation.requireCurrent()
            // The inspection is only a comparison witness. A fresh original
            // session owns this operation, and never adopts a changed row.
            guard snapshot.annotationUUID == inspected.annotationUUID,
                  snapshot.annotation.id == inspected.annotation.id,
                  snapshot.databaseURL.absoluteString.utf8.elementsEqual(inspected.databaseURL.absoluteString.utf8),
                  snapshot.source == inspected.source,
                  snapshot.revision == inspected.revision,
                  snapshot.version == inspected.version else {
                throw AnnotationOriginalEditorUIError.changed
            }
            let opened = try await AnnotationOriginalEditorMount.openLocalAnnotation(
                local: local, snapshot: snapshot, source: observation,
                appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier
            )
            guard !closed, !Task.isCancelled else {
                opened.retire()
                throw AnnotationOriginalEditorUIError.closed
            }
            mount = opened
            stage = .editing
        } catch {
            mount?.retire()
            source?.retire()
            local?.retire()
            if !closed { stage = .failed }
        }
    }

    func save() {
        guard canSave, operation == nil, let mount else { return }
        stage = .saving
        operation = Task { [self] in
            defer { operation = nil }
            do {
                let outcome = try await mount.save()
                // Either outcome is a real durable commit, even if its old
                // presentation lost authority while the SQLite worker ran.
                switch outcome {
                case .committed, .completedWithoutOwnership:
                    if !closed { stage = .saved }
                }
            } catch {
                // Keep mount and its original retained capture for recovery.
                // No automatic native recapture or uncertain commit retry.
                if !closed { stage = .failed }
            }
        }
    }

    func close() {
        guard canClose else { return }
        retire()
    }

    func retire() {
        guard !closed else { return }
        closed = true
        presentationLifetime.retire()
        operation?.cancel()
        mount?.retire()
        source?.retire()
        local?.retire()
        stage = .closed
    }

    isolated deinit {
        presentationLifetime.retire()
        operation?.cancel()
        mount?.retire()
        source?.retire()
        local?.retire()
    }
}

@MainActor
private struct AnnotationOriginalEditorProductionView: View {
    @Environment(\.dismiss) private var dismiss
    let model: AnnotationOriginalEditorProductionPresentation
    @State private var showDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .opening:
                    ProgressView {
                        Text("Opening the saved note…", tableName: "OriginalAnnotationEditor")
                    }
                case .editing, .saving:
                    if let mount = model.mount {
                        AnnotationOriginalEditorProductionController(controller: mount.viewController)
                            .id(ObjectIdentifier(mount.viewController))
                            .accessibilityIdentifier("annotation-expanded-editor-host")
                            .accessibilityElement(children: .contain)
                            .disabled(model.stage == .saving)
                    }
                case .saved:
                    ContentUnavailableView {
                        Label {
                            Text("Note saved", tableName: "OriginalAnnotationEditor")
                        } icon: { Image(systemName: "checkmark.circle") }
                    } description: {
                        Text("The full note has been saved. You can close the editor.",
                             tableName: "OriginalAnnotationEditor")
                    }
                case .failed:
                    ContentUnavailableView {
                        Label {
                            Text("The editor could not finish", tableName: "OriginalAnnotationEditor")
                        } icon: { Image(systemName: "exclamationmark.triangle") }
                    } description: {
                        Text("Close the editor and reopen the note to check the saved version.",
                             tableName: "OriginalAnnotationEditor")
                    }
                case .closed:
                    EmptyView()
                }
            }
            .navigationTitle(Text("Expanded note", tableName: "OriginalAnnotationEditor"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                DisclosureGroup {
                    Text(model.annotation.context)
                        .font(.callout)
                        .lineLimit(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("The formatted note is stored on this device.",
                         tableName: "OriginalAnnotationEditor")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } label: {
                    Label(model.annotation.resolvedBookTitle, systemImage: "book.closed")
                        .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if model.canSave { showDiscardConfirmation = true }
                        else { model.close(); dismiss() }
                    } label: {
                        Text("Close", tableName: "OriginalAnnotationEditor")
                    }
                    .disabled(!model.canClose)
                    .accessibilityIdentifier("annotation-expanded-editor-close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.stage == .saving {
                        ProgressView()
                            .accessibilityLabel(Text("Saving note…", tableName: "OriginalAnnotationEditor"))
                    } else if model.canSave {
                        Button { model.save() } label: {
                            Text("Save", tableName: "OriginalAnnotationEditor")
                        }
                        .accessibilityIdentifier("annotation-expanded-editor-save")
                    }
                }
            }
            .confirmationDialog(
                Text("Discard this draft?", tableName: "OriginalAnnotationEditor"),
                isPresented: $showDiscardConfirmation, titleVisibility: .visible
            ) {
                Button(role: .destructive) { model.close(); dismiss() } label: {
                    Text("Discard draft", tableName: "OriginalAnnotationEditor")
                }
                Button(role: .cancel) {} label: {
                    Text("Continue editing", tableName: "OriginalAnnotationEditor")
                }
            } message: {
                Text("The saved note will stay unchanged.", tableName: "OriginalAnnotationEditor")
            }
        }
        .task { await model.begin() }
        .onDisappear { model.retire() }
    }
}

/// The source is frozen before authentication. Neither a changed row nor a
/// newly selected profile may be silently adopted after the account UI returns.
@MainActor @Observable
private final class AnnotationOriginalEditorSharePresentation: Identifiable {
    enum Stage { case opening, authenticating, confirmation, sending, copied, failed, closing, closeFailed, closed }
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
    private var attempt: AnnotationOriginalEditorImportAttempt?
    private var operation: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var began = false
    private(set) var stage = Stage.opening
    private(set) var receiptURL: URL?
    private(set) var localStopNeedsRetry = false
    var controller: UIViewController? { presentation?.viewController }
    var spaceID: String? { account?.identity.spaceID }
    var canClose: Bool { stage != .sending && stage != .closing && stage != .closed }

    init(annotation: Annotation, inspected: AnnotationLocalEditorSnapshot,
         workspace: StudyWorkspaceNavigationAdapter) {
        self.annotation = annotation
        self.inspected = inspected
        self.workspace = workspace
    }

    func begin() async {
        guard !began else { return }
        began = true
        do {
            let observation = try AnnotationOriginalEditorSourceObservation(
                annotation: annotation, store: AnnotationStore.shared,
                workspace: workspace, presentationLifetime: lifetime)
            self.observation = observation
            let local = try AnnotationStore.shared.makeLocalAnnotationEditor(
                annotation: annotation, supportedFormats: AnnotationOriginalEditorMount.supportedFormats)
            self.local = local
            try observation.bindLocal(local)
            let snapshot = try await local.read()
            try observation.requireCurrent()
            guard snapshot.annotationUUID == inspected.annotationUUID,
                  snapshot.source == inspected.source, snapshot.revision == inspected.revision,
                  snapshot.version == inspected.version,
                  snapshot.databaseURL == inspected.databaseURL,
                  try AnnotationOriginalEditorMount.nativeBody(in: snapshot) != nil else {
                throw AnnotationOriginalEditorUIError.changed
            }
            self.snapshot = snapshot
            localStopNeedsRetry = true
            try await AnytypeOriginalEditorModule.suspendLocalAnnotationRuntime(
                appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
            localStopNeedsRetry = false
            try observation.requireCurrent()
            try Task.checkCancellation()
            presentation = try AnytypeOriginalEditorAccountSession.makePresentation(
                appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier,
                onReady: { [weak self] session in self?.selected(session) },
                onFailure: { [weak self] _ in self?.authenticationFailed() })
            stage = .authenticating
        } catch {
            if stage != .closing && stage != .closed { stage = .failed }
        }
    }

    func retryLocalStop() {
        guard stage == .failed, localStopNeedsRetry, presentation == nil,
              operation == nil, let observation else { return }
        stage = .opening
        operation = Task { [self] in
            defer { operation = nil }
            do {
                try await AnytypeOriginalEditorModule.retrySuspendLocalAnnotationRuntime(
                    appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
                localStopNeedsRetry = false
                try observation.requireCurrent()
                try Task.checkCancellation()
                presentation = try AnytypeOriginalEditorAccountSession.makePresentation(
                    appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier,
                    onReady: { [weak self] session in self?.selected(session) },
                    onFailure: { [weak self] _ in self?.authenticationFailed() })
                stage = .authenticating
            } catch {
                if stage != .closing && stage != .closed { stage = .failed }
            }
        }
    }

    private func selected(_ session: AnytypeOriginalEditorAccountSession) {
        guard stage == .authenticating else { return }
        do {
            try observation?.requireCurrent()
            guard lifetime.isCurrent, observation != nil else { throw AnnotationOriginalEditorUIError.closed }
            try session.validateCurrent()
            account = session
            stage = .confirmation
        } catch { stage = .failed }
    }

    private func authenticationFailed() {
        guard stage != .closing, stage != .closed, stage != .closeFailed else { return }
        stage = .failed
    }

    func sendSavedNote() {
        guard stage == .confirmation, operation == nil,
              let local, let snapshot, let observation, let account else { return }
        stage = .sending
        operation = Task { [self] in
            defer { operation = nil }
            do {
                try observation.requireCurrent()
                try account.validateCurrent()
                let prepared = try await AnnotationOriginalEditorImportAttempt.prepare(
                    local: local, snapshot: snapshot, observation: observation, account: account)
                switch prepared {
                case .recordedWithoutOwnership:
                    throw AnnotationOriginalEditorUIError.changed
                case .prepared(let attempt):
                    self.attempt = attempt
                    let invocation = try await attempt.invoke()
                    switch invocation {
                    case .recordedWithoutOwnership:
                        throw AnnotationOriginalEditorUIError.changed
                    case .nativeAwaitReturned:
                        // The returned await is NOT success. Only its independent
                        // genuine readback and completed durable write earn this UI.
                        receiptURL = try await attempt.history.durableNativeReceipt()
                        stage = .copied
                    }
                }
            } catch { stage = .failed }
        }
    }

    func close(retrying: Bool = false) {
        guard canClose || (retrying && stage == .closeFailed) else { return }
        guard closeTask == nil else { return }
        lifetime.retire()
        observation?.retire()
        local?.retire()
        attempt?.retire()
        stage = .closing
        closeTask = Task { [self] in
            defer { closeTask = nil }
            do {
                if let presentation {
                    if retrying { try await presentation.retryClose() }
                    else { try await presentation.close() }
                }
                account = nil
                presentation = nil
                stage = .closed
            } catch { stage = .closeFailed }
        }
    }

    func removed() {
        // Covers scene/window removal independently of the close button. The
        // original one-use import keeps its late drained history and never retries.
        attempt?.requestCancellation()
        operation?.cancel()
        if stage == .sending { stage = .failed }
        close()
    }

    isolated deinit {
        lifetime.retire()
        observation?.retire()
        local?.retire()
        attempt?.retire()
    }
}

@MainActor
private struct AnnotationOriginalEditorShareView: View {
    @Environment(\.dismiss) private var dismiss
    let model: AnnotationOriginalEditorSharePresentation

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .opening, .sending, .closing:
                    ProgressView {
                        Text("Finishing the original Anytype operation…", tableName: "OriginalAnnotationEditor")
                    }
                case .authenticating:
                    if let controller = model.controller {
                        AnnotationOriginalEditorProductionController(controller: controller)
                            .accessibilityIdentifier("annotation-anytype-original-account")
                    }
                case .confirmation:
                    VStack(spacing: 20) {
                        Text("Send this saved note?", tableName: "OriginalAnnotationEditor").font(.title2)
                        Text("Only the saved rich note will be copied to the selected Anytype space.",
                             tableName: "OriginalAnnotationEditor")
                        if let spaceID = model.spaceID {
                            Text(spaceID).font(.caption).textSelection(.enabled)
                                .accessibilityIdentifier("annotation-anytype-selected-space")
                        }
                        Button { model.sendSavedNote() } label: {
                            Text("Send saved note", tableName: "OriginalAnnotationEditor")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("annotation-anytype-share-confirm")
                    }.padding()
                case .copied:
                    ContentUnavailableView {
                        Label {
                            Text("Copy verified in Anytype", tableName: "OriginalAnnotationEditor")
                        } icon: { Image(systemName: "checkmark.circle") }
                    } description: {
                        Text("Anytype read back the complete note and its object mapping. Delivery to another device has not yet been verified.",
                             tableName: "OriginalAnnotationEditor")
                    }
                    .accessibilityIdentifier("annotation-anytype-native-copy-verified")
                case .failed:
                    ContentUnavailableView {
                        Label {
                            Text("Sharing could not finish", tableName: "OriginalAnnotationEditor")
                        } icon: { Image(systemName: "exclamationmark.triangle") }
                    } description: {
                        Text("Close this screen and check Anytype before trying again. A started transfer may already have created a copy; it will not be sent twice automatically.",
                             tableName: "OriginalAnnotationEditor")
                    } actions: {
                        if model.localStopNeedsRetry {
                            Button { model.retryLocalStop() } label: {
                                Text("Retry closing the local editor", tableName: "OriginalAnnotationEditor")
                            }
                            .accessibilityIdentifier("annotation-anytype-retry-local-stop")
                        }
                    }
                case .closeFailed:
                    VStack(spacing: 20) {
                        Text("Anytype has not finished closing. Retry the original close operation before switching accounts.",
                             tableName: "OriginalAnnotationEditor")
                        Button { model.close(retrying: true) } label: {
                            Text("Retry close", tableName: "OriginalAnnotationEditor")
                        }
                        .accessibilityIdentifier("annotation-anytype-retry-close")
                    }.padding()
                case .closed:
                    EmptyView()
                }
            }
            .navigationTitle(Text("Share with Anytype", tableName: "OriginalAnnotationEditor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { model.close() } label: {
                        Text("Close", tableName: "OriginalAnnotationEditor")
                    }
                    .disabled(!model.canClose || model.stage == .closeFailed)
                    .accessibilityIdentifier("annotation-anytype-share-close")
                }
            }
        }
        .task { await model.begin() }
        .onChange(of: model.stage) { _, stage in if stage == .closed { dismiss() } }
        .onDisappear { model.removed() }
    }
}

/// The complete supplied controller belongs to the original native SDK.
@MainActor
struct AnnotationOriginalEditorProductionController: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
#endif
