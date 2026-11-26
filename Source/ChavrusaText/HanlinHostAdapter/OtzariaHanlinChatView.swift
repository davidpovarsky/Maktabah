#if os(iOS)
import SwiftUI
import HanlinChatUI
import HanlinScriptUI
import HanlinHostContracts
import HanlinPresentationKit
import HanlinRichUI

/// The actual native reader/global toolbar shares this scene's original owner.
struct OtzariaHanlinChatLaunchButton: View {
    let identifier: String
    @Environment(\.otzariaHanlinChatOwner) private var owner
    var body: some View {
        if let owner {
            Button { owner.open() } label: {
                Label(String(localized: "Study chat"), systemImage: "bubble.left.and.text.bubble.right")
            }
            .accessibilityIdentifier(identifier)
        }
    }
}

struct OtzariaHanlinChatPresentationHost: ViewModifier {
    let owner: OtzariaHanlinChatOwner?
    func body(content: Content) -> some View {
        let dismissedSessionID = owner?.presentation?.id
        return content
            .environment(\.otzariaHanlinChatOwner, owner)
            .sheet(isPresented: Binding(
                get: { owner?.isPresented == true && owner?.presentation?.id == dismissedSessionID },
                set: { [dismissedSessionID] in owner?.presentationBindingChanged($0, sessionID: dismissedSessionID) }),
                onDismiss: { [dismissedSessionID] in owner?.didDismiss(sessionID: dismissedSessionID) }) {
                    if let owner, let session = owner.presentation {
                        OtzariaHanlinChatView(session: session, owner: owner)
                    }
                }
    }
}

