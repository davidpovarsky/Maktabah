#!/usr/bin/env python3
"""Verify the source packet and existing receipts; does not build or run UI."""
import ast
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

w = Path(sys.argv[1]).resolve()
d = w / 'docs/hq-ui-inventory/wave3-search-parent-focus-20261127'
manifest = json.loads((d / 'SOURCE_INPUTS.json').read_text())
for item in manifest['items']:
    assert hashlib.sha256((w / item['path']).read_bytes()).hexdigest() == item['sha256'], item['path']

base = subprocess.check_output(['git', '-C', str(w), 'show', manifest['base'] + ':Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift'])
actual = (w / 'Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift').read_bytes()
assert len(base) == 187907 and actual.startswith(base)
assert hashlib.sha1(b'blob ' + str(len(base)).encode() + bytes([0]) + base).hexdigest() == '54b4aa02f673921ab7ce83cac9fcd584f98f8acd'


def bodies(text):
    result = {}
    for match in re.finditer(r'        test\("([^"]+)"\) \{', text):
        start, pos, depth = match.start(), match.end(), 1
        while depth:
            if text[pos] == '{':
                depth += 1
            elif text[pos] == '}':
                depth -= 1
            pos += 1
        result[match.group(1)] = text[start:pos]
    return result


old = bodies((d / 'validation/lifecycle-attempt-3/Controls.swift').read_text())
new = bodies((d / 'validation/lifecycle-attempt-6-final-root-callers/Controls.swift').read_text())
assert len(old) == 39 and len(new) == 52, (len(old), len(new))
assert all(new[key] == value for key, value in old.items())
(d / 'validation/ORIGINAL39_PRESERVATION.json').write_text(json.dumps({
    'original': 39, 'final': 52, 'exact_unchanged_original_bodies': sorted(old),
    'added': sorted(set(new) - set(old)),
}, indent=2) + '\n')

main = (w / 'Source/UI/iOS/Views/iOSMainView.swift').read_text()
raw_writes = re.findall(r'(?m)^\s*(?:selectedTab|showSettings)\s*=', main)
assert not raw_writes
assert main.count('$selectedTab') == 1 and main.count('$showSettings') == 1
assert main.count('selectedTab: originalSelectedTab') == 3
assert main.count('originalSelectedTab.wrappedValue =') == 14
assert main.count('originalSettingsPresentation.wrappedValue =') == 2
(d / 'validation/ROOT_CALLERS.json').write_text(json.dumps({
    'source_sha256': hashlib.sha256(main.encode()).hexdigest(),
    'raw_assignment_pattern': r'(?m)^\s*(?:selectedTab|showSettings)\s*=',
    'raw_assignments': raw_writes,
    'original_selectedTab_bindings': 3,
    'original_debug_tab_assignments': 14,
    'original_settings_Done_and_debug_assignments': 2,
    'raw_binding_occurrences': {'selectedTab': 1, 'showSettings': 1},
    'native_runtime_claim': False,
}, indent=2) + '\n')

receipts = []
for name in ['syntax-final.json', 'syntax-final-main-callers.json', 'syntax-final-session.json']:
    value = json.loads((d / 'validation' / name).read_text())
    for item in value.get('items', [value]):
        receipts.append((name, item))
matched = []
for source in manifest['items']:
    values = [(name, item) for name, item in receipts
              if item['path'] == source['path'] and item['sha256'] == source['sha256']]
    assert len(values) == 1 and values[0][1]['exit'] == 0, source['path']
    matched.append({'path': source['path'], 'sha256': source['sha256'], 'receipt': values[0][0]})
(d / 'validation/FINAL_SYNTAX_INPUTS.json').write_text(json.dumps({
    'scope': '12 exact changed Swift files, Linux iOS27 frontend SYNTAX ONLY; no app SDK or native execution',
    'items': matched,
}, indent=2) + '\n')

for path in d.rglob('*.json'):
    json.loads(path.read_text())
for path in d.rglob('*.py'):
    ast.parse(path.read_text())
subprocess.run(['git', '-C', str(w), 'diff', '--check'], check=True)
print(json.dumps({'source_inputs': len(manifest['items']), 'native_prefix_bytes': len(base),
                  'original_controls_unchanged': len(old), 'final_controls': len(new),
                  'syntax_inputs': len(matched), 'raw_original_root_assignments': len(raw_writes)}))
