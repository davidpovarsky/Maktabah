from pathlib import Path
import json,hashlib,difflib

ROOT=Path(__file__).parent
SHEET='Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift'
LIST='Source/Features/Annotations/iOS/AnnotationListView.swift'
edits=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def edit(path,old,new,count=1):
    value=current[path]
    assert value.count(old)==count,(path,old[:90],value.count(old),count)
    current[path]=value.replace(old,new)
    edits.append({'path':path,'old':old,'new':new,'occurrences':count})
original={p:(ROOT/'baseline'/p).read_text() for p in [SHEET,LIST]}
current=dict(original)

edit(SHEET,'    var nativeSurface: (@MainActor () -> AnyView)? = nil\n',
'''    var nativeSurface: (@MainActor () -> AnyView)? = nil
    // Optional same-scene original List ownership; other presenters keep nil.
    var nativeControls: MaktabahNativeAnnotationEditorControls.Attachment? = nil
    @State private var nativeEditorViewID = UUID()
    @FocusState private var nativeTagsFocused: Bool
''')
edit(SHEET,'iOSAutoDirectionTextView(text: $noteText, onCreated:',
           'iOSAutoDirectionTextView(text: nativeEditorBinding($noteText), onCreated:')
edit(SHEET,'                        .frame(minHeight: 80)\n                        .disabled(!allowsPlainEditing)',
'''                        .frame(minHeight: 80)
                        .disabled(!allowsPlainEditing)
                        .modifier(MaktabahNativeAnnotationEditorControl(attachment: nativeControls,
                            viewID: nativeEditorViewID, anchor: .body, bodyTextView: { editorTextView }))''')
edit(SHEET,'Toggle("Underline", isOn: $isUnderline)',
'''Toggle("Underline", isOn: nativeEditorBinding($isUnderline))
                        .modifier(MaktabahNativeAnnotationEditorControl(attachment: nativeControls,
                            viewID: nativeEditorViewID, anchor: .style))''')
edit(SHEET,'TextField("tag1, tag2...", text: $tagsText)',
'''TextField("tag1, tag2...", text: nativeEditorBinding($tagsText))
                        .modifier(MaktabahNativeAnnotationEditorTagsFocus(enabled: nativeControls != nil,
                            focused: $nativeTagsFocused))
                        .modifier(MaktabahNativeAnnotationEditorControl(attachment: nativeControls,
                            viewID: nativeEditorViewID, anchor: .tags))''')
edit(SHEET,'            .background { nativeSurface?() }\n',
'''            .background { nativeSurface?() }
            .modifier(MaktabahNativeAnnotationEditorForm(attachment: nativeControls,
                viewID: nativeEditorViewID, snapshot: {
                    .init(annotation: annotation, note: noteText, nativeNote: editorTextView?.text,
                        tags: tagsText, color: selectedColorHex, underline: isUnderline,
                        initialized: hasInitialized, allowsPlainEditing: allowsPlainEditing,
                        blocked: nativeEditorIsBlocked)
                }, bodyTextView: { editorTextView }, focusTags: { nativeTagsFocused = true }))
''')
edit(SHEET,'}, availability: $originalEditorAvailability, present: { originalEditorModal = $0 })',
           '}, availability: nativeEditorBinding($originalEditorAvailability), present: { nativeEditorStateWillChange(); originalEditorModal = $0 })')
edit(SHEET,'.fullScreenCover(item: $originalEditorModal, onDismiss:',
           '.fullScreenCover(item: nativeEditorBinding($originalEditorModal), onDismiss:')

# The exact original operations/order are preserved. Each actual draft/modal
# write not already reached through a wrapped Binding publishes BEFORE its write.
lines=current[SHEET].splitlines(keepends=True)
assignments=('annotation = saved','noteText = ','selectedColorHex = ','isUnderline = ','tagsText = ',
             'hasInitialized = true','editorTextView?.text = ')
for line in list(lines):
    stripped=line.lstrip()
    if any(stripped.startswith(prefix) for prefix in assignments):
        indent=line[:len(line)-len(stripped)]
        edit(SHEET,line,indent+'nativeEditorStateWillChange()\n'+line)

# Cancellation/foreign editor actions revoke before original callbacks; a
# callback may reenter, so a later original dismiss independently publishes.
edit(SHEET,'dismiss()', 'nativeEditorStateWillChange(); dismiss()', count=current[SHEET].count('dismiss()'))
for token in ['OtzariaMiniAppsCoordinator.shared.shareRetainedFiles(',
              'OtzariaMiniAppsCoordinator.shared.showEditor(']:
    line=next(x for x in current[SHEET].splitlines(keepends=True) if token in x)
    indent=line[:len(line)-len(line.lstrip())]
    edit(SHEET,line,indent+'nativeEditorStateWillChange()\n'+line)
edit(SHEET,'            .onDisappear {\n                OtzariaMiniAppsCoordinator.shared.unregisterEditor',
'''            .onDisappear {
                nativeEditorStateWillChange()
                OtzariaMiniAppsCoordinator.shared.unregisterEditor''')
