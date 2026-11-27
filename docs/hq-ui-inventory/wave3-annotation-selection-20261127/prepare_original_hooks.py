from pathlib import Path
import hashlib
import json

root = Path(__file__).parent
edits = []

def edit(path, changes, suffix=''):
    original = (root / 'source' / path).read_text()
    candidate = original
    for before, after in changes:
        assert candidate.count(before) == 1, (path, before[:90], candidate.count(before))
        candidate = candidate.replace(before, after)
        edits.append({'path': path, 'before': before, 'after': after})
    if suffix:
        candidate += suffix
        edits.append({'path': path, 'append': suffix})
    output = root / 'candidate' / path
    output.parent.mkdir(parents=True, exist_ok=True)
    assert not output.exists()
    output.write_text(candidate)
    return {'path': path, 'before_sha256': hashlib.sha256(original.encode()).hexdigest(),
            'after_sha256': hashlib.sha256(candidate.encode()).hexdigest()}

model = 'Source/Features/Annotations/ViewModel/AnnotationViewModel.swift'
changes = [('    var state: ViewModelState = .loading', '''    #if os(iOS)
    @ObservationIgnored let nativeRoutingPublication = MaktabahNativeAnnotationListPublication()
    #endif
    var state: ViewModelState = .loading {
        willSet { nativeRoutingInputWillChange() }
    }

    private func nativeRoutingInputWillChange() {
        #if os(iOS)
        nativeRoutingPublication.willPublish()
        #endif
    }
    private func nativeRoutingBeginSearch() -> UUID? {
        #if os(iOS)
        return nativeRoutingPublication.beginOriginalSearch()
        #else
        return nil
        #endif
    }
    private func nativeRoutingFinishSearch(_ token: UUID?) {
        #if os(iOS)
        if let token { nativeRoutingPublication.finishOriginalSearch(token) }
        #endif
    }''')]
for declaration in [
    '    var searchText: String = "" {',
    '    var searchScope: AnnotationSearchScope = .all {',
    '    var groupingMode: AnnotationGroupingMode = UserDefaults.standard.selectedAnnGroupingMode {',
    '    var sortField: AnnotationSortField = UserDefaults.standard.selectedAnnSortField {',
    '    var sortAscending: Bool = UserDefaults.standard.selectedAnnAscending {',
    '    var selectedTags: Set<String> = [] {',
    '    var tagFilterMode: TagFilterMode = .or {']:
    changes.append((declaration, declaration + '\n        willSet { nativeRoutingInputWillChange() }'))
changes += [
    ('            searchTask?.cancel()\n            searchTask = Task { [weak self] in',
     '            searchTask?.cancel()\n            let nativeSearch = nativeRoutingBeginSearch()\n            searchTask = Task { [weak self] in\n                defer { self?.nativeRoutingFinishSearch(nativeSearch) }'),
    ('    private func handleTreeDiff(_ diff: AnnotationTreeDiff?) {',
     '    private func handleTreeDiff(_ diff: AnnotationTreeDiff?) {\n        nativeRoutingInputWillChange()'),
    ('        guard let callback = onIncrementalUpdate else { return }\n        for diff in bufferedDiffs {',
     '        guard let callback = onIncrementalUpdate else { return }\n        if !bufferedDiffs.isEmpty { nativeRoutingInputWillChange() }\n        for diff in bufferedDiffs {'),
    ('    func loadAnnotations() async {', '    func loadAnnotations() async {\n        nativeRoutingInputWillChange()'),
    ('    func applyFilter() {', '    func applyFilter() {\n        nativeRoutingInputWillChange()')]
rows = [edit(model, changes)]

controller = 'Source/Features/Annotations/iOS/iOSAnnotationViewController.swift'
changes = [
    ('    weak var viewModel: AnnotationViewModel?', '''    weak var viewModel: AnnotationViewModel? {
        willSet {
            if viewModel !== newValue { nativeRoutingPublication.willPublish() }
        }
    }
    let nativeRoutingPublication = MaktabahNativeAnnotationListPublication()
    private weak var nativeRoutingBinding: MaktabahNativeAnnotationSelectionBinding?
    private var nativeRoutingOwner: UUID?
    private var nativeRoutingLastLayout: String?'''),
    ('    // MARK: - Full Rebuild (nodes passed from ViewModel)', '''    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nativeRoutingPublishLayout()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        nativeRoutingPublishLayout()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nativeRoutingPublishLayout()
    }

    // MARK: - Full Rebuild (nodes passed from ViewModel)'''),
    ('    func handleTreeUpdate(nodes: [SwiftUIAnnotationNode], groupingMode: AnnotationGroupingMode) {',
     '    func handleTreeUpdate(nodes: [SwiftUIAnnotationNode], groupingMode: AnnotationGroupingMode) {\n        nativeRoutingPublication.willPublish()'),
    ('    func handleIncrementalUpdate(diff: AnnotationTreeDiff) {',
     '    func handleIncrementalUpdate(diff: AnnotationTreeDiff) {\n        nativeRoutingPublication.willPublish()'),
    ('    func applyNodes(_ nodes: [SwiftUIAnnotationNode], groupingMode: AnnotationGroupingMode, animated: Bool = false) {',
     '    func applyNodes(_ nodes: [SwiftUIAnnotationNode], groupingMode: AnnotationGroupingMode, animated: Bool = false) {\n        nativeRoutingPublication.willPublish()'),
    ('                guard let self else { return }\n                var snap = dataSource.snapshot()',
     '                guard let self else { return }\n                nativeRoutingPublication.willPublish()\n                var snap = dataSource.snapshot()'),
    ('                guard let self else { return }\n                var snap = self.dataSource.snapshot()',
     '                guard let self else { return }\n                self.nativeRoutingPublication.willPublish()\n                var snap = self.dataSource.snapshot()'),
    ('''    private func toggleGroup(_ node: SwiftUIAnnotationNode) {
        let id = node.id
        let wasExpanded = expandedGroups.contains(id)
        let willExpand = !wasExpanded
''', '''    private func toggleGroup(_ node: SwiftUIAnnotationNode) {
        nativeRoutingPublication.willPublish()
        let wasExpanded = expandedGroups.contains(node.id)
        setOriginalGroupExpanded(node, willExpand: !wasExpanded, animated: true)
    }

    /// The existing expansion owner serves both ordinary taps and the single
    /// canonical reveal. Ordinary toggle arguments and effects are unchanged.
    private func setOriginalGroupExpanded(_ node: SwiftUIAnnotationNode, willExpand: Bool, animated: Bool) {
        let id = node.id
'''),
    ('        dataSource.apply(sectionSnapshot, to: id, animatingDifferences: true)',
     '        dataSource.apply(sectionSnapshot, to: id, animatingDifferences: animated)'),
    ('    @objc private func handleRefresh() {\n        onRefreshRequested?()',
     '    @objc private func handleRefresh() {\n        nativeRoutingPublication.willPublish()\n        onRefreshRequested?()'),
    ('    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {\n        guard let item',
     '    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {\n        nativeRoutingPublication.willPublish()\n        guard let item')]
