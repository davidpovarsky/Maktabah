#!/usr/bin/env python3
"""Local synthetic admission/SQL controls; zero original native UI executions."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sqlite3
import tempfile
import traceback
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--helper', type=Path, default=ROOT / 'reader-v40-natural-inspector-catalog.py')
parser.add_argument('--core-source', type=Path, default=ROOT.parent / 'inspector-generation-control/kit/Sources/TorahInspectorCore')
parser.add_argument('--manifest', type=Path, default=ROOT / 'torah-inspector-core-canonical-blobs.json')
parser.add_argument('--adapter-source', type=Path,
    default=ROOT / 'own-original/Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift')
parser.add_argument('--output', type=Path, default=ROOT / 'SOURCE_CONTROLS_RESULT.json')
arguments = parser.parse_args()
spec = importlib.util.spec_from_file_location('natural_catalog_candidate', arguments.helper)
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
cases = []

def check(name, operation):
    try:
        operation(); cases.append({'name': name, 'pass': True})
    except Exception:
        cases.append({'name': name, 'pass': False, 'failure': traceback.format_exc()})

def rejects(operation):
    try: operation()
    except (ValueError, FileNotFoundError): return
    raise AssertionError('Malformed or incomplete input was admitted')

def document():
    candidates = []
    for book, number in zip((6, 107, 120), module.SCALES):
        indices = [2, 4, 7]
        members = [[n, 900, 1000 + n] for n in range(1, number + 1)]
        candidates.append({'bookID': book, 'bookTitle': 'SYNTHETIC CONTROL ONLY', 'mode': 'chapter',
            'unitID': 'toc:' + str(book), 'sourceLineIndices': indices,
            'unitStartLineIndex': 2, 'unitEndLineIndex': 7, 'unitRowCount': 3,
            'sourceIndicesSHA256': module.sha(module.encoded(indices)), 'candidateRawRelationshipCount': number,
            'requestedCount': number,
            'candidateRawMembership': members, 'rawMembershipSHA256': module.sha(module.encoded(members)),
            'discoveryReceipt': {'path': 'synthetic-not-native.json', 'sha256': 'a' * 64}})
    return {'schema': 1, 'status': 'NATURAL_CANDIDATES_SELECTED_REQUIRES_INSTALLED_SWIFT_AND_NATIVE',
        'databaseSHA256': module.DATABASE_SHA256, 'candidates': candidates}

def mutation(name, transform):
    def run():
        value = document(); transform(value); rejects(lambda: module.admit_candidates(value))
    check(name, run)

check('Complete synthetic exact set admits only to source-input validation', lambda: module.admit_candidates(document()))
mutation('Missing natural 2000 remains blocked', lambda x: x['candidates'].pop())
mutation('Claimed 2006 with only a 2000-prefix cannot pass', lambda x: x['candidates'][2].update(candidateRawRelationshipCount=2006))
mutation('Pending discovery status cannot pass', lambda x: x.update(status='MISSING_NATURAL_2000'))
mutation('Wrong corpus hash cannot pass', lambda x: x.update(databaseSHA256='0' * 64))
mutation('Duplicate source index cannot pass', lambda x: x['candidates'][0]['sourceLineIndices'].append(7))
mutation('Altered full source membership cannot pass', lambda x: x['candidates'][0]['sourceLineIndices'].__setitem__(1, 5))
mutation('Original three-book exploration cannot be replaced', lambda x: x['candidates'][0].update(bookID=103))
mutation('Whole relationship prefix cannot pass', lambda x: x['candidates'][2]['candidateRawMembership'].pop())
mutation('Duplicate relationship membership cannot pass', lambda x: x['candidates'][1]['candidateRawMembership'].__setitem__(1, x['candidates'][1]['candidateRawMembership'][0]))
mutation('Relationship identity change cannot pass digest', lambda x: x['candidates'][1]['candidateRawMembership'][0].__setitem__(1, 901))
mutation('Bool SQL identifier cannot pass', lambda x: x['candidates'][0]['candidateRawMembership'][0].__setitem__(0, True))
mutation('Omitted original discovery identity cannot pass', lambda x: x['candidates'][0].pop('discoveryReceipt'))
mutation('Reading mode fallback cannot pass', lambda x: x['candidates'][0].update(mode='line'))

def complete_larger_workload():
    value = document(); candidate = value['candidates'][2]
    candidate['candidateRawMembership'] += [[n, 900, 1000 + n] for n in range(2001, 2007)]
    candidate['candidateRawRelationshipCount'] = 2006
    candidate['rawMembershipSHA256'] = module.sha(module.encoded(candidate['candidateRawMembership']))
    actual = module.admit_candidates(value)[2]
    assert actual['requestedCount'] == 2000 and len(actual['candidateRawMembership']) == 2006
    assert actual['candidateRawRelationshipCount'] != actual['requestedCount']
check('Complete natural2006 satisfies requested2000 while preserving actual count and every member', complete_larger_workload)

def sql_fixture():
    db = sqlite3.connect(':memory:')
    db.executescript('''
        CREATE TABLE book(id INTEGER PRIMARY KEY);
        CREATE TABLE line(id INTEGER PRIMARY KEY,bookId INTEGER,lineIndex INTEGER);
        CREATE TABLE link(id INTEGER PRIMARY KEY,sourceBookId INTEGER,sourceLineId INTEGER,
            targetBookId INTEGER,targetLineId INTEGER,connectionTypeId INTEGER);
        CREATE TABLE connection_type(id INTEGER PRIMARY KEY,name TEXT);
        CREATE TABLE link_coverage(linkId INTEGER,side INTEGER,lineId INTEGER);
        CREATE TABLE link_suppressed_side(linkId INTEGER,side INTEGER);
        INSERT INTO book VALUES(1),(2);
        INSERT INTO line VALUES(10,1,0),(11,1,1),(12,1,2),(20,2,0),(21,2,1);
        INSERT INTO connection_type VALUES(1,'COMMENTARY'),(2,'REFERENCE'),(3,'UNRELATED_TYPE');
        INSERT INTO link VALUES(1,1,10,2,20,1),(2,2,21,1,12,1),(3,1,11,2,21,1),
            (4,1,12,2,20,2),(5,2,20,1,10,3),(6,1,10,1,12,2);
        INSERT INTO link_coverage VALUES(1,0,12);
        INSERT INTO link_suppressed_side VALUES(4,0);
    ''')
    return db

def sql_cases():
    with sql_fixture() as db:
        query = module.query_for_indices(2)
        rows = list(db.execute(query, [1, 0, 2, 1, 1, 1, 1]))
        membership = sorted({tuple(row[:3]) for row in rows})
        assert membership == [(1, 2, 20), (2, 2, 21), (6, 1, 10), (6, 1, 12)], membership
        assert all(row[3] in (10, 12) for row in rows)
        assert len([row for row in rows if row[0] == 1]) == 2
        # Partitioned queries preserve full membership with duplicate coverage
        # deduped by the original id/book/line key, not locator-only dedup.
        chunks = set()
        for index in (0, 2):
            chunks.update(tuple(row[:3]) for row in db.execute(module.query_for_indices(1), [1, index, 1, 1, 1, 1]))
        assert sorted(chunks) == membership

check('Actual SQLite synthetic fixture covers holes/inverse/coverage/suppression/full identity dedup', sql_cases)

class Files:
    @staticmethod
    def bounded_read(path, limit):
        path = Path(path)
        assert not path.is_symlink()
        data = path.read_bytes(); assert 0 < len(data) <= limit
        return data
    @staticmethod
    def bounded_json(path, limit): return json.loads(Files.bounded_read(path, limit))

manifest = arguments.manifest
kit = arguments.core_source
check('All eight actual retained Core files match canonical pinned Git SHA1 and SHA256',
    lambda: module.qualified_core_sources(Files, kit, manifest))

def changed_core():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory); shutil.copytree(kit, root / 'Core')
        changed = root / 'Core/Models.swift'; changed.write_bytes(changed.read_bytes() + b'\n')
        rejects(lambda: module.qualified_core_sources(Files, root / 'Core', manifest))
check('Changed actual Core source cannot use a pinned manifest', changed_core)

def wrong_commit():
    with tempfile.TemporaryDirectory() as directory:
        value = json.loads(manifest.read_bytes()); value['commit'] = '0' * 40
        path = Path(directory) / 'manifest.json'; path.write_text(json.dumps(value))
        rejects(lambda: module.qualified_core_sources(Files, kit, path))
check('Wrong canonical Git commit is rejected', wrong_commit)

def missing_scale_before_any_compile():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        file = root / 'candidates.json'; value = document(); value['candidates'].pop(); file.write_text(json.dumps(value))
        called = []
        def original(*args): called.append(True); raise AssertionError('Original catalog executed for missing discovery')
        core = SimpleNamespace(ROOT=root, CORPUS_NAME='full-v40', prepare_catalog=original,
            ObservationHost=type('UnexecutedHost', (), {}), bounded_json=Files.bounded_json)
        module.install(core, core_source=kit)
        rejects(lambda: core.prepare_catalog({'natural_inspector_catalog': {'candidates_file': 'candidates.json'}}, {}))
        assert not called
check('Missing natural scale stops before original catalog compile or database access', missing_scale_before_any_compile)

def v32_rejected():
    rejects(lambda: module.install(SimpleNamespace(CORPUS_NAME='full-v32'), core_source=kit))
check('v32 cannot receive the natural v40 integration hook', v32_rejected)

adapter = arguments.adapter_source
def exact_enum():
    raw = adapter.read_bytes(); compiled, receipt = module.original_formatting_fragment(raw)
    original = raw[receipt['startByteInclusive']:receipt['endByteExclusive']]
    assert compiled == receipt['addedPrefix'].encode() + original
    assert module.sha(original) == receipt['completeEnumSHA256']
    assert module.sha(raw) == receipt['sourceSHA256']
check('Complete actual original Formatting enum extraction retains exact bytes and offsets', exact_enum)
check('Changed original conditional tail fails closed instead of rewriting helper',
    lambda: rejects(lambda: module.original_formatting_fragment(adapter.read_bytes() + b'\n')))
check('Ambiguous duplicate original Formatting enum fails closed', lambda: rejects(lambda:
    module.original_formatting_fragment(adapter.read_bytes().replace(b'\nenum MaktabahTorahInspectorFormatting {\n',
        b'\nenum MaktabahTorahInspectorFormatting {\n\nenum MaktabahTorahInspectorFormatting {\n'))))

def projection_fixture():
    identities = [{'ordinal': i, 'id': 'synthetic-id-' + str(i), 'sourceRef': 'synthetic-ref-' + str(i),
        'rawProviderPayload': 'synthetic-locator-' + str(i)} for i in range(3)]
    digest = hashlib.sha256(); total = 0
    for text in ['otzaria.original-inspector-membership/1', '3'] + [value for item in identities
        for value in (str(item['ordinal']), item['id'], item['sourceRef'], item['rawProviderPayload'])]:
        data = text.encode(); digest.update(len(data).to_bytes(8, 'big')); digest.update(data); total += len(data) + 8
    projection = {'schema': 1, 'status': 'ORIGINAL_IDENTITY_PROJECTION_REQUIRES_NATIVE_ARRAY_COMPARISON',
        'count': 3, 'identities': identities, 'orderedIdentitySHA256': digest.hexdigest(),
        'hashedBytes': total, 'identityDigestEncoding': module.IDENTITY_ENCODING}
    scale = {'requestedCount': 2, 'originalMetadataCount': 3,
        'nativeOrderedIdentitySHA256': digest.hexdigest(), 'nativeIdentityHashedBytes': total,
        'rawMembershipSHA256': 'a' * 64, 'identityProjectionSHA256': 'b' * 64}
    record = {'full_cached_count': 3, 'native_ordered_identity_sha256': digest.hexdigest(),
        'native_report': projection, 'request_id': 'synthetic-no-native-request', 'target_key': 'synthetic',
        'native_report_file': {'path': 'not-a-real-native-report', 'sha256': 'c' * 64}}
    returned = {'fullCachedCount': 3, 'nativeOrderedIdentitySHA256': digest.hexdigest()}
    return scale, projection, record, returned

check('Full ordered projection bytes independently rederive length-prefixed identity digest',
    lambda: module.check_projection(*projection_fixture()[:2]))
def changed_projection():
    scale, projection, _, _ = projection_fixture()
    projection['identities'][1]['id'] += '-changed'
    rejects(lambda: module.check_projection(scale, projection))
check('One changed interior identity rejects even when count and endpoints agree', changed_projection)
def reordered_projection():
    scale, projection, _, _ = projection_fixture()
    projection['identities'].reverse()
    rejects(lambda: module.check_projection(scale, projection))
check('Reordered complete metadata array rejects without silently sorting', reordered_projection)
def complete_match():
    scale, _, record, returned = projection_fixture()
    proof = module.match_native_projection(scale, record, returned)
    assert proof['actualCompleteCount'] == 3 and proof['atLeastRequestedCount'] is True and proof['exactRequestedCount'] is False
check('Synthetic post-super matching retains actual-count versus requested-count distinction', complete_match)
def count_only_match():
    scale, _, record, returned = projection_fixture()
    record['native_report']['orderedIdentitySHA256'] = '0' * 64
    rejects(lambda: module.match_native_projection(scale, record, returned))
check('Equal count cannot admit a mismatched native complete-array digest', count_only_match)
def encoding_mismatch():
    scale, _, record, returned = projection_fixture()
    record['native_report']['identityDigestEncoding'] = 'different'
    rejects(lambda: module.match_native_projection(scale, record, returned))
check('Different original native digest encoding cannot be accepted', encoding_mismatch)

result = {'schema': 1, 'status': 'SOURCE_CONTROLS_PASS' if all(x['pass'] for x in cases) else 'FAILED',
    'scope': 'Synthetic admission and SQLite fixture controls plus canonical source-byte comparison; no production corpus, Apple compilation, app or native UI',
    'nativeUIExecuted': 0, 'productionDatabaseRead': False, 'cases': cases,
    'passed': sum(x['pass'] for x in cases), 'failed': sum(not x['pass'] for x in cases),
    'helperSHA256': module.sha(arguments.helper.read_bytes()),
    'controlSHA256': module.sha(Path(__file__).read_bytes()),
    'actualInputPaths': {key: str(getattr(arguments, key).resolve(strict=True))
        for key in ('helper', 'core_source', 'manifest', 'adapter_source')}}
arguments.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
raise SystemExit(0 if result['failed'] == 0 else 1)
