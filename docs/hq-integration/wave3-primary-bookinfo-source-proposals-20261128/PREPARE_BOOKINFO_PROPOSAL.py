"""Assemble an exact local BookInfo review packet; never apply or qualify it."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parent
WORK = ROOT.parent
SHARED = WORK / 'bookinfo-shared-wiring-proposal'
PRIMARY = WORK / 'primary-shared-integration-implementation'
PBX = 'Maktabah.xcodeproj/project.pbxproj'
CATALOG = 'Source/Localizable.xcstrings'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def save(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.read_bytes() == raw, str(path)
    else:
        path.write_bytes(raw)


def save_json(name, value):
    save(ROOT / name, (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())


ledger_raw = (SHARED / 'EXACT_SHARED_EDITS.json').read_bytes()
assert digest(ledger_raw) == 'b533af94fec04ebe2ffb42789fdd4a86d122e08829c8abe38ca94478b5f3dcfc'
ledger = json.loads(ledger_raw)
assert len(ledger['edits']) == 43
source_rows = []
for record in ledger['files']:
    path = record['path']
    before = (PRIMARY / 'candidate' / path).read_bytes()
    candidate = (SHARED / 'candidate' / path).read_bytes()
    assert (len(before), digest(before)) == (record['before_bytes'], record['before_sha256'])
    assert (len(candidate), digest(candidate)) == (record['after_bytes'], record['after_sha256'])
    selected = [edit for edit in ledger['edits'] if edit['path'] == path]
    replay = before.decode()
    for edit in selected:
        assert replay.count(edit['before']) == edit['occurrences'] == 1
        assert digest(edit['before'].encode()) == edit['before_sha256']
        assert digest(edit['after'].encode()) == edit['after_sha256']
        replay = replay.replace(edit['before'], edit['after'], 1)
    assert replay.encode() == candidate
    for edit in reversed(selected):
        assert replay.count(edit['after']) == 1
        replay = replay.replace(edit['after'], edit['before'], 1)
    assert replay.encode() == before
    save(ROOT / 'baseline' / path, before)
    save(ROOT / 'candidate' / path, candidate)
    source_rows.append({**record, 'source': str(SHARED / 'candidate' / path),
                        'root_exact_forward_and_reverse_replay': True})

dependencies_raw = (SHARED / 'DEPENDENCIES_AND_MEMBERSHIP.json').read_bytes()
assert digest(dependencies_raw) == 'da1ce26b85bd80b4e68739a89498b4a7b8d534651b50381b5d03071327fd9819'
dependencies = json.loads(dependencies_raw)['frozen_prerequisites']
for row in dependencies:
    raw = Path(row['local_path']).read_bytes()
    assert (len(raw), digest(raw)) == (row['bytes'], row['sha256'])
    save(ROOT / 'candidate' / row['repository_path'], raw)
    source_rows.append({'path': row['repository_path'], 'bytes': len(raw), 'sha256': digest(raw),
                        'source': row['local_path'], 'new_file': row['new_file']})

# Add only explicit iOS Integration memberships. SwiftPM Host files stay under
# their established package target; duplicating them in the app target is wrong.
pbx_original = (PRIMARY / 'candidate' / PBX).read_bytes()
assert digest(pbx_original) == 'd28844ac06a705e8de87ea75d0e3c336f698977ff29b752c5b528e65cca6140e'
pbx_text = pbx_original.decode()
members = []
for name in ['MaktabahNativeBookInfoSetterPublication.swift',
             'MaktabahNativeBookInfoPresentation.swift',
             'MaktabahNativeBookInfoSheet.swift']:
    assert name not in pbx_text
    build = digest(('otzaria-wave3-bookinfo-build:' + name).encode())[:24].upper()
    reference = digest(('otzaria-wave3-bookinfo-ref:' + name).encode())[:24].upper()
    assert build not in pbx_text and reference not in pbx_text
    members.append({'name': name, 'buildID': build, 'fileReferenceID': reference})
anchor_name = 'MaktabahNativeAnnotationEditorControls.swift'
anchor_build = '391EA830625F5FB1A8E1A6BE'
anchor_ref = '19CC9E671ADE09B048FC6B1E'
anchors = {
    'build': f'\t\t{anchor_build} /* {anchor_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {anchor_ref} /* {anchor_name} */; }};\n',
    'reference': f'\t\t{anchor_ref} /* {anchor_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "UIRoutingHost/Integration/{anchor_name}"; sourceTree = "<group>"; }};\n',
    'group': f'\t\t\t\t{anchor_ref} /* {anchor_name} */,\n',
    'source': f'\t\t\t\t{anchor_build} /* {anchor_name} in Sources */,\n',
}
blocks = {kind: '' for kind in anchors}
for row in members:
    name, build, reference = row['name'], row['buildID'], row['fileReferenceID']
    blocks['build'] += f'\t\t{build} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {reference} /* {name} */; }};\n'
    blocks['reference'] += f'\t\t{reference} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "UIRoutingHost/Integration/{name}"; sourceTree = "<group>"; }};\n'
    blocks['group'] += f'\t\t\t\t{reference} /* {name} */,\n'
    blocks['source'] += f'\t\t\t\t{build} /* {name} in Sources */,\n'
metadata_edits = []
for kind, anchor in anchors.items():
    assert pbx_text.count(anchor) == 1
    addition = anchor + blocks[kind]
    pbx_text = pbx_text.replace(anchor, addition, 1)
    metadata_edits.append({'path': PBX, 'kind': kind, 'before': anchor, 'after': addition})
for row in members:
    assert pbx_text.count(row['buildID']) == 2
    assert pbx_text.count(row['fileReferenceID']) == 3

catalog_original = (PRIMARY / 'candidate' / CATALOG).read_bytes()
assert digest(catalog_original) == '2e6e0e9a906fb4d8cdc6edcde7703b34c899a250afe0f0e81baff16f51168e6f'
catalog = json.loads(catalog_original)
strings = {
    'Open book information': 'פתיחת פרטי ספר',
    'Show the original information sheet for a book in the Library.': 'הצגת חלון המידע המקורי של ספר בספרייה.',
}
assert all(key not in catalog['strings'] for key in strings)
for key, hebrew in [('Book', 'ספר'), ('Library window', 'חלון הספרייה')]:
    locales = catalog['strings'][key]['localizations']
    assert locales['en']['stringUnit']['value'] == key
    assert locales['he']['stringUnit']['value'] == hebrew
entries = {key: {'localizations': {
    language: {'stringUnit': {'state': 'translated', 'value': value}}
    for language, value in [('en', key), ('he', hebrew)]}}
    for key, hebrew in strings.items()}
block = json.dumps(entries, ensure_ascii=False, indent=2)[2:-2]
block = '\n'.join('  ' + line for line in block.splitlines()) + ',\n'
anchor = '  "strings": {\n'
addition = anchor + block
catalog_text = catalog_original.decode()
assert catalog_text.count(anchor) == 1
catalog_text = catalog_text.replace(anchor, addition, 1)
parsed = json.loads(catalog_text)
assert len(parsed['strings']) == len(catalog['strings']) + 2
assert all(parsed['strings'][key] == value for key, value in catalog['strings'].items())
metadata_edits.append({'path': CATALOG, 'kind': 'two additive EN/HE keys', 'before': anchor, 'after': addition})

metadata_rows = []
for path, original, final_text in [(PBX, pbx_original, pbx_text), (CATALOG, catalog_original, catalog_text)]:
    inverse = final_text
    for edit in reversed([edit for edit in metadata_edits if edit['path'] == path]):
        assert inverse.count(edit['after']) == 1
        inverse = inverse.replace(edit['after'], edit['before'], 1)
    assert inverse.encode() == original
    raw = final_text.encode()
    save(ROOT / 'baseline' / path, original)
    save(ROOT / 'candidate' / path, raw)
    patch = ''.join(difflib.unified_diff(original.decode().splitlines(True), final_text.splitlines(True),
                                       fromfile='a/' + path, tofile='b/' + path))
    save(ROOT / 'diffs' / (Path(path).name + '.patch'), patch.encode())
    metadata_rows.append({'path': path, 'before_bytes': len(original), 'before_sha256': digest(original),
                          'after_bytes': len(raw), 'after_sha256': digest(raw), 'exact_inverse': True})

save_json('METADATA_EDITS.json', {'status': 'LOCAL_SOURCE_PROPOSAL_NOT_APPLIED_NOT_COMPILED',
          'memberships': members, 'new_EN_HE_keys': strings, 'reused_existing_keys': ['Book', 'Library window'],
          'files': metadata_rows, 'edits': metadata_edits,
          'package_membership': 'Two Host files remain in the original SwiftPM target directory; Apple discovery is unrun.',
          'native_runs': 0, 'compiler_invocations': 0, 'remote_actions': 0})
review = {
    'status': 'ROOT_INDEPENDENT_SOURCE_REVIEW_NO_DEMONSTRATED_BLOCKER_IN_REVIEWED_SCOPE',
    'source_preparation_only': True,
    'shared_ledger_sha256': digest(ledger_raw),
    'root_read_scope': [
        'All43 exact shared edits; final41+42 completion body read together, not superseded36.',
        'Session typed retained original-window source and final Notes/Workspace/owner identity fence.',
        'Original sheet setter/child/Library coverage ordering and same actual owner lifetime.',
        'Actual Root NativeBookInfoIntentService body b04198dd and full receipt checks.',
        'Typed AppDependency registration; private descriptor; generic public binder refusal.',
        'All4 complete forward/inverse source replays and10 exact frozen feature dependencies.',
    ],
    'source_conclusions': [
        'Original book row/window/source is retained before first await; no replacement Library lookup after own sheet coverage.',
        'Actual receipt and original request/lease/session/manager/owner/deadline association survive to final service validation.',
        'Completion is consumed before callbacks; final source check follows the final backend getter, then pure identity/deadline.',
        'Navigation failure removes only its own association. Weak per-scene association is bounded and cannot revalidate another receipt.',
        'Three iOS application memberships and two EN/HE keys are additive; all primary metadata bytes and translations survive exact inverse.',
    ],
    'source_files': source_rows,
    'metadata_files': metadata_rows,
    'limits': [
        'No Swift typing, owner/service controls, Apple compilation, AppIntents discovery or native acceptance has run for this combined proposal.',
        'Frozen service cancellation or receipt-shape failure before ValidateCompletion cannot notify this association immediately; weak entry expires and clears on next capture/unmount.',
        'Synchronous Library coverage inside the original setter before return is refused; real UIKit timing is unrun.',
        'Presentation acknowledgement does not establish metadata correctness, all segments, accessibility, restoration, production or Release acceptance.',
        'Original Annotation/Library/Inspector proposals and their capacity-held controls remain separate required prerequisites.',
    ],
    'native_runs': 0, 'compiler_invocations': 0, 'remote_source_mutations': 0,
}
save_json('ROOT_SOURCE_REVIEW.json', review)
print(json.dumps({'status': review['status'], 'shared_edits_replayed': len(ledger['edits']),
                  'feature_dependencies': len(dependencies), 'metadata_files': metadata_rows,
                  'native_runs': 0, 'compiler_invocations': 0}, ensure_ascii=False))