rows.append(edit(controller, changes, (root / 'proposal/ANNOTATION_CONTROLLER_ADDITION.swift').read_text()))

wrapper = 'Source/Features/Annotations/iOS/AnnotationViewControllerWrapper.swift'
changes = [
    ('    var onShowBookInfo: ((BooksData) -> Void)?', '''    var onShowBookInfo: ((BooksData) -> Void)?
    var nativeRoutingBinding: MaktabahNativeAnnotationSelectionBinding? = nil
    var nativeRoutingOwner: UUID? = nil
    var nativeRoutingBlocked: @MainActor () -> Bool = { true }'''),
    ('        uiViewController.updateTagFilterHeader()\n    }', '''        uiViewController.updateTagFilterHeader()
        uiViewController.nativeRoutingAttach(binding: nativeRoutingBinding, owner: nativeRoutingOwner,
                                              blocked: nativeRoutingBlocked)
    }

    static func dismantleUIViewController(_ controller: iOSAnnotationViewController, coordinator: Coordinator) {
        controller.nativeRoutingDetach()
    }''')]
rows.append(edit(wrapper, changes))

view = 'Source/Features/Annotations/iOS/AnnotationListView.swift'
changes = [
    ('    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager', '''    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @Environment(\.maktabahNativeRoutingSession) private var nativeRoutingSession
    @State private var nativeRoutingOwner = UUID()'''),
    ('            onEditAnnotation: { editingAnnotation = $0 },\n            onShowBookInfo: { navigationManager.selectedBookForInfo = $0 }', '''            onEditAnnotation: { nativeModalWillChange(); editingAnnotation = $0 },
            onShowBookInfo: { navigationManager.selectedBookForInfo = $0 },
            nativeRoutingBinding: nativeRoutingSession?.annotationSelectionBinding,
            nativeRoutingOwner: nativeRoutingOwner,
            nativeRoutingBlocked: {
                isExporting || isImporting || showOverwriteDialog || showImportAlert
                    || showMissingBookAlert || editingAnnotation != nil
            }'''),
    ('            Button {\n                isImporting = true',
     '            Button {\n                nativeModalWillChange()\n                isImporting = true'),
    ('                    exportDocument = AnnotationJsonDocument(jsonString: jsonString)',
     '                    nativeModalWillChange()\n                    exportDocument = AnnotationJsonDocument(jsonString: jsonString)'),
    ('                        pendingImportAnnotations = decoded',
     '                        nativeModalWillChange()\n                        pendingImportAnnotations = decoded'),
    ('    private func showImportAlert(title: String, message: String) {',
     '    private func showImportAlert(title: String, message: String) {\n        nativeModalWillChange()'),
    ('        let annotations = pendingImportAnnotations\n        pendingImportAnnotations = []',
     '        let annotations = pendingImportAnnotations\n        nativeModalWillChange()\n        pendingImportAnnotations = []'),
    ('                    importAlertTitle = String(localized: .Annotation.importAnnotations)',
     '                    nativeModalWillChange()\n                    importAlertTitle = String(localized: .Annotation.importAnnotations)'),
    ('                    importAlertTitle = "Import Failed".localized',
     '                    nativeModalWillChange()\n                    importAlertTitle = "Import Failed".localized'),
    ('    private func exportAnnotations() {', '''    private func nativeModalWillChange() {
        nativeRoutingSession?.annotationSelectionBinding?.originalModalWillChange(owner: nativeRoutingOwner)
    }

    /// Preserve the exact original State setter; only publication metadata is
    /// invalidated, including an equal write from a presentation binding.
    private func nativeModalBinding<Value>(_ original: Binding<Value>) -> Binding<Value> {
        Binding(get: { original.wrappedValue }, set: { value in
            nativeModalWillChange(); original.wrappedValue = value
        })
    }

    private func exportAnnotations() {''')]
for prop in ['showMissingBookAlert','isExporting','isImporting','showOverwriteDialog','pendingImportAnnotations','showImportAlert','editingAnnotation']:
    changes.append(('$' + prop, 'nativeModalBinding($' + prop + ')'))
rows.append(edit(view, changes))
(root / 'EXACT_ORIGINAL_HOOKS.json').write_text(json.dumps({'source': '37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be', 'files': rows, 'edits': edits}, indent=2) + '\n')
print(json.dumps({'original_files': len(rows), 'exact_edits': len(edits), 'files': rows}, indent=2))
