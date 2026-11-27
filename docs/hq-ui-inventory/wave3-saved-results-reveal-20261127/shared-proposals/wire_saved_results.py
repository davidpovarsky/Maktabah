from pathlib import Path
import hashlib,json,difflib
BASE=Path(__file__).parent/'baseline'; OUT=BASE.parent/'candidate'
P='Source/ChavrusaText/UIRoutingHost/Integration/'
texts={p.name:p.read_text() for p in (BASE/P).glob('*.swift')}
edits=[]
def change(name,old,new,count=1):
 s=texts[name]; actual=s.count(old)
 if actual!=count:raise RuntimeError((name,old[:100],actual,count))
 texts[name]=s.replace(old,new)
 edits.append({'path':P+name,'old':old,'new':new,'occurrences':count})
S='MaktabahNativeSceneSession.swift';C='MaktabahNativeRoutingComposition.swift';R='MaktabahNativeSceneProjection.swift';B='MaktabahNativePublicBindingAdapter.swift'
# Public primitive root only: the existing v2 protocol remains unchanged.
change(B,'    var readySefariaSurface: Bool = false\n','    var readySefariaSurface: Bool = false\n    var readySavedResults: Bool = false\n')
change(B,'        case "native.sefariaEmbedded": return readySefariaSurface\n','        case "native.sefariaEmbedded": return readySefariaSurface\n        case "native.savedResults": return readySavedResults\n')
change(B,'                   destination != MaktabahNativeSefariaSurfaceBinding.destination,\n','                   destination != MaktabahNativeSefariaSurfaceBinding.destination,\n                   destination != MaktabahNativeSavedResultsBinding.destination,\n')
change(B,'workspaceProfiles, workspaceOverview, sefariaEmbedded }','workspaceProfiles, workspaceOverview, sefariaEmbedded, savedResults }')
change(B,'        case ("native.sefariaEmbedded", .sheet, false): return .sefariaEmbedded\n','        case ("native.sefariaEmbedded", .sheet, false): return .sefariaEmbedded\n        case ("native.savedResults", .sheet, false): return .savedResults\n')
change(B,'        case .library, .settings, .search, .annotations, .workspaceProfiles, .workspaceOverview, .sefariaEmbedded:\n','        case .library, .settings, .search, .annotations, .workspaceProfiles, .workspaceOverview, .sefariaEmbedded, .savedResults:\n')
change(B,'            || descriptor.id == MaktabahNativeSefariaSurfaceBinding.destination ? .sheet\n','            || descriptor.id == MaktabahNativeSefariaSurfaceBinding.destination\n            || descriptor.id == MaktabahNativeSavedResultsBinding.destination ? .sheet\n')
# Actual original sheet and row are independently projected, never copied from route.
change(R,'workspaceProfiles, workspaceOverview, sefariaEmbedded }','workspaceProfiles, workspaceOverview, sefariaEmbedded, savedResults }')
change(R,'                  sefariaSurface: MaktabahNativeSefariaSurfaceBinding? = nil) throws -> NativeSceneIdentity {','                  sefariaSurface: MaktabahNativeSefariaSurfaceBinding? = nil,\n                  savedResults: MaktabahNativeSavedResultsBinding? = nil) throws -> NativeSceneIdentity {')
change(R,'            originalSheet = MaktabahNativeSefariaSurfaceBinding.destination\n        } else { originalSheet = nil }','            originalSheet = MaktabahNativeSefariaSurfaceBinding.destination\n        } else if savedResults?.isRequestedOrMounted == true {\n            originalSheet = MaktabahNativeSavedResultsBinding.destination\n        } else { originalSheet = nil }')
change(R,'                 historyRecord: MaktabahNativeHistoryRecordBinding? = nil) throws -> NativeSurfaceState? {','                 historyRecord: MaktabahNativeHistoryRecordBinding? = nil,\n                 savedResults: MaktabahNativeSavedResultsBinding? = nil,\n                 savedResultsRequestID: UUID? = nil) throws -> NativeSurfaceState? {')
change(R,'        switch surface {\n','''        switch surface {
        case .savedResults:
            guard !settingsPresented, selectedTab.canonical == .search, manager.currentMode == .search,
                  let original = savedResults, let requestID = savedResultsRequestID,
                  original.hasVisibleSurface(requestID: requestID) else { return nil }
            return .init(destination: MaktabahNativeSavedResultsBinding.destination,
                presentation: .init(kind: .sheet), content: nil,
                state: .init(workspaceID: state.workspaceID, profileID: state.profileID,
                             selectedItemID: original.observedItem(requestID: requestID)), focus: nil)
''')
# Scene-local original owner and exact retained parent lifetime.
change(S,'    @ObservationIgnored private var retainedHistoryRecord = false\n','    @ObservationIgnored private var retainedHistoryRecord = false\n    private(set) var savedResultsBinding: MaktabahNativeSavedResultsBinding?\n    @ObservationIgnored private var retainedSavedResults = false\n')
change(S,'    func retainParentSource(destination: UIDestinationID, requestID: UUID) throws {\n','''    func retainParentSource(destination: UIDestinationID, requestID: UUID) throws {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            guard mounted, let original = savedResultsBinding else {
                throw UIRouteError(.unavailable, "native_saved_results_owner_missing")
            }
            try original.retain(record: nil, requestID: requestID)
            return
        }
''')
change(S,'    func validateParentSource(destination: UIDestinationID, requestID: UUID) throws {\n','''    func validateParentSource(destination: UIDestinationID, requestID: UUID) throws {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            guard let original = savedResultsBinding else {
                throw UIRouteError(.staleState, "native_saved_results_owner_detached")
            }
            try original.validateSource(requestID: requestID)
            return
        }
''')
change(S,'    func releaseParentSource(destination: UIDestinationID, requestID: UUID) {\n','''    func releaseParentSource(destination: UIDestinationID, requestID: UUID) {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            savedResultsBinding?.releaseSource(requestID: requestID)
            return
        }
''')
change(S,'        historyRecordBinding?.retire()\n','        historyRecordBinding?.retire()\n        savedResultsBinding?.retire()\n')
change(S,'        historyRecordBinding?.originalForeignStateWillChange()\n        if retainedSefariaSurface','        historyRecordBinding?.originalForeignStateWillChange()\n        savedResultsBinding?.retire()\n        if retainedSefariaSurface')
change(S,'readerTabBinding == nil && workspaceSelectionBinding == nil && bindings.isPresentationReady && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface','readerTabBinding == nil && workspaceSelectionBinding == nil && bindings.isPresentationReady && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface\n            && savedResultsBinding?.isRequestedOrMounted != true')
change(S,'    func isPresentationReady(for destination: UIDestinationID) -> Bool {\n','''    func isPresentationReady(for destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            guard mounted, foreground, let original = savedResultsBinding, original.isAvailable else { return false }
            if let requestID = submissionID, command?.invocation.requestId == requestID,
               command?.route.route.destination == destination,
               original.isContinuingAppliedRequest(requestID: requestID) { return true }
            if original.isRequestedOrMounted { return original.isStableOriginalPresentation }
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        guard savedResultsBinding?.isRequestedOrMounted != true else { return false }
''')
change(S,'            && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface\n            && studyChatPresentationID == nil','            && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface\n            && savedResultsBinding?.isRequestedOrMounted != true\n            && studyChatPresentationID == nil')
change(S,'    func isRootAvailable(_ destination: UIDestinationID) -> Bool {\n','''    func isRootAvailable(_ destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            return savedResultsBinding?.isAvailable == true
        }
''')
anchor='            let sefaria = MaktabahNativeSefariaSurfaceBinding(sceneID: sceneID,\n'
change(S,anchor,'''            let saved = MaktabahNativeSavedResultsBinding(sceneID: sceneID, bindings: bindings,
                workspaceSource: workspaceSource, workspacePresentation: original,
                commonReady: { [weak self] in
                    guard let self else { return false }
                    // Primitive foreign-presentation checks, deliberately not
                    // recursive isPresentationReady (which blocks this own sheet).
                    return mounted && readerBinding == nil && readerTabBinding == nil
                        && workspaceSelectionBinding == nil && searchResultsBinding == nil
                        && searchContinuationOwner == nil && bindings.isPresentationReady
                        && !bindings.showSettings.wrappedValue && !hasOriginalWorkspacePresentation
                        && !hasOriginalSefariaSurface && studyChatPresentationID == nil
                        && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
                }, windowReady: { [weak self] in
                    guard let self else { return false }
                    return foreground && windowSource?.isPresentationReady(in: sceneID) == true
                }, retainWindow: { [weak self] in
                    guard let self else { throw UIRouteError(.staleState, "native_saved_results_window_detached") }
                    return try retainOriginalWindowObservation()
                }, readForeignPresentations: { [weak self] in
                    guard let self else { return }
                    _ = mounted; _ = studyChatPresentationID
                    _ = workspacePresentation?.originalStateRevision
                })
            savedResultsBinding = saved
            saved.install(changed: { [weak self, weak saved] in
                guard let self, let saved, savedResultsBinding === saved else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in
                guard let self, retainedSavedResults else { return }
                presentation.revoke()
            })
'''+anchor)
change(S,'        let workspaceSelection = value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination\n','        let workspaceSelection = value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination\n        let savedResults = value.route.route.destination == MaktabahNativeSavedResultsBinding.destination\n')
change(S,'        if workspaceParent != nil || phoneTOC || sefaria || historyRecord {','        if workspaceParent != nil || phoneTOC || sefaria || historyRecord || savedResults {')
anchor='            if historyRecord {\n'
change(S,anchor,'''            if savedResults {
                guard let savedResultsBinding, let parentValidation else {
                    throw UIRouteError(.unavailable, "native_saved_results_owner_missing")
                }
                try savedResultsBinding.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
'''+anchor)
change(S,'            historyRecordBinding?.finish(requestID: value.invocation.requestId, completed: false)\n','            historyRecordBinding?.finish(requestID: value.invocation.requestId, completed: false)\n            savedResultsBinding?.finish(requestID: value.invocation.requestId, completed: false)\n')
change(S,'        retainedHistoryRecord = historyRecord\n','        retainedHistoryRecord = historyRecord\n        retainedSavedResults = savedResults\n        if !savedResults { savedResultsBinding?.clearCompletedProof() }\n')
anchor='    /// Typed record metadata is converted into private route state only by the\n'
change(S,anchor,'''    func retainSavedResult(_ record: NativeSavedResultIntentService.Record, requestID: UUID) throws
        -> MaktabahNativeSavedResultsBinding {
        guard mounted, let original = savedResultsBinding else {
            throw UIRouteError(.unavailable, "native_saved_results_owner_missing")
        }
        try original.retain(record: record, requestID: requestID)
        return original
    }
    func prepareSavedResult(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard mounted, foreground, scene.sceneID == sceneID, let original = savedResultsBinding else {
            throw UIRouteError(.staleState, "native_saved_results_window_changed")
        }
        let selected = try original.selectedItem(requestID: invocation.requestId)
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding)
        return RouteSpec(requestId: invocation.requestId, destination: MaktabahNativeSavedResultsBinding.destination,
            backend: invocation.snapshot.backend, presentation: .init(kind: .sheet),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID, selectedItemID: selected),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }
    func validateCompletedSavedResult(_ receipt: UISceneReceipt,
                                     original: MaktabahNativeSavedResultsBinding) throws {
        guard savedResultsBinding === original,
              receipt.route.destination == MaktabahNativeSavedResultsBinding.destination,
              original.hasVisibleSurface(requestID: receipt.requestId),
              original.observedItem(requestID: receipt.requestId) == receipt.route.state.selectedItemID else {
            throw UIRouteError(.staleState, "native_saved_results_completion_changed")
        }
        try original.validateCompletedSurface(requestID: receipt.requestId)
        try validateCompletedJourneySurface(receipt)
        try original.validateSource(requestID: receipt.requestId)
    }

'''+anchor)
anchor='        if route.destination == MaktabahNativeHistoryRecords.destination, let itemID = route.state.selectedItemID {\n'
change(S,anchor,'''        if route.destination == MaktabahNativeSavedResultsBinding.destination {
            guard route.backend == .otzaria, route.content == nil, route.focus == nil,
                  route.presentation == .init(kind: .sheet), let savedResultsBinding,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID,
                      profileID: identity.state.profileID,
                      selectedItemID: try savedResultsBinding.selectedItem(requestID: command.invocation.requestId)) else {
                throw UIRouteError(.staleState, "native_saved_results_route_changed")
            }
            return
        }
'''+anchor)
anchor='        if command.route.route.destination == MaktabahNativeHistoryRecords.destination,\n'
change(S,anchor,'''        if command.route.route.destination == MaktabahNativeSavedResultsBinding.destination {
            try validateSurface(command)
            guard retainedSavedResults, let savedResultsBinding else {
                throw UIRouteError(.staleState, "native_saved_results_not_prepared")
            }
            try savedResultsBinding.apply(requestID: command.invocation.requestId)
            return
        }
'''+anchor)
change(S,'if retainedComponentOwner != nil || retainedHistoryRecord || [','if retainedComponentOwner != nil || retainedHistoryRecord || retainedSavedResults || [')
change(S,'                                               historyRecord: historySource) else { return nil }','''                                               historyRecord: historySource,
                                               savedResults: savedResultsBinding,
                                               savedResultsRequestID: kind == .savedResults
                                                   ? submissionID ?? lastCompletedSurface?.route.requestId : nil) else { return nil }''')
