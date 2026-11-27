from pathlib import Path
import hashlib, json, difflib

BASE = Path('wave3-all-original-entry-wiring/candidate')
OUT = Path('annotations-selection-analysis/proposal/shared')
PREFIX = 'Source/ChavrusaText/UIRoutingHost/Integration/'
session = PREFIX + 'MaktabahNativeSceneSession.swift'
composition = PREFIX + 'MaktabahNativeRoutingComposition.swift'
projection = PREFIX + 'MaktabahNativeSceneProjection.swift'
pins = {session: 'a77dd4223cf3a9c8336d405e45690b02016a022031b9002a5b97bb795650a4d9', composition: '9ebdf1237a1cd9cb0d64e7fd31542c2c3aee3907c7ce24488c966a14a4f4a720'}
original = {p: (BASE / p).read_text() for p in [session, composition, projection]}
for path, pin in pins.items(): assert hashlib.sha256(original[path].encode()).hexdigest() == pin
texts = dict(original)
edits = []
def edit(path, before, after, count=1):
    assert texts[path].count(before) == count, (path, before[:100], texts[path].count(before), count)
    texts[path] = texts[path].replace(before, after)
    edits.append({'path': path, 'before': before, 'after': after, 'occurrences': count})
def method(text, prefix):
    start = text.index(prefix); point = text.index('{', start); depth = 1; end = point + 1
    while depth:
        if text[end] == '{': depth += 1
        elif text[end] == '}': depth -= 1
        end += 1
    return text[start:end]

