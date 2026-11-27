from pathlib import Path
import hashlib,json,difflib
root=Path(__file__).resolve().parent
base=root/'baseline';candidate=root/'candidate'
paths={
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceGroupSelectionReservation.swift':root.parent/'profile-group-parent-implementation/original-inputs/Source/ChavrusaText/StudyWorkspace/StudyWorkspaceGroupSelectionReservation.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift':root.parent/'profile-group-cold-implementation/candidate/Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift',
'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift':root.parent/'profile-group-cold-implementation/candidate/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift'}
expected=['a9a75bd53eb711e2a21e5f3011c965eb50414b2397f797806eb08bd74f6c739d','3e01142c5d0dcc5f16136173e973d438349cf2b741e62c71fae7929e55b3e7c3','97249458394c290bb2c52f13da088b7f597226ae27faad0d8e19fdd9847ff24d']
pins=[];edits=[]
for (p,s),h in zip(paths.items(),expected):
 b=s.read_bytes();assert hashlib.sha256(b).hexdigest()==h
 q=base/p;q.parent.mkdir(parents=True,exist_ok=True)
 if q.exists():assert q.read_bytes()==b
 else:q.write_bytes(b)
 q=candidate/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
 pins.append({'path':p,'bytes':len(b),'sha256':h})
def edit(path,before,after):
 p=candidate/path;s=p.read_text();assert s.count(before)==1,(path,before[:90],s.count(before));p.write_text(s.replace(before,after,1));edits.append({'path':path,'before':before,'after':after})
policy,adapter,binding=list(paths)
edit(policy,'case installTabs, restoreClosingTabs, select(UUID), close(UUID), liveContext','case installTabs, restoreClosingTabs, select(UUID), presentActive(UUID), close(UUID), liveContext')
edit(policy,'actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?) throws {\n        guard phase == .preparing,', 'actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?,\n                           presentingActiveTab: StudyWorkspaceGroupNativeTab? = nil) throws {\n        guard phase == .preparing,')
edit(policy,'            try append(.select(selected.id), changes)\n        } else {\n            try append(.restoreClosingTabs,', '''            try append(.select(selected.id), changes)
            if let presentingActiveTab {
                // Only the retained ORIGINAL same-active phone presentation
                // supplies this exact tab. The ordinary select call stays a
                // no-op; its separate original presentation owns one setter.
                guard presentingActiveTab == selected, changes.isEmpty,
                      actual.tabs.filter({ $0.id == selected.id }) == [selected],
                      actual.activeID == selected.id, actual.selectedBookOwner == nil,
                      actual.selectedBookID == nil, actual.selectedBookMode == nil else { throw invalid() }
                try append(.presentActive(selected.id), [.book(selected.bookOwner, selected.target.bookID)])
            }
        } else {
            guard presentingActiveTab == nil else { throw invalid() }
            try append(.restoreClosingTabs,''')
edit(adapter,'prepared: StudyWorkspacePreparedGroupSelection) throws\n        -> StudyWorkspaceNativeGroupSelectionReservation {\n        try backendObservation.validate()', '''prepared: StudyWorkspacePreparedGroupSelection,
                                     activePresentation: StudyWorkspaceNativeGroupSelectionReservation.ActivePresentation? = nil) throws
        -> StudyWorkspaceNativeGroupSelectionReservation {
        try backendObservation.validate()
        try activePresentation?.original.validate()
        guard activePresentation == nil || activePresentation?.original.requestID == requestID else {
            throw StudyWorkspaceError.invalidMembership
        }''')
edit(adapter,'backendObservation: backendObservation)\n        do {\n            try backendObservation.bind(policy)', 'backendObservation: backendObservation, activePresentation: activePresentation)\n        do {\n            try backendObservation.bind(policy)')
edit(adapter,'''                try reservation.captureOriginalReaderSources()
                try reservation.policy.finishPreparation(staged: groupNativeTabs(reservation.prepared.staged),
                    requested: reservation.prepared.requested, actual: groupNativeState(manager), snapshot: store.snapshot)''', '''                try reservation.captureOriginalReaderSources()
                let presenting: StudyWorkspaceGroupNativeTab?
                if let retained = reservation.activePresentation {
                    try retained.original.validate()
                    guard let selected = reservation.selectedTab, selected.id == retained.tab.id,
                          selected.book === retained.tab.book, selected.viewModel === retained.tab.viewModel,
                          !retained.original.hasPublishedBook,
                          let actual = groupNativeTabs([selected]).first else { throw StudyWorkspaceError.invalidMembership }
                    presenting = actual
                } else { presenting = nil }
                try reservation.policy.finishPreparation(staged: groupNativeTabs(reservation.prepared.staged),
                    requested: reservation.prepared.requested, actual: groupNativeState(manager), snapshot: store.snapshot,
                    presentingActiveTab: presenting)''')
