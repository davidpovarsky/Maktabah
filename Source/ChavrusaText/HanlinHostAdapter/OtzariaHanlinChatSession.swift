#if os(iOS)
import Foundation
import Observation
import HanlinAgentCore
import HanlinChatCore
import HanlinChatUI
import HanlinHostContracts
import HanlinPresentationKit
import HanlinRichUI
import HanlinPlatformContracts
import AI_Hanlin

/// One immutable, transient request from the native connection form. The nonce
/// binds the user's current-work consent to this exact endpoint/model/key
/// configuration without persisting or hashing a credential.
@MainActor
final class OtzariaHanlinConnectionRequest {
    let id = UUID()
    let configuration: HanlinChatModelConfiguration
    init(endpoint: String, modelID: String, credential: String) throws {
        configuration = try OtzariaHanlinChatSession.configuration(
            endpoint: endpoint, modelID: modelID, credential: credential)
    }
}


/// A bounded acceptance journal of original control flow. Every value is a fixed
/// enum or boolean; credentials, model/source text and session identities never
/// enter this schema. It cannot grant access or alter an original outcome.
@MainActor
enum OtzariaHanlinConnectionDiagnostic {
    enum Stage: String {
        case inputConsumed, connectEntered, connectRejected, requestValidated, readRequestValidated
        case readRequestReturned, connectFailed
        case carriedConfigureEntered, carriedConfigureRejected, carriedConfigurationMismatch
        case engineConstructed, configurationActivated, configurationCompleted, configureFailed
        case openEntered, openRejected, openIssued, openFailed, mountObserved
        case consentCaptureEntered, consentCaptured, closeRequested
        case dismissObserved, dismissAccepted, readReopenEntered
        case consentConsumeEntered, consentConsumed
        case sourceComparisonRejected, sourceValidationFailed
        case sendEntered, sendRejected, sendCheckpointFailed, sendCheckpointed, sendSettled
        case streamOpening, streamOpened, streamFinished, streamFailed
        case hostResultObserved, hostResultRetained, hostResultLimitReached, sessionInvalidated
        case streamToolCallObserved, streamToolResultObserved, streamToolResultUnmatched
        case sourceResultObserved, sourceLinkCreated, streamToolOutputDenied
        case streamRunStarted, streamStepStarted, streamTextObserved, streamReasoningObserved
        case streamToolInputStarted, streamToolInputDeltaObserved, streamApprovalRequested, streamApprovalResolved
        case streamStepFinished, streamFinishObserved, streamCancelledObserved, runCompletionObserved
    }
    enum Reason: String {
        case none, cancelled, invalidArguments, invalidContext, staleContext
        case denied, duplicateInvocation, otherHostError, otherError
        case unknownTool, deadlineExceeded, resultMismatch, outputLimitExceeded, unresolvedWrite
        case unsupportedProviderCapability, storeConflict, invalidRecord, storageLimitExceeded
        case nativeProviderInjectionRequired, nativeUnsupportedContent, nativeUnsupportedToolInput, invalidProviderToolSchema
        case invalidSDKConversation, emptyProviderResponse, incompleteProviderResponse
        case finishStop, finishToolCalls, finishLength, finishContentFilter, finishError, finishOther
    }
    enum Flag: String {
        case closed, storageFailed, configured, connecting, hasOperation
        case allowRead, hasReadOffer, hasReadScope, credentialPresent
        case retired, hasPresentation, hasNativeSession, mounted, foreground
        case hasNavigationTask, matchingSession, isPresented, hasPendingReadReopen
        case preservingContinuation, hasConsent, hasConnection
        case sameBackend, sameMappingSource, sameMappingEpoch, sameWorkspaceProjection
        case sameReaderContent, sameReadSource, sameSelection, sameLocale
        case streaming, referenceResult, hostSucceeded, toolFailed, hasOriginalResult
        case hasSources, hasActivities
        case hasActiveTools, searchAdvertised, referenceAdvertised, hasVisibleSchemas
        case approvalAllowed, hasMeaningfulEvents, completionSucceeded, completionCancelled, completionFailed
        case hasAssistantText, hasReasoning
    }

    #if DEBUG && targetEnvironment(simulator)
    private static var boundNonce: String?
    private static var destination: URL?
    private static var events: [[String: Any]] = []
    private static var overflow = false
    private static var firstStreamObservations = Set<String>()
    #endif

    static func reason(for error: any Error) -> Reason {
        if error is CancellationError { return .cancelled }
        if let error = error as? HanlinAISDKError {
            switch error {
            case .nativeProviderInjectionRequired: return .nativeProviderInjectionRequired
            case .nativeUnsupportedContent: return .nativeUnsupportedContent
            case .nativeUnsupportedToolInput: return .nativeUnsupportedToolInput
            case .invalidToolSchema(_): return .invalidProviderToolSchema
            case .invalidConversation(_): return .invalidSDKConversation
            case .emptyProviderResponse(_): return .emptyProviderResponse
            case .incompleteProviderResponse(_): return .incompleteProviderResponse
            }
        }
        guard let error = error as? HanlinHostError else { return .otherError }
        switch error {
        case .invalidArguments: return .invalidArguments
        case .invalidContext: return .invalidContext
        case .staleContext: return .staleContext
        case .denied: return .denied
        case .duplicateInvocation: return .duplicateInvocation
        case .unknownTool: return .unknownTool
        case .deadlineExceeded: return .deadlineExceeded
        case .resultMismatch: return .resultMismatch
        case .outputLimitExceeded: return .outputLimitExceeded
        case .unresolvedWrite: return .unresolvedWrite
        case .unsupportedProviderCapability: return .unsupportedProviderCapability
        case .storeConflict: return .storeConflict
        case .invalidRecord: return .invalidRecord
        case .storageLimitExceeded: return .storageLimitExceeded
        default: return .otherHostError
        }
    }



