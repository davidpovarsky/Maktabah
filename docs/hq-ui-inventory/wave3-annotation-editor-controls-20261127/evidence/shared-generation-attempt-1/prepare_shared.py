from pathlib import Path
import hashlib,json,difflib
P=Path(__file__).parent
I='Source/ChavrusaText/UIRoutingHost/Integration/'
paths=[I+'MaktabahNativeSceneSession.swift',I+'MaktabahNativeSceneProjection.swift',I+'MaktabahNativePublicBindingAdapter.swift',I+'MaktabahNativeRoutingComposition.swift']
texts={p:(P/'baseline'/p).read_text() for p in paths};original=dict(texts);edits=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def edit(p,old,new,count=1):
    assert texts[p].count(old)==count,(p,old[:100],texts[p].count(old),count)
    texts[p]=texts[p].replace(old,new)
    edits.append({'path':p,'old':old,'new':new,'count':count})
s=paths[0]
edit(s,'    private(set) var annotationSelectionBinding: MaktabahNativeAnnotationSelectionBinding?\n',
'''    private(set) var annotationEditorControls: MaktabahNativeAnnotationEditorControls?
    @ObservationIgnored private var retainedAnnotationEditor = false
    private(set) var annotationSelectionBinding: MaktabahNativeAnnotationSelectionBinding?
''')
edit(s,'    func retainParentSource(destination: UIDestinationID, requestID: UUID) throws {\n',
'''    func retainParentSource(destination: UIDestinationID, requestID: UUID) throws {
        if destination == MaktabahNativeAnnotationEditorControls.destination {
            guard mounted, isOriginalAnnotationEditorRootReady, let original = annotationEditorControls else {
                throw UIRouteError(.unavailable, "original_annotation_editor_owner_missing")
            }
            try original.retainSource(requestID: requestID)
            return
        }
''')
edit(s,'    func validateParentSource(destination: UIDestinationID, requestID: UUID) throws {\n',
'''    func validateParentSource(destination: UIDestinationID, requestID: UUID) throws {
        if destination == MaktabahNativeAnnotationEditorControls.destination {
            guard let original = annotationEditorControls else {
                throw UIRouteError(.staleState, "original_annotation_editor_owner_detached")
            }
            try original.validateSource(requestID: requestID)
            return
        }
''')
edit(s,'    func releaseParentSource(destination: UIDestinationID, requestID: UUID) {\n',
'''    func releaseParentSource(destination: UIDestinationID, requestID: UUID) {
        if destination == MaktabahNativeAnnotationEditorControls.destination {
            annotationEditorControls?.releaseSource(requestID: requestID)
            return
        }
''')
edit(s,'        annotationSelectionBinding?.retire()\n        sefariaRootSources.values.forEach',
       '        annotationSelectionBinding?.retire()\n        annotationEditorControls?.retire()\n        sefariaRootSources.values.forEach')
edit(s,'        originalAnnotationPresentationPublication.invalidateRetainedSources()\n',
       '        originalAnnotationPresentationPublication.invalidateRetainedSources()\n        annotationEditorControls?.retire()\n')
marker='    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {\n'
editor_facet='''    /// This finite internal facet describes the ALREADY OPEN original List
    /// editor. The public URL carries no owner/record/draft identity.
    private func retainOriginalAnnotationEditorPresentationObservation(owner: UUID) throws
        -> @MainActor () throws -> Void {
        guard mounted, let revision = annotationPresentationPublicationRevision,
              annotationPresentationOwner == owner, let original = annotationEditorControls,
              original.originalListOwner == owner else {
            throw UIRouteError(.unavailable, "original_annotation_editor_parent_unavailable")
        }
        let validate: @MainActor () throws -> Void = { [weak self, weak original] in
            guard let self, let original, self.mounted,
                  self.annotationEditorControls === original,
                  self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner,
                  original.originalListOwner == owner,
                  self.annotationPresentationBlocked?() == true,
                  original.isAvailable() else {
                throw UIRouteError(.staleState, "original_annotation_editor_parent_changed")
            }
            // Both getters above may synchronously publish/detach an owner.
            guard self.mounted, self.annotationEditorControls === original,
                  self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner,
                  original.originalListOwner == owner else {
                throw UIRouteError(.staleState, "original_annotation_editor_parent_changed")
            }
        }
        try validate()
        return validate
    }

'''
edit(s,marker,editor_facet+marker)
edit(s,'        defer { annotationSelectionBinding?.retire() }\n',
       '        defer { annotationSelectionBinding?.retire(); annotationEditorControls?.retire() }\n')
