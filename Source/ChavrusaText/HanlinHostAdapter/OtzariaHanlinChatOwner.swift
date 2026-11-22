#if os(iOS)
import Foundation
import Observation
import SwiftUI
import HanlinHostContracts
import HanlinAgentCore
import OtzariaUIRouting

/// A source click retains one original host identity through actual dismissal.
/// Its dispatcher performs the context transition after the covering sheet is gone.
@MainActor
final class OtzariaHanlinNavigationHandoff {
    let destination: HanlinHostDestination
    let session: HanlinHostSession
    let host: OtzariaHanlinHostAdapter
    var requestID: UUID { destination.requestID }
    private var action: (@MainActor () async throws -> HanlinHostNavigationReceipt)?
    private let closeOriginal: @MainActor () -> Void
    init(destination: HanlinHostDestination, session: HanlinHostSession,
         host: OtzariaHanlinHostAdapter, closeOriginal: @escaping @MainActor () -> Void) {
        self.destination = destination; self.session = session; self.host = host
        self.closeOriginal = closeOriginal
        let dispatcher = HanlinHostDispatcher(host: host)
        action = { try await dispatcher.openWithContextTransition(destination, session: session) }
    }
    func consume() async throws -> HanlinHostNavigationReceipt {
        guard let action else { throw HanlinHostError.duplicateInvocation }
        self.action = nil
        try Task.checkCancellation()
        return try await action()
    }
    func cancel() { action = nil; closeOriginal() }
}

@MainActor @Observable
final class OtzariaHanlinChatOwner {
    private(set) var presentation: OtzariaHanlinChatSession?
    private(set) var isPresented = false
    private(set) var navigationReceipt: HanlinHostNavigationReceipt?
    @ObservationIgnored private weak var manager: iOSNavigationManager?
    @ObservationIgnored private weak var nativeSession: MaktabahNativeSceneSession?
    @ObservationIgnored private let composition: MaktabahNativeRoutingComposition
    @ObservationIgnored private var host: OtzariaHanlinHostAdapter?
    @ObservationIgnored private var presentedSceneID: String?
    @ObservationIgnored private var pendingNavigation: OtzariaHanlinNavigationHandoff?
    @ObservationIgnored private var pendingHistory: (namespace: HanlinConversationNamespace, id: UUID)?
    private struct ReadReopen {
        let originalSessionID: UUID
        let namespace: HanlinConversationNamespace
        let conversationID: UUID
        let consent: MaktabahNativeRoutingComposition.HanlinReadConsent?
        let connection: OtzariaHanlinConnectionRequest?
    }
    @ObservationIgnored private var pendingReadReopen: ReadReopen?
    @ObservationIgnored private var connectionAfterMount: (sessionID: UUID, request: OtzariaHanlinConnectionRequest)?
    @ObservationIgnored private let conversations = OtzariaHanlinConversationStore.shared
    @ObservationIgnored private var navigationTask: Task<Void, Never>?
    @ObservationIgnored private var retired = false

    init(manager: iOSNavigationManager, session: MaktabahNativeSceneSession,
         composition: MaktabahNativeRoutingComposition) {
        self.manager = manager; nativeSession = session; self.composition = composition
    }

    func open(conversationID: UUID? = nil, expectedNamespace: HanlinConversationNamespace? = nil) {
        openConversation(conversationID: conversationID, expectedNamespace: expectedNamespace, readReopen: nil)
    }

