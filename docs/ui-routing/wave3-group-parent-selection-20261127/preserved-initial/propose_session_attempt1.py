from pathlib import Path
import json, hashlib, difflib

ROOT = Path(__file__).resolve().parent
PATH = 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift'
original = (ROOT / 'baseline' / PATH).read_text()
candidate = original
edits = []

def replace(before, after):
    global candidate
    assert candidate.count(before) == 1, (before[:150], candidate.count(before))
    candidate = candidate.replace(before, after, 1)
    edits.append({'before': before, 'after': after})

def prepend(signature, body):
    replace(signature, signature + body)

replace('    @ObservationIgnored private var readerTabParentObservation: NativeOriginalParentObservation?\n',
        '    @ObservationIgnored private var readerTabParentObservation: NativeOriginalParentObservation?\n'
        '    @ObservationIgnored private var workspaceSelectionParentObservation: NativeOriginalParentObservation?\n')
replace('''        guard mounted, workspaceSelectionBinding == nil, readerTabBinding == nil, isReaderTabSourceReady,
              bindings.selectedTab.wrappedValue == .viewer, bindings.manager.currentMode == .viewer,
              let source = workspaceProjectionSource else { return [] }
''', '''        guard mounted, workspaceSelectionBinding == nil, readerTabBinding == nil, isReaderTabSourceReady,
              let source = workspaceProjectionSource else { return [] }
        let originalViewer = bindings.selectedTab.wrappedValue == .viewer && bindings.manager.currentMode == .viewer
        guard originalViewer || viewerParentHost?.isAvailable(bindings: bindings) == true else { return [] }
''')
replace('''        let bound = try MaktabahNativeWorkspaceSelectionBinding(requestID: requestID, target: target,
            bindings: bindings, source: source,
''', '''        let bound = try MaktabahNativeWorkspaceSelectionBinding(requestID: requestID, target: target,
            bindings: bindings, source: source, viewerParentHost: viewerParentHost,
''')
replace('''        guard workspaceSelectionBinding === bound else { return }
        workspaceSelectionBinding = nil
''', '''        guard workspaceSelectionBinding === bound else { return }
        workspaceSelectionBinding = nil; workspaceSelectionParentObservation = nil
''')
replace('''                let originalLifetime = try componentValidation(value)
                try bound.begin { [weak self, weak bound] in
''', '''                workspaceSelectionParentObservation = nil
                try bound.viewerParent?.bind(value)
                let originalLifetime = try componentValidation(value)
                try bound.begin { [weak self, weak bound] in
''')
replace('''    // Opt-in ONLY for an existing Reader-tab request retained on a foreign
    // original root. The same command/preparation owns both effects; these
''', '''    // Opt-in ONLY for the finite original Reader-tab or prepared workspace
    // selection retained on a foreign root. The same preparation owns both effects; these
''')
prepend('''    func originalParentSelectionKind(for value: UISceneCommand) throws -> UIOriginalParentSelectionKind? {
''', '''        if value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            guard command == value, let bound = workspaceSelectionBinding,
                  bound.requestID == value.invocation.requestId, bound.isPrepared else {
                throw UIRouteError(.staleState, "native_workspace_selection_owner_missing")
            }
            guard let kind = try bound.originalParentSelectionKind(), let parent = bound.viewerParent else { return nil }
            try parent.validates(value)
            guard workspaceSelectionBinding === bound, command == value, bound.viewerParent === parent else {
                throw UIRouteError(.staleState, "native_workspace_selection_owner_changed")
            }
            try bound.validate()
            return kind
        }
''')
prepend('''    func applyOriginalParent(_ value: UISceneCommand) throws {
''', '''        if value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            try validateSurface(value)
            guard command == value, let bound = workspaceSelectionBinding, let parent = bound.viewerParent,
                  bound.requestID == value.invocation.requestId, bound.isPrepared, !bound.isApplied else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try bound.validate()
            try parent.applyParent(value)
            guard workspaceSelectionBinding === bound, command == value, bound.viewerParent === parent else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try bound.validate()
            originalPresentationStateDidChange()
            return
        }
''')
prepend('''    func waitUntilOriginalParentReady(_ value: UISceneCommand) async throws -> NativeOriginalParentObservation {
''', '''        if value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            guard command == value, let bound = workspaceSelectionBinding, let parent = bound.viewerParent,
                  bound.requestID == value.invocation.requestId, !bound.isApplied else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try bound.validate()
            let actual = try await parent.waitUntilReady(value)
            guard workspaceSelectionBinding === bound, command == value, bound.viewerParent === parent else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try bound.validate()
            try parent.validateParent(actual, command: value)
            guard workspaceSelectionBinding === bound, command == value, bound.viewerParent === parent else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            workspaceSelectionParentObservation = actual
            return actual
        }
''')
prepend('''    func validateOriginalParent(_ actual: NativeOriginalParentObservation, for value: UISceneCommand) throws {
''', '''        if value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            guard command == value, let bound = workspaceSelectionBinding, let parent = bound.viewerParent,
                  bound.requestID == value.invocation.requestId, workspaceSelectionParentObservation == actual else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try bound.validate()
            try parent.validateParent(actual, command: value)
            guard workspaceSelectionBinding === bound, command == value, bound.viewerParent === parent,
                  workspaceSelectionParentObservation == actual else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try bound.validate()
            return
        }
''')
prepend('''    func applyOriginalSelection(_ value: UISceneCommand) throws {
''', '''        if value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            guard command == value, let bound = workspaceSelectionBinding, let parent = bound.viewerParent,
                  bound.requestID == value.invocation.requestId, let actual = workspaceSelectionParentObservation else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            try validateOriginalParent(actual, for: value)
            try parent.beginSelection(actual, command: value)
            guard workspaceSelectionBinding === bound, command == value, bound.viewerParent === parent else {
                throw UIRouteError(.staleState, "native_workspace_selection_parent_changed")
            }
            // The SAME Core terminal capability was just consumed. The complete
            // original group flush/Store/native publisher stays synchronous.
            try apply(value)
            return
        }
''')
replace('''        readerTabParentObservation = nil
        try? nativeStateChanged()
''', '''        readerTabParentObservation = nil
        workspaceSelectionParentObservation = nil
        try? nativeStateChanged()
''')
replace('''        workspaceSelectionBinding?.release(); workspaceSelectionBinding = nil
''', '''        workspaceSelectionBinding?.release(); workspaceSelectionBinding = nil; workspaceSelectionParentObservation = nil
''')

inverse = candidate
for edit in reversed(edits):
    assert inverse.count(edit['after']) == 1
    inverse = inverse.replace(edit['after'], edit['before'], 1)
assert inverse == original
dest = ROOT / 'proposal-candidate' / PATH
dest.write_text(candidate)
out = ROOT / 'proposal'
out.mkdir(exist_ok=True)
(out / 'SESSION_EDITS.json').write_text(json.dumps(edits, indent=2) + '\n')
(out / 'SESSION.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True), candidate.splitlines(True), fromfile='a/' + PATH, tofile='b/' + PATH)))
def pin(text):
    raw=text.encode()
    return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
result={'base':pin(original),'candidate':pin(candidate),'edits':len(edits),'inverse_original_bytes':True,
        'root_owned_proposal_only':True}
(out / 'SESSION_JOIN.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
