"""Prepare only the source-qualified Annotation opening intake; no remote mutation."""
from pathlib import Path
import hashlib
import json
import zipfile

HERE = Path(__file__).resolve().parent
WORK = HERE.parent
LANE = WORK / 'annotations-editor-opening-implementation'
BASE = 'ffa47784063bfda88b5d3c083d1a32bcacd14041'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def save(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.read_bytes() == raw
    else:
        path.write_bytes(raw)


handoff = json.loads((LANE / 'FINAL_INTAKE.json').read_bytes())
assert sha((LANE / 'FINAL_INTAKE.json').read_bytes()) == '607accf1b8926800bf83ad46b5ada9e24fb926050aafddb7088317f205148a1a'
assert handoff['actual']['owner'] == {'passed': 34, 'failed': 0}
assert handoff['actual']['service'] == {'passed': 14, 'failed': 0}
ledger_raw = (LANE / 'proposal/SHARED_EDITS.json').read_bytes()
assert sha(ledger_raw) == '35b7ef090b517ce5397a63f19a16dfee6e07926371dd829636af830254510a39'
ledger = json.loads(ledger_raw)
assert len(ledger['edits']) == 40
archive_path = WORK / 'source-proposal-checkpoint-20261128/PROPOSALS.zip'
assert sha(archive_path.read_bytes()) == 'df641fafd9b470eaa22307025fff8599f6c60cc18196c6aed1d900adb43c94eb'
archive = zipfile.ZipFile(archive_path)
archive_manifest = json.loads(archive.read('MANIFEST.json'))
index = {row['path']: row for row in archive_manifest['files']}
products = []
for row in handoff['owned_source']:
    rel = row['path']
    raw = (LANE / 'candidate' / rel).read_bytes()
    assert {'bytes': len(raw), 'sha256': sha(raw)} == row['after']
    key = 'annotations-editor-opening-implementation/candidate/' + rel
    assert index[key]['sha256'] == sha(raw) and archive.read('blobs/' + sha(raw)) == raw
    before = None if row['before'] is None else (LANE / 'baseline' / rel).read_bytes()
    assert before is None or {'bytes': len(before), 'sha256': sha(before)} == row['before']
    products.append({'path': rel, 'before': row['before'], 'after': row['after'], 'archiveKey': key})
    save(HERE / 'candidate' / rel, raw)
for row in handoff['shared']['files']:
    rel = row['path']
    before = (LANE / 'proposal/baseline' / rel).read_bytes()
    raw = (LANE / 'proposal/candidate' / rel).read_bytes()
    assert sha(before) == row['before_sha256'] and sha(raw) == row['after_sha256']
    text = before.decode()
    edits = [edit for edit in ledger['edits'] if edit['path'] == rel]
    for edit in edits:
        assert text.count(edit['before']) == edit['occurrences'] == 1
        text = text.replace(edit['before'], edit['after'], 1)
    assert text.encode() == raw
    for edit in reversed(edits):
        assert text.count(edit['after']) == 1
        text = text.replace(edit['after'], edit['before'], 1)
    assert text.encode() == before
    key = 'annotations-editor-opening-implementation/proposal/candidate/' + rel
    assert index[key]['sha256'] == sha(raw) and archive.read('blobs/' + sha(raw)) == raw
    products.append({'path': rel, 'before': {'bytes': len(before), 'sha256': sha(before)},
                     'after': {'bytes': len(raw), 'sha256': sha(raw)}, 'archiveKey': key})
    save(HERE / 'candidate' / rel, raw)

pbx_path = 'Maktabah.xcodeproj/project.pbxproj'
original = (WORK / 'primary-shared-integration-implementation/baseline' / pbx_path).read_bytes()
assert sha(original) == '32e0a629c5ecdb68317f0bc65baec850a51622fc80886d9316b24a27080874ad'
text = original.decode()
name = 'MaktabahNativeAnnotationEditorOpening.swift'
build = sha(('otzaria-wave3-primary-build:' + name).encode())[:24].upper()
ref = sha(('otzaria-wave3-primary-ref:' + name).encode())[:24].upper()
assert name not in text and build not in text and ref not in text
anchor_name = 'MaktabahNativeAnnotationEditorControls.swift'
anchor_build = '391EA830625F5FB1A8E1A6BE'
anchor_ref = '19CC9E671ADE09B048FC6B1E'
pieces = [
    (f'\t\t{anchor_build} /* {anchor_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {anchor_ref} /* {anchor_name} */; }};\n',
     f'\t\t{build} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n'),
    (f'\t\t{anchor_ref} /* {anchor_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "UIRoutingHost/Integration/{anchor_name}"; sourceTree = "<group>"; }};\n',
     f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "UIRoutingHost/Integration/{name}"; sourceTree = "<group>"; }};\n'),
    (f'\t\t\t\t{anchor_ref} /* {anchor_name} */,\n', f'\t\t\t\t{ref} /* {name} */,\n'),
    (f'\t\t\t\t{anchor_build} /* {anchor_name} in Sources */,\n', f'\t\t\t\t{build} /* {name} in Sources */,\n'),
]
metadata_edits = []
for before, addition in pieces:
    assert text.count(before) == 1
    after = before + addition
    text = text.replace(before, after, 1)
    metadata_edits.append({'path': pbx_path, 'before': before, 'after': after})