    private func openConversation(conversationID: UUID?, expectedNamespace: HanlinConversationNamespace?, readReopen: ReadReopen?) {
        OtzariaHanlinConnectionDiagnostic.record(.openEntered, flags: [
            .retired: retired, .hasPresentation: presentation != nil,
            .hasNavigationTask: navigationTask != nil, .hasNativeSession: nativeSession != nil,
            .mounted: nativeSession?.mounted == true, .foreground: nativeSession?.foreground == true,
            .hasConsent: readReopen?.consent != nil, .hasConnection: readReopen?.connection != nil,
        ])
        guard !retired, presentation == nil, navigationTask == nil,
              let manager, let nativeSession, nativeSession.mounted, nativeSession.foreground else {
            OtzariaHanlinConnectionDiagnostic.record(.openRejected)
            return
        }
        var issued: HanlinHostSession?
        do {
            let readConnection: (consent: MaktabahNativeRoutingComposition.HanlinReadConsent, dismissedSessionID: UUID, configurationID: UUID)?
            if let readReopen, let consent = readReopen.consent, let connection = readReopen.connection {
                readConnection = (consent, readReopen.originalSessionID, connection.id)
            } else { readConnection = nil }
            let prepared = try composition.makeHanlinHostSession(manager: manager, conversationID: conversationID ?? UUID(),
                readConnection: readConnection) { [weak self] in
                self?.requestClose()
            }
            issued = prepared.session
            let identity = prepared.session
            if let expectedNamespace {
                guard identity.context.namespace == expectedNamespace else { throw HanlinHostError.staleContext }
                if readReopen == nil {
                    guard try conversations.history(identity.conversationID, namespace: expectedNamespace) != nil else {
                        throw HanlinHostError.staleContext
                    }
                }
            }
            let sessionID = identity.id
            let scopedStore = OtzariaHanlinScopedConversationStore(identity: identity, store: conversations) { [weak self] in
                guard let self, !self.retired, let nativeSession = self.nativeSession,
                      nativeSession.mounted, nativeSession.foreground else { throw HanlinHostError.staleContext }
                try self.composition.validateHanlinHostSession(identity)
            }
            let readScope = try composition.hanlinCurrentWorkReadScope(for: identity)
            let readOffer = try? composition.hanlinCurrentWorkReadOffer(manager: manager, session: identity)
            let value = try OtzariaHanlinChatSession(identity: identity, host: prepared.host, store: scopedStore,
                currentWorkReadOffer: readOffer, currentWorkReadScope: readScope,
                requiredConfigurationID: readScope == nil ? nil : readReopen?.connection?.id,
                onConnectionConfigured: { [weak self] configurationID in
                    guard let self else { throw HanlinHostError.staleContext }
                    try self.validate(sessionID)
                    try self.composition.hanlinConnectionConfigured(configurationID, session: identity)
                }, onRequestReadConnection: { [weak self] request, scope in
                    guard let self else { throw HanlinHostError.staleContext }
                    try self.requestReadConnection(request, displayedScope: scope, sessionID: sessionID)
                },
                sourceDestination: { [weak self] event in
                    guard let self else { throw HanlinHostError.staleContext }
                    return try self.composition.hanlinSourceDestination(event, session: identity)
                }, validateOwner: { [weak self] in
                    guard let self else { throw HanlinHostError.staleContext }
                    try self.validate(sessionID)
                }, onClose: { [weak self] in self?.requestClose(sessionID: sessionID) },
                onNavigate: { [weak self] url in
                    guard let self else { throw HanlinHostError.staleContext }
                    try await self.queueNavigation(url, sessionID: sessionID)
                })
            try nativeSession.beginStudyChatPresentation(sessionID)
            host = prepared.host; presentation = value; presentedSceneID = nil; isPresented = true
            if let connection = readReopen?.connection {
                connectionAfterMount = (sessionID, connection)
            }
            OtzariaHanlinConnectionDiagnostic.record(.openIssued, flags: [.hasReadScope: readScope != nil])
        } catch {
            OtzariaHanlinConnectionDiagnostic.record(.openFailed,
                reason: OtzariaHanlinConnectionDiagnostic.reason(for: error))
            readReopen?.consent?.revoke()
            connectionAfterMount = nil
            if let issued {
                nativeSession.finishStudyChatPresentation(issued.id)
                composition.closeHanlinHostSession(issued)
            }
            manager.alertMessage = .init(title: String(localized: "Study chat unavailable"),
                message: String(localized: "The original study window is not ready. Try again from the reader."))
        }
    }

    func didMount(sceneID: String, sessionID: UUID) {
        OtzariaHanlinConnectionDiagnostic.record(.mountObserved, flags: [
            .matchingSession: presentation?.id == sessionID, .isPresented: isPresented,
            .retired: retired, .hasNativeSession: nativeSession != nil,
        ])
        guard presentation?.id == sessionID, isPresented, !retired else { return }
        guard let nativeSession, sceneID == nativeSession.sceneID.rawValue else {
            requestClose(sessionID: sessionID); return
        }
        presentedSceneID = sceneID
        if let pending = connectionAfterMount, pending.sessionID == sessionID {
            connectionAfterMount = nil
            presentation?.configure(pending.request)
        }
    }

    private func validate(_ sessionID: UUID) throws {
        guard !retired, isPresented, let presentation, presentation.id == sessionID,
              let nativeSession, nativeSession.mounted, nativeSession.foreground,
              presentedSceneID == nativeSession.sceneID.rawValue else { throw HanlinHostError.staleContext }
        try composition.validateHanlinHostSession(presentation.identity)
    }