ready='''    private var isOriginalAnnotationEditorRootReady: Bool {
        mounted && readerBinding == nil && readerTabBinding == nil && workspaceSelectionBinding == nil
            && searchResultsBinding == nil && searchContinuationOwner == nil
            && bindings.selectedTab.wrappedValue.canonical == .annotations
            && bindings.manager.currentMode == .annotations
            && bindings.isPresentationReady && !bindings.showSettings.wrappedValue
            && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface
            && savedResultsBinding?.isRequestedOrMounted != true
            && studyChatPresentationID == nil && searchPresentationBlocked?() != true
            && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
    }

'''
edit(s,'    func isPresentationReady(for destination: UIDestinationID) -> Bool {\n',
ready+'''    func isPresentationReady(for destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeAnnotationEditorControls.destination {
            // The stable own editor supplies its original top-sheet witness.
            // Every other route retains the existing no-Annotations-modal gate.
            return foreground && isOriginalAnnotationEditorRootReady
                && annotationEditorControls?.isAvailable() == true
        }
''')
edit(s,'        annotationSelectionBinding?.retire()\n        savedResultsBinding?.originalForeignStateWillChange()',
       '        annotationSelectionBinding?.retire()\n        annotationEditorControls?.retire()\n        savedResultsBinding?.originalForeignStateWillChange()')
edit(s,'    func isRootAvailable(_ destination: UIDestinationID) -> Bool {\n',
'''    func isRootAvailable(_ destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeAnnotationEditorControls.destination {
            return isOriginalAnnotationEditorRootReady && annotationEditorControls?.isAvailable() == true
        }
''')
factory='''            let editor = MaktabahNativeAnnotationEditorControls(sceneID: sceneID,
                retainWindow: { [weak self] in
                    guard let self else { throw UIRouteError(.staleState, "original_annotation_editor_window_detached") }
                    return try retainOriginalWindowObservation()
                }, retainParent: { [weak self] owner in
                    guard let self else { throw UIRouteError(.staleState, "original_annotation_editor_parent_detached") }
                    return try captureAnnotationEditorWindow(owner: owner)
                })
            annotationEditorControls = editor
            editor.install(changed: { [weak self, weak editor] in
                guard let self, let editor, annotationEditorControls === editor else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in
                guard let self, retainedAnnotationEditor else { return }
                presentation.revoke()
            })
            attachComponentOwner(editor.componentOwner)
'''
edit(s,'            let saved = MaktabahNativeSavedResultsBinding(sceneID: sceneID, bindings: bindings,\n',factory+'            let saved = MaktabahNativeSavedResultsBinding(sceneID: sceneID, bindings: bindings,\n')
edit(s,'               (kind != .noteDraft || (try? noteDraftBinding?.validateVisible()) != nil) {\n',
'''               (kind != .noteDraft || (try? noteDraftBinding?.validateVisible()) != nil),
               (kind != .annotationEditor || (try? annotationEditorControls?.validateVisible(requestID: command.invocation.requestId)) != nil) {
''')
edit(s,'        let annotationSelection = value.route.route.destination == MaktabahNativeAnnotationSelectionBinding.destination\n',
'''        let annotationSelection = value.route.route.destination == MaktabahNativeAnnotationSelectionBinding.destination
        let annotationEditor = value.route.route.destination == MaktabahNativeAnnotationEditorControls.destination
''')
edit(s,'if workspaceParent != nil || phoneTOC || sefaria || historyRecord || savedResults || annotationSelection {',
       'if workspaceParent != nil || phoneTOC || sefaria || historyRecord || savedResults || annotationSelection || annotationEditor {')
edit(s,'            if annotationSelection {\n',
'''            if annotationEditor {
                guard let annotationEditorControls, let parentValidation else {
                    throw UIRouteError(.staleState, "original_annotation_editor_parent_not_retained")
                }
                try annotationEditorControls.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
            if annotationSelection {
''')
edit(s,'            annotationSelectionBinding?.finish(requestID: value.invocation.requestId, completed: false)\n',
       '            annotationSelectionBinding?.finish(requestID: value.invocation.requestId, completed: false)\n            annotationEditorControls?.finish(requestID: value.invocation.requestId, completed: false)\n')