change(S,'            readySefariaSurface: mounted && foreground && isPresentationReady(for: MaktabahNativeSefariaSurfaceBinding.destination),\n','            readySefariaSurface: mounted && foreground && isPresentationReady(for: MaktabahNativeSefariaSurfaceBinding.destination),\n            readySavedResults: mounted && foreground && isPresentationReady(for: MaktabahNativeSavedResultsBinding.destination),\n')
anchor='    func observe(_ evidence: NativeSurfaceWitness.Evidence) {\n        guard mounted, evidence.sceneID == sceneID else { return }\n'
change(S,anchor,anchor+'''        if evidence.isVisible, evidence.surface.destination == MaktabahNativeSavedResultsBinding.destination {
            do {
                guard retainedSavedResults, let original = savedResultsBinding,
                      let requestID = evidence.submissionID, submissionID == requestID,
                      command?.invocation.requestId == requestID else {
                    throw UIRouteError(.staleState, "native_saved_results_report_not_owned")
                }
                try original.withValidatedSurface(requestID: requestID) {
                    guard isPresentationReady(for: evidence.surface.destination),
                          let actual = try surface(.savedResults), actual == evidence.surface else {
                        throw UIRouteError(.staleState, "native_saved_results_report_changed")
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
change(S,'        historyRecordBinding?.finish(requestID: requestID, completed: completed && retainedHistoryRecord)\n','        historyRecordBinding?.finish(requestID: requestID, completed: completed && retainedHistoryRecord)\n        savedResultsBinding?.finish(requestID: requestID, completed: completed && retainedSavedResults)\n')
change(S,'        retainedHistoryRecord = false\n','        retainedHistoryRecord = false\n        retainedSavedResults = false\n')
change(S,'        historyRecordBinding?.unmount(); historyRecordBinding = nil; retainedHistoryRecord = false\n','        historyRecordBinding?.unmount(); historyRecordBinding = nil; retainedHistoryRecord = false\n        savedResultsBinding?.unmount(); savedResultsBinding = nil; retainedSavedResults = false\n')
change(S,'        case "native.sefariaEmbedded": .sefariaEmbedded\n','        case "native.sefariaEmbedded": .sefariaEmbedded\n        case "native.savedResults": .savedResults\n')
# All original identity reads share the same optional original sheet owner.
old='identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding)'
change(S,old,'identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)',texts[S].count(old))
# Finite registration and sole original entry path.
anchor='            .init(id: id("native.search.results"), title: "Search results".localized, implementation: .implemented,\n'
change(C,anchor,'''            .init(id: MaktabahNativeSavedResultsBinding.destination, title: "Saved Results".localized,
                  implementation: .implemented, supportedBackends: [.otzaria], presentations: [.sheet],
                  requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .sheet)])),