edit(session, '    private(set) var savedResultsBinding: MaktabahNativeSavedResultsBinding?', '    private(set) var annotationSelectionBinding: MaktabahNativeAnnotationSelectionBinding?\n    @ObservationIgnored private var retainedAnnotationSelection = false\n    private(set) var savedResultsBinding: MaktabahNativeSavedResultsBinding?')
edit(session, '        savedResultsBinding?.retire()\n', '        savedResultsBinding?.retire()\n        annotationSelectionBinding?.retire()\n', 2)
edit(session, '    private func advanceOriginalSearchPresentationPublication() {\n', '    private func advanceOriginalSearchPresentationPublication() {\n        // This original foreign State publication cannot rearm an annotation source.\n        defer { annotationSelectionBinding?.retire() }\n')
needle = '    func validateParentSource(destination: UIDestinationID, requestID: UUID) throws {\n'
edit(session, needle, needle + '''        if destination == MaktabahNativeAnnotationSelectionBinding.destination {
            guard let original = annotationSelectionBinding else {
                throw UIRouteError(.staleState, "native_annotation_owner_detached")
            }
            try original.validateSource(requestID: requestID)
            return
        }
''')
needle = '    func isPresentationReady(for destination: UIDestinationID) -> Bool {\n'
edit(session, needle, needle + '''        if destination == MaktabahNativeAnnotationSelectionBinding.destination {
            return mounted && foreground && annotationSelectionBinding?.isAvailable == true
                && windowSource?.isPresentationReady(in: sceneID) == true
        }
''')
needle = '            let saved = MaktabahNativeSavedResultsBinding(sceneID: sceneID, bindings: bindings,'
installation = '''            let annotations = MaktabahNativeAnnotationSelectionBinding(sceneID: sceneID, bindings: bindings,
                workspaceSource: workspaceSource, workspacePresentation: original,
                commonReady: { [weak self] in
                    guard let self else { return false }
                    return mounted && isPresentationReady && !bindings.showSettings.wrappedValue
                        && readerBinding == nil && searchResultsBinding == nil && searchContinuationOwner == nil
                        && searchPresentationBlocked?() != true
                }, windowReady: { [weak self] in
                    guard let self else { return false }
                    return foreground && windowSource?.isPresentationReady(in: sceneID) == true
                }, retainWindow: { [weak self] in
                    guard let self else { throw UIRouteError(.staleState, "native_annotation_window_detached") }
                    return try retainOriginalWindowObservation()
                }, readForeignPresentations: { [weak self] in
                    guard let self else { return }
                    _ = mounted; _ = studyChatPresentationID; _ = workspacePresentation?.originalStateRevision
                })
            annotationSelectionBinding = annotations
            annotations.install(changed: { [weak self, weak annotations] in
                guard let self, let annotations, annotationSelectionBinding === annotations else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in
                guard let self, retainedAnnotationSelection else { return }
                presentation.revoke()
            })
'''
edit(session, needle, installation + needle)
edit(session, '        let savedResults = value.route.route.destination == MaktabahNativeSavedResultsBinding.destination\n', '        let annotationSelection = value.route.route.destination == MaktabahNativeAnnotationSelectionBinding.destination\n        let savedResults = value.route.route.destination == MaktabahNativeSavedResultsBinding.destination\n')
edit(session, 'if workspaceParent != nil || phoneTOC || sefaria || historyRecord || savedResults {', 'if workspaceParent != nil || phoneTOC || sefaria || historyRecord || savedResults || annotationSelection {')
needle = '            if savedResults {\n'
edit(session, needle, '''            if annotationSelection {
                guard let annotationSelectionBinding, let parentValidation else {
                    throw UIRouteError(.staleState, "native_annotation_parent_not_retained")
                }
                try annotationSelectionBinding.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
''' + needle)
edit(session, '            savedResultsBinding?.finish(requestID: value.invocation.requestId, completed: false)\n', '            savedResultsBinding?.finish(requestID: value.invocation.requestId, completed: false)\n            annotationSelectionBinding?.finish(requestID: value.invocation.requestId, completed: false)\n')
edit(session, '        retainedSavedResults = savedResults\n', '        retainedSavedResults = savedResults\n        retainedAnnotationSelection = annotationSelection\n        if !annotationSelection { annotationSelectionBinding?.clearCompletedProof() }\n')
needle = '    func retainSavedResult(_ record: NativeSavedResultIntentService.Record, requestID: UUID) throws\n'
helper = '''    func retainAnnotation(_ record: NativeAnnotationSelectionIntentService.Record, requestID: UUID) throws
        -> MaktabahNativeAnnotationSelectionBinding {
        guard mounted, let original = annotationSelectionBinding else {
            throw UIRouteError(.unavailable, "native_annotation_owner_missing")
        }
        try original.retain(record: record, requestID: requestID)
        return original
    }
    func prepareAnnotation(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard mounted, foreground, scene.sceneID == sceneID, let original = annotationSelectionBinding else {
            throw UIRouteError(.staleState, "native_annotation_window_changed")
        }
        let selected = try original.selectedItem(requestID: invocation.requestId)
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        return RouteSpec(requestId: invocation.requestId, destination: MaktabahNativeAnnotationSelectionBinding.destination,
            backend: invocation.snapshot.backend, presentation: .init(kind: .currentTab),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID, selectedItemID: selected),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }
    func validateCompletedAnnotation(_ receipt: UISceneReceipt,
                                     original: MaktabahNativeAnnotationSelectionBinding) throws {
        guard annotationSelectionBinding === original,
              receipt.route.destination == MaktabahNativeAnnotationSelectionBinding.destination,
              original.hasVisibleSurface(requestID: receipt.requestId),
              original.observedItem(requestID: receipt.requestId) == receipt.route.state.selectedItemID else {
            throw UIRouteError(.staleState, "native_annotation_completion_changed")
        }
        try original.validateCompletedSurface(requestID: receipt.requestId)
        try validateCompletedJourneySurface(receipt)
        try original.validateSource(requestID: receipt.requestId)
    }

'''
edit(session, needle, helper + needle)
needle = '        if route.destination == MaktabahNativeSavedResultsBinding.destination {\n'
edit(session, needle, '''        if route.destination == MaktabahNativeAnnotationSelectionBinding.destination {
            guard route.content == nil, route.focus == nil, route.presentation == .init(kind: .currentTab),
                  let annotationSelectionBinding,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID,
                      selectedItemID: try annotationSelectionBinding.selectedItem(requestID: command.invocation.requestId)) else {
                throw UIRouteError(.staleState, "native_annotation_route_changed")
            }
            return
        }
''' + needle)
needle = '        if command.route.route.destination == MaktabahNativeSavedResultsBinding.destination {\n'
edit(session, needle, '''        if command.route.route.destination == MaktabahNativeAnnotationSelectionBinding.destination {
            try validateSurface(command)
            guard retainedAnnotationSelection, let annotationSelectionBinding else {
                throw UIRouteError(.staleState, "native_annotation_owner_missing")
            }
            try annotationSelectionBinding.apply(requestID: command.invocation.requestId)
            return
        }
''' + needle)
edit(session, 'if retainedComponentOwner != nil || retainedHistoryRecord || retainedSavedResults || [', 'if retainedComponentOwner != nil || retainedHistoryRecord || retainedSavedResults || retainedAnnotationSelection || [')
needle = '        guard let state = try project().surface(kind, workspacePresentation: workspacePresentation,\n'
edit(session, needle, '''        let annotationSource = kind == .annotations && (retainedAnnotationSelection
            || (command == nil && lastCompletedSurface?.route.destination == MaktabahNativeAnnotationSelectionBinding.destination))
            ? annotationSelectionBinding : nil
''' + needle)
edit(session, '                                               historyRecord: historySource,\n', '                                               historyRecord: historySource,\n                                               annotationSelection: annotationSource,\n                                               annotationRequestID: annotationSource != nil ? submissionID ?? lastCompletedSurface?.route.requestId : nil,\n')
needle = '        if evidence.isVisible, evidence.surface.destination == MaktabahNativeSavedResultsBinding.destination {\n'
edit(session, needle, '''        if evidence.isVisible, evidence.surface.destination == MaktabahNativeAnnotationSelectionBinding.destination {
            do {
                guard retainedAnnotationSelection, let original = annotationSelectionBinding,
                      let requestID = evidence.submissionID, submissionID == requestID,
                      command?.invocation.requestId == requestID else {
                    throw UIRouteError(.staleState, "native_annotation_report_not_owned")
                }
                try original.withValidatedSurface(requestID: requestID) {
                    guard isPresentationReady(for: evidence.surface.destination),
                          let actual = try surface(.annotations), actual == evidence.surface else {
                        throw UIRouteError(.staleState, "native_annotation_report_changed")
                    }
                    recordNativeObservation(evidence)
                }
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
''' + needle)
edit(session, '        savedResultsBinding?.finish(requestID: requestID, completed: completed && retainedSavedResults)\n', '        savedResultsBinding?.finish(requestID: requestID, completed: completed && retainedSavedResults)\n        annotationSelectionBinding?.finish(requestID: requestID, completed: completed && retainedAnnotationSelection)\n')
edit(session, '        retainedSavedResults = false\n', '        retainedSavedResults = false\n        retainedAnnotationSelection = false\n')
edit(session, '        savedResultsBinding?.unmount(); savedResultsBinding = nil; retainedSavedResults = false\n', '        savedResultsBinding?.unmount(); savedResultsBinding = nil; retainedSavedResults = false\n        annotationSelectionBinding?.unmount(); annotationSelectionBinding = nil; retainedAnnotationSelection = false\n')
edit(session, '        case "native.annotations": .annotations\n', '        case "native.annotations", "native.annotations.record": .annotations\n')