    /// Observe only finite facts from original public stream events. Payloads,
    /// provider strings, IDs and usage values never enter the journal.
    static func observeStreamEvent(_ event: HanlinAISDKStreamEvent) {
        #if DEBUG && targetEnvironment(simulator)
        switch event {
        case .runStarted:
            record(.streamRunStarted)
        case .stepStarted(_, let preparation):
            record(.streamStepStarted, flags: [
                .hasActiveTools: !preparation.activeToolAliases.isEmpty,
                .searchAdvertised: preparation.activeToolAliases.contains("otzaria_search_query"),
                .referenceAdvertised: preparation.activeToolAliases.contains("otzaria_catalog_resolve_reference"),
                .hasVisibleSchemas: preparation.visibleSchemaBytes > 0,
            ])
        case .textDelta(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recordFirst(.streamTextObserved)
            }
        case .reasoningDelta(let text):
            if !text.isEmpty { recordFirst(.streamReasoningObserved) }
        case .toolCallArgumentsStarted:
            recordFirst(.streamToolInputStarted)
        case .toolCallArgumentsDelta(_, let delta):
            if !delta.isEmpty { recordFirst(.streamToolInputDeltaObserved) }
        case .toolApprovalRequest:
            recordFirst(.streamApprovalRequested)
        case .toolApprovalResolved(_, let allowed):
            recordFirst(.streamApprovalResolved, flags: [.approvalAllowed: allowed])
        case .stepFinished(_, let reason, _, let meaningfulEventCount):
            record(.streamStepFinished, reason: finishReason(reason), flags: [
                .hasMeaningfulEvents: meaningfulEventCount > 0,
            ])
        case .finished(let reason, _):
            record(.streamFinishObserved, reason: finishReason(reason))
        case .cancelled:
            record(.streamCancelledObserved)
        default:
            break
        }
        #endif
    }

    /// This callback only observes the original completion; it cannot settle,
    /// cancel, invalidate or otherwise change the original run.
    static func observeRunCompletion(_ completion: HanlinAgentRunCompletion, matchingSession: Bool) {
        #if DEBUG && targetEnvironment(simulator)
        var flags: [Flag: Bool] = [
            .matchingSession: matchingSession,
            .completionSucceeded: false, .completionCancelled: false, .completionFailed: false,
        ]
        let completionReason: Reason
        switch completion.outcome {
        case .completed:
            flags[.completionSucceeded] = true
            completionReason = .none
        case .cancelled:
            flags[.completionCancelled] = true
            completionReason = .cancelled
        case .failed(let error):
            flags[.completionFailed] = true
            completionReason = reason(for: error)
        }
        record(.runCompletionObserved, reason: completionReason, flags: flags)
        #endif
    }

    static func beginStreamObservation() {
        #if DEBUG && targetEnvironment(simulator)
        firstStreamObservations.removeAll(keepingCapacity: true)
        #endif
    }

    private static func recordFirst(_ stage: Stage, flags: [Flag: Bool] = [:]) {
        #if DEBUG && targetEnvironment(simulator)
        guard firstStreamObservations.insert(stage.rawValue).inserted else { return }
        record(stage, flags: flags)
        #endif
    }

    private static func finishReason(_ value: String) -> Reason {
        switch value {
        case "stop": return .finishStop
        case "tool_calls", "tool-calls": return .finishToolCalls
        case "length": return .finishLength
        case "content_filter", "content-filter": return .finishContentFilter
        case "error": return .finishError
        default: return .finishOther
        }
    }

    /// Only the original one-use input consumer calls this after validating,
    /// consuming and applying that exact input. Existing evidence is preserved.
    static func beginOwnedLiveInput(nonce: String) {
        #if DEBUG && targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        guard boundNonce == nil,
              environment["OTZARIA_HANLIN_LIVE_PROVIDER_CASE"] == "1",
              environment["OTZARIA_HANLIN_LIVE_NONCE"] == nonce,
              UUID(uuidString: nonce)?.uuidString == nonce else { return }
        do {
            let directory = try FileManager.default.url(for: .documentDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let file = directory.appendingPathComponent("otzaria-hanlin-connection-stages-" + nonce + ".json")
            let initial: [[String: Any]] = [[
                "sequence": 1, "stage": Stage.inputConsumed.rawValue,
                "reason": Reason.none.rawValue, "flags": [String: Bool](),
            ]]
            let data = try JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1, "overflow": false, "events": initial,
            ], options: [.sortedKeys])
            try data.write(to: file, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            events = initial
            overflow = false
            destination = file
            boundNonce = nonce
        } catch {
            // Keep the original business flow and any preexisting evidence.
            // A missing/incomplete journal is not diagnostic success.
        }
        #endif
    }