edit(s,'        retainedAnnotationSelection = annotationSelection\n',
       '        retainedAnnotationSelection = annotationSelection\n        retainedAnnotationEditor = annotationEditor\n')
edit(s,'    func captureHistoryReaderWindow() throws -> @MainActor () throws -> Void {\n        let searchPresentation = try retainHistorySearchPresentationObservation()\n        let annotationPresentation = try retainOriginalAnnotationPresentationObservation()\n',
'''    func captureHistoryReaderWindow(annotationEditorOwner: UUID? = nil) throws -> @MainActor () throws -> Void {
        let searchPresentation = try retainHistorySearchPresentationObservation()
        let annotationPresentation: @MainActor () throws -> Void
        if let annotationEditorOwner {
            annotationPresentation = try retainOriginalAnnotationEditorPresentationObservation(owner: annotationEditorOwner)
        } else { annotationPresentation = try retainOriginalAnnotationPresentationObservation() }
''')
capture='''    /// Reuse the unchanged original root/window/workspace fence. Only the
    /// exact warm editor substitutes its own captured modal facet; no caller
    /// supplies a new scene, editor, record, backend or lifetime.
    private func captureAnnotationEditorWindow(owner: UUID) throws -> @MainActor () throws -> Void {
        guard isOriginalAnnotationEditorRootReady, let original = annotationEditorControls,
              original.originalListOwner == owner else {
            throw UIRouteError(.unavailable, "original_annotation_editor_root_unavailable")
        }
        let observation = MaktabahNativeComponentSourceObservation {
            _ = mounted; _ = studyChatPresentationID
            _ = workspacePresentation?.originalStateRevision
            _ = sefariaSurfaceBinding?.presentationFacets
            _ = savedResultsBinding?.isRequestedOrMounted
        }
        let originalRoot = try captureHistoryReaderWindow(annotationEditorOwner: owner)
        let validate: @MainActor () throws -> Void = { [weak self, weak original] in
            try observation.validate(); try originalRoot()
            guard let self, let original, self.annotationEditorControls === original,
                  original.originalListOwner == owner, self.isOriginalAnnotationEditorRootReady else {
                throw UIRouteError(.staleState, "original_annotation_editor_root_changed")
            }
            try originalRoot(); try observation.validate()
        }
        try validate()
        return validate
    }

'''
edit(s,'    func retainAnnotation(_ record: NativeAnnotationSelectionIntentService.Record, requestID: UUID) throws\n',capture+'    func retainAnnotation(_ record: NativeAnnotationSelectionIntentService.Record, requestID: UUID) throws\n')
edit(s,'        case "native.workspace.profiles", "native.workspace.overview":\n',
'''        case "native.annotations.editor":
            guard route.presentation.kind == .sheet, isRootAvailable(route.destination) else {
                throw UIRouteError(.unavailable, "original_annotation_editor_unavailable")
            }
        case "native.workspace.profiles", "native.workspace.overview":
''')
edit(s,'    func apply(_ command: UISceneCommand) throws {\n',
'''    func apply(_ command: UISceneCommand) throws {
        if command.route.route.destination == MaktabahNativeAnnotationEditorControls.destination {
            try validateSurface(command)
            guard retainedAnnotationEditor, let original = annotationEditorControls else {
                throw UIRouteError(.staleState, "original_annotation_editor_owner_missing")
            }
            try original.apply(requestID: command.invocation.requestId)
            if let owner = retainedComponentOwner { try owner.apply(requestID: command.invocation.requestId) }
            try original.validateSource(requestID: command.invocation.requestId)
            return
        }
''')
edit(s,'if retainedComponentOwner != nil || retainedHistoryRecord || retainedSavedResults || retainedAnnotationSelection || [',
       'if retainedComponentOwner != nil || retainedHistoryRecord || retainedSavedResults || retainedAnnotationSelection || retainedAnnotationEditor || [')
