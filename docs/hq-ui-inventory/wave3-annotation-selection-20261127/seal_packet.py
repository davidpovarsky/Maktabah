from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent
BASE = '37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be'
DOCS = 'docs/hq-ui-inventory/wave3-annotation-selection-20261127'
OUT = ROOT / 'packet' / DOCS
OUT.mkdir(parents=True, exist_ok=False)

def digest(raw): return hashlib.sha256(raw).hexdigest()
def copy(src, dst):
    p = OUT / dst
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes((ROOT / src).read_bytes())

inputs = json.loads((ROOT / 'SOURCE_INPUTS.json').read_text())
assert inputs['base'] == BASE and len(inputs['files']) == 16
for row in inputs['files']:
    raw = (ROOT / 'source' / row['path']).read_bytes()
    assert len(raw) == row['bytes'] and digest(raw) == row['sha256']
    copy('source/' + row['path'], 'original-source/' + row['path'])

original = json.loads((ROOT / 'FINAL_ORIGINAL_HOOKS.json').read_text())
assert len(original['files']) == 4 and len(original['edits']) == 47
for row in original['files']:
    raw = (ROOT / 'candidate' / row['path']).read_bytes()
    assert digest(raw) == row['after_sha256'] and row['byte_exact_inverse']

shared = json.loads((ROOT / 'proposal/shared/EXACT_SHARED_EDITS.json').read_text())
assert len(shared['files']) == 3 and len(shared['edits']) == 37
for row in shared['files']:
    p = row['path']
    before = (ROOT / 'proposal/shared/baseline' / p).read_bytes()
    after = (ROOT / 'proposal/shared/candidate' / p).read_bytes()
    assert digest(before) == row['before_sha256'] and digest(after) == row['after_sha256']
    current = before.decode()
    for edit in shared['edits']:
        if edit['path'] == p:
            assert current.count(edit['before']) == edit['occurrences']
            current = current.replace(edit['before'], edit['after'])
    assert current.encode() == after
    for edit in reversed(shared['edits']):
        if edit['path'] == p:
            assert current.count(edit['after']) == edit['occurrences']
            current = current.replace(edit['after'], edit['before'])
    assert current.encode() == before

raw_archives = []
for relative, expected, count in [
    ('evidence/raw-controls/RAW.zip', '02f822be00dba2a820b9c0c3132b08d456347a24ed323cfdffeee9e615c93a9b', 34),
    ('evidence/modal-controls/RAW.zip', '69d2ad00bb15095099cd1a41fc514418d99d515b6bc3538ca5a7a66d5793866f', 18),
]:
    raw = (ROOT / relative).read_bytes()
    assert digest(raw) == expected
    with zipfile.ZipFile(ROOT / relative) as z:
        manifest = json.loads(z.read('RAW_MANIFEST.json'))
        assert len(manifest) == count
        assert set(z.namelist()) == {x['path'] for x in manifest} | {'RAW_MANIFEST.json'}
        assert len(z.namelist()) == count + 1
        for row in manifest:
            data = z.read(row['path'])
            assert len(data) == row['bytes'] and digest(data) == row['sha256']
    raw_archives.append({'path': relative, 'bytes': len(raw), 'sha256': digest(raw),
                         'verified_raw_files': count, 'verified_members': count + 1})

counts = [
    ('evidence/raw-controls/files/attempt-1/service-controls.stdout', 11, 0),
    ('evidence/raw-controls/files/attempt-2/publication-controls.stdout', 10, 0),
    ('evidence/raw-controls/files/attempt-3/actual-owner-controls.stdout', 24, 0),
    ('evidence/modal-controls/files/attempt-5/actual-modal-controls.stdout', 24, 0),
    ('evidence/modal-controls/files/attempt-5/old-caller-annotations-aba.stdout', 0, 2),
]
for name, passed, failed in counts:
    s = (ROOT / name).read_text()
    if s.lstrip().startswith('{'):
        value = json.loads(s)
        assert value['passed'] == passed and value['failed'] == failed
        assert len([x for x in value['cases'] if x['pass'] is True]) == passed
        assert len([x for x in value['cases'] if x['pass'] is False]) == failed
    else:
        assert len([x for x in s.splitlines() if x.startswith('PASS ')]) == passed
        assert len([x for x in s.splitlines() if x.startswith('FAIL ')]) == failed

for p in sorted((ROOT / 'candidate').rglob('*.swift')):
    target = ROOT / 'packet' / p.relative_to(ROOT / 'candidate')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(p.read_bytes())
product = [{'path': str(p.relative_to(ROOT / 'candidate')), 'bytes': p.stat().st_size,
            'sha256': digest(p.read_bytes())} for p in sorted((ROOT / 'candidate').rglob('*.swift'))]
assert len(product) == 8

