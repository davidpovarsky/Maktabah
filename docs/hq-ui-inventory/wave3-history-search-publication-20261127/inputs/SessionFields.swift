    private(set) var mounted = true
    private var searchPresentationOwner: UUID?
    private var searchPresentationBlocked: (@MainActor () -> Bool)?
    // Candidate declaration matches the source; baseline never reads this
    // fixture-only seed slot because its actual caller has no new helper.
    private var searchPresentationPublicationRevision: UInt64? = 0
    private let bindings = Bindings()
    private let sceneID = UIStableID(rawValue: "scene")
    private var workspaceProjectionSource: WorkspaceSource?
    private var windowSource: AnyObject?
    private let originalWindow = OriginalWindow()
    private var onWindowRetain: (() -> Void)?
    private let directory = Directory()
    private var searchContinuationOwner: CallbackOwner? = CallbackOwner()
    private var publicSearchContinuationCatalog: CallbackOwner? = CallbackOwner()
    private var searchEntryBinding: CallbackOwner? = CallbackOwner()
    private var historyRecordBinding: CallbackOwner? = CallbackOwner()
    private var savedResultsBinding: CallbackOwner? = CallbackOwner()
    private var readerTabBinding: CallbackOwner?
    private var readerTabParentObservation: Int?
    private var viewerParentHost: CallbackOwner?
    private var workspaceSelectionBinding: CallbackOwner?
    private var forwardingWorkspaceOwner: CallbackOwner?
    private var workspacePresentation: CallbackOwner?
    private var retainedWorkspaceParent: Int?
    private var phoneTOCPresentation: CallbackOwner?
    private var retainedPhoneTOC = false
    private var retainedHistoryRecord = false
    private var retainedSavedResults = false
    private var sefariaRootSources: [UUID: CallbackOwner] = [:]
    private var completedSefariaRootSource: CallbackOwner?
    private var sefariaSurfaceBinding: CallbackOwner?
    private var retainedSefariaSurface = false
    private var lastCompletedSurface: Int?
    private let presentation = CallbackOwner()
    private var submissionID: Int?; private var command: Int?
    private var visible: [Int] = []; private var visibilityChecks: [Int] = []
    private var nativeSearchField: Int?; private var retainedSearchField: Int?; private var inspectorBinding: Int?
    private var componentOwners: [Int: CallbackOwner] = [:]; private var retainedComponentOwner: Int?
    private var componentValidation: Int?; private var noteEditorOwner: Int?; private var noteDraftBinding: Int?
    private var searchResultsBinding: Int?; private var lease: Int?

    init() { workspaceProjectionSource = WorkspaceSource(bindings.manager) }
    private func retainOriginalWindowObservation() throws -> OriginalWindow { onWindowRetain?(); return originalWindow }
    func fixtureSeedRevision(_ value: UInt64?) { searchPresentationPublicationRevision = value }
    var fixtureRevision: UInt64? { searchPresentationPublicationRevision }
    var fixtureOwner: UUID? { searchPresentationOwner }
    func fixtureOnRetire(_ body: @escaping () -> Void) { searchContinuationOwner?.onCall = { _ in body() } }
    func fixtureOnEntry(_ body: @escaping (String) -> Void) { searchEntryBinding?.onCall = body }
    func fixtureOnCatalog(_ body: @escaping (String) -> Void) { publicSearchContinuationCatalog?.onCall = body }
    func fixtureOnHistory(_ body: @escaping (String) -> Void) { historyRecordBinding?.onCall = body }
    func fixtureOnWindowRetain(_ body: (() -> Void)?) { onWindowRetain = body }
    func fixtureOnWindowValidate(_ body: (() -> Void)?) { originalWindow.onValidate = body }
    func fixtureOnReadiness(_ body: (() -> Void)?) { bindings.onReady = body }