edit(s,'                                               annotationSelection: annotationSource,\n',
'''                                               annotationSelection: annotationSource,
                                               annotationEditor: annotationEditorControls,
                                               annotationEditorRequestID: kind == .annotationEditor
                                                   ? submissionID ?? lastCompletedSurface?.route.requestId : nil,
''')
edit(s,'            readySavedResults: mounted && foreground && isPresentationReady(for: MaktabahNativeSavedResultsBinding.destination),\n',
'''            readySavedResults: mounted && foreground && isPresentationReady(for: MaktabahNativeSavedResultsBinding.destination),
            readyAnnotationEditor: mounted && foreground && isPresentationReady(for: MaktabahNativeAnnotationEditorControls.destination),
''')
edit(s,'    func observe(_ evidence: NativeSurfaceWitness.Evidence) {\n        guard mounted, evidence.sceneID == sceneID else { return }\n',
'''    func observe(_ evidence: NativeSurfaceWitness.Evidence) {
        guard mounted, evidence.sceneID == sceneID else { return }
        if evidence.isVisible, evidence.surface.destination == MaktabahNativeAnnotationEditorControls.destination {
            do {
                guard retainedAnnotationEditor, let original = annotationEditorControls,
                      let requestID = evidence.submissionID, submissionID == requestID,
                      command?.invocation.requestId == requestID else {
                    throw UIRouteError(.staleState, "original_annotation_editor_report_not_owned")
                }
                try original.withValidatedSurface(requestID: requestID) {
                    guard isPresentationReady(for: evidence.surface.destination),
                          let actual = try surface(.annotationEditor), actual == evidence.surface else {
                        throw UIRouteError(.staleState, "original_annotation_editor_report_changed")
                    }
                    recordNativeObservation(evidence)
                }
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
''')
edit(s,'        annotationSelectionBinding?.finish(requestID: requestID, completed: completed && retainedAnnotationSelection)\n',
       '        annotationSelectionBinding?.finish(requestID: requestID, completed: completed && retainedAnnotationSelection)\n        annotationEditorControls?.finish(requestID: requestID, completed: completed && retainedAnnotationEditor)\n')
edit(s,'        retainedAnnotationSelection = false\n',
       '        retainedAnnotationSelection = false\n        retainedAnnotationEditor = false\n')
edit(s,'        annotationSelectionBinding?.unmount(); annotationSelectionBinding = nil; retainedAnnotationSelection = false\n',
       '        annotationSelectionBinding?.unmount(); annotationSelectionBinding = nil; retainedAnnotationSelection = false\n        annotationEditorControls?.unmount(); annotationEditorControls = nil; retainedAnnotationEditor = false\n')
edit(s,'        case "native.annotations", "native.annotations.record": .annotations\n',
       '        case "native.annotations", "native.annotations.record": .annotations\n        case "native.annotations.editor": .annotationEditor\n')
old='identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)'
edit(s,old,'identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding, annotationEditor: annotationEditorControls)',texts[s].count(old))
edit(s,'            sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)\n',
       '            sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding, annotationEditor: annotationEditorControls)\n')

p=paths[1]
edit(p,'annotations, settings, inspector,','annotations, annotationEditor, settings, inspector,')
edit(p,'                  savedResults: MaktabahNativeSavedResultsBinding? = nil) throws -> NativeSceneIdentity {',
'''                  savedResults: MaktabahNativeSavedResultsBinding? = nil,
                  annotationEditor: MaktabahNativeAnnotationEditorControls? = nil) throws -> NativeSceneIdentity {''')
edit(p,'        } else { originalSheet = nil }\n',
'''        } else if annotationEditor?.isMounted == true {
            originalSheet = MaktabahNativeAnnotationEditorControls.destination
        } else { originalSheet = nil }
''')
edit(p,'                 annotationRequestID: UUID? = nil,\n',
'''                 annotationRequestID: UUID? = nil,
                 annotationEditor: MaktabahNativeAnnotationEditorControls? = nil,
                 annotationEditorRequestID: UUID? = nil,
''')
edit(p,'        switch surface {\n',
'''        switch surface {
        case .annotationEditor:
            guard !settingsPresented, selectedTab.canonical == .annotations, manager.currentMode == .annotations,
                  let original = annotationEditor, let requestID = annotationEditorRequestID,
                  original.isAvailable(), (try? original.validateVisible(requestID: requestID)) != nil else { return nil }
            // Exact original editor/control proof is necessary, but the
            // separate original sheet UIKit witness still supplies the receipt.
            return .init(destination: MaktabahNativeAnnotationEditorControls.destination,
                presentation: .init(kind: .sheet), content: nil, state: state, focus: nil)
''')