for src, dst in [
    ('README.delivery.md', 'README.md'), ('CONTRACT_PROPOSAL.md', 'CONTRACT_PROPOSAL.md'),
    ('SOURCE_INPUTS.json', 'SOURCE_INPUTS.json'), ('EXACT_ORIGINAL_HOOKS.json', 'preserved/INITIAL_ORIGINAL_HOOKS.json'),
    ('FINAL_ORIGINAL_HOOKS.json', 'FINAL_ORIGINAL_HOOKS.json'), ('ORIGINAL_INVERSE.json', 'ORIGINAL_INVERSE.json'),
    ('FINAL_ORIGINAL.patch', 'FINAL_ORIGINAL.patch'), ('prepare_original_hooks.py', 'prepare_original_hooks.py'),
    ('prepare_shared_proposal.py', 'prepare_shared_proposal.py'),
]: copy(src, dst)
for directory in ['controls', 'evidence', 'proposal']:
    for p in sorted((ROOT / directory).rglob('*')):
        if p.is_file() and '__pycache__' not in p.parts:
            copy(str(p.relative_to(ROOT)), str(p.relative_to(ROOT)))

membership = {
    'integration_ios_only': [x['path'] for x in product if '/Integration/' in x['path']],
    'host_package_ordinary_source_discovery': [x['path'] for x in product if '/Sources/ChavrusaUIRoutingHost/' in x['path']],
    'manual_pbx_applied': False,
    'new_shortcut_provider_entries': 0,
    'existing_ten_shortcuts_preserved': True,
    'apple_metadata_discovery_and_typecheck': 'NOT_RUN',
    'localization_proposals': [
        {'key': 'Annotation record', 'en': 'Annotation record', 'he': 'רשומת הערה'},
        {'key': 'Show an annotation', 'en': 'Show an annotation', 'he': 'הצגת הערה'},
        {'key': 'Annotations window', 'en': 'Annotations window', 'he': 'חלון הערות'},
        {'key': 'Select an existing annotation in its original list.',
         'en': 'Select an existing annotation in its original list.', 'he': 'בחירת הערה קיימת ברשימה המקורית שלה.'},
    ],
    'root_owned_shared_dependencies': {
        'closed_publication_source_sha256': '24ff00ddfc80351456bda7270ecb7a5bb48e2029fa9991721e3aa1d8d3a35e3f',
        'shared_edit_count': 37,
        'private_destination': 'native.annotations.record',
        'new_public_codec_or_url_fields': False,
        'rn_join': 'Separate RN_ANNOTATION_FACET follow-up; register original publication before getter',
    },
}
(OUT / 'MEMBERSHIP_AND_LOCALIZATION.json').write_text(json.dumps(membership, ensure_ascii=False, indent=2) + '\n')
proof = {
    'schema': 'otzaria.original-annotations.selected-record-source.v1', 'base': BASE,
    'base_source_tree': '7afa76212dec72644917e6aaff3257ca56a14ccf', 'product': product,
    'original_source_inputs': inputs['files'], 'original_edits': 47, 'original_inverse': True,
    'root_only_shared_hunks': 37, 'root_only_shared_files': shared['files'],
    'source_controls': {'portable_service': {'passed': 11, 'failed': 0},
        'publication': {'passed': 10, 'failed': 0}, 'owner': {'passed': 24, 'failed': 0},
        'modal_and_actual_history_caller': {'passed': 24, 'failed': 0},
        'historical_caller_new_facet_counterexample': {'passed': 0, 'failed': 2, 'expected': True}},
    'native': 'NOT_RUN', 'apple_sdk_typecheck': 'NOT_RUN', 'raw_archives': raw_archives,
    'preserved_failures': ['nested Witness actor isolation', 'class instead of original struct fixture',
                           'oversized local transport rejected before host dispatch'],
    'remaining': ['native original row acceptance', 'editor body/tags/style and allowsPlainEditing',
        'actual filter/tag/group/sort control reveal', 'record to original editor', 'original Reader book list',
        'cold or foreign-root record entry', 'production v40/full Native116/Release114+2/physical qualification'],
}
(OUT / 'SOURCE_PACKET.json').write_text(json.dumps(proof, indent=2) + '\n')
shutil.copyfile(__file__, OUT / 'seal_packet.py')
manifest = [{'path': str(p.relative_to(OUT)), 'bytes': p.stat().st_size, 'sha256': digest(p.read_bytes())}
            for p in sorted(OUT.rglob('*')) if p.is_file()]
(OUT / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
files = [{'path': str(p.relative_to(ROOT / 'packet')), 'bytes': p.stat().st_size, 'sha256': digest(p.read_bytes())}
         for p in sorted((ROOT / 'packet').rglob('*')) if p.is_file()]
payload = ROOT / 'PUBLICATION_PAYLOAD.zip'
with zipfile.ZipFile(payload, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for row in files: z.write(ROOT / 'packet' / row['path'], row['path'])
publication = {'base': BASE, 'branch': 'codex/otzaria-wave3-annotation-selection-20261127',
    'docs': DOCS, 'source_files': product, 'files': files,
    'zip_bytes': payload.stat().st_size, 'zip_sha256': digest(payload.read_bytes())}
(ROOT / 'PUBLICATION_INPUTS.json').write_text(json.dumps(publication, indent=2) + '\n')
print(json.dumps({'docs_files': len(manifest) + 1, 'all_paths': len(files),
    'zip_bytes': publication['zip_bytes'], 'zip_sha256': publication['zip_sha256'],
    'manifest_sha256': digest((OUT / 'MANIFEST.json').read_bytes())}))