edit(adapter,'                    publishOriginalGroupSelection(reservation.prepared, manager: manager, owner: reservation)\n                }, willClearPending:', '                    publishOriginalGroupSelection(reservation.prepared, manager: manager, owner: reservation, validate: validate)\n                }, willClearPending:')
edit(adapter,'        reservation.backendObservation.retire()\n        reservation.policy.release()', '        reservation.backendObservation.retire()\n        reservation.activePresentation?.original.release()\n        reservation.policy.release()')
edit(adapter,'    // MARK: Workspace presentation\n', '''    /// This is part of the SAME synchronous authorized terminal, after the
    /// unchanged original selectTab no-op. No renderer or validator grants it.
    private func presentOriginalActiveGroupTab(_ tab: iOSNavigationManager.ReaderTab,
                                              selection: StudyWorkspacePreparedGroupSelection,
                                              manager: iOSNavigationManager,
                                              owner: StudyWorkspaceNativeGroupSelectionReservation,
                                              validate: @MainActor () throws -> Void) -> Bool {
        do {
            guard groupSelectionReservation === owner, owner.prepared === selection,
                  let retained = owner.activePresentation, retained.tab.id == tab.id,
                  retained.tab.book === tab.book, retained.tab.viewModel === tab.viewModel,
                  retained.original.requestID == owner.policy.requestID else { throw StudyWorkspaceError.invalidMembership }
            try retained.original.validate()
            try validate()
            try validateNativeGroupSelection(owner)
            try owner.policy.beginOperation(.presentActive(tab.id), actual: groupNativeState(manager))
            try retained.original.apply {
                // Manager invokes this only before/after an original effect,
                // never inside its intermediate selectedBook will/did pair.
                guard groupSelectionReservation === owner, owner.prepared === selection,
                      owner.activePresentation?.original === retained.original else { throw StudyWorkspaceError.invalidMembership }
                try validate()
                guard groupSelectionReservation === owner, owner.prepared === selection else { throw StudyWorkspaceError.invalidMembership }
                try validateNativeGroupSelection(owner)
            }
            try owner.policy.finishOperation(.presentActive(tab.id), actual: groupNativeState(manager))
            try validate()
            guard groupSelectionReservation === owner, owner.prepared === selection,
                  retained.original.hasPublishedBook else { throw StudyWorkspaceError.invalidMembership }
            try retained.original.validate()
            try validateNativeGroupSelection(owner)
            return true
        } catch {
            owner.recordPublicationFailure(error)
            invalidateNativeGroupSelection(owner)
            return false
        }
    }

    // MARK: Workspace presentation
''')
edit(adapter,'                publishOriginalGroupSelection(prepared, manager: manager)\n', '                publishOriginalGroupSelection(prepared, manager: manager, validate: {})\n')
edit(adapter,'owner: StudyWorkspaceNativeGroupSelectionReservation? = nil) {\n        let id = selection.target.id, requested = selection.requested, staged = selection.staged', 'owner: StudyWorkspaceNativeGroupSelectionReservation? = nil,\n                                               validate: @MainActor () throws -> Void) {\n        let id = selection.target.id, requested = selection.requested, staged = selection.staged')
edit(adapter,'''                body: { manager.selectTab(id: active.id) }) else { return }
            active.viewModel.needsScrollRestore = true''', '''                body: { manager.selectTab(id: active.id) }) else { return }
            if let owner, owner.activePresentation != nil {
                guard presentOriginalActiveGroupTab(active, selection: selection, manager: manager,
                    owner: owner, validate: validate) else { return }
            }
            active.viewModel.needsScrollRestore = true''')
edit(adapter,'@MainActor final class StudyWorkspaceNativeGroupSelectionReservation {\n    struct ReaderSource {', '''@MainActor final class StudyWorkspaceNativeGroupSelectionReservation {
    /// Exact existing objects; this is source metadata, never effect authority.
    struct ActivePresentation {
        let tab: iOSNavigationManager.ReaderTab
        let original: iOSNavigationManager.ActiveReaderTabPresentation
    }
    let activePresentation: ActivePresentation?
    struct ReaderSource {''')
edit(adapter,'''         backendObservation: StudyWorkspaceGroupBackendObservation) {
        self.policy = policy; self.prepared = prepared; self.backendObservation = backendObservation
    }''', '''         backendObservation: StudyWorkspaceGroupBackendObservation,
         activePresentation: ActivePresentation? = nil) {
        self.policy = policy; self.prepared = prepared; self.backendObservation = backendObservation
        self.activePresentation = activePresentation
    }''')
