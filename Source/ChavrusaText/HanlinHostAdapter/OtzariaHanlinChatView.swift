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
        content
            .environment(\.otzariaHanlinChatOwner, owner)
            .sheet(isPresented: Binding(
                get: { owner?.isPresented == true },
                set: { owner?.presentationBindingChanged($0) }),
                onDismiss: { owner?.didDismiss() }) {
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
                                                // Native actions are not advertised by this metadata-only host.
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
                .padding(.bottom, composerHeight)
            }
            .scrollDismissesKeyboard(.interactively)
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
            title: { _ in String(localized: "Study chat") },
            subtitle: { _ in String(localized: "Conversation appearance") },
            backIdentifier: { _ in "otzaria-hanlin-composer-back" },
            onOpen: { expanded = true },
            onBackgroundTap: { expanded = false },
            onInputHeightChange: { inputHeight = $0 },
            onToolbarHeightChange: { toolbarHeight = $0 }) {
                Picker(String(localized: "Appearance"), selection: $session.selectedProfile) {
                    ForEach(session.presentationDescriptor.availableProfiles, id: \.reference) { profile in
                        Text(profile.shellID == "hanlin.research" ? String(localized: "Research") : String(localized: "Standard"))
                            .tag(profile.reference)
                    }
                }
                .disabled(session.isStreaming)
                .accessibilityIdentifier("otzaria-hanlin-profile-picker")
            } detail: { _ in
                EmptyView()
            } input: {
                HStack(alignment: .bottom, spacing: 10) {
                    NativeMultilineTextEditor(text: $session.draft, textHeight: $editorHeight,
                        placeholderText: String(localized: "Message"), maxHeight: budget,
                        usesAutomaticLineLimits: true, onSendMessage: session.send)
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
            }
            .padding(12)
    }
}

private struct OtzariaHanlinConnectionView: View {
    @Bindable var session: OtzariaHanlinChatSession
    @State private var endpoint = "https://api.openai.com/v1"
    @State private var model = ""
    @State private var credential = ""
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
                    session.configure(endpoint: endpoint, modelID: model, credential: credential)
                    credential = ""
                }
                .disabled(session.isConnecting)
                .accessibilityIdentifier("otzaria-hanlin-connect")
            }
            Section {
                Text(String(localized: "This conversation uses your messages and permitted catalog metadata. Book text and selections are not shared."))
                Text(String(localized: "Conversations are saved for this study profile, group and library. Your API key lasts only until you close this chat."))
            }
        }
        .onDisappear { credential = "" }
    }
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
        catch { error = String(localized: "Saved conversations are unavailable. Existing data has been preserved.") }
    }
}
#endif
