#if os(iOS)
import Foundation
import Observation
import HanlinAgentCore
import HanlinChatCore
import HanlinChatUI
import HanlinHostContracts
import HanlinPresentationKit
import HanlinRichUI

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
        if historyRevision == nil, draft.isEmpty, messages.isEmpty,
           selectedProfile == presentationDescriptor.defaultProfile { return }
        let history = OtzariaHanlinHistory(draft: draft, selectedProfile: selectedProfile, messages: messages,
            presentations: messageStates.mapValues(\.snapshot), activities: activities, reasoning: reasoning, sources: sources)
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
        guard !closed, !storageFailed, !isConfigured, !isConnecting, operation == nil else { return }
        do {
            let request = try OtzariaHanlinConnectionRequest(endpoint: endpoint, modelID: modelID, credential: credential)
            if allowCurrentWorkRead {
                guard currentWorkReadScope == nil, let offer = currentWorkReadOffer else { throw HanlinHostError.denied }
                try validateOwner()
                try onRequestReadConnection(request, offer)
            } else {
                configure(request)
            }
        } catch {
            if !closed { errorMessage = String(localized: "The connection could not be configured. Check the address, model and key.") }
        }
    }

    /// Only the original owner may carry the same immutable request through an
    /// actual sheet dismissal. A different request cannot reuse its read grant.
    func configure(_ request: OtzariaHanlinConnectionRequest) {
        guard !closed, !storageFailed, !isConfigured, !isConnecting, operation == nil else { return }
        guard requiredConfigurationID == nil || requiredConfigurationID == request.id else {
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
                try self.onConnectionConfigured(request.id)
                try await self.requireCurrent()
                let session = HanlinAgentSession(identity: self.identity, host: self.host, engine: engine, store: self.store)
                session.onHostResult = { [weak self] event in
                    guard let self, !self.closed, self.isStreaming, event.call.session == self.identity else { return }
                    let key = event.call.runID.uuidString + ":" + event.call.providerCallID
                    guard self.pendingHostResults.count < 256 else { self.operation?.cancel(); return }
                    self.pendingHostResults[key] = event
                }
                session.onSessionInvalidated = { [weak self] _ in
                    guard let self, !self.closed else { return }
                    self.onClose()
                }
                self.agent = session
                self.model = .init(provider: HanlinAISDKProviderFactory.descriptor(for: configuration).kind.rawValue,
                                   modelID: configuration.baseModelID)
                self.isConfigured = true
                self.errorMessage = nil
            } catch {
                if !self.closed {
                    self.errorMessage = String(localized: "The connection could not be configured. Check the address, model and key.")
                    // A failed granted connection cannot be retried with a new
                    // endpoint/key while retaining the previous user's consent.
                    if self.currentWorkReadScope != nil { self.onClose() }
                }
            }
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
        guard canSend, let agent, let model, let profile else { return }
        let prompt = draft
        isMutatingHistory = true
        defer { isMutatingHistory = false }
        draft = ""
        messages.append(.user(prompt))
        let history = messages.map { HanlinAISDKMessage(role: $0.role == "user" ? .user : .assistant, text: $0.content) }
        let answerID = UUID()
        messages.append(.init(id: answerID, role: "assistant", content: ""))
        let messageIdentity = PresentationMessageIdentity(appID: identity.context.namespace.app,
            conversationID: identity.conversationID, messageID: answerID)
        messageStates[answerID] = MessageOpenUIStateStore(snapshot: .init(identity: messageIdentity, profile: profile))
        if let state = messageStates[answerID] { observe(state) }
        do { try checkpoint() }
        catch {
            messages.removeLast(2); messageStates[answerID] = nil
            storageFailed = true; draft = prompt
            errorMessage = String(localized: "The message could not be saved, so it was not sent. Close and reopen this conversation.")
            return
        }
        pendingHostResults.removeAll()
        isStreaming = true
        errorMessage = nil
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isStreaming = false; self.operation = nil }
            do {
                try await self.requireCurrent()
                let readInstructions = try self.currentWorkReadScope?.modelInstructions()
                    ?? "This conversation has no permission to read a book or selection or modify library data."
                let instructions = OpenUICatalogs.instructions(for: profile)
                    + "\nUse only the host's current advertised catalog. " + readInstructions
                    + " Do not invent citations or application actions."
                let stream = try await agent.stream(messages: history, systemPrompt: instructions,
                    modelReference: model, maxSteps: 8, presentationReference: profile.profile.reference.key)
                for try await event in stream {
                    try Task.checkCancellation()
                    try await self.requireCurrent()
                    guard event.session == self.identity else { throw HanlinHostError.staleContext }
                    try self.receive(event.event, messageID: answerID, runID: event.runID)
                    try self.checkpoint()
                }
            } catch {
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
            guard call.argumentsJSON.utf8.count <= 65_536, activities.count < 256 else { throw HanlinHostError.outputLimitExceeded }
            if let index = activities.firstIndex(where: { $0.id == call.id && $0.messageID == messageID }) {
                activities[index].arguments = call.argumentsJSON
            } else {
                activities.append(.init(id: call.id, messageID: messageID, name: call.name,
                    status: String(localized: "Running"), arguments: call.argumentsJSON, isActive: true))
            }
        case .toolResult(let callID, let name, let text, _, let isError):
            guard text.utf8.count <= 262_144 else { throw HanlinHostError.outputLimitExceeded }
            guard let index = activities.firstIndex(where: { $0.id == callID && $0.messageID == messageID }) else { return }
            activities[index].name = name
            activities[index].status = isError ? String(localized: "Failed") : String(localized: "Completed")
            activities[index].result = text
            activities[index].isActive = false
            let resultKey = runID.uuidString + ":" + callID
            if let original = pendingHostResults.removeValue(forKey: resultKey), !isError,
               let destination = try sourceDestination(original) {
                guard sources.count < 256 else { throw HanlinHostError.outputLimitExceeded }
                sources.append(.init(id: original.resultID, messageID: messageID, destination: destination))
            }
        case .toolOutputDenied(let callID, _):
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

    func stop() { operation?.cancel() }

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
        // Mutations already checkpoint through this exact lease. Flush once
        // while it is still current, then revoke before asynchronous SDK work.
        if !storageFailed { try? checkpoint() }
        store.revoke()
        operation?.cancel(); operation = nil
        let prior = agent
        agent = nil; model = nil
        draft = ""; messages.removeAll(); messageStates.removeAll(); activities.removeAll(); reasoning.removeAll(); sources.removeAll()
        pendingHostResults.removeAll()
        isConfigured = false; isConnecting = false; isStreaming = false; isNavigating = false
        Task { await prior?.invalidate() }
    }
}
#endif