/// Composition of the canonical SDK layout, Markdown/OpenUI, tool activity,
/// Morph composer and native editor. There is no host renderer or agent loop.
private struct OtzariaHanlinChatView: View {
    @Bindable var session: OtzariaHanlinChatSession
    let owner: OtzariaHanlinChatOwner
    @State private var showsConnection = false
    @State private var expanded = false
    @State private var activePage: String?
    @State private var editorHeight: CGFloat = 38
    @State private var inputHeight: CGFloat = 52
    @State private var toolbarHeight: CGFloat = 0
    @State private var composerHeight: CGFloat = 70

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let scope = session.currentWorkReadScope {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Book search: \(scope.title)")).font(.subheadline)
                        Text(String(localized: "Otzaria. Matching excerpts may be shared with your connected model."))
                            .font(.caption).foregroundStyle(.secondary)
                        Button(String(localized: "End book access")) { owner.endCurrentWorkReadAccess(sessionID: session.id) }
                            .accessibilityIdentifier("otzaria-hanlin-end-book-access")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.vertical, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("otzaria-hanlin-book-access")
                }
                if let error = session.errorMessage { HanlinChatErrorBanner(errorMessage: error) }
                if session.isConfigured || !session.messages.isEmpty || !session.draft.isEmpty {
                    GeometryReader { geometry in
                        HanlinChatView(shell: session.profile?.shell ?? .init(id: "hanlin.research", title: String(localized: "Study chat"))) {
                            transcript
                        } composer: {
                            composer(availableHeight: geometry.size.height)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { composerHeight = $0 }
                        }
                    }
                } else {
                    OtzariaHanlinConnectionView(session: session)
                }
            }
            .navigationTitle(String(localized: "Study chat"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !session.isConfigured && (!session.messages.isEmpty || !session.draft.isEmpty) {
                    ToolbarItem(placement: .primaryAction) {
                        Button(String(localized: "Connect")) { showsConnection = true }
                            .accessibilityIdentifier("otzaria-hanlin-reconnect")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        OtzariaHanlinHistoryView(owner: owner, currentID: session.identity.conversationID)
                    } label: {
                        Label(String(localized: "Conversations"), systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("otzaria-hanlin-history")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close"), action: session.close)
                        .accessibilityIdentifier("otzaria-hanlin-close")
                }
            }
        }
        .sheet(isPresented: $showsConnection) {
            NavigationStack {
                VStack(spacing: 0) {
                    if let error = session.errorMessage { HanlinChatErrorBanner(errorMessage: error) }
                    OtzariaHanlinConnectionView(session: session)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Close")) { showsConnection = false }
                    }
                }
            }
        }
        .onChange(of: session.isConfigured) { _, value in if value { showsConnection = false } }
        .background {
            ReaderSceneIdentityReader { sceneID in owner.didMount(sceneID: sceneID, sessionID: session.id) }
                .frame(width: 0, height: 0).accessibilityHidden(true)
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme?.lowercased() == "maktabah" {
                session.requestNavigation(url)
                return .handled
            }
            return ["https", "http"].contains(url.scheme?.lowercased() ?? "") ? .systemAction : .discarded
        })
        .accessibilityIdentifier("otzaria-hanlin-chat")
    }

    private var transcript: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(session.messages) { message in
                        VStack(alignment: .leading, spacing: 10) {
                            if message.role == "user" {
                                HanlinChatMessageBubble(message: message, presentationMode: .full)
                            } else if let state = session.messageStates[message.id] {
                                if let reasoning = session.reasoning[message.id], !reasoning.isEmpty {
                                    DisclosureGroup(String(localized: "Thinking"), isExpanded: Binding(
                                        get: { state.expandedActivityIDs.contains("reasoning") },
                                        set: { state.setExpanded($0, activityID: "reasoning") })) {
                                        HanlinMarkdownView(text: reasoning)
                                    }
                                    .disclosureGroupStyle(HanlinMotionDisclosureStyle())
                                }
                                ForEach(session.activities.filter { $0.messageID == message.id }) { activity in
                                    DisclosureGroup(isExpanded: Binding(
                                        get: { state.expandedActivityIDs.contains(activity.id) },
                                        set: { state.setExpanded($0, activityID: activity.id) })) {
                                        Text(activity.arguments).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                                        if let result = activity.result { HanlinMarkdownView(text: result) }
                                    } label: {
                                        HanlinToolActivityHeader(title: activity.name, status: activity.status,
                                            symbol: "wrench.and.screwdriver", isActive: activity.isActive)
                                    }
                                    .disclosureGroupStyle(HanlinMotionDisclosureStyle())
                                }
                                ForEach(session.sources.filter { $0.messageID == message.id }) { source in
                                    Button {
                                        session.requestNavigation(source.destination)
                                    } label: {
                                        Label(String(localized: "Open source"), systemImage: "book")
                                    }
                                    .disabled(session.isStreaming || session.isNavigating)
                                    .accessibilityIdentifier("otzaria-hanlin-source-" + source.id.uuidString)
                                }
                                if message.content.isEmpty && session.isStreaming && message.id == session.messages.last?.id {
                                    ProgressView().accessibilityLabel(String(localized: "Thinking"))
                                }
                                ForEach(OpenUIInlineParts.split(message.content, identity: state.identity,
                                    catalogs: state.profile.catalogs.map(\.reference),
                                    isStreaming: session.isStreaming && message.id == session.messages.last?.id)) { part in
                                        switch part.payload {
                                        case .markdown(let text): HanlinMarkdownView(text: text)
                                        case .openUI:
                                            OpenUIBlock(part: part, state: state) { _ in
                                                // Native actions are not advertised by this read-only host.
                                                // Local renderer state uses the original message state owner.
                                                throw HanlinHostError.denied
                                            }
                                        }
                                    }
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding()
            }
            // Auto-follow must place the final message above the floating input.
            // Stack padding alone leaves source actions under the native editor.
            .safeAreaPadding(.bottom, composerHeight)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("otzaria-hanlin-transcript")
            .onChange(of: session.messages.last?.content) { _, _ in
                if let last = session.messages.last { reader.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private func composer(availableHeight: CGFloat) -> some View {
        let budget = max(38, HanlinMorphGeometry.editorBudget(availableHeight: availableHeight,
            accessoryHeight: 0, inputHeight: inputHeight, editorHeight: editorHeight,
            toolbarHeight: toolbarHeight, isExpanded: expanded))
        return HanlinMorphComposer(
            isExpanded: $expanded, activePage: $activePage, availableHeight: availableHeight, accessoryHeight: 0,
            inputHeight: inputHeight,
            title: { _ in String(localized: "Study chat") },
            subtitle: { _ in String(localized: "Conversation appearance") },
            backIdentifier: { _ in "otzaria-hanlin-composer-back" },
            onOpen: { expanded = true },
            onBackgroundTap: { expanded = false },
            onToolbarHeightChange: { toolbarHeight = $0 },
            home: {
                Picker(String(localized: "Appearance"), selection: $session.selectedProfile) {
                    ForEach(session.presentationDescriptor.availableProfiles, id: \.reference) { profile in
                        Text(profile.shellID == "hanlin.research" ? String(localized: "Research") : String(localized: "Standard"))
                            .tag(profile.reference)
                    }
                }
                .disabled(session.isStreaming)
                .accessibilityIdentifier("otzaria-hanlin-profile-picker")
            }, detail: { _ in
                EmptyView()
            }, input: {
                HStack(alignment: .bottom, spacing: 10) {
                    NativeMultilineTextEditor(
                        text: Binding(
                            get: { [session] in session.draft },
                            set: { [session] in session.updateDraftFromEditor($0) }),
                        textHeight: $editorHeight,
                        placeholderText: String(localized: "Message"), maxHeight: budget,
                        usesAutomaticLineLimits: true, onSendMessage: session.send,
                        readCurrentTextState: { [session] in session.readCurrentDraftTextState() })
                        .frame(height: min(editorHeight, budget))
                        .accessibilityIdentifier("otzaria-hanlin-composer")
                    if session.isStreaming {
                        Button(action: session.stop) {
                            Image(systemName: "stop.circle.fill").font(.title)
                        }
                        .accessibilityLabel(String(localized: "Stop"))
                        .accessibilityIdentifier("otzaria-hanlin-stop")
                    } else {
                        HanlinChatSendButton(canSend: session.canSend, isStreaming: false,
                            presentationMode: .full, action: session.send)
                            .accessibilityIdentifier("otzaria-hanlin-send")
                    }
                }
                .padding(10)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    guard height.isFinite, height > 1, abs(height - inputHeight) > 0.5 else { return }
                    inputHeight = height
                }
            })
            .padding(12)
    }
}

private struct OtzariaHanlinConnectionView: View {
    @Bindable var session: OtzariaHanlinChatSession
    @State private var endpoint = "https://api.openai.com/v1"
    @State private var model = ""
    @State private var credential = ""
    @State private var allowCurrentWorkRead = false
    var body: some View {
        Form {
            Section(String(localized: "Model connection")) {
                TextField(String(localized: "Service address"), text: $endpoint)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("otzaria-hanlin-service-address")
                TextField(String(localized: "Model"), text: $model)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("otzaria-hanlin-model")
                SecureField(String(localized: "API key"), text: $credential)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("otzaria-hanlin-api-key")
                Button(String(localized: "Connect")) {
                    session.configure(endpoint: endpoint, modelID: model, credential: credential,
                        allowCurrentWorkRead: allowCurrentWorkRead)
                    credential = ""
                }
                .disabled(session.isConnecting || session.currentWorkReadScope != nil)
                .accessibilityIdentifier("otzaria-hanlin-connect")
            }
            if let scope = session.currentWorkReadOffer, session.currentWorkReadScope == nil {
                Section {
                    Text(scope.title).font(.headline)
                        .accessibilityIdentifier("otzaria-hanlin-consent-book-title")
                    Text(String(localized: "Library: Otzaria")).foregroundStyle(.secondary)
                    Toggle(String(localized: "Allow search in this book for this chat"), isOn: $allowCurrentWorkRead)
                        .disabled(session.isConnecting)
                        .accessibilityIdentifier("otzaria-hanlin-allow-current-book")
                    Text(String(localized: "When you send a message, matching excerpts from this book may be sent to the service and model above. This permission ends when the chat closes or its source changes."))
                        .font(.footnote)
                    Text(String(localized: "Connecting with book access reopens this saved conversation. Your messages and draft stay saved."))
                        .font(.footnote)
                } header: {
                    Text(String(localized: "Book access"))
                        .accessibilityIdentifier("otzaria-hanlin-current-book-consent")
                }
            } else if session.currentWorkReadScope == nil {
                Section(String(localized: "Book access")) {
                    Text(String(localized: "Search access is unavailable for the current source."))
                }
            }
            Section {
                Text(String(localized: "This conversation uses your messages and permitted catalog metadata. Book search is off unless you allow the displayed book. Selections are not shared."))
                Text(String(localized: "Conversations are saved for this study profile, group and library. Your API key lasts only until you close this chat."))
            }
        }
        .accessibilityIdentifier("otzaria-hanlin-connection-form")
        .onAppear {
#if DEBUG && targetEnvironment(simulator)
            prefillLiveAcceptanceConnectionIfRequested()
#endif
        }
        .onDisappear { credential = "" }
    }

#if DEBUG && targetEnvironment(simulator)
    /// Uses the same one-use private-input pattern as the pinned Hanlin app.
    /// This only fills the existing form; Connect, consent and Send stay native.
    private func prefillLiveAcceptanceConnectionIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["OTZARIA_HANLIN_LIVE_PROVIDER_CASE"] == "1",
              let nonce = environment["OTZARIA_HANLIN_LIVE_NONCE"], UUID(uuidString: nonce) != nil else { return }
        let manager = FileManager.default
        do {
            let support = try manager.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let file = support.appendingPathComponent("OtzariaHanlinLiveProviderAcceptance/provider.json")
            // Reopening the original form never restores a consumed credential.
            guard manager.fileExists(atPath: file.path) else { return }
            let attributes = try manager.attributesOfItem(atPath: file.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 8192,
                  ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0) == 0o600,
                  let input = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: String],
                  Set(input.keys) == ["nonce", "apiKey", "model", "endpoint"],
                  input["nonce"] == nonce,
                  input["endpoint"] == "https://generativelanguage.googleapis.com/v1beta/openai/",
                  let configuredModel = input["model"], configuredModel.utf8.count <= 128,
                  configuredModel.range(of: #"\Agemini-[a-z0-9][a-z0-9._-]*\z"#, options: .regularExpression) != nil,
                  let key = input["apiKey"], !key.isEmpty, key.utf8.count <= 4096 else {
                fatalError("The private live-acceptance input is unavailable")
            }
            try manager.removeItem(at: file)
            endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/"
            model = configuredModel
            credential = key
            OtzariaHanlinConnectionDiagnostic.beginOwnedLiveInput(nonce: nonce)
        } catch {
            // Do not print parser errors, input bytes or account fields.
            fatalError("The private live-acceptance input could not be consumed")
        }
    }
#endif
}
private struct OtzariaHanlinHistoryView: View {
    let owner: OtzariaHanlinChatOwner
    let currentID: UUID
    @State private var rows: [OtzariaHanlinConversationSummary] = []
    @State private var error: String?
    @State private var pendingDelete: OtzariaHanlinConversationSummary?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if rows.isEmpty && error == nil {
                ContentUnavailableView(String(localized: "No saved conversations"), systemImage: "bubble.left.and.bubble.right")
            }
            ForEach(rows) { row in
                Button {
                    do { try owner.selectHistory(row.id) }
                    catch { self.error = String(localized: "This conversation could not be opened in the current study group.") }
                } label: {
                    VStack(alignment: .leading) {
                        Text(row.title.isEmpty ? String(localized: "Untitled conversation") : row.title).lineLimit(2)
                        Text(row.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("otzaria-hanlin-saved-" + row.id.uuidString)
                .swipeActions {
                    if row.id != currentID {
                        Button(String(localized: "Delete"), role: .destructive) { pendingDelete = row }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Conversations"))
        .accessibilityIdentifier("otzaria-hanlin-history-list")
        .onAppear(perform: reload)
        .confirmationDialog(String(localized: "Delete this conversation?"),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible) {
                if let row = pendingDelete {
                    Button(String(localized: "Delete"), role: .destructive) {
                        do { try owner.deleteHistory(row); pendingDelete = nil; reload() }
                        catch { self.error = String(localized: "The conversation changed or could not be deleted. Reload the list before retrying.") }
                    }
                }
            }
    }
    private func reload() {
        do { rows = try owner.history(); error = nil }
        catch { self.error = String(localized: "Saved conversations are unavailable. Existing data has been preserved.") }
    }
}
#endif
