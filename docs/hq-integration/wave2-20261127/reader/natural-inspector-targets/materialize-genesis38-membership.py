#!/usr/bin/env python3
"""One bounded read-only materialization of an already observed full natural unit."""
import hashlib
import json
from pathlib import Path
import resource
import sqlite3
import time

ROOT = Path('/mnt/development/projects/worktrees/Maktabah-wave2-reader-20261127')
OUT = ROOT / 'docs/hq-integration/wave2-20261127/reader/natural-inspector-targets'
DATABASE = Path('/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127/seforim.db')
RECOVERY = Path('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127/docs/hq-integration/wave2-20261127/search/corpus-restore/RESTORE_RESULT.json')
EXPECTED_RECOVERY = '768d333cceb7e9d5e05bcb299f1ee579c8acd5174c5aec54c3afe76e0c074afb'
EXPECTED_DB = '8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01'
EXPECTED_DISCOVERY = {1: 'efd18aad0afa12b31355c5b449bc96cec3c2a0249bfa48e6286935859a73c01e',
    2: '5ad7a7d05ed0dfce0b8d334f59f80a9dd31ba7ce9ea38cdfbb7cfd4d2b9c548a'}
SQL = "WITH win(id) AS (SELECT id FROM line WHERE bookId=? AND lineIndex IN (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)),\nmatched(linkId,matchedSide,anchorLineId) AS (\n SELECT id,0,sourceLineId FROM link WHERE sourceBookId=? AND sourceLineId IN (SELECT id FROM win)\n UNION SELECT link.id,0,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId\n       WHERE c.side=0 AND link.sourceBookId=? AND c.lineId IN (SELECT id FROM win)\n UNION SELECT id,1,targetLineId FROM link WHERE targetBookId=? AND targetLineId IN (SELECT id FROM win)\n UNION SELECT link.id,1,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId\n       WHERE c.side=1 AND link.targetBookId=? AND c.lineId IN (SELECT id FROM win)\n), resolved AS (\n SELECT DISTINCT link.id AS linkId,matched.anchorLineId,\n   CASE matched.matchedSide WHEN 0 THEN link.targetLineId ELSE link.sourceLineId END AS linkedLineId,\n   CASE matched.matchedSide WHEN 0 THEN link.targetBookId ELSE link.sourceBookId END AS linkedBookId\n FROM matched JOIN link ON link.id=matched.linkId\n LEFT JOIN connection_type ON connection_type.id=link.connectionTypeId\n WHERE (matched.matchedSide=0 AND NOT EXISTS (\n   SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0))\n OR (matched.matchedSide=1 AND connection_type.name IN ('COMMENTARY','SUPER_COMMENTARY','TARGUM','MIDRASH','PARSHANUT','DIBUR_HAMATCHIL','ELUCIDATION','EXPLICATION','FOOTNOTES','REFERENCE','QUOTATION','MESORAT_HASHAS','EIN_MISHPAT','MISHNAH_IN_TALMUD','RELATED','OTHER','SIFREI_MITZVOT','ESSAY','ALLUSION','LITURGY','LAW','SUMMARY')\n   AND NOT EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=1)\n   AND (link.sourceBookId!=link.targetBookId OR (\n     connection_type.name IN ('REFERENCE','QUOTATION','MESORAT_HASHAS','EIN_MISHPAT','MISHNAH_IN_TALMUD','RELATED','OTHER','SIFREI_MITZVOT','ESSAY','ALLUSION','LITURGY','LAW','SUMMARY') AND (\n       EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0)\n       OR (matched.anchorLineId!=link.sourceLineId AND NOT EXISTS (\n         SELECT 1 FROM link_coverage c WHERE c.linkId=link.id AND c.side=0 AND c.lineId=matched.anchorLineId))\n     )\n   )))\n)\nSELECT resolved.linkId,resolved.linkedBookId,resolved.linkedLineId,resolved.anchorLineId\nFROM resolved JOIN line linked_line ON linked_line.id=resolved.linkedLineId\nJOIN book linked_book ON linked_book.id=resolved.linkedBookId\n"
SQL_HELPER_SHA256 = '9d9892ffa03b2d3bc79676607a86de0f229942befd5f37ff1d54828c850487e4'

def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()

def digest(data):
    return hashlib.sha256(data).hexdigest()