    static func record(_ stage: Stage, reason: Reason = .none, flags: [Flag: Bool] = [:]) {
        #if DEBUG && targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        guard let boundNonce, let file = destination,
              environment["OTZARIA_HANLIN_LIVE_PROVIDER_CASE"] == "1",
              environment["OTZARIA_HANLIN_LIVE_NONCE"] == boundNonce else { return }
        if events.count < 96 && flags.count <= 9 {
            events.append([
                "sequence": events.count + 1,
                "stage": stage.rawValue,
                "reason": reason.rawValue,
                "flags": Dictionary(uniqueKeysWithValues: flags.map { ($0.key.rawValue, $0.value) }),
            ])
        } else { overflow = true }
        do {
            let data = try JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1, "overflow": overflow, "events": events,
            ], options: [.sortedKeys])
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch {
            // Diagnostic I/O never changes the original action, error, guard or
            // cleanup. The collector reports a missing journal explicitly.
        }
        #endif
    }
}

/// Scene-owned presentation state around the original SDK session and engine.
/// The original Core/scene adapter remains the only source of host authority.
@MainActor @Observable
final class OtzariaHanlinChatSession: Identifiable {
    let identity: HanlinHostSession
    nonisolated var id: UUID { identity.id }
    private var draftRevision = UUID()
    private(set) var draft = "" {
        didSet {
            // Write identity is ephemeral and advances even for an explicit
            // same-string clear. History remains owned by the existing store.
            draftRevision = UUID()
            historyChanged()
        }
    }
    var selectedProfile: PresentationReference { didSet { historyChanged() } }
    private(set) var messages: [HanlinChatMessage] = []
    private(set) var messageStates: [UUID: MessageOpenUIStateStore] = [:]
    private(set) var activities: [Activity] = []
    private(set) var reasoning: [UUID: String] = [:]
    private(set) var sources: [OtzariaHanlinSourceLink] = []
    private(set) var draftCapabilities: [HanlinCapabilityAttachment] = [] { didSet { historyChanged() } }
    private(set) var messageCapabilities: [UUID: [HanlinCapabilityAttachment]] = [:]
    private(set) var capabilityCatalog: [HanlinComposerCapabilityDescriptor] = []
    private(set) var assistantServices: HanlinAssistantServices?
    let assistantConsent = HanlinAppToolConsent()
    private(set) var isNavigating = false
    private(set) var isConfigured = false
    private(set) var isConnecting = false
    private(set) var isStreaming = false
    private(set) var errorMessage: String?
    let presentationDescriptor: HostPresentationDescriptor
    let currentWorkReadOffer: OtzariaHanlinCurrentWorkReadScope?
    let currentWorkReadScope: OtzariaHanlinCurrentWorkReadScope?
    private let requiredConfigurationID: UUID?

    typealias Activity = OtzariaHanlinToolActivity

    @ObservationIgnored private let host: OtzariaHanlinHostAdapter
    @ObservationIgnored private let validateOwner: @MainActor () throws -> Void
    @ObservationIgnored private let onClose: @MainActor () -> Void
    @ObservationIgnored private let onNavigate: @MainActor (URL) async throws -> Void
    @ObservationIgnored private let onConnectionConfigured: @MainActor (UUID) throws -> Void
    @ObservationIgnored private let onRequestReadConnection: @MainActor (OtzariaHanlinConnectionRequest, OtzariaHanlinCurrentWorkReadScope) throws -> Void
    @ObservationIgnored private let sourceDestination: @MainActor (HanlinHostResultEvent) throws -> URL?
    @ObservationIgnored private var pendingHostResults: [String: HanlinHostResultEvent] = [:]
    @ObservationIgnored private let store: OtzariaHanlinScopedConversationStore
    @ObservationIgnored private var historyRevision: UInt64?
    @ObservationIgnored private var storageFailed = false
    @ObservationIgnored private var isMutatingHistory = false
    @ObservationIgnored private var agent: HanlinAgentSession?
    @ObservationIgnored private var model: HanlinModelReference?
    @ObservationIgnored private var assistantHost: HanlinAssistantConversationHost?
    @ObservationIgnored private var composedHost: OtzariaHanlinComposedHost?
    @ObservationIgnored private var currentToolReferences: [HanlinSkillToolReference] = []
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var closed = false

