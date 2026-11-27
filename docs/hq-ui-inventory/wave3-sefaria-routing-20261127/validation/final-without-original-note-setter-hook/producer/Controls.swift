private struct ControlFailure: Error, CustomStringConvertible {
    let description: String
    init(_ value: String) { description = value }
}
@MainActor private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw ControlFailure(message) }
}
@MainActor private func rejects(_ operation: () throws -> Void) throws {
    do { try operation() }
    catch { return }
    throw ControlFailure("retained source was accepted after invalidation")
}
@MainActor private func rejectsAsync(_ operation: () async throws -> Void) async throws {
    do { try await operation() }
    catch { return }
    throw ControlFailure("operation completed despite the refused original input")
}

@MainActor private final class Runner {
    var passed = 0, failed = 0
    func check(_ name: String, _ body: () throws -> Void) {
        do { try body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    func checkAsync(_ name: String, _ body: () async throws -> Void) async {
        do { try await body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    func run() async -> Int32 {
        check("root capture preserves all original +0 owners") {
            let h = Harness(), source = try h.capture()
            try source.validate(h.bindings, workspace: h.workspacePresentation)
            try require(h.root.selectionRevision == 0 && h.root.settingsRevision == 0, "root changed")
            try require(h.bindings.manager.nativeModePresentationRevision == 0, "mode changed")
            try require(h.bindings.manager.selectedBookPresentationRevision == 0, "book changed")
            try require(h.workspacePresentation?.originalStateRevision == 0, "Workspace changed")
        }
        check("selectedTab A-B-A before original mode publication revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.selectedTab.wrappedValue = .history; h.bindings.selectedTab.wrappedValue = .viewer
            try require(h.bindings.manager.nativeModePresentationRevision == 0, "test must precede mode publisher")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original selectedTab write revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.selectedTab.wrappedValue = .viewer
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("Settings false-true-false before view mount revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.showSettings.wrappedValue = true; h.bindings.showSettings.wrappedValue = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original Settings false write revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.showSettings.wrappedValue = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("last finite selection revision permits zero writes then exhausts") {
            let h = Harness(selection: .max), source = try h.capture()
            try source.validate(h.bindings, workspace: h.workspacePresentation)
            h.bindings.selectedTab.wrappedValue = .viewer
            try require(h.root.selectionRevision == nil, "counter wrapped")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("exhausted Settings revision never re-arms") {
            let h = Harness(settings: .max), source = try h.capture()
            h.bindings.showSettings.wrappedValue = false; h.bindings.showSettings.wrappedValue = false
            try require(h.root.settingsRevision == nil, "counter re-armed")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original mode A-B-A revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.manager.currentMode = .history; h.bindings.manager.currentMode = .viewer
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original mode publication revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.manager.currentMode = .viewer
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original mode exhaustion fails closed") {
            let h = Harness(mode: .max), source = try h.capture()
            h.bindings.manager.currentMode = .viewer
            try require(h.bindings.manager.nativeModePresentationRevision == nil, "mode wrapped")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original selectedBook A-B-A revokes") {
            let h = Harness(), a = BooksData(), b = BooksData()
            h.bindings.manager.selectedBook = a
            let source = try h.capture()
            h.bindings.manager.selectedBook = b; h.bindings.manager.selectedBook = a
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("same original selectedBook assignment revokes") {
            let h = Harness(), a = BooksData(); h.bindings.manager.selectedBook = a
            let source = try h.capture(); h.bindings.manager.selectedBook = a
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original book exhaustion fails closed") {
            let h = Harness(book: .max), source = try h.capture()
            h.bindings.manager.selectedBook = nil
            try require(h.bindings.manager.selectedBookPresentationRevision == nil, "book wrapped")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("foreign Workspace local State A-B-A revokes") {
            let h = Harness(), source = try h.capture()
            h.workspacePresentation?.publishOriginalState(); h.workspacePresentation?.publishOriginalState()
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("foreign Workspace exhausted publication never re-arms") {
            let h = Harness(workspace: .max), source = try h.capture()
            h.workspacePresentation?.publishOriginalState(); h.workspacePresentation?.publishOriginalState()
            try require(h.workspacePresentation?.originalStateRevision == nil, "Workspace counter re-armed")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original geometry alone does not change Workspace State source") {
            let h = Harness(), source = try h.capture()
            h.workspacePresentation?.publishGeometryOnly()
            try source.validate(h.bindings, workspace: h.workspacePresentation)
        }
        check("replaced Workspace state owner with same counter is refused") {
            let h = Harness(), source = try h.capture()
            h.workspacePresentation = MaktabahNativeWorkspacePresentationBinding()
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("missing original source counters refuse capture") {
            for h in [Harness(selection: nil), Harness(settings: nil), Harness(mode: nil), Harness(book: nil), Harness(workspace: nil)] {
                try rejects { _ = try h.capture() }
            }
        }
        check("replaced root publication object with equal values is refused") {
            let h = Harness(), source = try h.capture(), replacement = MaktabahNativeRootPublicationSource()
            let b = MaktabahNativeSceneBindings(manager: h.bindings.manager,
                selectedTab: h.bindings.selectedTab, showSettings: h.bindings.showSettings,
                sidebar: h.bindings.sidebar, rootPublications: replacement)
            try rejects { try source.validate(b, workspace: h.workspacePresentation) }
        }
        check("replaced original manager with equal values is refused") {
            let h = Harness(), source = try h.capture()
            let b = MaktabahNativeSceneBindings(manager: iOSNavigationManager(),
                selectedTab: h.bindings.selectedTab, showSettings: h.bindings.showSettings,
                sidebar: h.bindings.sidebar, rootPublications: h.root)
            try rejects { try source.validate(b, workspace: h.workspacePresentation) }
        }
        check("Donation modal A-B-A consumes original observation") {
            let h = Harness(), source = try h.capture()
            DonationManager.shared.showDonationSheet = true; DonationManager.shared.showDonationSheet = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original Reader popover A-B-A consumes observation") {
            let h = Harness(), source = try h.capture()
            h.bindings.manager.activeReaderViewModel?.isPopoverPresented = true
            h.bindings.manager.activeReaderViewModel?.isPopoverPresented = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original Sidebar blocker A-B-A consumes observation") {
            let h = Harness(), source = try h.capture()
            h.bindings.sidebar?.overview.blocksRouting = true; h.bindings.sidebar?.overview.blocksRouting = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("background-foreground does not renew original source") {
            let h = Harness(), source = try h.capture()
            h.foreground = false; h.foreground = true
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original non-Observable note State A-B-A consumes retained source") {
            let h = Harness(), source = try h.capture()
            h.originalNoteState?.edit(.init(value: "unsaved draft")); h.originalNoteState?.edit(nil)
            try require(h.noteEditorOwner?.current == nil, "original note State did not return")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original note State write before begin revokes retained source") {
            let h = Harness(); h.retainedSefariaSurface = false
            let source = try h.capture()
            h.originalNoteState?.edit(nil)
            try require(h.presentation.revokeCalls == 0, "pre-begin callback changed unrelated presentation")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original note State revokes completed proof after public release") {
            let h = Harness(), source = try h.capture()
            h.completedSefariaRootSource = source; h.sefariaRootSources.removeAll()
            h.retainedSefariaSurface = false
            h.originalNoteState?.edit(nil)
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("old note owner callback cannot revoke current source") {
            let h = Harness(), source = try h.capture()
            h.originalNoteEditorStateWillChange(id: UUID(), reader: h.noteEditorOwner!.reader)
            try source.validate(h.bindings, workspace: h.workspacePresentation)
            try require(h.presentation.revokeCalls == 0, "foreign owner callback revoked current presentation")
        }
        check("same note owner ID with foreign Reader cannot revoke current source") {
            let h = Harness(), source = try h.capture()
            h.originalNoteEditorStateWillChange(id: h.noteEditorOwner!.id, reader: ReaderViewModel())
            try source.validate(h.bindings, workspace: h.workspacePresentation)
            try require(h.presentation.revokeCalls == 0, "foreign Reader callback revoked current presentation")
        }
        check("original note setter preserves original presentation and Phone TOC retirement") {
            let h = Harness(), state = h.originalNoteState!
            state.usesNativeStudySheet = true
            let before = state.nativeNoteEditorPresentationID
            state.edit(.init(value: "same original draft"))
            try require(state.editingAnnotation?.value == "same original draft", "draft changed")
            try require(state.nativeNoteEditorPresentationID != before, "original presentation identity not advanced")
            try require(state.nativeStudyPresentation.presentationID == state.nativeNoteEditorPresentationID, "original owner bypassed")
            state.edit(nil)
            try require(state.nativePhoneTOCAttachment.retirementCalls == 2, "existing phone retirement changed")
        }
        check("native window owner invalidation cannot be rearmed") {
            let h = Harness(), source = try h.capture(); source.invalidate()
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }

        let destination = MaktabahNativeSefariaSurfaceBinding.destination
        check("cold RN requires actual original ready window") {
            let h = Harness()
            try require(h.isPresentationReady(for: destination), "initial root refused")
            h.windowSource?.ready = false
            try require(!h.isPresentationReady(for: destination), "foreign transition accepted")
        }
        check("cold RN does not substitute a missing window owner") {
            let h = Harness(); h.windowSource = nil
            try require(!h.isPresentationReady(for: destination), "missing original window accepted")
        }
        check("cold RN cannot use unavailable original runtime/backend") {
            let h = Harness(); h.sefariaSurfaceBinding?.isAvailable = false
            try require(!h.isPresentationReady(for: destination), "unavailable feature accepted")
        }
        check("Settings remains blocking without dismissal") {
            let h = Harness(); h.bindings.showSettings.wrappedValue = true
            try require(!h.isPresentationReady(for: destination), "Settings was bypassed")
            try require(h.state.settings, "Settings was dismissed")
        }
        check("foreign Workspace presentation remains blocking") {
            let h = Harness(); h.hasOriginalWorkspacePresentation = true
            try require(!h.isPresentationReady(for: destination), "Workspace modal was bypassed")
        }
        check("own applied continuation can await only its same transition") {
            let h = Harness(); h.windowSource?.ready = false
            h.sefariaSurfaceBinding?.presentationFacets = .init(requested: true, mounted: false, visible: false, transitioning: true, ready: false)
            h.sefariaSurfaceBinding?.continuingRequest = h.submissionID
            try require(h.isPresentationReady(for: destination), "same admitted transition refused")
            h.sefariaSurfaceBinding?.continuingRequest = UUID()
            try require(!h.isPresentationReady(for: destination), "foreign continuation accepted")
        }
        check("own continuation cannot bypass foreign Settings") {
            let h = Harness(); h.bindings.showSettings.wrappedValue = true
            h.sefariaSurfaceBinding?.continuingRequest = h.submissionID
            try require(!h.isPresentationReady(for: destination), "own request covered foreign Settings")
        }
        check("pending requested sheet without actual mount is not fresh readiness") {
            let h = Harness(); h.sefariaSurfaceBinding?.presentationFacets.requested = true
            try require(!h.isPresentationReady(for: destination), "request alone accepted")
        }
        check("warm original sheet requires stable real host facets") {
            let h = Harness(); h.windowSource?.ready = false
            h.sefariaSurfaceBinding?.presentationFacets = .init(requested: true, mounted: true, visible: true, transitioning: false, ready: true)
            try require(h.isPresentationReady(for: destination), "stable own sheet refused")
            h.sefariaSurfaceBinding?.presentationFacets.visible = false
            try require(!h.isPresentationReady(for: destination), "hidden own sheet accepted")
        }
        check("foreign foreground lifetime and ended command cannot continue") {
            let h = Harness(); h.sefariaSurfaceBinding?.continuingRequest = h.submissionID
            h.sefariaSurfaceBinding?.presentationFacets.transitioning = true
            h.command = nil
            try require(!h.isPresentationReady(for: destination), "ended command continued")
            h.foreground = false
            try require(!h.isPresentationReady(for: destination), "background accepted")
        }

        await checkAsync("structured RN wait cannot inspect or report marker before original child drains") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted()
            try require(h.markerChecks == 0 && h.presentation.waitCalls == 0, "marker read before original RPC proof")
            original.originalWait.succeed()
            let result = try await task.value
            try require(result == h.expectedSurface, "observed state changed")
            try require(original.awaitCalls == 1 && h.presentation.reportCalls > 0, "new wait or missing marker")
        }
        await checkAsync("cancelled original RN child joins before shared wait returns") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted(); task.cancel()
            try await rejectsAsync { _ = try await task.value }
            try require(original.originalWait.cancelled, "child not drained")
            try require(h.presentation.reportCalls == 0 && h.presentation.waitCalls == 0, "cancelled child produced observation")
        }
        await checkAsync("original RN invalidation stops before marker observation") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted(); original.originalWait.fail()
            try await rejectsAsync { _ = try await task.value }
            try require(h.markerChecks == 0 && h.presentation.reportCalls == 0, "invalidated proof reached marker")
        }
        await checkAsync("Settings ABA during original RN wait is checked again before marker") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted()
            h.bindings.showSettings.wrappedValue = true; h.bindings.showSettings.wrappedValue = false
            original.originalWait.succeed()
            try await rejectsAsync { _ = try await task.value }
            try require(h.markerChecks == 0 && h.presentation.reportCalls == 0, "stale root reached marker")
        }
        await checkAsync("original non-Observable note State ABA during RN wait cannot reach marker") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted()
            h.originalNoteState?.edit(.init(value: "unsaved original note")); h.originalNoteState?.edit(nil)
            original.originalWait.succeed()
            try await rejectsAsync { _ = try await task.value }
            try require(h.markerChecks == 0 && h.presentation.reportCalls == 0, "stale note source reached marker")
        }
        await checkAsync("RN source proof alone cannot replace missing native marker") {
            let h = Harness(); h.captured = try h.capture()
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted(); original.originalWait.succeed()
            await h.presentation.markerWait.untilStarted()
            try require(h.presentation.reportCalls == 0, "proof fabricated visible marker")
            task.cancel()
            try await rejectsAsync { _ = try await task.value }
            try require(h.presentation.markerWait.cancelled, "native wait not drained")
        }
        await checkAsync("different submission cannot start original RN child") {
            let h = Harness(); h.captured = try h.capture(); let original = h.sefariaSurfaceBinding!
            let foreign = UISceneCommand(request: UUID(), destination: destination)
            try await rejectsAsync { _ = try await h.waitUntilVisible(foreign) }
            try require(original.awaitCalls == 0, "foreign submission started RPC")
        }
        print("RESULT \(passed) PASS / \(failed) FAIL")
        return failed == 0 ? 0 : 1
    }
}
@main private enum Controls {
    static func main() async { exit(await Runner().run()) }
}
