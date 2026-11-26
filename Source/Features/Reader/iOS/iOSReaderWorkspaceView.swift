import FloatingPanel
import SwiftUI
import TorahInspectorCore
import TorahInspectorUI

struct ContentsToggleIcon: View {
    let isOpen: Bool

    var body: some View {
        ZStack {
            if isOpen {
                Image(systemName: "list.bullet.rectangle.fill")
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Image(systemName: "list.bullet.rectangle")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 22)
        .animation(.snappy(duration: 0.31, extraBounce: 0), value: isOpen)
    }
}

struct PanelToggleIcon: View {
    let isOpen: Bool

    var body: some View {
        ZStack {
            if isOpen {
                Image(systemName: "rectangle.split.2x1.fill")
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Image(systemName: "rectangle.split.2x1")
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 22)
        .animation(.snappy(duration: 0.31, extraBounce: 0), value: isOpen)
    }
}

final class StudyContentFloatingPanelLayout: FloatingPanelLayout {
    let position: FloatingPanelPosition = .bottom
    let initialState: FloatingPanelState = .hidden
    let anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] = [
        .full: FloatingPanelLayoutAnchor(
            absoluteInset: 12,
            edge: .top,
            referenceGuide: .safeArea
        ),
        .half: FloatingPanelLayoutAnchor(
            fractionalInset: 0.5,
            edge: .bottom,
            referenceGuide: .superview
        ),
        .hidden: FloatingPanelLayoutAnchor(
            absoluteInset: 0,
            edge: .bottom,
            referenceGuide: .superview
        ),
    ]

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        switch state {
        case .full: 0.18
        case .half, .hidden: 0
        default: 0
        }
    }
}

struct iOSReaderWorkspaceView: View {
    private static let minimumPanelWidth: CGFloat = 300
    private static let maximumPanelWidth: CGFloat = 520
    private static let defaultPanelWidth: CGFloat = 390

    let book: BooksData
    let viewModel: ReaderViewModel
    let initialContentId: Int?
    @Binding private var libraryColumnVisibility: NavigationSplitViewVisibility
    @Binding private var preferredCompactColumn: NavigationSplitViewColumn

