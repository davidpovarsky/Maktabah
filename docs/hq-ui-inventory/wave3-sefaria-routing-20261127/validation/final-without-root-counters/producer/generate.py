#!/usr/bin/env python3
"""Compile actual shared RN source over explicit app/UIKit/RPC boundary inputs.

No app, React runtime, SDK, permission grant or native receipt is constructed.
Original root metadata, manager setters, one-shot observation, zero-write source,
RN readiness branch and complete structured-wait method are copied verbatim.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root, peer, out = map(lambda x: Path(x).resolve(), sys.argv[1:4])
variant = sys.argv[4] if len(sys.argv) > 4 else 'candidate'
out.mkdir(parents=True, exist_ok=False)
inputs = {}


def read(name, source=root):
    path = source / name
    data = path.read_bytes() if path.exists() else subprocess.check_output(
        ['git', '-C', str(source), 'show', 'HEAD:' + name])
    role = 'peer' if source == peer else 'source'
    inputs[role + ':' + name] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
    snap = out / 'source-inputs' / role / name
    snap.parent.mkdir(parents=True, exist_ok=True)
    snap.write_bytes(data)
    return data.decode()


def block(source, marker):
    start = source.index(marker)
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        if source[end] == '{':
            depth += 1
        elif source[end] == '}':
            depth -= 1
        end += 1
    return source[start:end]


integration = 'Source/ChavrusaText/UIRoutingHost/Integration/'
session = read(integration + 'MaktabahNativeSceneSession.swift')
bindings = read(integration + 'MaktabahNativeSceneBindings.swift')
entry = read(integration + 'MaktabahNativeSearchEntry.swift')
manager = read('Source/UI/iOS/Managers/iOSNavigationManager.swift')
latch = read('Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift')
workspace = read(integration + 'MaktabahNativeWorkspacePresentationBinding.swift', peer)
reader_workspace = read('Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift')
source = block(session, '@MainActor private final class MaktabahNativeSefariaRootSource')
note_invalidation = block(session, '    func originalNoteEditorStateWillChange(id: UUID, reader: ReaderViewModel)')
note_setter = block(reader_workspace, '    private func setEditingAnnotation(_ value: Annotation?)')
note_hook = '''        nativeRoutingSession?.originalNoteEditorStateWillChange(
            id: nativeNoteEditorOwnerID, reader: viewModel)
'''
assert note_setter.count(note_hook) == 1
publication = block(entry, '@MainActor\nfinal class MaktabahNativeRootPublicationSource')
manager_fields = block(manager, '    var currentMode: AppMode') + '\n'
manager_fields += '    private(set) var nativeModePresentationRevision: UInt64? = 0\n'
manager_fields += block(manager, '    var selectedBook: BooksData?') + '\n'
manager_fields += '    private(set) var selectedBookPresentationRevision: UInt64? = 0\n'
manager_fields += '    private(set) var selectedBookPresentationMode: AppMode?\n'
assert manager_fields in manager
workspace_field = '    private(set) var originalStateRevision: UInt64? = 0'
assert workspace_field in workspace
workspace_advance = block(workspace, '    private func advanceOriginalStateRevision()')
readiness = block(session, '    private var isSefariaOriginalRootReady: Bool')
ready_method = block(session, '    func isPresentationReady(for destination: UIDestinationID)')
ready_branch = block(ready_method, '        if destination == MaktabahNativeSefariaSurfaceBinding.destination')
wait = block(session, '    func waitUntilVisible(_ command: UISceneCommand)')

counterfactual = None
if variant == 'without-root-counters':
    target = '              root.selectionRevision == selectionRevision, root.settingsRevision == settingsRevision,\n'
    assert source.count(target) == 1
    source = source.replace(target, '')
    counterfactual = 'Remove only exact original selectedTab/Settings publication equality from the retained root source.'
elif variant == 'without-one-shot-observation':
    target = '        try observation.validate()\n'
    assert source.count(target) == 1
    source = source.replace(target, '')
    counterfactual = 'Remove only retained one-shot validation; original counter/value/readiness comparisons remain.'
elif variant == 'without-original-note-setter-hook':
    note_setter = note_setter.replace(note_hook, '')
    counterfactual = 'Remove only the two-line original note State pre-mutation hook; Session and every original setter effect remain.'
elif variant != 'candidate':
    raise ValueError(variant)

domain = Path(__file__).with_name('DomainBoundary.swift').read_text()
controls = Path(__file__).with_name('Controls.swift').read_text()
text = domain + '\n'
text += '@MainActor @Observable final class iOSNavigationManager {\n' + manager_fields + '''
    var selectedBookForInfo: BooksData?
    var showingTabsList = false
    var activeReaderViewModel: ReaderViewModel? = ReaderViewModel()
    init(modeSeed: UInt64? = 0, bookSeed: UInt64? = 0) {
        nativeModePresentationRevision = modeSeed
        selectedBookPresentationRevision = bookSeed
    }
}
@MainActor @Observable final class MaktabahNativeWorkspacePresentationBinding {
'''
text += workspace_field + '\n' + workspace_advance + '''
    init(seed: UInt64? = 0) { originalStateRevision = seed }
    // The genuine setter/sidebar call sites have their own peer controls. This
    // explicit boundary calls the exact source-owned advance method only.
    func publishOriginalState() { advanceOriginalStateRevision() }
    func publishGeometryOnly() {}
}
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator?
    let rootPublications: MaktabahNativeRootPublicationSource?
'''
text += block(bindings, '    var isPresentationReady: Bool') + '\n}\n'
text += '\n'.join(x for x in latch.splitlines() if not x.startswith('import ')) + '\n'
text += publication + '\n' + source + '\n'
text += '''
// The original State setter body below runs verbatim. Stored values here are
// explicit SwiftUI State/Binding and presentation-owner substitutes only.
@MainActor private final class OriginalNoteStateBoundary {
    weak var nativeRoutingSession: Harness?
    let owner: BoundaryNoteEditorOwner
    var nativeNoteEditorOwnerID: UUID { owner.id }
    var viewModel: ReaderViewModel { owner.reader }
    let nativePhoneTOCAttachment = BoundaryPhoneTOCAttachment()
    let nativeStudyPresentation = BoundaryStudyPresentation()
    var usesNativeStudySheet = false
    var showPanelSheet = false
    var fallbackNoteHost = BoundaryNoteHost.reader
    var nativeNoteEditorPresentationID = UUID()
    // Simulates the original owner's Binding read, without Observation.
    var editingAnnotation: Annotation? { didSet { owner.current = editingAnnotation } }
    init(owner: BoundaryNoteEditorOwner) { self.owner = owner }
    func edit(_ value: Annotation?) { setEditingAnnotation(value) }
'''
text += note_setter + '\n}\n'
text += '''
// Boundary-only exhaustion seeds. No production setter/API is added or reset.
extension MaktabahNativeRootPublicationSource {
    func seedForControls(selection: UInt64?, settings: UInt64?) {
        selectionRevision = selection; settingsRevision = settings
    }
}
@MainActor @Observable private final class Harness {
    let bindings: MaktabahNativeSceneBindings
    let state: OriginalRootState
    let root: MaktabahNativeRootPublicationSource
    var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    let sceneID = UIStableID(rawValue: "original-source-scene")!
    var mounted = true
    var foreground = true
    var hasOriginalWorkspacePresentation = false
    var studyChatPresentationID: UUID?
    var noteEditorOwner: BoundaryNoteEditorOwner? = BoundaryNoteEditorOwner()
    var sefariaSurfaceBinding: MaktabahNativeSefariaSurfaceBinding? = MaktabahNativeSefariaSurfaceBinding()
    var windowSource: BoundaryWindowSource? = BoundaryWindowSource()
    var submissionID: UUID?
    var command: UISceneCommand?
    var retainedSefariaSurface = true
    var retainedComponentOwner: Bool?
    var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    let presentation = BoundaryPresentation()
    var sefariaRootSources: [UUID: MaktabahNativeSefariaRootSource] = [:]
    var completedSefariaRootSource: MaktabahNativeSefariaRootSource?
    var originalNoteState: OriginalNoteStateBoundary?
    var captured: MaktabahNativeSefariaRootSource?
    var markerVisible = false
    var markerChecks = 0
    var validations = 0
    let expectedSurface = NativeSurfaceState(destination: MaktabahNativeSefariaSurfaceBinding.destination, stamp: 47)

    init(selection: UInt64? = 0, settings: UInt64? = 0,
         mode: UInt64? = 0, book: UInt64? = 0, workspace: UInt64? = 0) {
        DonationManager.shared.showDonationSheet = false
        let state = OriginalRootState(), root = MaktabahNativeRootPublicationSource()
        root.seedForControls(selection: selection, settings: settings)
        self.state = state; self.root = root
        let tab = Binding(get: { state.tab }, set: { state.tab = $0; state.lastTransaction = $1 })
        let sheet = Binding(get: { state.settings }, set: { state.settings = $0; state.lastTransaction = $1 })
        bindings = .init(manager: .init(modeSeed: mode, bookSeed: book),
                         selectedTab: root.selectionBinding(tab), showSettings: root.settingsBinding(sheet),
                         sidebar: ReaderSidebarPageCoordinator(), rootPublications: root)
        workspacePresentation = .init(seed: workspace)
        originalNoteState = OriginalNoteStateBoundary(owner: noteEditorOwner!)
        originalNoteState?.nativeRoutingSession = self
        let request = UUID()
        submissionID = request
        command = .init(request: request, destination: MaktabahNativeSefariaSurfaceBinding.destination)
        visibilityChecks[MaktabahNativeSefariaSurfaceBinding.destination] = { [weak self] in
            guard let self else { return nil }
            markerChecks += 1
            return markerVisible ? .init(sceneID: sceneID, submissionID: submissionID,
                surface: expectedSurface, isVisible: true) : nil
        }
    }
    func capture() throws -> MaktabahNativeSefariaRootSource {
        let source = try MaktabahNativeSefariaRootSource(bindings: bindings, workspace: workspacePresentation!) { [weak self] in
            guard let self else { return }
            _ = mounted; _ = foreground; _ = studyChatPresentationID
        }
        sefariaRootSources[submissionID!] = source
        return source
    }
    func validateSurface(_ command: UISceneCommand) throws {
        validations += 1
        guard mounted, foreground, let captured else { throw UIRouteError(.unavailable, "controlled-source-absent") }
        try captured.validate(bindings, workspace: workspacePresentation)
    }
    func observe(_ evidence: NativeSurfaceWitness.Evidence) {
        // This is the named test input at the view boundary, not the product's
        // final source-locked ACK method or a native acceptance claim.
        if evidence.isVisible { presentation.report(evidence.surface) }
    }
'''
text += note_invalidation + '\n'
text += readiness + '\n'
text += '    func isPresentationReady(for destination: UIDestinationID) -> Bool {\n' + ready_branch + '\n        return false // Other routes are outside this boundary.\n    }\n'
text += wait + '\n}\n' + controls
(out / 'Generated.swift').write_text(text)
(out / 'SOURCE_INPUTS.json').write_text(json.dumps({
    'scope': 'Actual source bodies over explicit app/UIKit/RPC/presentation boundary inputs; no Apple SDK, app, Core grant or native execution.',
    'variant': variant, 'counterfactual': counterfactual, 'inputs': inputs,
    'generatedSHA256': hashlib.sha256(text.encode()).hexdigest(),
    'domainSHA256': hashlib.sha256(domain.encode()).hexdigest(),
    'controlsSHA256': hashlib.sha256(controls.encode()).hexdigest(),
    'extractedBodies': ['MaktabahNativeSefariaRootSource', 'MaktabahNativeRootPublicationSource',
        'NativeComponentSourceObservation', 'original manager mode/book declarations',
        'original Workspace state revision/advance', 'original bindings.isPresentationReady',
        'original iOSReaderWorkspaceView.setEditingAnnotation', 'Session.originalNoteEditorStateWillChange',
        'Session.isSefariaOriginalRootReady', 'Session RN readiness branch', 'Session.waitUntilVisible']
}, indent=2) + '\n')
print(json.dumps({'variant': variant, 'output': str(out), 'sourceInputs': len(inputs),
                  'generatedBytes': len(text.encode()), 'generatedSHA256': hashlib.sha256(text.encode()).hexdigest()}))