edit(projection, '                 historyRecord: MaktabahNativeHistoryRecordBinding? = nil,\n', '                 historyRecord: MaktabahNativeHistoryRecordBinding? = nil,\n                 annotationSelection: MaktabahNativeAnnotationSelectionBinding? = nil,\n                 annotationRequestID: UUID? = nil,\n')
needle = '            // Existing private query/note state remains in its original owner.\n'
edit(projection, needle, '''            if surface == .annotations, let original = annotationSelection {
                guard let requestID = annotationRequestID, original.hasVisibleSurface(requestID: requestID),
                      let selected = original.observedItem(requestID: requestID) else { return nil }
                return .init(destination: MaktabahNativeAnnotationSelectionBinding.destination,
                    presentation: .init(kind: .currentTab), content: nil,
                    state: .init(workspaceID: state.workspaceID, profileID: state.profileID, selectedItemID: selected), focus: nil)
            }
''' + needle)

needle = '            .init(id: id("native.annotations"), title: "Annotations".localized, implementation: .implemented,\n'
edit(composition, needle, '''            // Typed original-row selection only. No public-v2 root rule or
            // generic root discovery is supplied for this private destination.
            .init(id: MaktabahNativeAnnotationSelectionBinding.destination, title: "Annotation record".localized,
                  implementation: .implemented, supportedBackends: ActionBackendID.allCases,
                  presentations: [.currentTab], requiredCoreActions: []),
''' + needle)
helper = method(original[composition], '    private func savedResultsCatalog()')
helper = helper.replace('savedResultsCatalog','annotationSelectionCatalog').replace('NativeSavedResultIntentService','NativeAnnotationSelectionIntentService').replace('savedResultsBinding','annotationSelectionBinding')
helper = helper.replace('        guard snapshot.backend == .otzaria else { return .init(snapshot: snapshot, records: []) }\n','')
helper += '''
    private func annotationSelectionWindows() throws -> [NativeIntentService.Destination] {
        try intentRootEntities().filter { $0.destination.rawValue == "native.annotations" && $0.component == nil }
    }
'''
action = method(original[composition], '    private func revealSavedResult(')
for before, after in [('revealSavedResult','revealAnnotation'),('NativeSavedResultIntentService','NativeAnnotationSelectionIntentService'),('savedResultsWindows','annotationSelectionWindows'),('retainSavedResult','retainAnnotation'),('savedResultsBinding','annotationSelectionBinding'),('prepareSavedResult','prepareAnnotation'),('validateCompletedSavedResult','validateCompletedAnnotation'),('native_saved_results','native_annotation')]: action = action.replace(before,after)
action = action.replace('              window.backend == .otzaria, let original = scenes[window.sceneID],','              window.backend == request.expectedSnapshot.backend, window.destination.rawValue == "native.annotations",\n              let original = scenes[window.sceneID],')
helper += action + '\n\n'
needle = '    private func savedResultsCatalog() throws -> NativeSavedResultIntentService.Catalog {\n'
edit(composition, needle, helper + needle)
needle = '        let savedService = NativeSavedResultIntentService(read: { [self] in\n'
registration = '''        let annotationService = NativeAnnotationSelectionIntentService(read: { [self] in
            try annotationSelectionCatalog()
        }, windows: { [self] in
            try annotationSelectionWindows()
        }, navigate: { [self] in
            do { return try await revealAnnotation($0) }
            catch { logIntentFailure(error, stage: "annotation_record"); throw error }
        })
        AppDependencyManager.shared.add(dependency: annotationService)
'''
edit(composition, needle, registration + needle)