    init(identity: HanlinHostSession, host: OtzariaHanlinHostAdapter,
         store: OtzariaHanlinScopedConversationStore,
         currentWorkReadOffer: OtzariaHanlinCurrentWorkReadScope? = nil,
         currentWorkReadScope: OtzariaHanlinCurrentWorkReadScope? = nil,
         requiredConfigurationID: UUID? = nil,
         onConnectionConfigured: @escaping @MainActor (UUID) throws -> Void = { _ in },
         onRequestReadConnection: @escaping @MainActor (OtzariaHanlinConnectionRequest, OtzariaHanlinCurrentWorkReadScope) throws -> Void = { _, _ in throw HanlinHostError.denied },
         sourceDestination: @escaping @MainActor (HanlinHostResultEvent) throws -> URL?,
         validateOwner: @escaping @MainActor () throws -> Void,
         onClose: @escaping @MainActor () -> Void,
         onNavigate: @escaping @MainActor (URL) async throws -> Void) throws {
        self.identity = identity; self.host = host; self.store = store; self.sourceDestination = sourceDestination
        self.validateOwner = validateOwner; self.onClose = onClose; self.onNavigate = onNavigate
        self.currentWorkReadOffer = currentWorkReadOffer; self.currentWorkReadScope = currentWorkReadScope
        self.requiredConfigurationID = requiredConfigurationID
        self.onConnectionConfigured = onConnectionConfigured; self.onRequestReadConnection = onRequestReadConnection
        guard (currentWorkReadScope == nil) == (requiredConfigurationID == nil) else { throw HanlinHostError.denied }
        let descriptor = try OpenUICatalogs.host(appID: identity.context.namespace.app, research: true)
        presentationDescriptor = descriptor
        selectedProfile = descriptor.defaultProfile
        // Observable draft and profile setters can checkpoint. Restore the
        // entire snapshot before either setter may write to its original file.
        isMutatingHistory = true
        defer { isMutatingHistory = false }
        if let (history, revision) = try store.history() {
            _ = try ProfileResolver.resolve(host: descriptor, conversationID: identity.conversationID,
                assignment: .init(conversationID: identity.conversationID, profile: history.selectedProfile))
            for snapshot in history.presentations.values {
                let original = try ProfileResolver.resolve(host: descriptor, conversationID: identity.conversationID,
                    assignment: .init(conversationID: identity.conversationID, profile: snapshot.profile.profile.reference))
                guard original == snapshot.profile else { throw HanlinHostError.invalidRecord }
            }
            historyRevision = revision
            draft = history.draft; selectedProfile = history.selectedProfile
            messages = history.messages; reasoning = history.reasoning; sources = history.sources
            draftCapabilities = history.draftCapabilities ?? []
            messageCapabilities = history.messageCapabilities ?? [:]
            activities = history.activities.map {
                var value = $0
                if value.isActive { value.isActive = false; value.status = String(localized: "Interrupted") }
                return value
            }
            for (id, snapshot) in history.presentations { messageStates[id] = MessageOpenUIStateStore(snapshot: snapshot) }
        }
        for state in messageStates.values { observe(state) }
    }

    private func observe(_ state: MessageOpenUIStateStore) {
        state.onChange = { [weak self] _ in self?.historyChanged() }
    }

    private func checkpoint() throws {
        // Merely opening the native conversation picker does not create an
        // empty saved chat. A user draft, message or appearance choice does.
        if historyRevision == nil, draft.isEmpty, draftCapabilities.isEmpty, messages.isEmpty,
           selectedProfile == presentationDescriptor.defaultProfile { return }
        let history = OtzariaHanlinHistory(draft: draft, selectedProfile: selectedProfile, messages: messages,
            presentations: messageStates.mapValues(\.snapshot), activities: activities, reasoning: reasoning, sources: sources,
            draftCapabilities: draftCapabilities.isEmpty ? nil : draftCapabilities,
            messageCapabilities: messageCapabilities.isEmpty ? nil : messageCapabilities)
        historyRevision = try store.saveHistory(history, replacing: historyRevision)
    }

    private func historyChanged() {
        guard !closed, !storageFailed, !isMutatingHistory else { return }
        do { try checkpoint() }
        catch {
            storageFailed = true
            operation?.cancel()
            errorMessage = String(localized: "The conversation could not be saved. Close and reopen it before continuing; the previous saved conversation is preserved.")
        }
    }

    /// A live read of this presentation's original draft owner, never a render snapshot.
    func readCurrentDraftTextState() -> NativeMultilineTextEditor.TextState? {
        guard !closed else { return nil }
        do { try validateOwner() }
        catch { return nil }
        return .init(ownerID: identity.id, revision: draftRevision, text: draft)
    }

    /// A retained native callback cannot write after this original owner is revoked.
    func updateDraftFromEditor(_ value: String) {
        guard !storageFailed, readCurrentDraftTextState() != nil else { return }
        draft = value
    }

    var canSend: Bool {
        isConfigured && !closed && !storageFailed && !isStreaming && !isConnecting && !isNavigating
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.utf8.count <= 32_768 && messages.count <= 254
            && draftCapabilities.allSatisfy { attachment in
                capabilityCatalog.first(where: { $0.id == attachment.reference.id })?
                    .validationIssues(for: attachment).isEmpty == true
            }
    }

    var profile: ResolvedPresentationProfile? {
        try? ProfileResolver.resolve(host: presentationDescriptor, conversationID: identity.conversationID,
            assignment: .init(conversationID: identity.conversationID, profile: selectedProfile))
    }

    private func requireCurrent() async throws {
        guard !closed else { throw HanlinHostError.staleContext }
        try validateOwner()
        let current = try await host.context(for: identity)
        try Task.checkCancellation()
        guard !closed, current == identity.context else { throw HanlinHostError.staleContext }
        try validateOwner()
    }

