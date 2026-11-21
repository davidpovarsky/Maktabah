#!/usr/bin/env python3
"""Compile actual Foundation state and exact source-extracted owner callbacks.

No SwiftUI/UIKit/full app/Native proof. Root activates an Apple route separately.
The original owner-close method and complete Workspace methods are copied byte
for byte into explicit property-storage/animation/Reader-data boundaries.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import sys

STATE = 'Source/ChavrusaText/Reader/NativeStudySheetPresenter.swift'
WORKSPACE = 'Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift'
READER = 'Source/Otzaria/Reading/ReaderViewModel+OtzariaLineSources.swift'
FIXTURES = 'Tests/HQ/native-study-sheet'
EXPECTED_RED = {'system_nil_closes_original_owner_before_layout_callback',
                'double_nil_callback_cannot_cancel_explicit_queued_reopen'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def method(text, signature):
    """Extract one complete brace-balanced method/property (no literal rewriting)."""
    if text.count(signature) != 1:
        raise ValueError('signature must be unique: ' + signature)
    start = text.index(signature)
    opening = text.index('{', start)
    depth = 0
    # These exact retained methods have no braces in strings/comments; reject a
    # future input that could make this constrained extraction ambiguous.
    for index in range(opening, len(text)):
        char = text[index]
        if char == '{': depth += 1
        if char == '}':
            depth -= 1
            if depth == 0: return text[start:index + 1]
    raise ValueError('unterminated method: ' + signature)


def materialize(root, output, workspace):
    boundary = (root / FIXTURES / 'NativeStudySheetOwnerBoundary.swift').read_text()
    source = workspace.read_text()
    originals = {
        'ORIGINAL_BINDING_BODY': method(source, '    private var nativeStudyBinding:'),
        'ORIGINAL_UPDATE_BODY': method(source, '    private func updatePanelPresentation('),
        'ORIGINAL_TOGGLE_BODY': method(source, '    private func toggleStudyPanel('),
        'ORIGINAL_DISMISS_BODY': method(source, '    private func nativeStudyDidDismiss('),
        'ORIGINAL_CLOSE_BODY': method((root / READER).read_text(), '    func closeReaderInspector('),
    }
    for name, value in originals.items():
        marker = '    // ' + name
        if boundary.count(marker) != 1: raise ValueError('missing exact marker ' + name)
        boundary = boundary.replace(marker, value)
    output.write_text(boundary)
    return {key: {'sha256': digest(value.encode()), 'bytes': len(value.encode())}
            for key, value in originals.items()}


def run(command, prefix, timeout):
    try:
        result = subprocess.run(command, capture_output=True, timeout=timeout)
        (prefix.with_suffix('.stdout')).write_bytes(result.stdout)
        (prefix.with_suffix('.stderr')).write_bytes(result.stderr)
        return {'argv': command, 'returncode': result.returncode, 'timeout': False}
    except subprocess.TimeoutExpired as error:
        prefix.with_suffix('.stdout').write_bytes(error.stdout or b'')
        prefix.with_suffix('.stderr').write_bytes(error.stderr or b'')
        return {'argv': command, 'returncode': None, 'timeout': True}


def case_ids(source):
    ids = re.findall(r'check\("([a-z0-9_]+)"\)', source)
    if not ids or len(ids) != len(set(ids)): raise ValueError('duplicate/empty declared IDs')
    return ids


def qualify(checks, declared, result, expected_failures):
    if result['timeout'] or result['returncode'] != (1 if expected_failures else 0): return False
    if not isinstance(checks, list) or len(checks) != len(declared): return False
    if [r.get('id') for r in checks] != declared: return False
    if any(type(r.get('passed')) is not bool for r in checks): return False
    return {r['id'] for r in checks if not r['passed']} == expected_failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--before-workspace', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    root, out = args.root.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    required = [STATE, WORKSPACE, READER] + [FIXTURES + '/' + value for value in
        ['NativeStudySheetOwnerBoundary.swift', 'NativeStudySheetOwnerAcceptance.swift', 'NativeStudySheetLifecycleAcceptance.swift']]
    before = {path: digest((root / path).read_bytes()) for path in required}
    before['before_workspace'] = digest(args.before_workspace.read_bytes())
    source_proof = {
        phase: materialize(root, out / (phase + '.swift'), workspace)
        for phase, workspace in [('baseline', args.before_workspace), ('candidate', root / WORKSPACE)]
    }
    (out / 'SOURCES.json').write_text(json.dumps({'inputs': before, 'extracted': source_proof}, indent=2) + '\n')
    if args.prepare_only:
        print(json.dumps({'prepared': True, 'Swift_executed': 0, 'output': str(out)}))
        return 0
    if platform.system() != 'Darwin': raise RuntimeError('Actual Apple Foundation execution requires Darwin; no alternate success path')
    stages, qualified = [], True
    for name, fixture, boundary, expected in [
        ('baseline', 'NativeStudySheetOwnerAcceptance.swift', out / 'baseline.swift', EXPECTED_RED),
        ('candidate', 'NativeStudySheetOwnerAcceptance.swift', out / 'candidate.swift', set()),
        ('lifecycle', 'NativeStudySheetLifecycleAcceptance.swift', None, set()),
    ]:
        fixture = root / FIXTURES / fixture
        declared = case_ids(fixture.read_text())
        executable = out / (name + '-acceptance')
        command = ['xcrun', 'swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-j', '1', '-parse-as-library',
                   str(root / STATE), *([str(boundary)] if boundary else []), str(fixture), '-o', str(executable)]
        compiled = run(command, out / (name + '-compile'), 180)
        record = {'phase': name, 'declared': declared, 'expected_failures': sorted(expected), 'compile': compiled,
                  'executed': 0, 'qualified': False}
        if compiled['returncode'] == 0 and not compiled['timeout']:
            checks_path = out / (name + '-checks.json')
            execution = run([str(executable), str(checks_path)], out / (name + '-runtime'), 30)
            record['runtime'] = execution
            if checks_path.is_file():
                checks = json.loads(checks_path.read_text())
                record['checks'] = checks
                record['executed'] = len(checks) if isinstance(checks, list) else 0
                record['qualified'] = qualify(checks, declared, execution, expected)
        qualified = qualified and record['qualified']
        stages.append(record)
    after = {path: digest((root / path).read_bytes()) for path in required}
    after['before_workspace'] = digest(args.before_workspace.read_bytes())
    result = {'schema': 1, 'qualified': qualified and before == after, 'before': before, 'after': after,
              'stages': stages, 'scope': 'Actual Foundation state and extracted owner callbacks; SwiftUI/UIKit/Native NOT_RUN'}
    (out / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'qualified': result['qualified'], 'executed': [s['executed'] for s in stages]}))
    return 0 if result['qualified'] else 1


if __name__ == '__main__':
    sys.exit(main())