edit(SHEET,'    private func saveAnnotation() {\n',
           '    private func saveAnnotation() {\n        nativeEditorStateWillChange()\n')
edit(SHEET,'    private func deleteAnnotation(_ id: Int64) {\n',
           '    private func deleteAnnotation(_ id: Int64) {\n        nativeEditorStateWillChange()\n')
edit(SHEET,'                        if let id = annotation.id {\n                            try? onDelete(id)',
'''                        if let id = annotation.id {
                            nativeEditorStateWillChange()
                            try? onDelete(id)''')
edit(SHEET,'set: { if !$0 { operationErrorMessage = nil } }',
           'set: { if !$0 { nativeEditorStateWillChange(); operationErrorMessage = nil } }')
edit(SHEET,'Button("OK", role: .cancel) { operationErrorMessage = nil }',
           'Button("OK", role: .cancel) { nativeEditorStateWillChange(); operationErrorMessage = nil }')
for line in list(current[SHEET].splitlines(keepends=True)):
    stripped=line.lstrip()
    if stripped.startswith('operationErrorMessage = '):
        indent=line[:len(line)-len(stripped)]
        edit(SHEET,line,indent+'nativeEditorStateWillChange()\n'+line,count=current[SHEET].count(line))

edit(SHEET,'    private func saveAnnotation() {\n',
'''    private var nativeEditorIsBlocked: Bool {
        #if os(iOS) && canImport(AnytypeOriginalEditor)
        operationErrorMessage != nil || originalEditorModal != nil
        #else
        operationErrorMessage != nil
        #endif
    }
    private func nativeEditorStateWillChange() {
        nativeControls?.controls.originalStateWillChange(viewID: nativeEditorViewID)
    }
    private func nativeEditorBinding<Value>(_ original: Binding<Value>) -> Binding<Value> {
        guard nativeControls != nil else { return original }
        return Binding(get: { original.wrappedValue }, set: {
            nativeEditorStateWillChange()
            original.wrappedValue = $0
        })
    }

    private func saveAnnotation() {
''')

edit(LIST,'''            editingAnnotation: nativeModalBinding($editingAnnotation),
            viewModel: viewModel
''','''            editingAnnotation: nativeModalBinding($editingAnnotation),
            viewModel: viewModel,
            nativeControls: nativeRoutingSession?.annotationEditorControls,
            nativeListOwner: nativeRoutingOwner,
            nativeParentAvailable: {
                !isExporting && !isImporting && !showOverwriteDialog && !showImportAlert && !showMissingBookAlert
            }, nativeSurface: nativeRoutingSession.map { session in
                { AnyView(MaktabahNativeRoutingWitness(kind: .annotationEditor)
                    .environment(\\.maktabahNativeRoutingSession, session)) }
            }
''')
edit(LIST,'''        editingAnnotation: Binding<Annotation?>,
        viewModel: AnnotationViewModel
''','''        editingAnnotation: Binding<Annotation?>,
        viewModel: AnnotationViewModel,
        nativeControls: MaktabahNativeAnnotationEditorControls? = nil,
        nativeListOwner: UUID? = nil,
        nativeParentAvailable: @escaping @MainActor () -> Bool = { true },
        nativeSurface: (@MainActor () -> AnyView)? = nil
''')
edit(LIST,'''                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            )
''','''                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }, nativeSurface: nativeSurface,
                nativeControls: nativeControls.flatMap { controls in
                    nativeListOwner.map { owner in
                        .init(controls: controls, listOwner: owner,
                            parentCurrent: { editingAnnotation.wrappedValue == ann && nativeParentAvailable() })
                    }
                }
            )
''')

inverse=dict(current)
for e in reversed(edits):
    assert inverse[e['path']].count(e['new'])==e['occurrences'],('inverse ambiguity',e['new'][:100])
    inverse[e['path']]=inverse[e['path']].replace(e['new'],e['old'])
assert inverse==original
for p,v in current.items():
    out=ROOT/'candidate'/p;out.parent.mkdir(parents=True,exist_ok=True);out.write_text(v)
rows=[{'path':p,'before':sha(original[p].encode()),'after':sha(current[p].encode()),
       'original_bytes':len(original[p].encode()),'candidate_bytes':len(current[p].encode())} for p in original]
(ROOT/'ORIGINAL_HOOK_EDITS.json').write_text(json.dumps({'files':rows,'edits':edits,'inverse':'BYTE_EXACT'},indent=2)+'\n')
(ROOT/'ORIGINAL_HOOKS.diff').write_text(''.join(''.join(difflib.unified_diff(original[p].splitlines(True),current[p].splitlines(True),fromfile='a/'+p,tofile='b/'+p)) for p in original))
print(json.dumps({'files':rows,'edits':len(edits),'inverse':'BYTE_EXACT'},indent=2))