def write(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')

def identity():
    value = DATABASE.stat()
    assert DATABASE.is_file() and not DATABASE.is_symlink() and value.st_mode & 0o777 == 0o444
    return {'device': value.st_dev, 'inode': value.st_ino, 'bytes': value.st_size,
        'mtimeNs': value.st_mtime_ns, 'ctimeNs': value.st_ctime_ns}

def main():
    resource.setrlimit(resource.RLIMIT_AS, (256 * 1024 * 1024, 256 * 1024 * 1024))
    start = time.monotonic()
    recovery_bytes = RECOVERY.read_bytes()
    assert digest(recovery_bytes) == EXPECTED_RECOVERY
    recovery = json.loads(recovery_bytes)
    before = identity()
    assert before == {key: recovery['sourceDatabase']['identity'][key] for key in before}
    assert recovery['sourceDatabase']['path'] == str(DATABASE) and recovery['sourceDatabase']['sha256'] == EXPECTED_DB
    candidates = []
    for batch, book, unit, requested in [(2, 107, 'toc:2448', 100), (1, 6, 'toc:199', 500), (1, 1, 'toc:39', 2000)]:
        path = ROOT / ('docs/hq-integration/wave2-20261127/reader/perf-natural-target-batch%02d-recovered-v40/DISCOVERY.json' % batch)
        raw = path.read_bytes(); assert digest(raw) == EXPECTED_DISCOVERY[batch]
        discovery = json.loads(raw)
        found = [u for b in discovery['books'] if b['bookID'] == book
            and b['status'] == 'COMPLETE_BOOK_METADATA_CANDIDATES_ONLY'
            for u in b['units'] if u['unitID'] == unit]
        assert len(found) == 1
        candidate = dict(found[0]); candidate.update(requestedCount=requested,
            discoveryReceipt={'path': str(path.relative_to(ROOT)), 'sha256': digest(raw)})
        candidates.append(candidate)
    target = candidates[2]
    assert target['candidateRawRelationshipCount'] == 2006
    indices = target['sourceLineIndices']; assert indices == list(range(1158, 1189))
    assert digest(encoded(indices)) == target['sourceIndicesSHA256']
    deadline = time.monotonic() + 20
    members = set(); rows = 0
    with sqlite3.connect(DATABASE.as_uri() + '?mode=ro&immutable=1', uri=True) as connection:
        connection.execute('PRAGMA query_only=ON'); assert connection.execute('PRAGMA query_only').fetchone() == (1,)
        connection.execute('PRAGMA cache_size=-8192')
        connection.set_progress_handler(lambda: int(time.monotonic() >= deadline), 10000)
        actual_lines = connection.execute('SELECT id,lineIndex FROM line WHERE bookId=? AND lineIndex IN ('
            + ','.join('?' for _ in indices) + ') ORDER BY lineIndex', [1] + indices).fetchall()
        assert [v[1] for v in actual_lines] == indices
        source_ids = {v[0] for v in actual_lines}
        for link, book, line, anchor in connection.execute(SQL, [1] + indices + [1] * 4):
            rows += 1
            assert rows <= 500000 and time.monotonic() < deadline and anchor in source_ids
            members.add((link, book, line))
    materialized = [list(row) for row in sorted(members)]
    assert len(materialized) == 2006 and digest(encoded(materialized)) == target['rawMembershipSHA256']
    target['candidateRawMembership'] = materialized
    for value in candidates:
        assert len(value['candidateRawMembership']) == value['candidateRawRelationshipCount']
        assert digest(encoded(value['candidateRawMembership'])) == value['rawMembershipSHA256']
        value['atLeastRequestedCount'] = value['candidateRawRelationshipCount'] >= value['requestedCount']
        value['exactRequestedCount'] = value['candidateRawRelationshipCount'] == value['requestedCount']
    after = identity(); assert before == after
    selected = {'schema': 1, 'status': 'NATURAL_CANDIDATES_SELECTED_REQUIRES_INSTALLED_SWIFT_AND_NATIVE',
        'databaseSHA256': EXPECTED_DB, 'candidates': candidates,
        'nativeUIExecuted': 0, 'originalSwiftExecuted': False,
        'requestedCounts': [100, 500, 2000], 'completeActualCounts': [100, 500, 2006],
        'selectionScope': 'Three distinct complete natural units; 2006 is not truncated to requested2000; original at-least contract, exact diagnostic retained false.',
        'requirements': ['Asana1219603004720175: 2000 links plus RAM/FPS', 'Asana1219613714507780: 100-500-2000 workloads',
            'Original complete_inspector requires natural_at_least_workloads_met; exact_size_criterion_met is separate']}
    write(OUT / 'SELECTED_CANDIDATES.json', selected)
    (OUT / 'materialized-unit-relationships.sql').write_text(SQL)
    result = {'schema': 1, 'status': 'COMPLETE_EXISTING_GENESIS38_SQL_MEMBERSHIP_RETAINED_NOT_SWIFT_OR_UI_ACCEPTANCE',
        'sourceBefore': before, 'sourceAfter': after, 'databasePath': str(DATABASE),
        'databaseSHA256FromRecovery': EXPECTED_DB, 'recoveryReceiptSHA256': EXPECTED_RECOVERY,
        'nativeUIExecuted': 0, 'originalSwiftExecuted': False, 'newDiscoverySweep': False, 'freshFullHashPerformed': False,
        'sourceLineIndices': indices, 'sourceLineIDs': sorted(source_ids), 'resolvedRows': rows,
        'rawMembershipSHA256': target['rawMembershipSHA256'], 'completeCount': len(materialized),
        'seconds': time.monotonic() - start, 'querySHA256': digest(SQL.encode()), 'queryHelperSHA256': SQL_HELPER_SHA256,
        'scriptSHA256': digest(Path(__file__).read_bytes()),
        'selectedCandidatesSHA256': digest((OUT / 'SELECTED_CANDIDATES.json').read_bytes()),
        'scope': 'One already discovered31-line complete unit, read-only materialization matches its preexisting full2006 digest. Runtime installed Swift/cardinality and complete native-cache comparison are still required.'}
    write(OUT / 'MEMBERSHIP_MATERIALIZATION.json', result)
    print(json.dumps({'status': result['status'], 'completeCount': len(materialized), 'rows': rows,
        'seconds': result['seconds'], 'resultSHA256': digest((OUT / 'MEMBERSHIP_MATERIALIZATION.json').read_bytes()),
        'selectedCandidatesSHA256': result['selectedCandidatesSHA256']}, ensure_ascii=False), flush=True)

if __name__ == '__main__': main()