'''+anchor)
change(C,'            || destination.destination == MaktabahNativeSefariaSurfaceBinding.destination\n','            || destination.destination == MaktabahNativeSefariaSurfaceBinding.destination\n            || destination.destination == MaktabahNativeSavedResultsBinding.destination\n')
change(C,'                    || destination.destination == MaktabahNativeSefariaSurfaceBinding.destination) ? .sheet : .currentTab,','                    || destination.destination == MaktabahNativeSefariaSurfaceBinding.destination\n                    || destination.destination == MaktabahNativeSavedResultsBinding.destination) ? .sheet : .currentTab,')
anchor='    /// One typed local record, one exact existing window, one original Core\n'
change(C,anchor,'''    private func savedResultsCatalog() throws -> NativeSavedResultIntentService.Catalog {
        try Task.checkCancellation()
        let snapshot = try backend.currentBackendSnapshot()
        guard snapshot.backend == .otzaria else { return .init(snapshot: snapshot, records: []) }
        var records: [NativeSavedResultIntentService.Record] = []
        for (id, entry) in scenes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where entry.session.mounted {
            guard entry.session.sceneID == id, let original = entry.session.savedResultsBinding,
                  original.sceneID == id else { continue }
            records += try original.catalog()
        }
        try Task.checkCancellation()
        guard try backend.currentBackendSnapshot() == snapshot else { throw ActionPortError.staleState }
        return .init(snapshot: snapshot, records: records)
    }
    private func savedResultsWindows() throws -> [NativeIntentService.Destination] {
        try intentRootEntities().filter {
            $0.backend == .otzaria && $0.destination == MaktabahNativeSavedResultsBinding.destination
                && $0.component == nil
        }
    }
    private func revealSavedResult(_ request: NativeSavedResultIntentService.OpenRequest) async throws
        -> UISceneAcknowledgement {
        try Task.checkCancellation()
        let window = request.window, end = deadline()
        let matches = try savedResultsWindows().filter { $0 == window }
        guard matches.count == 1, request.record.sceneID == window.sceneID,
              window.backend == .otzaria, let original = scenes[window.sceneID],
              original.session.mounted, let manager = original.manager,
              ObjectIdentifier(manager) == original.managerID,
              try backend.currentBackendSnapshot() == request.expectedSnapshot else {
            throw UIRouteError(.staleState, "native_saved_results_window_changed")
        }
        let retained = try original.session.retainSavedResult(request.record, requestID: request.requestID)
        defer { retained.releaseSource(requestID: request.requestID) }
        let activated = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: original.managerID)
        }
        try Task.checkCancellation()
        guard activated == window.sceneID, let current = scenes[window.sceneID],
              current.session === original.session, current.managerID == original.managerID,
              current.manager === manager, current.session.mounted, current.session.foreground,
              current.session.savedResultsBinding === retained,
              try backend.currentBackendSnapshot() == request.expectedSnapshot else {
            throw UIRouteError(.staleState, "native_saved_results_activation_changed")
        }
        try retained.validateSource(requestID: request.requestID)
        let context = context(sceneID: window.sceneID, origin: .appIntent, snapshot: request.expectedSnapshot)
        try issue(context, sceneID: window.sceneID)
        defer { finish(context, sceneID: window.sceneID) }
        let invocation = ActionPortInvocation(requestId: request.requestID, snapshot: request.expectedSnapshot,
                                             deadlineUptimeNanoseconds: end)
        let scene = try await directory.currentScene(sceneID: window.sceneID, context: context, invocation: invocation)
        try retained.validateSource(requestID: request.requestID)
        guard scenes[window.sceneID]?.session === original.session,
              original.session.savedResultsBinding === retained,
              try backend.currentBackendSnapshot() == request.expectedSnapshot else {
            throw UIRouteError(.staleState, "native_saved_results_source_changed")
        }
        let route = try original.session.prepareSavedResult(invocation: invocation, scene: scene)
        let command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: scene)
        let result = try await orchestrator.commit(command, context: context)
        record(result)
        if case .acknowledged(let receipt) = result {
            do {
                try Task.checkCancellation()
                guard scenes[window.sceneID]?.session === original.session,
                      original.session.savedResultsBinding === retained,
                      try backend.currentBackendSnapshot() == request.expectedSnapshot,
                      SystemActionClock().now() < end else {
                    throw UIRouteError(.staleState, "native_saved_results_completion_changed")
                }
                try original.session.validateCompletedSavedResult(receipt, original: retained)
                guard receipt.requestId == request.requestID, receipt.sceneID == window.sceneID,
                      receipt.route.state.selectedItemID == request.record.itemID else {
                    throw UIRouteError(.failed, "native_effect_uncertain")
                }
            } catch {
                throw NativeSavedResultIntentService.Failure(acknowledgement: result, underlying: error)
            }
        }
        return result
    }

