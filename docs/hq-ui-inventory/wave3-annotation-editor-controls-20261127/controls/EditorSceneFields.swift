    var mounted = true
    var annotationEditorControls: MaktabahNativeAnnotationEditorControls?
    let originalAnnotationPresentationPublication = NativeComponentSourcePublication()
    private var annotationPresentationOwner: UUID?
    private var annotationPresentationBlocked: (@MainActor () -> Bool)?
    private var annotationPresentationPublicationRevision: UInt64? = 0
    private var annotationSelectionBinding: EditorSceneCallback? = .init()
    private var searchPresentationOwner: UUID?
    private var searchPresentationPublicationRevision: UInt64? = 0
    private var searchPresentationBlocked: (@MainActor () -> Bool)?
    private var searchEntryBinding: EditorSceneCallback? = .init()
    private var publicSearchContinuationCatalog: EditorSceneCallback? = .init()
    private var historyRecordBinding: EditorSceneCallback? = .init()
    private var searchContinuationOwner: EditorSceneCallback?
    private var readerBinding: Int?; private var readerTabBinding: Int?
    private var workspaceSelectionBinding: Int?; private var searchResultsBinding: Int?
    private var workspacePresentation: EditorForeignPresentation? = .init()
    private var sefariaSurfaceBinding: EditorForeignPresentation? = .init()
    private var savedResultsBinding: EditorForeignPresentation? = .init()
    private var hasOriginalWorkspacePresentation = false
    private var hasOriginalSefariaSurface = false
    private var studyChatPresentationID: UUID?
    private var noteEditorOwner: EditorSceneNote?
    let bindings = EditorSceneBindings()
    private let sceneID = UIStableID(rawValue: "editor-scene")!
    private var workspaceProjectionSource: EditorSceneWorkspaceSource?
    let originalWindow = EditorSceneWindow()
    var onWindowRetain: (() -> Void)?
    init() { workspaceProjectionSource = EditorSceneWorkspaceSource(bindings.manager) }
    private func retainOriginalWindowObservation() throws -> EditorSceneWindow { onWindowRetain?(); return originalWindow }
    func fixtureCaptureEditor(_ owner: UUID) throws -> @MainActor () throws -> Void { try captureAnnotationEditorWindow(owner: owner) }
    func fixtureRevision(_ revision: UInt64?) { annotationPresentationPublicationRevision=revision }
    var fixtureCurrentRevision: UInt64? { annotationPresentationPublicationRevision }
    func fixtureEntryCallback(_ body: @escaping () -> Void) { annotationSelectionBinding?.onCall=body }
    func fixtureWorkspaceABA() { workspacePresentation?.originalStateRevision = 1; workspacePresentation?.originalStateRevision = 2 }