# Closed original Annotations modal source, shared with History/ReaderTools/RN.
edit(session, '    @ObservationIgnored private var searchPresentationOwner: UUID?\n', '    @ObservationIgnored let originalAnnotationPresentationPublication = NativeComponentSourcePublication()\n    @ObservationIgnored private var annotationPresentationOwner: UUID?\n    @ObservationIgnored private var annotationPresentationBlocked: (@MainActor () -> Bool)?\n    @ObservationIgnored private var annotationPresentationPublicationRevision: UInt64? = 0\n    @ObservationIgnored private var searchPresentationOwner: UUID?\n')
modal = Path('annotations-selection-analysis/proposal/ANNOTATION_MODAL_SESSION_METHODS.swift').read_text()
edit(session, '    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {\n', modal + '    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {\n')
edit(session, '        readerTabBinding == nil && workspaceSelectionBinding == nil && bindings.isPresentationReady && !hasOriginalWorkspacePresentation', '        readerTabBinding == nil && workspaceSelectionBinding == nil && bindings.isPresentationReady && !hasOriginalAnnotationPresentation && !hasOriginalWorkspacePresentation')
edit(session, '    func isPresentationReady(for destination: UIDestinationID) -> Bool {\n', '    func isPresentationReady(for destination: UIDestinationID) -> Bool {\n        guard !hasOriginalAnnotationPresentation else { return false }\n')
edit(session, '    private var isReaderTabSourceReady: Bool {\n        bindings.isPresentationReady', '    private var isReaderTabSourceReady: Bool {\n        !hasOriginalAnnotationPresentation && bindings.isPresentationReady')
edit(session, '    private var isSefariaOriginalRootReady: Bool {\n        mounted && foreground', '    private var isSefariaOriginalRootReady: Bool {\n        !hasOriginalAnnotationPresentation && mounted && foreground')
edit(session, '        let searchPresentation = try retainHistorySearchPresentationObservation()\n', '        let searchPresentation = try retainHistorySearchPresentationObservation()\n        let annotationPresentation = try retainOriginalAnnotationPresentationObservation()\n')
edit(session, '            try searchPresentation()\n', '            try searchPresentation()\n            try annotationPresentation()\n', 2)
edit(session, '    func unmount() {\n        guard mounted else { return }\n', '    func unmount() {\n        guard mounted else { return }\n        advanceOriginalAnnotationPresentationPublication()\n')
edit(session, '        windowSource = nil; searchPresentationOwner = nil; searchPresentationBlocked = nil\n', '        windowSource = nil; searchPresentationOwner = nil; searchPresentationBlocked = nil\n        annotationPresentationOwner = nil; annotationPresentationBlocked = nil\n')

OUT.mkdir(parents=True, exist_ok=True)
rows = []
for path, value in texts.items():
    for folder, data in [('baseline', original[path]), ('candidate', value)]:
        dest = OUT / folder / path; dest.parent.mkdir(parents=True, exist_ok=True); dest.write_text(data)
    inverse = value
    for item in reversed([e for e in edits if e['path'] == path]):
        assert inverse.count(item['after']) == item['occurrences'], (path, item['after'][:80])
        inverse = inverse.replace(item['after'], item['before'])
    assert inverse == original[path]
    rows.append({'path': path, 'before_bytes': len(original[path].encode()), 'before_sha256': hashlib.sha256(original[path].encode()).hexdigest(), 'after_bytes': len(value.encode()), 'after_sha256': hashlib.sha256(value.encode()).hexdigest(), 'inverse_byte_exact': True})
(OUT / 'EXACT_SHARED_EDITS.json').write_text(json.dumps({'source': '37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be', 'mode': 'Root-only proposal, not applied to integrated source', 'files': rows, 'edits': edits}, indent=2) + '\n')
(OUT / 'PROPOSAL.patch').write_text(''.join(''.join(difflib.unified_diff(original[p].splitlines(True),texts[p].splitlines(True),fromfile='a/'+p,tofile='b/'+p)) for p in texts))
print(json.dumps({'files':rows,'exact_edits':len(edits)},indent=2))