'''+anchor)
change(C,'        AppDependencyManager.shared.add(dependency: historyService)\n','''        AppDependencyManager.shared.add(dependency: historyService)
        let savedService = NativeSavedResultIntentService(read: { [self] in
            try savedResultsCatalog()
        }, windows: { [self] in
            try savedResultsWindows()
        }, navigate: { [self] in
            do { return try await revealSavedResult($0) }
            catch { logIntentFailure(error, stage: "saved_result"); throw error }
        })
        AppDependencyManager.shared.add(dependency: savedService)
''')
rows=[];diff=[]
for name,text in texts.items():
 original=(BASE/P/name).read_text()
 if original==text:continue
 p=OUT/P/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
 rows.append({'path':P+name,'before_bytes':len(original.encode()),'before_sha256':hashlib.sha256(original.encode()).hexdigest(),'bytes':len(text.encode()),'sha256':hashlib.sha256(text.encode()).hexdigest()})
 diff+=difflib.unified_diff(original.splitlines(True),text.splitlines(True),fromfile='a/'+P+name,tofile='b/'+P+name)
(BASE.parent/'EXACT_WIRING_EDITS.json').write_text(json.dumps(edits,indent=2)+'\n')
(BASE.parent/'SOURCE_MANIFEST.json').write_text(json.dumps({'base':'24cd9291dbc87d799c22a41f0bc73a82c6415bfa','shared_patch_only':True,'files':rows},indent=2)+'\n')
(BASE.parent/'SAVED_RESULTS_SHARED.patch').write_text(''.join(diff))
print(json.dumps(rows,indent=2))
