"""Preserve source proposals, their baselines and actual prior evidence as bytes."""
from pathlib import Path
import hashlib
import json
import stat
import zipfile

ROOT = Path(__file__).resolve().parent
WORK = ROOT.parent
SCOPES = [
    'primary-shared-integration-implementation',
    'annotations-editor-opening-implementation',
    'library-selection-implementation',
    'inspector-selection-implementation',
    'bookinfo-presentation-implementation',
    'bookinfo-setter-publication-implementation',
    'bookinfo-library-source-implementation',
    'bookinfo-service-controls-implementation',
    'bookinfo-native-acceptance',
    'bookinfo-shared-wiring-proposal',
    'bookinfo-root-integration-implementation',
]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


rows, blobs, omitted_bytecode = [], {}, []
for scope in SCOPES:
    directory = WORK / scope
    assert directory.is_dir() and not directory.is_symlink()
    for path in sorted(directory.rglob('*')):
        relative = path.relative_to(WORK).as_posix()
        info = path.lstat()
        assert not stat.S_ISLNK(info.st_mode), relative
        if stat.S_ISDIR(info.st_mode):
            continue
        assert stat.S_ISREG(info.st_mode), relative
        if '__pycache__' in path.parts:
            omitted_bytecode.append(relative)
            continue
        assert info.st_size <= 8 * 1024 * 1024
        raw = path.read_bytes()
        after = path.lstat()
        assert (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns) == (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        digest = sha(raw)
        if digest in blobs:
            assert blobs[digest] == raw
        else:
            blobs[digest] = raw
        rows.append({'path': relative, 'bytes': len(raw), 'sha256': digest, 'mode': stat.S_IMODE(info.st_mode)})

assert len(rows) < 1200
assert sum(len(raw) for raw in blobs.values()) < 40 * 1024 * 1024
manifest = {
    'schema': 'otzaria.unqualified-source-proposal-checkpoint/1',
    'status': 'SOURCE_PREPARATION_AND_EXISTING_EVIDENCE_ONLY_NOT_PRODUCT_INTAKE',
    'integration_base': '40b558c03f26d4f4919f2de2d1c7b27e856fcdbf',
    'source_tree': 'c62aa1a24c1a10fb5129c25d6869faa00c9a3dfb',
    'vendor_tree': '2fb868bdbe5d2d52735e857a24933918ff658cef',
    'format': 'Every manifest row resolves to the exact bytes of blobs/<sha256> in PROPOSALS.zip. Repeated source copies share the same immutable blob.',
    'scopes': SCOPES,
    'files': rows,
    'file_count': len(rows),
    'logical_bytes': sum(row['bytes'] for row in rows),
    'unique_blobs': len(blobs),
    'unique_bytes': sum(len(raw) for raw in blobs.values()),
    'excluded_generated_python_bytecode': omitted_bytecode,
    'archive_scope': 'Regular file contents and executable modes; this code checkpoint does not promise filesystem timestamps or directory metadata restoration.',
    'current_gates': {
        'source_preparation_does_not_admit_product': True,
        'Annotation_owner_controls': 'Not executed; unchanged capacity admission refused before compile.',
        'Library_owner_controls': 'First wrapper compile failed; exact correction remains unrun. Existing19 service cases retain their original scope.',
        'Inspector_app_controls': 'First source wrapper compile failed; corrected candidate52 and baseline52 unrun. Existing Kit28/service23 retain their scope.',
        'BookInfo_owner_setter_service_shared_controls': 'Prepared/unrun; actual original module and capacity joins remain required.',
        'Apple_SDK_and_native': 'No new run for these proposals. Historical Native11682/34 is not final acceptance.',
        'Release_production_owner_signatures_TestFlight_physical': 'OPEN',
    },
}
manifest_raw = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
archive = ROOT / 'PROPOSALS.zip'
assert not archive.exists()
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for name, raw in [('MANIFEST.json', manifest_raw)] + [('blobs/' + key, raw) for key, raw in sorted(blobs.items())]:
        item = zipfile.ZipInfo(name, (2026, 11, 28, 0, 0, 0))
        item.create_system = 3
        item.external_attr = (stat.S_IFREG | 0o644) << 16
        item.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(item, raw, compresslevel=9)

# Reopen the actual archive and check every mapped source copy, including failed
# prior evidence. Recheck original local files; no source is changed here.
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist()) == {'MANIFEST.json'} | {'blobs/' + key for key in blobs}
    assert z.read('MANIFEST.json') == manifest_raw
    for row in rows:
        raw = z.read('blobs/' + row['sha256'])
        assert (len(raw), sha(raw)) == (row['bytes'], row['sha256'])
        assert (WORK / row['path']).read_bytes() == raw
assert archive.stat().st_size < 8 * 1024 * 1024
(ROOT / 'MANIFEST.json').write_bytes(manifest_raw)
receipt = {'status': manifest['status'], 'scopes': len(SCOPES), 'files': len(rows),
           'unique_blobs': len(blobs), 'logical_bytes': manifest['logical_bytes'],
           'manifest_bytes': len(manifest_raw), 'manifest_sha256': sha(manifest_raw),
           'archive_bytes': archive.stat().st_size, 'archive_sha256': sha(archive.read_bytes()),
           'all_source_and_archive_bytes_rejoined': True,
           'compiler_invocations': 0, 'native_runs': 0, 'remote_actions': 0}
(ROOT / 'LOCAL_PREPARATION.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))