    private func queueNavigation(_ url: URL, sessionID: UUID) async throws {
        try validate(sessionID)
        guard pendingNavigation == nil, pendingHistory == nil, pendingReadReopen == nil, navigationTask == nil,
              let host, let presentation else { throw HanlinHostError.duplicateInvocation }
        let destination = HanlinHostDestination(context: presentation.identity.context, objectReference: url.absoluteString)
        let response = try await host.open(destination)
        try response.validate(for: destination)
        guard case .queued = response else { throw HanlinHostError.resultMismatch }
        try validate(sessionID)
        let identity = presentation.identity
        pendingNavigation = .init(destination: destination, session: identity, host: host) { [weak self] in
            self?.composition.closeHanlinHostSession(identity)
        }
        requestClose(sessionID: sessionID, preservingContinuation: true)
    }

    func history() throws -> [OtzariaHanlinConversationSummary] {
        guard let presentation else { throw HanlinHostError.staleContext }
        try validate(presentation.id)
        return try conversations.summaries(namespace: presentation.identity.context.namespace)
    }

    func selectHistory(_ id: UUID) throws {
        guard let presentation, pendingNavigation == nil, pendingHistory == nil, pendingReadReopen == nil,
              navigationTask == nil else { throw HanlinHostError.staleContext }
        try validate(presentation.id)
        let namespace = presentation.identity.context.namespace
        guard try conversations.history(id, namespace: namespace) != nil else { throw HanlinHostError.invalidRecord }
        pendingHistory = (namespace, id)
        requestClose(sessionID: presentation.id, preservingContinuation: true)
    }

    func deleteHistory(_ summary: OtzariaHanlinConversationSummary) throws {
        guard let presentation, summary.id != presentation.identity.conversationID else { throw HanlinHostError.denied }
        try validate(presentation.id)
        try conversations.deleteConversation(summary, namespace: presentation.identity.context.namespace)
    }

    /// Called only by the native connection form after the user confirms the
    /// displayed work and supplies the exact immutable model configuration.
    private func requestReadConnection(_ request: OtzariaHanlinConnectionRequest,
        displayedScope: OtzariaHanlinCurrentWorkReadScope, sessionID: UUID) throws {
        OtzariaHanlinConnectionDiagnostic.record(.consentCaptureEntered)
        try validate(sessionID)
        guard let presentation, let manager, !presentation.isConfigured,
              !presentation.isConnecting, !presentation.isStreaming,
              pendingNavigation == nil, pendingHistory == nil, pendingReadReopen == nil,
              navigationTask == nil else { throw HanlinHostError.denied }
        let consent = try composition.makeHanlinCurrentWorkReadConsent(manager: manager,
            session: presentation.identity, displayedScope: displayedScope, configurationID: request.id) { [weak self] in
                self?.requestClose(sessionID: sessionID)
            }
        pendingReadReopen = .init(originalSessionID: sessionID, namespace: presentation.identity.context.namespace,
            conversationID: presentation.identity.conversationID, consent: consent, connection: request)
        OtzariaHanlinConnectionDiagnostic.record(.consentCaptured)
        requestClose(sessionID: sessionID, preservingContinuation: true)
    }

    /// Revocation cancels the original stream now, before asynchronous SDK
    /// invalidation or sheet dismissal. No connection/key follows the reopen.
    func endCurrentWorkReadAccess(sessionID: UUID) {
        guard let presentation, presentation.id == sessionID, presentation.currentWorkReadScope != nil else { return }
        do {
            try validate(sessionID)
            guard pendingNavigation == nil, pendingHistory == nil, pendingReadReopen == nil,
                  navigationTask == nil else { throw HanlinHostError.staleContext }
            pendingReadReopen = .init(originalSessionID: sessionID, namespace: presentation.identity.context.namespace,
                conversationID: presentation.identity.conversationID, consent: nil, connection: nil)
            requestClose(sessionID: sessionID, preservingContinuation: true)
        } catch { requestClose(sessionID: sessionID) }
    }

    /// A programmatic dismissal already owns its continuation. SwiftUI echoing
    /// false must not cancel the native handoff or the selected history reopen.
    func presentationBindingChanged(_ value: Bool, sessionID: UUID?) {
        guard let sessionID, presentation?.id == sessionID else { return }
        if !value && isPresented { requestClose(sessionID: sessionID) }
    }