    /// Explicit native input only. Reading is OFF unless this exact connection
    /// form action requests the displayed current work. That action only queues
    /// a source-bound dismissal/reopen; it never sends a model message.
    func configure(endpoint: String, modelID: String, credential: String, allowCurrentWorkRead: Bool = false) {
        OtzariaHanlinConnectionDiagnostic.record(.connectEntered, flags: [
            .closed: closed, .storageFailed: storageFailed, .configured: isConfigured,
            .connecting: isConnecting, .hasOperation: operation != nil,
            .allowRead: allowCurrentWorkRead, .hasReadOffer: currentWorkReadOffer != nil,
            .hasReadScope: currentWorkReadScope != nil, .credentialPresent: !credential.isEmpty,
        ])
        guard !closed, !storageFailed, !isConfigured, !isConnecting, operation == nil else {
            OtzariaHanlinConnectionDiagnostic.record(.connectRejected)
            return
        }
        do {
            let request = try OtzariaHanlinConnectionRequest(endpoint: endpoint, modelID: modelID, credential: credential)
            OtzariaHanlinConnectionDiagnostic.record(.requestValidated)
            if allowCurrentWorkRead {
                guard currentWorkReadScope == nil, let offer = currentWorkReadOffer else { throw HanlinHostError.denied }
                try validateOwner()
                OtzariaHanlinConnectionDiagnostic.record(.readRequestValidated)
                try onRequestReadConnection(request, offer)
                OtzariaHanlinConnectionDiagnostic.record(.readRequestReturned, flags: [.closed: closed])
            } else {
                configure(request)
            }
        } catch {
            OtzariaHanlinConnectionDiagnostic.record(.connectFailed, reason: OtzariaHanlinConnectionDiagnostic.reason(for: error))
            if !closed { errorMessage = String(localized: "The connection could not be configured. Check the address, model and key.") }
        }
    }