assert text.count(build) == 2 and text.count(ref) == 3
inverse = text
for edit in reversed(metadata_edits):
    assert inverse.count(edit['after']) == 1
    inverse = inverse.replace(edit['after'], edit['before'], 1)
assert inverse.encode() == original
save(HERE / 'candidate' / pbx_path, text.encode())
products.append({'path': pbx_path, 'before': {'bytes': len(original), 'sha256': sha(original)},
                 'after': {'bytes': len(text.encode()), 'sha256': sha(text.encode())}, 'metadata': True})

catalog_path = 'Source/Localizable.xcstrings'
original = (WORK / 'primary-shared-integration-implementation/baseline' / catalog_path).read_bytes()
assert sha(original) == '6ae875fa45ca7a70b27e7f6c50f54f12192ba635bf7e0947524b69087fe48547'
catalog = json.loads(original)
strings = {'Open annotation editor': 'פתיחת עורך ההערות',
           'Open an existing annotation in its original editor.': 'פתיחת הערה קיימת בעורך המקורי שלה.'}
assert all(key not in catalog['strings'] for key in strings)
entries = {key: {'localizations': {lang: {'stringUnit': {'state': 'translated', 'value': value}}
                                 for lang, value in [('en', key), ('he', he)]}} for key, he in strings.items()}
block = json.dumps(entries, ensure_ascii=False, indent=2)[2:-2]
block = '\n'.join('  ' + line for line in block.splitlines()) + ',\n'
before = '  "strings": {\n'
after = before + block
assert original.decode().count(before) == 1
text = original.decode().replace(before, after, 1)
parsed = json.loads(text)
assert len(parsed['strings']) == len(catalog['strings']) + 2
assert all(parsed['strings'][key] == value for key, value in catalog['strings'].items())
assert text.replace(after, before, 1).encode() == original
metadata_edits.append({'path': catalog_path, 'before': before, 'after': after})
save(HERE / 'candidate' / catalog_path, text.encode())
products.append({'path': catalog_path, 'before': {'bytes': len(original), 'sha256': sha(original)},
                 'after': {'bytes': len(text.encode()), 'sha256': sha(text.encode())}, 'metadata': True})
assert len(products) == len({p['path'] for p in products}) == 14
plan = {'schema': 'otzaria.annotation-opening.selective-intake-plan/1', 'base': BASE,
        'sourceBefore': 'c62aa1a24c1a10fb5129c25d6869faa00c9a3dfb',
        'vendorBefore': '2fb868bdbe5d2d52735e857a24933918ff658cef',
        'files': products, 'metadataEdits': metadata_edits,
        'sharedHunks': 40, 'appMemberships': [{'name': name, 'buildID': build, 'fileReferenceID': ref}],
        'localizedKeys': strings, 'hostSources': 'Original Host package target auto-discovery; no duplicate app membership.',
        'existingShortcuts': 'Ten unchanged; no registration edited.',
        'evidence': {'resultSHA256': '7c22bf9bb0b4cbc92b6b88db57376ff6a398a7b5c2afa9b7d10df18ad5a4228b',
                     'rawSHA256': 'dee386e151bfc956c6b63a7bd6e210cd5e4bba5797aafd62c530be6694e443d7',
                     'ownerPassed': 34, 'servicePassed': 14, 'expectedNegativeVariants': 3, 'fullFileSyntax': 24},
        'remaining': ['Apple SDK typechecking', 'real UIKit lifecycle and geometry', 'production database persistence',
                      'system App Intents delivery', 'Native116', 'Release114+2', 'genuine final owner gate', 'physical hardware QA'],
        'selectiveIntakeOnly': True, 'labBranchesMerged': 0}
raw = (json.dumps(plan, ensure_ascii=False, indent=2) + '\n').encode()
save(HERE / 'INTAKE_PLAN.json', raw)
print(json.dumps({'path': str(HERE / 'INTAKE_PLAN.json'), 'bytes': len(raw), 'sha256': sha(raw),
                  'sourceFiles': 12, 'metadataFiles': 2, 'metadata': [p for p in products if p.get('metadata')]}))