edit(binding,'    let viewerParent: MaktabahNativeViewerParentContinuation?\n', '    let viewerParent: MaktabahNativeViewerParentContinuation?\n    private let activePresentation: StudyWorkspaceNativeGroupSelectionReservation.ActivePresentation?\n')
edit(binding,'''            // Original selectTab is a no-op for the already active tab. Do not
            // advertise that it pushes a hidden compact Reader as a side effect.
            if !MaktabahApp.isIpad, let selected, manager.activeTabId == selected.id {
                guard let tab = manager.openTabs.first(where: { $0.id == selected.id }),
                      manager.selectedBook === tab.book, manager.selectedBookPresentationMode == .viewer else { return }
            }''', '''            // The same-active hidden phone case uses the ORIGINAL retained
            // presentation. Discovery checks feasibility without acquiring it.
            do { _ = try activePhoneTabRequiringPresentation(stage, manager: manager) }
            catch { return }''')
edit(binding,'    /// Read-only feasibility from the ORIGINAL saved documents/cache.', '''    private static func activePhoneTabRequiringPresentation(_ stage: StudyWorkspacePreparedGroupSelection,
                                                            manager: iOSNavigationManager) throws -> iOSNavigationManager.ReaderTab? {
        let selected = stage.documents.first(where: { $0.id == stage.requested }) ?? stage.documents.first
        guard !MaktabahApp.isIpad, let selected, manager.activeTabId == selected.id else { return nil }
        let matches = manager.openTabs.filter { $0.id == selected.id }
        guard matches.count == 1, let tab = matches.first else { throw StudyWorkspaceError.invalidMembership }
        if manager.selectedBook === tab.book, manager.selectedBookPresentationMode == .viewer { return nil }
        guard manager.selectedBook == nil, manager.selectedBookPresentationMode == nil,
              let revision = manager.selectedBookPresentationRevision, revision < .max else {
            throw StudyWorkspaceError.invalidMembership
        }
        return tab
    }

    /// Read-only feasibility from the ORIGINAL saved documents/cache.''')
edit(binding,'        viewerParent = retainedParent\n        // Do not observe', '''        viewerParent = retainedParent
        let retainedActive: StudyWorkspaceNativeGroupSelectionReservation.ActivePresentation?
        do {
            if let tab = try Self.activePhoneTabRequiringPresentation(stage, manager: manager) {
                retainedActive = .init(tab: tab,
                    original: try manager.retainActiveReaderTabPresentation(requestID: requestID, tab: tab))
            } else { retainedActive = nil }
        } catch { retainedParent?.release(); backendObservation.retire(); throw error }
        activePresentation = retainedActive
        // Do not observe''')
edit(binding,'        catch { retainedParent?.release(); backendObservation.retire(); throw error }\n    }\n\n    var isReserved', '        catch { retainedActive?.original.release(); retainedParent?.release(); backendObservation.retire(); throw error }\n    }\n\n    var isReserved')
edit(binding,'        try backendObservation.validate()\n        let manager = bindings.manager', '''        try backendObservation.validate()
        // This is called at original effect boundaries, not from Group's
        // intermediate will/did hooks while Manager's book phase is publishing.
        try activePresentation?.original.validate()
        let manager = bindings.manager''')
edit(binding,'            guard reservation.prepared === prepared, reservation.backendObservation === backendObservation,', '            guard reservation.prepared === prepared, reservation.backendObservation === backendObservation,\n                  reservation.activePresentation?.original === activePresentation?.original,')
edit(binding,'            manager: bindings.manager, backendObservation: backendObservation, prepared: prepared)', '            manager: bindings.manager, backendObservation: backendObservation, prepared: prepared,\n            activePresentation: activePresentation)')
edit(binding,'        viewerParent?.release()\n        if let reservation { workspace.releaseNativeGroupSelection(reservation) }', '        viewerParent?.release()\n        activePresentation?.original.release()\n        if let reservation { workspace.releaseNativeGroupSelection(reservation) }')
(root/'SOURCE_EDITS.json').write_text(json.dumps({'base':'b463ffd03a76026cea06c79c608df97d00094152','edits':edits},indent=2)+'\n')
manifest=[]
for p in paths:
 before=(base/p).read_bytes();after=(candidate/p).read_bytes();s=after.decode()
 for e in reversed([e for e in edits if e['path']==p]):assert s.count(e['after'])==1;s=s.replace(e['after'],e['before'],1)
 assert s.encode()==before
 manifest.append({'path':p,'before':{'bytes':len(before),'sha256':hashlib.sha256(before).hexdigest()},'after':{'bytes':len(after),'sha256':hashlib.sha256(after).hexdigest()}})
(root/'SOURCE_INPUTS.json').write_text(json.dumps(manifest,indent=2)+'\n')
(root/'SOURCE.diff').write_text(''.join(''.join(difflib.unified_diff((base/p).read_text().splitlines(True),(candidate/p).read_text().splitlines(True),fromfile='a/'+p,tofile='b/'+p))for p in paths))
print(json.dumps({'files':manifest,'edits':len(edits)},indent=2))