    /// Only the original owner may carry the same immutable request through an
    /// actual sheet dismissal. A different request cannot reuse its read grant.
    func configure(_ request: OtzariaHanlinConnectionRequest) {
        OtzariaHanlinConnectionDiagnostic.record(.carriedConfigureEntered, flags: [
            .closed: closed, .storageFailed: storageFailed, .configured: isConfigured,
            .connecting: isConnecting, .hasOperation: operation != nil,
            .hasReadScope: currentWorkReadScope != nil,
        ])
        guard !closed, !storageFailed, !isConfigured, !isConnecting, operation == nil else {
            OtzariaHanlinConnectionDiagnostic.record(.carriedConfigureRejected)
            return
        }
        guard requiredConfigurationID == nil || requiredConfigurationID == request.id else {
            OtzariaHanlinConnectionDiagnostic.record(.carriedConfigurationMismatch)
            onClose(); return
        }
        isConnecting = true
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isConnecting = false; self.operation = nil }
            do {
                try Task.checkCancellation()
                try self.validateOwner()
                let configuration = request.configuration
                let engine = try HanlinAISDKAgentEngine(configuration: configuration,
                    fetch: HanlinAISDKProviderFactory.makeFetch(sessionConfiguration: .ephemeral))
                OtzariaHanlinConnectionDiagnostic.record(.engineConstructed)
                try self.onConnectionConfigured(request.id)
                OtzariaHanlinConnectionDiagnostic.record(.configurationActivated)
                try await self.requireCurrent()
                let composed = try await self.configureAssistantHost()
                let session = HanlinAgentSession(identity: self.identity, host: composed, engine: engine,
                    store: self.store, capabilities: composed)
                session.onProviderToolApproval = { [weak self] approval in
                    guard let self, !self.closed, self.isStreaming, approval.session == self.identity,
                          (try? self.validateOwner()) != nil else { return false }
                    return await self.assistantConsent.request(approval)
                }
                session.onHostResult = { [weak self] event in
                    var hostSucceeded = false
                    if case .completed = event.result.result.outcome { hostSucceeded = true }
                    OtzariaHanlinConnectionDiagnostic.record(.hostResultObserved, flags: [
                        .closed: self?.closed ?? true, .streaming: self?.isStreaming ?? false,
                        .matchingSession: self.map { event.call.session == $0.identity } ?? false,
                        .referenceResult: event.call.logicalToolID.localToolID.rawValue == "catalog.resolve-reference",
                        .hostSucceeded: hostSucceeded,
                    ])
                    guard let self, !self.closed, self.isStreaming, event.call.session == self.identity else { return }
                    let key = event.call.runID.uuidString + ":" + event.call.providerCallID
                    guard self.pendingHostResults.count < 256 else {
                        OtzariaHanlinConnectionDiagnostic.record(.hostResultLimitReached)
                        self.operation?.cancel(); return
                    }
                    self.pendingHostResults[key] = event
                    OtzariaHanlinConnectionDiagnostic.record(.hostResultRetained)
                }
                session.onRunCompletion = { [weak self] completion in
                    OtzariaHanlinConnectionDiagnostic.observeRunCompletion(completion,
                        matchingSession: self.map { completion.session == $0.identity } ?? false)
                }
                session.onSessionInvalidated = { [weak self] _ in
                    OtzariaHanlinConnectionDiagnostic.record(.sessionInvalidated, flags: [.closed: self?.closed ?? true])
                    guard let self, !self.closed else { return }
                    self.onClose()
                }
                self.agent = session
                self.model = .init(provider: HanlinAISDKProviderFactory.descriptor(for: configuration).kind.rawValue,
                                   modelID: configuration.baseModelID)
                self.isConfigured = true
                self.errorMessage = nil
                OtzariaHanlinConnectionDiagnostic.record(.configurationCompleted)
            } catch {
                OtzariaHanlinConnectionDiagnostic.record(.configureFailed,
                    reason: OtzariaHanlinConnectionDiagnostic.reason(for: error))
                if !self.closed {
                    self.errorMessage = String(localized: "The connection could not be configured. Check the address, model and key.")
                    // A failed granted connection cannot be retried with a new
                    // endpoint/key while retaining the previous user's consent.
                    if self.currentWorkReadScope != nil { self.onClose() }
                }
            }
        }
    }


    /// Original capability metadata and management remain in the selected facade.
    /// Opening a picker does not prepare a request or execute a tool.
    @discardableResult
    func refreshCapabilityCatalog() -> Bool {
        guard !closed, !isStreaming, let assistantHost else { return false }
        do {
            try validateOwner()
            capabilityCatalog = try assistantHost.capabilityCatalog()
            return true
        } catch {
            errorMessage = String(localized: "Capabilities are unavailable for the current conversation.")
            return false
        }
    }

    func attachCapability(_ descriptor: HanlinComposerCapabilityDescriptor, actionID: String?) {
        guard !closed, !isStreaming, !storageFailed else { return }
        do {
            try validateOwner()
            guard let current = capabilityCatalog.first(where: { $0.id == descriptor.id }),
                  current == descriptor,
                  actionID == nil || current.actions.contains(where: { $0.id == actionID }) else {
                throw HanlinHostError.staleContext
            }
            let value = current.makeAttachment(actionID: actionID)
            guard !draftCapabilities.contains(where: { $0.selectionKey == value.selectionKey }) else { return }
            guard draftCapabilities.count < 32 else { throw HanlinHostError.storageLimitExceeded }
            draftCapabilities.append(value)
        } catch {
            errorMessage = String(localized: "This capability changed or could not be added. Open the picker again.")
        }
    }

    func updateCapability(_ attachment: HanlinCapabilityAttachment) {
        guard !closed, !isStreaming, !storageFailed,
              let index = draftCapabilities.firstIndex(where: { $0.id == attachment.id }) else { return }
        do {
            try validateOwner()
            let prior = draftCapabilities[index]
            guard prior.reference == attachment.reference, prior.title == attachment.title,
                  prior.configurationVersion == attachment.configurationVersion,
                  !draftCapabilities.enumerated().contains(where: {
                      $0.offset != index && $0.element.selectionKey == attachment.selectionKey
                  }) else { throw HanlinHostError.invalidArguments }
            // Preserve invalid/intermediate edits for the original configuration
            // view to explain; its original descriptor validator gates Send.
            draftCapabilities[index] = attachment
        } catch {
            errorMessage = String(localized: "The capability could not be updated in this conversation.")
        }
    }

    func removeCapability(_ id: UUID) {
        guard !closed, !isStreaming, !storageFailed, (try? validateOwner()) != nil else { return }
        draftCapabilities.removeAll { $0.id == id }
    }

    func answerToolConsent(id: UUID, allowed: Bool) {
        guard !closed, isStreaming, assistantConsent.pending?.id == id,
              (try? validateOwner()) != nil else {
            assistantConsent.answer(id: id, allowed: false)
            return
        }
        assistantConsent.answer(id: id, allowed: allowed)
    }

    private func configureAssistantHost() async throws -> OtzariaHanlinComposedHost {
        try await requireCurrent()
        let nativeCatalog = try await host.catalog(for: identity.context)
        try await requireCurrent()
        updateToolReferences(nativeCatalog)
        guard let appIdentifier = Bundle.main.bundleIdentifier else { throw HanlinHostError.invalidContext }
        let services = try HanlinAssistantServices.sharedRuntime(
            runtimeConfiguration: .applicationSupport(appIdentifier: appIdentifier),
            availableTools: { [weak self] in
                guard let self, !self.closed, (try? self.validateOwner()) != nil else { return [] }
                return self.currentToolReferences
            },
            validateConversation: { [weak self] conversationID in
                guard let self, !self.closed, conversationID == self.identity.conversationID else {
                    throw HanlinHostError.staleContext
                }
                try self.validateOwner()
            })
        let capabilityHost = services.makeConversationHost(identity: identity,
            validateCurrent: { [weak self] in
                guard let self, !self.closed else { throw HanlinHostError.staleContext }
                try self.validateOwner()
            }, consent: assistantConsent)
        let composed = OtzariaHanlinComposedHost(identity: identity, library: host, assistant: capabilityHost)
        assistantServices = services
        assistantHost = capabilityHost
        composedHost = composed
        await services.prepare()
        try await requireCurrent()
        capabilityCatalog = try capabilityHost.capabilityCatalog()
        return composed
    }

    private func updateToolReferences(_ catalog: HanlinHostCatalog) {
        currentToolReferences = catalog.tools.map {
            HanlinSkillToolReference(name: $0.route.alias, title: $0.descriptor.title.resolved(locale: .current))
        }
    }

    static func configuration(endpoint: String, modelID: String, credential: String) throws -> HanlinChatModelConfiguration {
        let model = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !model.isEmpty, model.utf8.count <= 128, !credential.isEmpty, credential.utf8.count <= 4_096 else {
            throw HanlinHostError.invalidArguments
        }
        return .init(modelID: model, company: "OPENAI", apiType: "OpenAI", endpoint: url,
                     apiKey: credential, supportsToolUse: true)
    }

    func send() {
        OtzariaHanlinConnectionDiagnostic.record(.sendEntered, flags: [
            .closed: closed, .storageFailed: storageFailed, .configured: isConfigured,
            .streaming: isStreaming, .connecting: isConnecting, .hasOperation: operation != nil,
        ])
        guard canSend, let agent, let model, let profile, let assistantHost else {
            OtzariaHanlinConnectionDiagnostic.record(.sendRejected)
            return
        }
        let prompt = draft
        let selectedCapabilities = draftCapabilities
        let userMessage = HanlinChatMessage.user(prompt)
        isMutatingHistory = true
        defer { isMutatingHistory = false }
        draft = ""
        draftCapabilities = []
        messages.append(userMessage)
        if !selectedCapabilities.isEmpty { messageCapabilities[userMessage.id] = selectedCapabilities }
        let history = messages.map { HanlinAISDKMessage(role: $0.role == "user" ? .user : .assistant, text: $0.content) }
        let answerID = UUID()
        messages.append(.init(id: answerID, role: "assistant", content: ""))
        let messageIdentity = PresentationMessageIdentity(appID: identity.context.namespace.app,
            conversationID: identity.conversationID, messageID: answerID)
        messageStates[answerID] = MessageOpenUIStateStore(snapshot: .init(identity: messageIdentity, profile: profile))
        if let state = messageStates[answerID] { observe(state) }
        do { try checkpoint() }
        catch {
            OtzariaHanlinConnectionDiagnostic.record(.sendCheckpointFailed,
                reason: OtzariaHanlinConnectionDiagnostic.reason(for: error))
            messages.removeLast(2); messageStates[answerID] = nil
            messageCapabilities[userMessage.id] = nil
            draftCapabilities = selectedCapabilities
            storageFailed = true; draft = prompt
            errorMessage = String(localized: "The message could not be saved, so it was not sent. Close and reopen this conversation.")
            return
        }
        OtzariaHanlinConnectionDiagnostic.beginStreamObservation()
        OtzariaHanlinConnectionDiagnostic.record(.sendCheckpointed)
        pendingHostResults.removeAll()
        isStreaming = true
        errorMessage = nil
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                assistantHost.finishRequest()
                self.isStreaming = false; self.operation = nil
                OtzariaHanlinConnectionDiagnostic.record(.sendSettled, flags: [
                    .closed: self.closed, .hasSources: !self.sources.isEmpty, .hasActivities: !self.activities.isEmpty,
                    .hasAssistantText: self.messages.first(where: { $0.id == answerID })?.content.isEmpty == false,
                    .hasReasoning: self.reasoning[answerID]?.isEmpty == false,
                ])
            }
            do {
                try await self.requireCurrent()
                let nativeCatalog = try await self.host.catalog(for: self.identity.context)
                try await self.requireCurrent()
                self.updateToolReferences(nativeCatalog)
                try await assistantHost.beginRequest(hostCatalog: nativeCatalog, attachments: selectedCapabilities)
                try await self.requireCurrent()
                let readInstructions = try self.currentWorkReadScope?.modelInstructions()
                    ?? "This conversation has no permission to read a book or selection or modify library data."
                let instructions = OpenUICatalogs.instructions(for: profile)
                    + "\nUse only the host's current advertised catalog. " + readInstructions
                    + " Do not invent citations or application actions."
                OtzariaHanlinConnectionDiagnostic.record(.streamOpening)
                let stream = try await agent.stream(messages: history, systemPrompt: instructions,
                    modelReference: model, maxSteps: 8, presentationReference: profile.profile.reference.key)
                OtzariaHanlinConnectionDiagnostic.record(.streamOpened)
                for try await event in stream {
                    try Task.checkCancellation()
                    try await self.requireCurrent()
                    guard event.session == self.identity else { throw HanlinHostError.staleContext }
                    try self.receive(event.event, messageID: answerID, runID: event.runID)
                    try self.checkpoint()
                }
                OtzariaHanlinConnectionDiagnostic.record(.streamFinished)
            } catch {
                OtzariaHanlinConnectionDiagnostic.record(.streamFailed,
                    reason: OtzariaHanlinConnectionDiagnostic.reason(for: error))
                if !self.closed {
                    self.errorMessage = Task.isCancelled
                        ? String(localized: "The response was stopped.")
                        : String(localized: "The request could not be completed. The original conversation context may have changed.")
                }
            }
            for index in self.activities.indices where self.activities[index].messageID == answerID && self.activities[index].isActive {
                self.activities[index].isActive = false
                self.activities[index].status = String(localized: "Stopped")
            }
            self.pendingHostResults.removeAll()
            if !self.closed { self.historyChanged() }
        }
    }

    private func receive(_ event: HanlinAISDKStreamEvent, messageID: UUID, runID: UUID) throws {
        OtzariaHanlinConnectionDiagnostic.observeStreamEvent(event)
        switch event {
        case .textDelta(let delta):
            guard let index = messages.firstIndex(where: { $0.id == messageID }),
                  messages[index].content.utf8.count + delta.utf8.count <= 262_144 else { throw HanlinHostError.outputLimitExceeded }
            messages[index].content += delta
        case .reasoningDelta(let delta):
            let prior = reasoning[messageID] ?? ""
            guard prior.utf8.count + delta.utf8.count <= 262_144 else { throw HanlinHostError.outputLimitExceeded }
            reasoning[messageID] = prior + delta
        case .toolCall(let call):
            OtzariaHanlinConnectionDiagnostic.record(.streamToolCallObserved)
            guard call.argumentsJSON.utf8.count <= 65_536, activities.count < 256 else { throw HanlinHostError.outputLimitExceeded }
            if let index = activities.firstIndex(where: { $0.id == call.id && $0.messageID == messageID }) {
                activities[index].arguments = call.argumentsJSON
            } else {
                activities.append(.init(id: call.id, messageID: messageID, name: call.name,
                    status: String(localized: "Running"), arguments: call.argumentsJSON, isActive: true))
            }
        case .toolResult(let callID, let name, let text, _, let isError):
            OtzariaHanlinConnectionDiagnostic.record(.streamToolResultObserved, flags: [.toolFailed: isError])
            guard text.utf8.count <= 262_144 else { throw HanlinHostError.outputLimitExceeded }
            guard let index = activities.firstIndex(where: { $0.id == callID && $0.messageID == messageID }) else {
                OtzariaHanlinConnectionDiagnostic.record(.streamToolResultUnmatched)
                return
            }
            activities[index].name = name
            activities[index].status = isError ? String(localized: "Failed") : String(localized: "Completed")
            activities[index].result = text
            activities[index].isActive = false
            let resultKey = runID.uuidString + ":" + callID
            OtzariaHanlinConnectionDiagnostic.record(.sourceResultObserved, flags: [
                .hasOriginalResult: pendingHostResults[resultKey] != nil, .toolFailed: isError,
            ])
            if let original = pendingHostResults.removeValue(forKey: resultKey), !isError,
               let destination = try sourceDestination(original) {
                guard sources.count < 256 else { throw HanlinHostError.outputLimitExceeded }
                sources.append(.init(id: original.resultID, messageID: messageID, destination: destination))
                OtzariaHanlinConnectionDiagnostic.record(.sourceLinkCreated)
            }
        case .toolOutputDenied(let callID, _):
            OtzariaHanlinConnectionDiagnostic.record(.streamToolOutputDenied)
            if let index = activities.firstIndex(where: { $0.id == callID && $0.messageID == messageID }) {
                activities[index].status = String(localized: "Denied"); activities[index].isActive = false
            }
        case .file, .structuredPart:
            // These require an original host media/structured-action owner;
            // do not silently display an empty successful answer or invent one.
            throw HanlinHostError.unsupportedProviderCapability
        default: break
        }
    }

    func stop() {
        operation?.cancel()
        assistantHost?.finishRequest()
        assistantConsent.revoke()
    }

    func requestNavigation(_ url: URL) {
        guard !closed, !isStreaming, !isConnecting, !isNavigating, operation == nil else { return }
        isNavigating = true
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.operation = nil; self.isNavigating = false }
            do { try await self.requireCurrent(); try await self.onNavigate(url) }
            catch { if !self.closed { self.errorMessage = String(localized: "This source could not be opened in the original window.") } }
        }
    }

    func close() { onClose() }

    /// Revocation is synchronous before async SDK cancellation or sheet dismissal.
    func revoke() {
        guard !closed else { return }
        closed = true
        assistantHost?.revoke()
        assistantConsent.revoke()
        // Mutations already checkpoint through this exact lease. Flush once
        // while it is still current, then revoke before asynchronous SDK work.
        if !storageFailed { try? checkpoint() }
        store.revoke()
        operation?.cancel(); operation = nil
        let prior = agent
        let priorHost = composedHost
        agent = nil; model = nil
        assistantHost = nil; composedHost = nil; assistantServices = nil
        capabilityCatalog.removeAll(); currentToolReferences.removeAll()
        draft = ""; messages.removeAll(); messageStates.removeAll(); activities.removeAll(); reasoning.removeAll(); sources.removeAll()
        pendingHostResults.removeAll()
        draftCapabilities.removeAll(); messageCapabilities.removeAll()
        isConfigured = false; isConnecting = false; isStreaming = false; isNavigating = false
        Task { await priorHost?.revoke(); await prior?.invalidate() }
    }
}
#endif
