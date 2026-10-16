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
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var compactContentsRequested = false
    @State private var compactUsesContentsFallback = false
    @State private var panelWidth = Self.defaultPanelWidth
    @State private var dragStartWidth: CGFloat?
    @State private var showPanelSheet = false
    @State private var compactPanelDetent: PresentationDetent = .medium
    @State private var runsCompactTOCTransitionSmoke = false
    @State private var runsFloatingFullSmoke = false
    @State private var pendingCompactContentsOpen = false
    @State private var floatingPanelState: FloatingPanelState? = .hidden
    @State private var selectedTool: TorahStudyTool = .commentaries
    @State private var inspectorSession: MaktabahTorahInspectorSession
    @State private var inspectorContentID = UUID()
    @State private var editingAnnotation: Annotation?
    @State private var noteErrorMessage: String?

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
        libraryColumnVisibility != .detailOnly
    }

    private var shouldPresentPanelInContent: Bool {
        useWideLayout && librarySidebarIsOpen && contentsIsOpen
    }

    private var showPanel: Bool {
        viewModel.readerInspectorVisible
    }

    private var readerHeaderTitle: String {
        if let index = viewModel.currentNavigationIndex,
           viewModel.navigationItems.indices.contains(index) {
            return viewModel.navigationItems[index].title
        }
        if let node = selectedTOCNode, !node.bab.isEmpty {
            return node.bab
        }
        return book.book
    }

    private var selectedTOCNode: TOCNode? {
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }

    var body: some View {
        Group {
            if !useWideLayout, compactUsesContentsFallback {
                tocColumn
            } else {
                workspaceDetail
            }
        }
        .onAppear { updatePanelPresentation(animated: false) }
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
                    floatingPanelState = .full
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
        .onChange(of: floatingPanelState) { _, newState in
            if shouldPresentPanelInContent, newState == .hidden, showPanel {
                viewModel.closeReaderInspector()
            }
        }
        .sheet(isPresented: $showPanelSheet, onDismiss: compactPanelDidDismiss) {
            compactStudyPanel
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
            embedsNavigationStack: false,
            onSelect: selectTOCNode
        )
        .toolbar(removing: .sidebarToggle)
    }

    @ViewBuilder
    private var workspaceDetail: some View {
        GeometryReader { geometry in
            if useWideLayout {
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
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("reader-header-title")
                .accessibilityLabel(book.book)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-surface")
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(readerHeaderTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .accessibilityIdentifier("reader-header-title")
                    Text(viewModel.statusSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("reader-header-subtitle")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleStudyPanel) {
                    PanelToggleIcon(isOpen: showPanel)
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

            if showPanel {
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
        chrome: TorahInspectorChrome
    ) -> some View {
        OtzariaReaderSourcesInspectorHost(
            viewModel: viewModel,
            navigationManager: navigationManager,
            inspectorSession: $inspectorSession,
            selectedTool: $selectedTool,
            showsCloseButton: showsCloseButton,
            chrome: chrome,
            onAddNote: { selection, _ in
                addNote(for: selection)
            },
            onOpenNote: { note, _, _ in
                openNote(note)
            },
            onDeleteNote: { note, _, completion in
                deleteNote(note, completion: completion)
            }
        )
        .id("\(BackendCoordinator.shared.generation):\(viewModel.currentReaderTextMode.rawValue):\(inspectorContentID)")
        .sheet(isPresented: annotationEditorBinding) {
            annotationEditor
        }
    }

    private var compactStudyPanel: some View {
        inspectorPanel(showsCloseButton: true, chrome: .embeddedSheet)
        .presentationDetents([.medium, .large], selection: $compactPanelDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    @ViewBuilder
    private var annotationEditor: some View {
        if let editingAnnotation {
            iOSAnnotationEditorSheet(
                annotation: editingAnnotation,
                onSave: { updated in
                    if updated.id == nil {
                        try viewModel.persistNewAnnotation(updated)
                    } else {
                        try viewModel.updateAnnotation(updated)
                    }
                    finishEditingAnnotation()
                },
                onDelete: { id in
                    try viewModel.deleteAnnotation(id: id)
                    finishEditingAnnotation()
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var annotationEditorBinding: Binding<Bool> {
        Binding(
            get: { editingAnnotation != nil },
            set: { isPresented in
                if !isPresented {
                    editingAnnotation = nil
                }
            }
        )
    }

    private func openContents() {
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
            if !showPanel {
                showPanelSheet = false
                floatingPanelState = .hidden
            } else if shouldPresentPanelInContent {
                showPanelSheet = false
                if floatingPanelState == nil || floatingPanelState == .hidden {
                    floatingPanelState = .half
                }
            } else if useWideLayout {
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
        guard let selectedRange = viewModel.selectedSegmentRange,
              selectedRange.location != NSNotFound,
              NSMaxRange(selectedRange) <= (viewModel.contentText as NSString).length else {
            noteErrorMessage = String(localized: "Select text in the reader before adding a note.")
            return
        }
        do {
            editingAnnotation = try viewModel.makeAnnotationDraft(
                in: selectedRange,
                mode: .highlight,
                sourceText: viewModel.contentText,
                color: UIColor(named: "HighlightText") ?? .systemYellow
            )
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-smokeInvalidateNoteOnSave") {
                // Deliberately simulate a stale editor after a content change so
                // UI acceptance can exercise the production save validation.
                viewModel.currentContentId &+= 1
            }
            #endif
        } catch {
            noteErrorMessage = error.localizedDescription
        }
        _ = selection
    }

    private func openNote(
        _ note: TorahInspectorNote
    ) {
        guard let id = Int64(note.id),
              let annotation = viewModel.currentAnnotations.first(where: { $0.id == id }) else { return }
        editingAnnotation = annotation
    }

    private func deleteNote(
        _ note: TorahInspectorNote,
        completion: TorahInspectorHostActions.NotesDidChange
    ) {
        guard let id = Int64(note.id) else { return }
        do {
            try viewModel.deleteAnnotation(id: id)
            completion()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func finishEditingAnnotation() {
        editingAnnotation = nil
        if let selection = inspectorSession.selection(
            sefariaLocator: viewModel.selectedSegmentLocator,
            otzariaLine: viewModel.otzariaSelectedLineAnchor
        ) {
            inspectorSession.repository.invalidateNotes(for: selection)
        }
        inspectorContentID = UUID()
    }
}