    func requestClose(sessionID: UUID? = nil, preservingContinuation: Bool = false) {
        OtzariaHanlinConnectionDiagnostic.record(.closeRequested, flags: [
            .hasPresentation: presentation != nil,
            .matchingSession: presentation != nil && (sessionID == nil || presentation?.id == sessionID),
            .preservingContinuation: preservingContinuation, .hasPendingReadReopen: pendingReadReopen != nil,
        ])
        guard let presentation, sessionID == nil || presentation.id == sessionID else { return }
        if !preservingContinuation {
            pendingNavigation?.cancel(); pendingNavigation = nil; pendingHistory = nil
            pendingReadReopen?.consent?.revoke(); pendingReadReopen = nil
        }
        connectionAfterMount = nil
        isPresented = false; presentedSceneID = nil
        presentation.revoke()
        if pendingNavigation == nil { composition.closeHanlinHostSession(presentation.identity) }
        host = nil
    }

    /// SwiftUI calls this after the actual owned sheet finishes dismissing.
    /// A replacement cannot be opened while that old presentation is retained.
    func didDismiss(sessionID: UUID?) {
        OtzariaHanlinConnectionDiagnostic.record(.dismissObserved, flags: [
            .hasPresentation: presentation != nil,
            .matchingSession: sessionID != nil && presentation?.id == sessionID,
            .isPresented: isPresented, .hasPendingReadReopen: pendingReadReopen != nil,
        ])
        // A superseded SwiftUI callback has no ownership over this sheet or its
        // pending grant, even if the current sheet is itself already dismissing.
        guard let sessionID, let current = presentation, current.id == sessionID, !isPresented else { return }
        OtzariaHanlinConnectionDiagnostic.record(.dismissAccepted)
        current.revoke()
        if pendingNavigation == nil { composition.closeHanlinHostSession(current.identity) }
        nativeSession?.finishStudyChatPresentation(sessionID)
        presentation = nil; host = nil; isPresented = false; presentedSceneID = nil
        connectionAfterMount = nil
        if let readReopen = pendingReadReopen {
            pendingReadReopen = nil
            guard !retired, readReopen.originalSessionID == sessionID else {
                readReopen.consent?.revoke(); return
            }
            OtzariaHanlinConnectionDiagnostic.record(.readReopenEntered, flags: [
                .hasConsent: readReopen.consent != nil, .hasConnection: readReopen.connection != nil,
            ])
            openConversation(conversationID: readReopen.conversationID,
                expectedNamespace: readReopen.namespace, readReopen: readReopen)
            return
        }
        if !retired, let history = pendingHistory {
            pendingHistory = nil
            open(conversationID: history.id, expectedNamespace: history.namespace)
            return
        }
        pendingHistory = nil
        guard !retired, let handoff = pendingNavigation, navigationTask == nil else {
            pendingNavigation?.cancel(); pendingNavigation = nil; return
        }
        pendingNavigation = nil
        navigationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.navigationTask = nil }
            do {
                let receipt = try await handoff.consume()
                try Task.checkCancellation()
                try receipt.validate(for: handoff.destination, session: handoff.session)
                guard !self.retired, receipt.presentationAcknowledged else { throw HanlinHostError.staleContext }
                self.navigationReceipt = receipt
                // A source button keeps the existing close-chat behavior. Do not
                // silently resume a model or transfer its former consent. A later
                // explicit chat opening uses the same saved conversation store.
                if let successor = receipt.successorSession { self.composition.closeHanlinHostSession(successor) }
                self.composition.closeHanlinHostSession(handoff.session)
            } catch {
                let observed = await handoff.host.navigationReceipt(for: handoff.requestID, session: handoff.session)
                if let successor = observed?.successorSession { self.composition.closeHanlinHostSession(successor) }
                self.composition.closeHanlinHostSession(handoff.session)
                if !self.retired {
                    self.manager?.alertMessage = .init(title: String(localized: "Source unavailable"),
                        message: String(localized: "The source could not be opened in the original study window."))
                }
            }
        }
    }

    func retire() {
        guard !retired else { return }
        retired = true
        if let presentation { nativeSession?.finishStudyChatPresentation(presentation.id) }
        navigationTask?.cancel(); navigationTask = nil
        pendingNavigation?.cancel(); pendingNavigation = nil; pendingHistory = nil
        pendingReadReopen?.consent?.revoke(); pendingReadReopen = nil; connectionAfterMount = nil
        requestClose()
    }
}

private struct OtzariaHanlinChatOwnerKey: EnvironmentKey {
    static let defaultValue: OtzariaHanlinChatOwner? = nil
}
extension EnvironmentValues {
    var otzariaHanlinChatOwner: OtzariaHanlinChatOwner? {
        get { self[OtzariaHanlinChatOwnerKey.self] }
        set { self[OtzariaHanlinChatOwnerKey.self] = newValue }
    }
}
#endif