p=paths[2]
edit(p,'    var readySavedResults: Bool = false\n','    var readySavedResults: Bool = false\n    var readyAnnotationEditor: Bool = false\n')
edit(p,'        case "native.savedResults": return readySavedResults\n',
       '        case "native.savedResults": return readySavedResults\n        case "native.annotations.editor": return readyAnnotationEditor\n')
edit(p,'                   destination != MaktabahNativeSavedResultsBinding.destination,\n',
       '                   destination != MaktabahNativeSavedResultsBinding.destination,\n                   destination != MaktabahNativeAnnotationEditorControls.destination,\n')
edit(p,'annotations, settings, reader,','annotations, annotationEditor, settings, reader,')
edit(p,'            guard !hasContent, search || settings || library || tableOfContents || profiles || overview else {\n',
'''            let editor = destination == MaktabahNativeAnnotationEditorControls.destination && presentation == .sheet
                && MaktabahNativeAnnotationEditorControls.Anchor.allCases.contains { $0.id == component }
            guard !hasContent, search || settings || library || tableOfContents || profiles || overview || editor else {
''')
edit(p,'        case ("native.annotations", .currentTab, false): return .annotations\n',
       '        case ("native.annotations", .currentTab, false): return .annotations\n        case ("native.annotations.editor", .sheet, false): return .annotationEditor\n')
edit(p,'case .library, .settings, .search, .annotations, .workspaceProfiles,',
       'case .library, .settings, .search, .annotations, .annotationEditor, .workspaceProfiles,')

p=paths[3]
edit(p,'            .init(id: id("native.settings"), title: "Settings".localized, implementation: .implemented,\n',
'''            .init(id: MaktabahNativeAnnotationEditorControls.destination, title: String(localized: "Annotation editor"),
                  implementation: .implemented, supportedBackends: ActionBackendID.allCases,
                  presentations: [.sheet], anchors: MaktabahNativeAnnotationEditorControls.Anchor.allCases.map(\\.id),
                  requiredCoreActions: [], publicNavigationV2: .init(rules: [.init(presentation: .sheet,
                      components: MaktabahNativeAnnotationEditorControls.Anchor.allCases.map(\\.id))])),
            .init(id: id("native.settings"), title: "Settings".localized, implementation: .implemented,
''')
edit(p,'            || destination.destination == MaktabahNativeSavedResultsBinding.destination\n',
       '            || destination.destination == MaktabahNativeSavedResultsBinding.destination\n            || destination.destination == MaktabahNativeAnnotationEditorControls.destination\n')
edit(p,'                    || destination.destination == MaktabahNativeSavedResultsBinding.destination) ? .sheet : .currentTab,\n',
       '                    || destination.destination == MaktabahNativeSavedResultsBinding.destination\n                    || destination.destination == MaktabahNativeAnnotationEditorControls.destination) ? .sheet : .currentTab,\n')

rows=[];diff=[]
for p in paths:
    restored=texts[p]
    for e in reversed([e for e in edits if e['path']==p]):
        assert restored.count(e['new'])==e['count'],('inverse',p,e['new'][:100],restored.count(e['new']))
        restored=restored.replace(e['new'],e['old'])
    assert restored==original[p],('inverse',p)
    target=P/'proposal/candidate'/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(texts[p])
    rows.append({'path':p,'before_bytes':len(original[p].encode()),'before_sha256':sha(original[p].encode()),'after_bytes':len(texts[p].encode()),'after_sha256':sha(texts[p].encode()),'edits':sum(1 for e in edits if e['path']==p),'inverse':'BYTE_EXACT'})
    diff.extend(difflib.unified_diff(original[p].splitlines(True),texts[p].splitlines(True),fromfile='a/'+p,tofile='b/'+p))
(P/'proposal/SHARED_EDITS.json').write_text(json.dumps({'base':'b463ffd03a76026cea06c79c608df97d00094152','source_only':True,'files':rows,'edits':edits},indent=2)+'\n')
(P/'proposal/SHARED.patch').write_text(''.join(diff))
print(json.dumps({'files':rows,'edits':len(edits)}))