    @Environment(iOSNavigationManager.self) private var navigationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.chavrusaReaderSidebar) private var sidebarCoordinator
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.maktabahNativeRoutingSession) private var nativeRoutingSession

    @State private var detailColumnWidth: CGFloat = 0
    @State private var compactContentsRequested = false
    @State private var compactUsesContentsFallback = false
    @State private var panelWidth = Self.defaultPanelWidth
    @State private var dragStartWidth: CGFloat?
    @State private var showPanelSheet = false
    @State private var compactPanelDetent: PresentationDetent = .medium
    @State private var nativeStudyPresentation = NativeStudySheetPresentationState()
    @State private var nativeStudyDetent: PresentationDetent = .medium
    @State private var runsCompactTOCTransitionSmoke = false
    @State private var runsFloatingFullSmoke = false
    @State private var pendingCompactContentsOpen = false
    @State private var floatingPanelState: FloatingPanelState? = .hidden
    @State private var selectedTool: TorahStudyTool = .commentaries
    @State private var inspectorSession: MaktabahTorahInspectorSession
    @State private var inspectorContentID = UUID()
    @State private var editingAnnotation: Annotation?
    @State private var fallbackNoteHost: NativeStudySheetPresentationState.NoteHost = .reader
    @State private var nativeNoteEditorOwnerID = UUID()
    @State private var nativeNoteEditorPresentationID = UUID()
    @State private var noteErrorMessage: String?
    @State private var pendingNotesDidChange: TorahInspectorHostActions.NotesDidChange?
    #if DEBUG
    @State private var nativeStudyAcceptance = NativeStudySheetAcceptance()
    #endif

    init(
        book: BooksData,
        viewModel: ReaderViewModel,
        initialContentId: Int? = nil,
        libraryColumnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.detailOnly),
        preferredCompactColumn: Binding<NavigationSplitViewColumn> = .constant(.detail)
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        let scenario = arguments.firstIndex(of: "-smokeScenario").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        self.book = book
        self.viewModel = viewModel
        self.initialContentId = initialContentId
        self._libraryColumnVisibility = libraryColumnVisibility
        self._preferredCompactColumn = preferredCompactColumn
        self._compactContentsRequested = State(initialValue: scenario == "readerTOC")
        self._floatingPanelState = State(
            initialValue: scenario == "studyFloatingFull" ? .full : .hidden
        )
        self._selectedTool = State(
            initialValue: scenario == "studyLinks" ? .links : scenario == "studyNotes" ? .notes : .commentaries
        )
        self._compactPanelDetent = State(initialValue: scenario == "studyCompactLarge" ? .large : .medium)
        self._runsCompactTOCTransitionSmoke = State(initialValue: scenario == "compactStudyToTOC")
        self._runsFloatingFullSmoke = State(initialValue: scenario == "studyFloatingFull")
        self._inspectorSession = State(initialValue: MaktabahTorahInspectorSession(viewModel: viewModel))
    }

    private var useWideLayout: Bool {
        horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }

    private var librarySidebarIsOpen: Bool {
        libraryColumnVisibility == .all
    }

    private var contentsIsOpen: Bool {
        if let sidebarCoordinator {
            return sidebarCoordinator.page == .contents && libraryColumnVisibility != .detailOnly
        }
        return libraryColumnVisibility != .detailOnly
    }

    private var shouldPresentPanelInContent: Bool {
        if sidebarCoordinator != nil {
            // The shared-sidebar Inspector overlays the existing Reader at
            // every iPad width; it must never reserve a second host column.
            return true
        }
        return useWideLayout && librarySidebarIsOpen && contentsIsOpen
    }

    private var showPanel: Bool {
        viewModel.readerInspectorVisible
    }

    private var usesNativeStudySheet: Bool {
        guard ChavrusaTextReaderUI.isEnabled else { return false }
        if #available(iOS 27.0, *) { return MaktabahApp.isIpad }
        return false
    }

    private var readerHeaderTitle: String {
        let title = book.book.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        if let currentBookName = viewModel.currentBook?.book,
           !currentBookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentBookName
        }
        if let node = selectedTOCNode, !node.bab.isEmpty {
            return node.bab
        }
        return ""
    }

    private var readerHeaderSubtitle: String {
        let status = viewModel.statusSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !status.isEmpty && status != readerHeaderTitle {
            return status
        }
        if let index = viewModel.currentNavigationIndex,
           viewModel.navigationItems.indices.contains(index) {
            let navTitle = viewModel.navigationItems[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !navTitle.isEmpty && navTitle != readerHeaderTitle {
                return navTitle
            }
        }
        if let node = selectedTOCNode, !node.bab.isEmpty && node.bab != readerHeaderTitle {
            return node.bab
        }
        return ""
    }

    private var selectedTOCNode: TOCNode? {
        if let locator = viewModel.backendSection?.locator ?? viewModel.currentBook?.backendLocator,
           let node = viewModel.tocViewModel.findMatchingNode(for: locator) {
            return node
        }
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }

    var body: some View {
        let dismissingNoteEditorPresentationID = nativeNoteEditorPresentationID
        let dismissingStudyPresentationID = nativeStudyPresentation.presentation?.id
        Group {
            if !useWideLayout, compactUsesContentsFallback {
                tocColumn
            } else {
                workspaceDetail
            }
        }
        .onAppear {
            updatePanelPresentation(animated: false)
            attachNativeNoteEditor()
        }
        .onChange(of: nativeRoutingSession.map(ObjectIdentifier.init), initial: true) { _, _ in
            attachNativeNoteEditor()
        }
        .onDisappear { nativeRoutingSession?.detachNoteEditor(id: nativeNoteEditorOwnerID) }
        #if DEBUG
        .task {
            guard usesNativeStudySheet, NativeStudySheetAcceptance.namespace != nil else { return }
            let deadline = ProcessInfo.processInfo.systemUptime + 300
            while !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
                if navigationManager.activeReaderViewModel === viewModel {
                    nativeStudyAcceptance.poll(context: nativeStudyAcceptanceContext,
                        close: { viewModel.closeReaderInspector() }, contents: openContents,
                        toggle: toggleStudyPanel)
                }
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
        .task {
            await MaktabahNativeRoutingComposition.shared.runNoteDraftAcceptanceProbe(
                manager: navigationManager, reader: viewModel, currentDraft: { editingAnnotation })
            await MaktabahNativeRoutingComposition.shared.runCommentaryAcceptanceProbe(
                manager: navigationManager, reader: viewModel)
        }
        #endif
        .task {
            if runsCompactTOCTransitionSmoke {
                for _ in 0..<50 where !showPanelSheet {
                    try? await Task.sleep(for: .milliseconds(200))
                }
                runsCompactTOCTransitionSmoke = false
                if showPanelSheet {
                    openContents()
                }
            }
            if runsFloatingFullSmoke {
                runsFloatingFullSmoke = false
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.spring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.08)) {
                    if usesNativeStudySheet { nativeStudyDetent = .large }
                    else { floatingPanelState = .full }
                }
            }
            let arguments = ProcessInfo.processInfo.arguments
            let scenario = arguments.firstIndex(of: "-smokeScenario").flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
            if scenario == "studyNotes" {
                for _ in 0..<30 {
                    if !viewModel.contentText.isEmpty, editingAnnotation == nil {
                        if let sel = inspectorSession.selection(
                            sefariaLocator: viewModel.selectedSegmentLocator,
                            otzariaLine: viewModel.otzariaSelectedLineAnchor
                        ) {
                            addNote(for: sel)
                            break
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        }
        .onChange(of: viewModel.readerInspectorVisible) { _, _ in
            updatePanelPresentation()
        }
        .onChange(of: libraryColumnVisibility) { _, _ in
            updatePanelPresentation()
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            updatePanelPresentation()
        }
        .onChange(of: shouldPresentPanelInContent) { _, _ in
            updatePanelPresentation()
        }
        .onChange(of: floatingPanelState) { _, newState in
            if !usesNativeStudySheet, shouldPresentPanelInContent, newState == .hidden, showPanel {
                viewModel.closeReaderInspector()
            }
        }
        .sheet(isPresented: $showPanelSheet, onDismiss: compactPanelDidDismiss) {
            compactStudyPanel
        }
        .sheet(item: nativeStudyBinding, onDismiss: {
            if let dismissingStudyPresentationID {
                nativeStudyDidDismiss(id: dismissingStudyPresentationID)
            }
        }) { presentation in
            if #available(iOS 27.0, *) {
                nativeStudyPanel(presentation)
            }
        }
        .sheet(isPresented: annotationEditorBinding, onDismiss: {
            noteEditorDidDismiss(presentationID: dismissingNoteEditorPresentationID)
        }) {
            annotationEditor
        }
        .alert(
            String(localized: "Cannot Add Note"),
            isPresented: Binding(
                get: { noteErrorMessage != nil },
                set: { if !$0 { noteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { noteErrorMessage = nil }
        } message: {
            Text(noteErrorMessage ?? "")
        }
    }

    private var tocColumn: some View {
        iOSTOCView(
            tocViewModel: viewModel.tocViewModel,
            selectedId: selectedTOCNode?.id,
            bookTitle: book.book,
            onClose: closeContents,
            onRetry: { viewModel.loadTOC(book: book) },
            embedsNavigationStack: false,
            onSelect: selectTOCNode
        )
        .toolbar(removing: .sidebarToggle)
    }

    @ViewBuilder
    private var workspaceDetail: some View {
        GeometryReader { geometry in
            if usesNativeStudySheet || sidebarCoordinator != nil {
                // One original HStack/reader position across page and width
                // changes; the original Inspector floats over that surface.
                wideWorkspace(totalWidth: geometry.size.width)
            } else if useWideLayout {
                if shouldPresentPanelInContent {
                    floatingWorkspace
                } else {
                    wideWorkspace(totalWidth: geometry.size.width)
                }
            } else if compactContentsRequested {
                tocColumn
            } else {
                readerSurface
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-workspace")
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailColumnWidth = $0 }
    }

    private var readerSurface: some View {
        iOSReaderView(
            book: book,
            viewModel: viewModel,
            initialContentId: initialContentId,
            columnVisibility: $libraryColumnVisibility,
            onShowTableOfContents: openContents
        )
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                Text(readerHeaderTitle)
                    .frame(width: 1, height: 1)
                    .clipped()
                    .accessibilityIdentifier("reader-header-title")
                    .accessibilityLabel(readerHeaderTitle)
                let canonicalLocator = viewModel.currentLocator?.persistenceKey ?? viewModel.backendSection?.locator.persistenceKey ?? viewModel.currentBook?.backendLocator?.persistenceKey ?? book.book
                Text(canonicalLocator)
                    .frame(width: 1, height: 1)
                    .clipped()
                    .accessibilityIdentifier("reader-current-locator")
                    .accessibilityLabel(canonicalLocator)
                    .accessibilityValue(canonicalLocator)
            }
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-surface")
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(readerHeaderTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .accessibilityIdentifier("reader-header-visible-title")
                    if !readerHeaderSubtitle.isEmpty {
                        Text(readerHeaderSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityIdentifier("reader-header-subtitle")
                    }
                }
            }

            if !MaktabahApp.isIpad {
                ToolbarItem(placement: .topBarTrailing) {
                    OtzariaHanlinChatLaunchButton(identifier: "otzaria-hanlin-reader-launch")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleStudyPanel) {
                    Label {
                        showPanel ? Text("Close Study Tools") : Text("Open Study Tools")
                    } icon: {
                        PanelToggleIcon(isOpen: showPanel)
                    }
                }
                .accessibilityLabel(showPanel ? Text("Close Study Tools") : Text("Open Study Tools"))
                .accessibilityIdentifier("reader-study-toggle")
                .help(showPanel ? Text("Close Study Tools") : Text("Open Study Tools"))
            }
        }
    }

    private var floatingWorkspace: some View {
        readerSurface
            .floatingPanel { _ in
                inspectorPanel(showsCloseButton: true, chrome: .floatingPanel)
            }
            .floatingPanelContentMode(.fitToBounds)
            .floatingPanelState($floatingPanelState)
            .floatingPanelLayout(StudyContentFloatingPanelLayout())
            .floatingPanelSurfaceAppearance(.transparent(cornerRadius: 26))
    }

    private func wideWorkspace(totalWidth: CGFloat) -> some View {
        let allowedMaximum = min(
            Self.maximumPanelWidth,
            max(Self.minimumPanelWidth, totalWidth - 430)
        )
        let actualPanelWidth = min(max(panelWidth, Self.minimumPanelWidth), allowedMaximum)

        return HStack(spacing: 0) {
            readerSurface
                .environment(\.layoutDirection, layoutDirection)
                .geometryGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showPanel && !usesNativeStudySheet && !(sidebarCoordinator != nil && shouldPresentPanelInContent) {
                panelResizeHandle(allowedMaximum: allowedMaximum)
                    .transition(.opacity)
                inspectorPanel(showsCloseButton: true, chrome: .floatingPanel)
                    .environment(\.layoutDirection, layoutDirection)
                    .frame(width: actualPanelWidth)
                    .transition(.opacity)
                    .clipped()
                    .allowsHitTesting(showPanel)
            }
        }
        .animation(.snappy(duration: 0.42, extraBounce: 0), value: showPanel)
        .modifier(SharedSidebarFloatingPanel(
            isEnabled: !usesNativeStudySheet && sidebarCoordinator != nil,
            isFloating: shouldPresentPanelInContent,
            state: $floatingPanelState,
            panel: inspectorPanel(showsCloseButton: true, chrome: .floatingPanel)
        ))
    }

    private func panelResizeHandle(allowedMaximum: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 18)
            .overlay {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 3, height: 54)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStartWidth ?? panelWidth
                        if dragStartWidth == nil { dragStartWidth = start }
                        let directionalTranslation = layoutDirection == .rightToLeft
                            ? value.translation.width
                            : -value.translation.width
                        panelWidth = min(
                            max(start + directionalTranslation, Self.minimumPanelWidth),
                            allowedMaximum
                        )
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
                    panelWidth = min(max(Self.defaultPanelWidth, Self.minimumPanelWidth), allowedMaximum)
                }
            }
            .accessibilityLabel(String(localized: "Resize Study Tools"))
            .accessibilityIdentifier("reader-study-resize-handle")
            .accessibilityHint(String(localized: "Drag to resize. Double-tap to reset."))
    }

    private func inspectorPanel(
        showsCloseButton: Bool,
        chrome: TorahInspectorChrome,
        nativeSheet: NativeStudySheetContent? = nil
    ) -> some View {
        OtzariaReaderSourcesInspectorHost(
            viewModel: viewModel,
            navigationManager: navigationManager,
            inspectorSession: $inspectorSession,
            selectedTool: $selectedTool,
            showsCloseButton: showsCloseButton,
            chrome: chrome,
            contentID: inspectorContentID,
            onAddNote: { selection, completion in
                pendingNotesDidChange = completion
                addNote(for: selection)
            },
            onOpenNote: { note, _, completion in
                pendingNotesDidChange = completion
                openNote(note)
            },
            onDeleteNote: { note, _, completion in
                deleteNote(note, completion: completion)
            },
            nativeSheet: nativeSheet
        )
        .id("\(BackendCoordinator.shared.generation):\(viewModel.currentReaderTextMode.rawValue):\(inspectorContentID)")
    }

    private var compactStudyPanel: some View {
        let notePresentationID = nativeNoteEditorPresentationID
        return inspectorPanel(showsCloseButton: true, chrome: .embeddedSheet)
            .presentationDetents([.medium, .large], selection: $compactPanelDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .sheet(isPresented: annotationEditorBinding(for: .compactStudy), onDismiss: {
                noteEditorDidDismiss(presentationID: notePresentationID)
            }) {
                annotationEditor
            }
    }

    private var nativeStudyBinding: Binding<NativeStudySheetPresentationState.Presentation?> {
        let id = nativeStudyPresentation.presentation?.id
        return Binding(
            get: { usesNativeStudySheet ? nativeStudyPresentation.presentedItem : nil },
            set: { value in
                guard value == nil, let id,
                      nativeStudyPresentation.presentation?.id == id,
                      nativeStudyPresentation.isPresented else { return }
                nativeStudyPresentation.requestDismissal()
                // Commit the same original close intent before layout callbacks
                // can interpret the old model value as a new open request.
                if showPanel { viewModel.closeReaderInspector() }
            }
        )
    }

    @available(iOS 27.0, *)
    private func nativeStudyPanel(_ presentation: NativeStudySheetPresentationState.Presentation) -> some View {
        let notePresentationID = nativeNoteEditorPresentationID
        let noteHost = NativeStudySheetPresentationState.NoteHost.study(presentation.id)
        let originalPanel = inspectorPanel(
            showsCloseButton: true,
            chrome: .embeddedSheet,
            nativeSheet: .init(
                isPeek: nativeStudyDetent == NativeStudySheetPresentation.peek,
                title: readerHeaderTitle,
                subtitle: readerHeaderSubtitle,
                excerpt: nativeStudyExcerpt,
                expand: { nativeStudyDetent = .medium }
            )
        )
        // Keep the real child presenter and observation mounted while the
        // original Inspector content obeys its existing close visibility.
        return ZStack {
            Color.clear.allowsHitTesting(false).accessibilityHidden(true)
            originalPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, layoutDirection)
        #if DEBUG
        .background {
            if NativeStudySheetAcceptance.namespace != nil {
                NativeStudySheetObservation { controller in
                    nativeStudyAcceptance.observe(controller, context: nativeStudyAcceptanceContext)
                }
                .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        #endif
        .modifier(NativeStudySheetPresentation(
            detent: $nativeStudyDetent,
            noteIsPresented: nativeStudyPresentation.note?.host == noteHost
        ))
        .sheet(isPresented: annotationEditorBinding(for: noteHost), onDismiss: {
            noteEditorDidDismiss(presentationID: notePresentationID)
        }) {
            annotationEditor
        }
    }

    private var nativeStudyExcerpt: String {
        let text = viewModel.contentText
        let selected = viewModel.selectedSegmentRange
            ?? viewModel.otzariaSelectedLineAnchor?.range
            ?? viewModel.readerState.selectedRange
        if let selected, let range = Range(selected, in: text) {
            return String(text[range].prefix(220))
        }
        // Section-scoped Inspector: the currently loaded unit is its source.
        // This display projection never changes the original Reader selection.
        return String(text.prefix(220))
    }

    private func nativeStudyDidDismiss(id: UUID) {
        guard nativeStudyPresentation.presentation?.id == id else { return }
        // A completed parent dismissal also proves any child presentation ended.
        // The exact child UUID makes a later child callback harmless.
        if let note = nativeStudyPresentation.note, note.host == .study(id) {
            setEditingAnnotation(nil)
            pendingNotesDidChange = nil
            noteEditorDidDismiss(presentationID: note.id, fromParentDismissal: true)
        }
        guard let result = nativeStudyPresentation.studyDidDismiss(id: id) else { return }
        #if DEBUG
        nativeStudyAcceptance.didDismissStudy(id)
        #endif
        if !result.studyStillRequested, showPanel { viewModel.closeReaderInspector() }
        if result.showContents { presentContents() }
    }

    private func noteEditorDidDismiss(presentationID: UUID, fromParentDismissal: Bool = false) {
        if usesNativeStudySheet {
            guard nativeNoteEditorPresentationID == presentationID,
                  editingAnnotation == nil else { return }
            guard nativeStudyPresentation.noteDidDismiss(id: presentationID) else { return }
        }
        nativeRoutingSession?.noteEditorDidDismiss(id: nativeNoteEditorOwnerID,
            presentationID: presentationID)
        #if DEBUG
        nativeStudyAcceptance.didDismissNote(presentationID, fromParent: fromParentDismissal)
        #endif
    }

    #if DEBUG
    private var nativeStudyAcceptanceContext: NativeStudySheetAcceptance.Context {
        let sourceToken = NativeStudySheetAcceptance.token([
            String(describing: ObjectIdentifier(viewModel)),
            navigationManager.activeTabId?.uuidString ?? "",
            viewModel.currentDestination?.sectionLocator.persistenceKey ?? "",
            viewModel.backendSection?.locator.persistenceKey ?? "",
            String(viewModel.currentContentId), viewModel.currentReaderTextMode.rawValue,
            String(BackendCoordinator.shared.generation)
        ])
        let selectionToken = NativeStudySheetAcceptance.token([
            viewModel.selectedSegmentLocator?.persistenceKey ?? "",
            viewModel.selectedSegmentRange.map(NSStringFromRange) ?? "",
            viewModel.readerState.selectedRange.map(NSStringFromRange) ?? ""
        ])
        return .init(ownerID: nativeNoteEditorOwnerID,
            presentationID: nativeStudyPresentation.presentation?.id,
            noteID: nativeStudyPresentation.note?.id,
            contentID: inspectorContentID,
            sessionIdentity: String(describing: ObjectIdentifier(inspectorSession)),
            readerIdentity: String(describing: ObjectIdentifier(viewModel)), sourceToken: sourceToken,
            selectionToken: selectionToken,
            selectedTool: selectedTool.rawValue,
            detent: nativeStudyDetent == .height(155) ? "peek"
                : (nativeStudyDetent == .large ? "large" : "medium"),
            studyVisible: showPanel)
    }
    #endif

    @ViewBuilder
    private var annotationEditor: some View {
        if let editingAnnotation {
            let presentationID = nativeNoteEditorPresentationID
            iOSAnnotationEditorSheet(
                annotation: editingAnnotation,
                onSave: { updated in
                    #if DEBUG
                    iOSAnnotationEditorSheet.appendDebugLog("[onSave] persist or update start, id=\(String(describing: updated.id))\n")
                    #endif
                    if updated.id == nil {
                        try viewModel.persistNewAnnotation(updated)
                    } else {
                        try viewModel.updateAnnotation(updated)
                    }
                    #if DEBUG
                    iOSAnnotationEditorSheet.appendDebugLog("[onSave] persist or update finished\n")
                    #endif
                    inspectorSession.repository.invalidateAllNotes()
                    NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
                    finishEditingAnnotation()
                },
                onDelete: { id in
                    #if DEBUG
                    iOSAnnotationEditorSheet.appendDebugLog("[onDelete] start id=\(id)\n")
                    #endif
                    try viewModel.deleteAnnotation(id: id)
                    #if DEBUG
                    iOSAnnotationEditorSheet.appendDebugLog("[onDelete] deleteAnnotation succeeded\n")
                    #endif
                    inspectorSession.repository.invalidateAllNotes()
                    NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
                    finishEditingAnnotation()
                },
                onNativeTextView: { textView in
                    nativeRoutingSession?.noteEditorTextViewChanged(
                        id: nativeNoteEditorOwnerID, reader: viewModel,
                        presentationID: presentationID, textView: textView)
                    #if DEBUG
                    if textView == nil || (nativeNoteEditorPresentationID == presentationID && editingAnnotation != nil) {
                        nativeStudyAcceptance.observeNote(textView, presentationID: presentationID)
                    }
                    #endif
                }
            )
        }
    }

    private func attachNativeNoteEditor() {
        nativeRoutingSession?.attachNoteEditor(
            id: nativeNoteEditorOwnerID, reader: viewModel,
            annotation: Binding(get: { editingAnnotation }, set: { setEditingAnnotation($0) }),
            presentationID: { nativeNoteEditorPresentationID })
    }

    private func setEditingAnnotation(_ value: Annotation?) {
        // One identity per original sheet entry, including reopening the same
        // unsaved value. Callback closures capture this value, never a live getter.
        if value != nil {
            let presentationID = UUID()
            if usesNativeStudySheet {
                guard nativeStudyPresentation.beginNote(id: presentationID) else { return }
            } else {
                // The compact inspector is already a system sheet. Its note
                // editor must be owned by that sheet, not a sibling presenter.
                fallbackNoteHost = showPanelSheet ? .compactStudy : .reader
            }
            nativeNoteEditorPresentationID = presentationID
        }
        editingAnnotation = value
    }

    private var annotationEditorBinding: Binding<Bool> {
        annotationEditorBinding(for: .reader)
    }

    private var currentNoteHost: NativeStudySheetPresentationState.NoteHost? {
        usesNativeStudySheet ? nativeStudyPresentation.note?.host : fallbackNoteHost
    }

    private func annotationEditorBinding(for host: NativeStudySheetPresentationState.NoteHost) -> Binding<Bool> {
        let presentationID = nativeNoteEditorPresentationID
        return Binding(
            get: {
                editingAnnotation != nil && currentNoteHost == host
                    && nativeNoteEditorPresentationID == presentationID
            },
            set: { isPresented in
                guard !isPresented, currentNoteHost == host,
                      nativeNoteEditorPresentationID == presentationID else { return }
                setEditingAnnotation(nil)
                pendingNotesDidChange = nil
            }
        )
    }

    private func openContents() {
        if usesNativeStudySheet, nativeStudyPresentation.presentation != nil {
            nativeStudyPresentation.requestDismissal(showContents: true)
            viewModel.closeReaderInspector()
            if nativeStudyPresentation.note != nil {
                setEditingAnnotation(nil)
                pendingNotesDidChange = nil
            }
            return
        }
        if sidebarCoordinator != nil {
            presentContents()
            return
        }
        if !useWideLayout, showPanelSheet {
            pendingCompactContentsOpen = true
            viewModel.closeReaderInspector()
            showPanelSheet = false
            return
        }
        if !useWideLayout, showPanel {
            viewModel.closeReaderInspector()
            DispatchQueue.main.async {
                presentContents()
            }
            return
        }
        presentContents()
    }

    private func presentContents() {
        if let sidebarCoordinator {
            sidebarCoordinator.showContents()
            preferredCompactColumn = .sidebar
            withAnimation(.snappy(duration: 0.34, extraBounce: 0)) { libraryColumnVisibility = .all }
            return
        }
        if !useWideLayout {
            withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
                compactContentsRequested = true
                compactUsesContentsFallback = true
            }
            return
        }
        preferredCompactColumn = .sidebar
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
                libraryColumnVisibility = .doubleColumn
            }
        }
    }

    private func closeContents() {
        if sidebarCoordinator != nil {
            preferredCompactColumn = .detail
            withAnimation(.snappy(duration: 0.30, extraBounce: 0)) { libraryColumnVisibility = .detailOnly }
            return
        }
        if !useWideLayout {
            withAnimation(.snappy(duration: 0.30, extraBounce: 0)) {
                compactContentsRequested = false
                compactUsesContentsFallback = false
            }
            return
        }
        withAnimation(.snappy(duration: 0.30, extraBounce: 0)) {
            preferredCompactColumn = .detail
            libraryColumnVisibility = .detailOnly
        }
    }

    private func selectTOCNode(_ id: Int) {
        viewModel.didSelectTOCNode(id: id)
        if !useWideLayout { closeContents() }
    }

    private func toggleStudyPanel() {
        if showPanel {
            viewModel.closeReaderInspector()
        } else {
            viewModel.readerInspectorVisible = true
        }
    }

    private func updatePanelPresentation(animated: Bool = true) {
        let updates = {
            if usesNativeStudySheet {
                showPanelSheet = false
                floatingPanelState = .hidden
                if showPanel {
                    nativeStudyPresentation.requestStudy()
                } else {
                    nativeStudyPresentation.requestDismissal()
                    if let note = nativeStudyPresentation.note,
                       case .study = note.host {
                        setEditingAnnotation(nil)
                        pendingNotesDidChange = nil
                    }
                }
            } else if !showPanel {
                showPanelSheet = false
                floatingPanelState = .hidden
            } else if shouldPresentPanelInContent {
                showPanelSheet = false
                if floatingPanelState == nil || floatingPanelState == .hidden {
                    floatingPanelState = .half
                }
            } else if sidebarCoordinator != nil || useWideLayout {
                showPanelSheet = false
                floatingPanelState = .hidden
            } else {
                floatingPanelState = .hidden
                showPanelSheet = true
            }
        }

        if animated {
            let animation = showPanel
                ? Animation.spring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.08)
                : Animation.spring(response: 0.34, dampingFraction: 0.96, blendDuration: 0.05)
            withAnimation(animation) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func compactPanelDidDismiss() {
        if fallbackNoteHost == .compactStudy, editingAnnotation != nil {
            let presentationID = nativeNoteEditorPresentationID
            setEditingAnnotation(nil)
            pendingNotesDidChange = nil
            noteEditorDidDismiss(presentationID: presentationID, fromParentDismissal: true)
        }
        if pendingCompactContentsOpen {
            pendingCompactContentsOpen = false
            presentContents()
            return
        }
        if !useWideLayout, showPanel {
            viewModel.closeReaderInspector()
        }
    }

    private func addNote(
        for selection: TorahInspectorSelection
    ) {
        let targetLocator = inspectorSession.locator(for: selection) ?? viewModel.selectedSegmentLocator
        let resolvedRange = viewModel.selectedSegmentRange
            ?? targetLocator.flatMap { viewModel.backendRenderModel?.renderedSegment(for: $0)?.visualRange }
            ?? viewModel.otzariaSelectedLineAnchor?.range
            ?? NSRange(location: 0, length: min((viewModel.contentText as NSString).length, 1))

        guard resolvedRange.location != NSNotFound,
              NSMaxRange(resolvedRange) <= (viewModel.contentText as NSString).length else {
            noteErrorMessage = String(localized: "Select text in the reader before adding a note.")
            return
        }
        do {
            var draft = try viewModel.makeAnnotationDraft(
                in: resolvedRange,
                mode: .highlight,
                sourceText: viewModel.contentText,
                color: UIColor(named: "HighlightText") ?? .systemYellow
            )
            if let locator = targetLocator {
                draft.backendLocator = locator
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-smokeInvalidateNoteOnSave") {
                // Deliberately simulate a stale editor after a content change so
                // UI acceptance can exercise the production save validation.
                viewModel.currentContentId &+= 1
            }
            #endif
            setEditingAnnotation(draft)
        } catch {
            noteErrorMessage = error.localizedDescription
        }
    }

    private func openNote(
        _ note: TorahInspectorNote
    ) {
        guard let id = Int64(note.id) else { return }
        if let annotation = viewModel.currentAnnotations.first(where: { $0.id == id }) {
            setEditingAnnotation(annotation)
        } else if let annotation = AnnotationManager.shared.loadAnnotationById(id) {
            setEditingAnnotation(annotation)
        }
    }

    private func deleteNote(
        _ note: TorahInspectorNote,
        completion: TorahInspectorHostActions.NotesDidChange
    ) {
        guard let id = Int64(note.id) else { return }
        do {
            try viewModel.deleteAnnotation(id: id)
            inspectorSession.repository.invalidateAllNotes()
            NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
            completion()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func finishEditingAnnotation() {
        #if DEBUG
        iOSAnnotationEditorSheet.appendDebugLog("[finishEditingAnnotation] called\n")
        #endif
        setEditingAnnotation(nil)
        inspectorSession.repository.invalidateAllNotes()
        NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
        let completion = pendingNotesDidChange
        pendingNotesDidChange = nil
        completion?()
    }
}

/// Same native FloatingPanel configuration as the authentic floatingWorkspace.
/// Attach it without changing the original reader's HStack position on reflow.
/// This file is fork-owned (absent from upstream 46e893c6).
private struct SharedSidebarFloatingPanel<Panel: View>: ViewModifier {
    let isEnabled: Bool
    let isFloating: Bool
    @Binding var state: FloatingPanelState?
    let panel: Panel

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .floatingPanel { _ in
                    if isFloating { panel }
                }
                .floatingPanelContentMode(.fitToBounds)
                .floatingPanelState($state)
                .floatingPanelLayout(StudyContentFloatingPanelLayout())
                .floatingPanelSurfaceAppearance(.transparent(cornerRadius: 26))
        } else {
            content
        }
    }
}
