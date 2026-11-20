#!/usr/bin/env python3
"""Read-only packet/source verifier. This never runs Swift or Native."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

BASE = '40c1eaa6bb0092336f1ee687ad1ce1425eaf4223'
DOCS = Path('docs/hq-integration/native-study-sheet-20261120')
WORKSPACE = 'Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift'
HOST = 'Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift'
PRESENTER = 'Source/Features/Reader/iOS/NativeStudySheetPresenter.swift'
TEST = 'Maktabah-iOSUITests/NativeStudySheetAcceptanceTests.swift'

def sha(data): return hashlib.sha256(data).hexdigest()
def blob(data): return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
def require(condition, reason):
    if not condition: raise ValueError(reason)

def verify(root):
    docs = root / DOCS
    manifest = json.loads((docs / 'ARTIFACTS.json').read_text())
    paths = set()
    for entry in manifest['files']:
        name = entry['path']; relative = Path(name)
        require(not relative.is_absolute() and '..' not in relative.parts and name not in paths, 'Unsafe/duplicate member')
        paths.add(name); path = root / relative
        require(path.is_file() and not path.is_symlink(), 'Missing/nonregular member: ' + name)
        data = path.read_bytes()
        require(len(data) == entry['bytes'] and sha(data) == entry['sha256'], 'Changed member: ' + name)
    authority = json.loads((docs / 'SOURCE_AUTHORITY.json').read_text())
    require(authority['base'] == BASE and authority['tree'] == '471d1ba11037617f2cadf14826bf5013d508b8ee', 'Wrong base')
    for item in authority['canonical_inputs']:
        data = (docs / 'base' / item['path']).read_bytes()
        require(blob(data) == item['git_blob'] and sha(data) == item['sha256'] and len(data) == item['bytes'], 'Canonical source mismatch')
    require(authority['kit']['commit'] == '19d1b35397af4f10ae70cfb3f444c9de87383b53', 'Original Kit pin changed')
    for item in authority['kit']['files']:
        data = (docs / item['path']).read_bytes()
        require(blob(data) == item['git_blob'] and sha(data) == item['sha256'], 'Original Kit source changed')
    inverses = json.loads((docs / 'SOURCE_INVERSE.json').read_text())
    require({entry['path'] for entry in inverses} == {WORKSPACE, HOST, 'Maktabah.xcodeproj/project.pbxproj'}, 'Original changed-path scope')
    for entry in inverses:
        data = (root / entry['path']).read_bytes()
        require(sha(data) == entry['candidate_sha256'], 'Inverse input changed')
        lines = data.decode().splitlines(True)
        for delta in reversed(entry['inverse']):
            start, end = delta['start_line'], delta['end_line']
            require(lines[start:end] == delta['after'], 'Inverse range mismatch')
            lines[start:end] = delta['before']
        original = ''.join(lines).encode()
        require(original == (docs / 'base' / entry['path']).read_bytes() and sha(original) == entry['base_sha256'], 'Whole inverse mismatch')
    spec = importlib.util.spec_from_file_location('sheet_driver', root / 'tools/hq-native-study-sheet-lifecycle.py')
    driver = importlib.util.module_from_spec(spec); spec.loader.exec_module(driver)
    old, current = (docs / 'base' / WORKSPACE).read_text(), (root / WORKSPACE).read_text()
    unchanged = ['    private var readerHeaderTitle:', '    private var readerHeaderSubtitle:', '    private var selectedTOCNode:',
                 '    private var readerSurface:', '    private var floatingWorkspace:', '    private func panelResizeHandle(',
                 '    private var compactStudyPanel:', '    private func attachNativeNoteEditor(', '    private func presentContents(',
                 '    private func closeContents(', '    private func selectTOCNode(', '    private func toggleStudyPanel(',
                 '    private func compactPanelDidDismiss(', '    private func addNote(', '    private func openNote(',
                 '    private func deleteNote(', '    private func finishEditingAnnotation(', 'final class StudyContentFloatingPanelLayout:']
    for signature in unchanged:
        require(driver.method(old, signature) == driver.method(current, signature), 'Original behavior body changed: ' + signature)
    annotation = driver.method(current, '    private var annotationEditor:')
    debug = '''                    #if DEBUG
                    if textView == nil || (nativeNoteEditorPresentationID == presentationID && editingAnnotation != nil) {
                        nativeStudyAcceptance.observeNote(textView, presentationID: presentationID)
                    }
                    #endif
'''
    require(annotation.count(debug) == 1 and annotation.replace(debug, '') == driver.method(old, '    private var annotationEditor:'), 'Original editor/callback body changed')
    native_policy = driver.method(current, '    private var usesNativeStudySheet:')
    require('guard ChavrusaTextReaderUI.isEnabled else { return false }' in native_policy and
            'if #available(iOS 27.0, *)' in native_policy and 'return MaktabahApp.isIpad' in native_policy, 'Fallback eligibility changed')
    presenter = (root / PRESENTER).read_text()
    require(presenter.count('.presentationDetents([Self.peek, .medium, .large], selection: $detent)') == 1, 'Three system detents changed')
    require('.presentationPlacement(layoutDirection == .rightToLeft ? .leading : .trailing)' in presenter, 'Physical-right policy changed')
    require('.interactiveDismissDisabled(noteIsPresented)' in presenter, 'Note background protection missing')
    require('-NativeStudySheetAcceptanceEnabled' in presenter and 'OtzariaDataProfileRegistry.activeProfileID == "miniTest10"' in presenter and 'UUID(uuidString: raw)' in presenter, 'DEBUG input admission missing')
    require('NativeSurfaceWitness' not in presenter.split('final class NativeStudySheetAcceptance {', 1)[1], 'Observer may not produce Native ACK')
    project = json.loads((docs / 'PROJECT_MEMBERSHIP.json').read_text())
    pbx = (root / 'Maktabah.xcodeproj/project.pbxproj').read_text()
    require(blob(pbx.encode()) == project['candidate_git_blob'], 'Project blob mismatch')
    inverse = pbx
    for line in project['added_lines']:
        require(inverse.count(line) == 1, 'Ambiguous new membership line')
        inverse = inverse.replace(line, '')
    require(inverse.encode() == (docs / 'base/Maktabah.xcodeproj/project.pbxproj').read_bytes(), 'Project four-line inverse changed')
    require('F30576DD2FA46222005732C6 /* Maktabah-iOS */ = {' in pbx and
            'F30576E22FA46222005732C6 /* Sources */,' in pbx, 'Original app target membership missing')
    metadata = json.loads((docs / 'NATIVE_CASES.json').read_text())
    names = []; class_name = None
    for line in (root / TEST).read_text().splitlines():
        match = re.match(r'final class (\w+):', line)
        if match: class_name = match[1]
        match = re.match(r'    func (test\w+)\(', line)
        if match: names.append(class_name + '/' + match[1])
    require(len(names) == 12 and len(set(names)) == 12 and names == [row['case_id'] for row in metadata['new_cases']], 'New Native declaration mismatch')
    require(all(row['timeout_seconds'] == 600 and row['status'] == 'NOT_RUN' for row in metadata['new_cases']), 'Native status/budget changed')
    original = (docs / 'base/docs/hq-integration/runtime27/R27_CASES.json').read_bytes()
    require(sha(original) == metadata['preserved_original_manifest_sha256'] and len(json.loads(original)['execution_case_ids']) == 116, 'Original Native116 changed')
    require(len(driver.case_ids((root / driver.FIXTURES / 'NativeStudySheetLifecycleAcceptance.swift').read_text())) == 20, 'Lifecycle declarations changed')
    require(len(driver.case_ids((root / driver.FIXTURES / 'NativeStudySheetOwnerAcceptance.swift').read_text())) == 5, 'Owner declarations changed')
    return {'qualified_source_only': True, 'manifested_files': len(paths), 'canonical_M40_inputs': len(authority['canonical_inputs']),
            'Kit_files': len(authority['kit']['files']), 'unchanged_original_bodies': len(unchanged) + 1,
            'declared_Foundation': 25, 'declared_new_Native': 12, 'Swift_executed': 0, 'Native_executed': 0}

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--run-python-controls', action='store_true'); args = parser.parse_args()
    root = args.root.resolve(); result = verify(root)
    if args.run_python_controls:
        proc = subprocess.run([sys.executable, str(root / 'Tests/HQ/native-study-sheet/test_native_study_sheet_contract.py')])
        require(proc.returncode == 0, 'Python control failure')
        result['Python_controls'] = 15
    print(json.dumps(result, sort_keys=True))
if __name__ == '__main__': main()
