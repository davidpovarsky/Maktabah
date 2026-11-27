#!/usr/bin/env python3
"""Additive full-v40 natural Inspector catalog; never modifies v32/shared code."""
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import time
from urllib.parse import unquote, urlsplit

DATABASE_SHA256 = '8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01'
CORE_COMMIT = '23db0f84e88d9ee9c7053c49de86903fc7bb5785'
CORE_TREE = '39941eb7cebab6cf834c206c4317295b9c30761a'
SCALES = [100, 500, 2000]
SOURCE_PATHS = [
    'Source/Core/Database/SQLiteDatabase.swift', 'Source/Core/Database/ZstdShim.swift',
    'Source/Otzaria/Core/OtzariaSQLiteError.swift', 'Source/Otzaria/Core/OtzariaSQLiteStatement.swift',
    'Source/Otzaria/Core/String+OtzariaText.swift', 'Source/Otzaria/Data/OtzariaSchema.swift',
    'Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift', 'Source/Otzaria/Domain/OtzariaModels.swift',
    'Source/Otzaria/Reading/OtzariaReadingUnit.swift', 'Source/Otzaria/Reading/OtzariaReadingUnitDescriptor.swift',
    'Source/Otzaria/Reading/OtzariaLineAnchor.swift', 'Source/Otzaria/Reading/OtzariaReadingUnitService.swift',
    'Source/Otzaria/Reading/OtzariaCategoryPathResolver.swift',
    'Source/Otzaria/Reading/OtzariaRelationshipClassifier.swift',
    'Source/Otzaria/Reading/OtzariaLineSourcesService.swift', 'Tests/HQ/sqlite/UnusedZstdBoundary.swift',
    'Source/LibraryBackend/LibraryBackendModels.swift',
    'Source/LibraryBackend/LibraryBackendProtocols.swift',
    'Source/Otzaria/Reading/OtzariaInspectorRelationshipsProvider.swift',
]
ADAPTER_PATH = 'Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift'
NATIVE_OBSERVER_PATH = 'Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift'
IDENTITY_ENCODING = ('SHA256 of eight-byte unsigned big-endian UTF8 byte lengths then exact UTF8; '
    'header,count,then original array ordinal,id,sourceRef,rawProviderPayload')
CORE_FILES = ['Models.swift', 'ProviderProtocols.swift', 'TorahInspectorCoordinator.swift',
    'TorahInspectorRepository.swift', 'TorahReaderScrollStateMachine.swift',
    'TorahRelatedDocumentsAccessError.swift', 'TorahSourceTransfer.swift', 'TorahToolSelectorStateMachine.swift']
DEPENDENT = ['COMMENTARY', 'SUPER_COMMENTARY', 'TARGUM', 'MIDRASH', 'PARSHANUT',
    'DIBUR_HAMATCHIL', 'ELUCIDATION', 'EXPLICATION', 'FOOTNOTES']
REFERENCE = ['REFERENCE', 'QUOTATION', 'MESORAT_HASHAS', 'EIN_MISHPAT', 'MISHNAH_IN_TALMUD',
    'RELATED', 'OTHER', 'SIFREI_MITZVOT', 'ESSAY', 'ALLUSION', 'LITURGY', 'LAW', 'SUMMARY']

def require(value, message):
    if not value: raise ValueError(message)

def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def identity(path):
    value = path.stat()
    require(path.is_file() and not path.is_symlink(), 'Actual admitted database must be a regular file')
    return {'device': value.st_dev, 'inode': value.st_ino, 'bytes': value.st_size,
        'mtimeNs': value.st_mtime_ns, 'ctimeNs': value.st_ctime_ns}

def source_file(core, name):
    require(isinstance(name, str) and not Path(name).is_absolute() and '..' not in Path(name).parts,
        'Require a committed checkout-relative input path')
    path = core.ROOT / name
    require(path.resolve(strict=True).is_relative_to(core.ROOT.resolve(strict=True))
        and not path.is_symlink() and path.is_file(), 'Input must remain inside the current checkout')
    return path

def admit_candidates(document):
    require(isinstance(document, dict) and document.get('schema') == 1
        and document.get('status') == 'NATURAL_CANDIDATES_SELECTED_REQUIRES_INSTALLED_SWIFT_AND_NATIVE'
        and document.get('databaseSHA256') == DATABASE_SHA256,
        'Missing complete full-v40 natural-candidate selection; discovery cannot claim native acceptance')
    candidates = document.get('candidates')
    require(isinstance(candidates, list) and len(candidates) == 3,
        'Exactly three independently discovered natural targets are required; missing 2000 remains blocked')
    require([c.get('requestedCount') for c in candidates] == SCALES,
        'Original requested scales 100/500/2000 must retain each complete actual natural workload')
    identities = set()
    for candidate, requested in zip(candidates, SCALES):
        count = candidate.get('candidateRawRelationshipCount')
        require(type(count) is int and requested <= count <= 10000,
            'Actual complete natural count must reach its declared workload within the bounded source-oracle cap')
        require(type(candidate.get('bookID')) is int and candidate['bookID'] > 0
            and candidate['bookID'] not in (103, 28, 3152) and candidate.get('mode') == 'chapter'
            and isinstance(candidate.get('bookTitle'), str) and candidate['bookTitle']
            and isinstance(candidate.get('unitID'), str), 'A separate actual natural chapter identity is required')
        indices = candidate.get('sourceLineIndices')
        require(isinstance(indices, list) and 0 < len(indices) <= 50_000
            and all(type(i) is int and i >= 0 for i in indices) and indices == sorted(set(indices))
            and candidate.get('unitStartLineIndex') == indices[0]
            and candidate.get('unitEndLineIndex') == indices[-1] and candidate.get('unitRowCount') == len(indices)
            and candidate.get('sourceIndicesSHA256') == sha(encoded(indices)), 'Complete natural source membership changed')
        members = candidate.get('candidateRawMembership')
        require(isinstance(members, list) and len(members) == count
            and all(isinstance(row, list) and len(row) == 3
                and all(type(v) is int and v > 0 for v in row) for row in members)
            and members == sorted([list(v) for v in set(map(tuple, members))])
            and sha(encoded(members)) == candidate.get('rawMembershipSHA256'),
            'Complete untruncated independent SQL relationship identities are required')
        provenance = candidate.get('discoveryReceipt')
        require(isinstance(provenance, dict) and isinstance(provenance.get('path'), str)
            and re.fullmatch('[a-f0-9]{64}', provenance.get('sha256', '')),
            'Each selected target must identify the exact retained original discovery receipt')
        identities.add((candidate['bookID'], candidate['unitID']))
    require(len(identities) == 3, 'The three requested scales require distinct complete natural units')
    return candidates

def verify_original_candidates(core, candidates):
    for candidate in candidates:
        reference = candidate['discoveryReceipt']
        path = source_file(core, reference['path'])
        raw = core.bounded_read(path, 64 * 1024 * 1024)
        require(sha(raw) == reference['sha256'], 'Retained original candidate receipt changed')
        original = json.loads(raw)
        require(original.get('status') == 'BOUNDED_READ_ONLY_NATURAL_CANDIDATES_NOT_SWIFT_OR_UI_ACCEPTANCE'
            and original.get('nativeUIExecuted') == 0 and original.get('adapterExecuted') is False
            and original.get('database', {}).get('sha256FromCompletedRecovery') == DATABASE_SHA256,
            'Candidate discovery is a separate genuine recovered-v40 SQL observation')
        complete_books = [book for book in original.get('books', [])
            if book.get('status') == 'COMPLETE_BOOK_METADATA_CANDIDATES_ONLY' and book.get('bookID') == candidate['bookID']]
        matched = [value for book in complete_books for value in book.get('units', [])
            if value.get('unitID') == candidate['unitID']]
        # Earlier exploration retained complete membership SHA even when its
        # count was not exactly 100/500/2000. Materialized full triples must match
        # that exact original digest, then independently match installed SQL and
        # unchanged Swift below. No larger unit is sliced to a requested count.
        require(len(matched) == 1 and all(candidate.get(k) == v for k, v in matched[0].items()),
            'Selected candidate does not equal the whole original discovered unit')

def query_for_indices(number):
    literals = lambda values: ','.join("'" + v + "'" for v in values)
    return '''WITH win(id) AS (SELECT id FROM line WHERE bookId=? AND lineIndex IN (%s)),
matched(linkId,matchedSide,anchorLineId) AS (
 SELECT id,0,sourceLineId FROM link WHERE sourceBookId=? AND sourceLineId IN (SELECT id FROM win)
 UNION SELECT link.id,0,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId
       WHERE c.side=0 AND link.sourceBookId=? AND c.lineId IN (SELECT id FROM win)
 UNION SELECT id,1,targetLineId FROM link WHERE targetBookId=? AND targetLineId IN (SELECT id FROM win)
 UNION SELECT link.id,1,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId
       WHERE c.side=1 AND link.targetBookId=? AND c.lineId IN (SELECT id FROM win)
), resolved AS (
 SELECT DISTINCT link.id AS linkId,matched.anchorLineId,
   CASE matched.matchedSide WHEN 0 THEN link.targetLineId ELSE link.sourceLineId END AS linkedLineId,
   CASE matched.matchedSide WHEN 0 THEN link.targetBookId ELSE link.sourceBookId END AS linkedBookId
 FROM matched JOIN link ON link.id=matched.linkId
 LEFT JOIN connection_type ON connection_type.id=link.connectionTypeId
 WHERE (matched.matchedSide=0 AND NOT EXISTS (
   SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0))
 OR (matched.matchedSide=1 AND connection_type.name IN (%s)
   AND NOT EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=1)
   AND (link.sourceBookId!=link.targetBookId OR (
     connection_type.name IN (%s) AND (
       EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0)
       OR (matched.anchorLineId!=link.sourceLineId AND NOT EXISTS (
         SELECT 1 FROM link_coverage c WHERE c.linkId=link.id AND c.side=0 AND c.lineId=matched.anchorLineId))
     )
   )))
)
SELECT resolved.linkId,resolved.linkedBookId,resolved.linkedLineId,resolved.anchorLineId
FROM resolved JOIN line linked_line ON linked_line.id=resolved.linkedLineId
JOIN book linked_book ON linked_book.id=resolved.linkedBookId
''' % (','.join('?' for _ in range(number)), literals(DEPENDENT + REFERENCE), literals(REFERENCE))

def installed_sql_memberships(core, installation, candidates, out):
    require(installation['database']['sha256'] == DATABASE_SHA256, 'The actual installed v40 hash is required')
    uri = installation['uri']
    require('mode=ro' in uri and 'immutable=1' in uri, 'Read only the admitted immutable installed database')
    database = Path(unquote(urlsplit(uri).path)).resolve(strict=True)
    before = identity(database)
    require(before['bytes'] == 4355063808, 'The current full v40 installed file is required')
    started = time.monotonic()
    deadline = started + 300
    proofs = []
    with contextlib.closing(sqlite3.connect(uri, uri=True)) as connection:
        connection.execute('PRAGMA query_only=ON')
        require(connection.execute('PRAGMA query_only').fetchone() == (1,), 'Read-only query admission failed')
        connection.execute('PRAGMA cache_size=-8192')
        for candidate in candidates:
            book = candidate['bookID']; indices = candidate['sourceLineIndices']
            local_deadline = min(deadline, time.monotonic() + 120)
            connection.set_progress_handler(lambda: int(time.monotonic() >= local_deadline), 10000)
            members = set(); anchors = {}; rows = 0; chunks = []
            for start in range(0, len(indices), 400):
                subset = indices[start:start + 400]
                require(time.monotonic() < local_deadline, 'Complete installed SQL membership exceeded its bound')
                ids = connection.execute('SELECT id,lineIndex FROM line WHERE bookId=? AND lineIndex IN ('
                    + ','.join('?' for _ in subset) + ')', [book] + subset).fetchall()
                require(len(ids) == len(subset) and {v[1] for v in ids} == set(subset),
                    'Every requested source index needs an actual installed SQL line identity')
                anchors.update(ids)
                query = query_for_indices(len(subset))
                for link, linked_book, linked_line, anchor in connection.execute(query, [book] + subset + [book] * 4):
                    rows += 1
                    require(rows <= 500000 and time.monotonic() < local_deadline,
                        'Entire target excluded when installed SQL row/time bound is exceeded')
                    require(anchor in anchors, 'Actual resolved relationship source is outside the complete natural unit')
                    members.add((link, linked_book, linked_line))
                chunks.append({'sourceLineIndices': subset, 'query': query, 'querySHA256': sha(query.encode())})
            ordered = [list(v) for v in sorted(members)]
            require(ordered == candidate['candidateRawMembership']
                and len(ordered) == candidate['candidateRawRelationshipCount'],
                'Actual installed complete membership differs from independent recovered-corpus discovery')
            proofs.append({'bookID': book, 'unitID': candidate['unitID'], 'sourceLineIndices': indices,
                'sourceLineIDs': sorted(anchors), 'resolvedAnchorRowsRead': rows,
                'completeMembership': ordered, 'membershipSHA256': sha(encoded(ordered)), 'chunks': chunks})
    after = identity(database)
    require(before == after, 'Actual installed database identity changed during bounded independent SQL')
    result = {'schema': 1, 'status': 'EXACT_INSTALLED_SQL_MEMBERSHIP_NOT_SWIFT_OR_NATIVE_ACCEPTANCE',
        'databaseSHA256': DATABASE_SHA256, 'databaseBefore': before, 'databaseAfter': after,
        'databasePath': str(database), 'freshFullHashPerformed': False,
        'seconds': time.monotonic() - started, 'targets': proofs}
    path = out / 'installed-sql-memberships.json'; core.write(path, result)
    return path

def qualified_core_sources(core, source_dir, manifest_path):
    directory = Path(source_dir).resolve(strict=True)
    manifest = core.bounded_json(manifest_path, 65536)
    require(manifest.get('commit') == CORE_COMMIT and manifest.get('tree') == CORE_TREE,
        'Only the original pinned canonical Git tree is admitted')
    names = {'Sources/TorahInspectorCore/' + name for name in CORE_FILES}
    require(set(manifest.get('sources', {})) == names
        and {p.name for p in directory.glob('*.swift')} == set(CORE_FILES),
        'All and only the eight canonical pinned Core Swift files are required')
    result = []
    for relative in sorted(names):
        path = directory / Path(relative).name
        data = core.bounded_read(path, 2 * 1024 * 1024)
        expected = manifest['sources'][relative]
        blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\x00' + data).hexdigest()
        require(len(data) == expected['bytes'] and sha(data) == expected['sha256']
            and blob == expected['gitBlob'], 'An actual Core source differs from its canonical pinned Git blob')
        result.append(path)
    return result

def original_formatting_fragment(data):
    """Exact complete enum extraction, failing if its original boundary drifts."""
    require(isinstance(data, bytes) and 0 < len(data) <= 512 * 1024,
        'Bound the full original adapter source before identifying its conditional boundary')
    marker = b'\nenum MaktabahTorahInspectorFormatting {\n'
    require(data.startswith(b'#if os(iOS)\n') and data.count(marker) == 1
        and data.endswith(b'}\n#endif\n'),
        'Original complete Formatting enum/conditional boundary changed; no rewritten fallback is permitted')
    start = data.index(marker) + 1
    end = len(data) - len(b'#endif\n')
    fragment = data[start:end]
    require(0 < len(fragment) <= 32 * 1024 and fragment.endswith(b'}\n')
        and b'#if' not in fragment and b'#endif' not in fragment,
        'Require the complete original unconditional Formatting enum as the last top-level declaration')
    compiled = b'import Foundation\nimport TorahInspectorCore\n\n' + fragment
    receipt = {'schema': 1, 'sourceSHA256': sha(data), 'sourceBytes': len(data),
        'startByteInclusive': start, 'endByteExclusive': end,
        'completeEnumSHA256': sha(fragment), 'completeEnumBytes': len(fragment),
        'compiledFileSHA256': sha(compiled), 'compiledFileBytes': len(compiled),
        'boundaryReason': 'The original adapter file is iOS-conditional; this macOS source oracle compiles its byte-exact complete Formatting enum, not the whole adapter lifecycle.',
        'addedPrefix': 'import Foundation\nimport TorahInspectorCore\n\n',
        'scope': 'Unchanged formatting projection only; whole original provider.map and canonical Core.id compiled separately; native complete cache comparison remains required'}
    return compiled, receipt

def check_projection(row, value):
    require(value.get('schema') == 1 and value.get('status')
        == 'ORIGINAL_IDENTITY_PROJECTION_REQUIRES_NATIVE_ARRAY_COMPARISON'
        and value.get('count') == row['originalMetadataCount']
        and value.get('identityDigestEncoding') == IDENTITY_ENCODING,
        'The complete original identity projection must retain its exact bounded schema')
    values = value.get('identities')
    require(isinstance(values, list) and len(values) == row['originalMetadataCount'] <= 10000,
        'Every original service element must appear in the complete identity projection')
    digest = hashlib.sha256(); hashed = 0
    def append(text):
        nonlocal hashed
        require(isinstance(text, str) and len(text.encode()) <= 8192, 'Oversized or nontext identity cannot be truncated')
        data = text.encode(); hashed += 8 + len(data)
        require(hashed <= 32 * 1024 * 1024, 'Native identity hash byte bound exceeded')
        digest.update(len(data).to_bytes(8, 'big')); digest.update(data)
    append('otzaria.original-inspector-membership/1'); append(str(len(values)))
    for ordinal, value_row in enumerate(values):
        require(type(value_row.get('ordinal')) is int and value_row['ordinal'] == ordinal,
            'The original metadata service order cannot be sorted, deduplicated or truncated after projection')
        for text in (str(ordinal), value_row.get('id'), value_row.get('sourceRef'), value_row.get('rawProviderPayload')):
            append(text)
    require(digest.hexdigest() == value.get('orderedIdentitySHA256') == row.get('nativeOrderedIdentitySHA256')
        and hashed == value.get('hashedBytes') == row.get('nativeIdentityHashedBytes'),
        'Complete identity records must rederive the exact original native digest contract')
    return {'completeCount': len(values), 'orderedIdentitySHA256': digest.hexdigest(), 'hashedBytes': hashed}

def match_native_projection(scale, record, returned):
    """Call only after the unchanged host validates the fresh original response."""
    report = record['native_report']
    require(record['full_cached_count'] == returned.get('fullCachedCount') == scale['originalMetadataCount']
        and record['native_ordered_identity_sha256'] == returned.get('nativeOrderedIdentitySHA256')
        == report.get('orderedIdentitySHA256') == scale['nativeOrderedIdentitySHA256']
        and report.get('identityDigestEncoding') == IDENTITY_ENCODING
        and report.get('hashedBytes') == scale['nativeIdentityHashedBytes'],
        'The entire genuine original cache array must equal the complete SQL-bound original identity projection')
    return {'status': 'NATURAL_COMPLETE_MEMBERSHIP_MATCHED_AFTER_ORIGINAL_NATIVE_OBSERVATION',
        'requestID': record['request_id'], 'targetKey': record['target_key'],
        'requestedCount': scale['requestedCount'], 'actualCompleteCount': record['full_cached_count'],
        'atLeastRequestedCount': record['full_cached_count'] >= scale['requestedCount'],
        'exactRequestedCount': record['full_cached_count'] == scale['requestedCount'],
        'nativeOrderedIdentitySHA256': scale['nativeOrderedIdentitySHA256'],
        'nativeIdentityHashedBytes': scale['nativeIdentityHashedBytes'],
        'independentCompleteMembershipSHA256': scale['rawMembershipSHA256'],
        'identityProjectionSHA256': scale['identityProjectionSHA256'],
        'nativeReport': record['native_report_file'],
        'scope': 'Full original ordered identity array agrees with complete independent SQL membership and original source projection; visible samples and rendered row bodies retain their separate bounded scope'}

def prepare(core, config, installation, *, core_source):
    declaration = config.get('natural_inspector_catalog')
    require(isinstance(declaration, dict) and set(declaration) == {'candidates_file', 'core_manifest', 'swift_source'},
        'Separate full-v40 natural-catalog configuration is required')
    candidate_path = source_file(core, declaration['candidates_file'])
    candidate_bytes = core.bounded_read(candidate_path, 4 * 1024 * 1024)
    candidates = admit_candidates(json.loads(candidate_bytes))
    verify_original_candidates(core, candidates)
    manifest_path = source_file(core, declaration['core_manifest'])
    core_sources = qualified_core_sources(core, core_source, manifest_path)
    catalog_source = source_file(core, declaration['swift_source'])
    sources = [source_file(core, name) for name in SOURCE_PATHS]
    source_paths = SOURCE_PATHS + [ADAPTER_PATH, NATIVE_OBSERVER_PATH]
    source_hashes = {name: sha(core.bounded_read(source_file(core, name), 2 * 1024 * 1024)) for name in source_paths}
    require(sum(source_file(core, name).stat().st_size for name in source_paths) <= 4 * 1024 * 1024,
        'The complete original source closure exceeded its bounded 4 MiB admission')
    out = core.OUT / 'natural-inspector-catalog'
    out.mkdir(parents=True, exist_ok=False)
    fragment, extraction = original_formatting_fragment(core.bounded_read(source_file(core, ADAPTER_PATH), 512 * 1024))
    formatting = out / 'OriginalMaktabahTorahInspectorFormatting.swift'
    with formatting.open('xb') as stream: stream.write(fragment)
    core.write(out / 'original-formatting-extraction.json', extraction)
    sql_path = installed_sql_memberships(core, installation, candidates, out)
    swiftc = core.command(['xcrun', '--sdk', 'macosx', '--find', 'swiftc']).stdout.strip()
    sdk = core.command(['xcrun', '--sdk', 'macosx', '--show-sdk-path']).stdout.strip()
    zstd = (Path(core.command(['brew', '--prefix', 'zstd']).stdout.strip()) / 'lib/libzstd.dylib').resolve(strict=True)
    flags = ['-parse-as-library', '-swift-version', '6', '-Xfrontend', '-strict-concurrency=complete',
        '-O', '-sdk', sdk, '-module-cache-path', str(out / 'module-cache')]
    core_command = [swiftc] + flags + ['-emit-module', '-emit-library', '-module-name', 'TorahInspectorCore']
    core_command += [str(p) for p in core_sources] + ['-emit-module-path', str(out / 'TorahInspectorCore.swiftmodule'),
        '-Xlinker', '-install_name', '-Xlinker', str(out / 'libTorahInspectorCore.dylib'),
        '-o', str(out / 'libTorahInspectorCore.dylib')]
    binary = out / 'original-natural-inspector-catalog'
    args = [swiftc] + flags + ['-I', str(out), '-L', str(out), '-lTorahInspectorCore',
        '-L', str(zstd.parent), '-lzstd', '-Xlinker', '-rpath', '-Xlinker', str(zstd.parent)]
    args += [str(p) for p in sources] + [str(formatting), str(catalog_source), '-o', str(binary)]
    compile_input = {'command': args, 'core_command': core_command, 'swiftc': core.witness(swiftc),
        'zstd': core.witness(zstd), 'source_sha256': source_hashes,
        'catalog_source': core.witness(catalog_source), 'core_manifest': core.witness(manifest_path),
        'core_sources': [core.witness(p) for p in core_sources],
        'formatting_extraction': extraction, 'formatting_compiled_file': core.witness(formatting),
        'scope': 'Complete unchanged production services/provider.map/Core.id; byte-exact complete conditional Formatting enum; explicit pass-through host/DTO/logging boundary. This is not whole-adapter/session or native-cache execution.'}
    compile_path = out / 'compile-inputs.json'; core.write(compile_path, compile_input)
    require(core.bounded(core_command, out / 'core-compile.log', 300) == 0, 'Pinned original Core compilation failed')
    require(core.bounded(args, out / 'compile.log', 300) == 0, 'Complete original natural-catalog service compilation failed')
    data = {'databaseURI': installation['uri'], 'databaseSHA256': DATABASE_SHA256, 'candidates': candidates,
        'candidateReceiptSHA256': sha(candidate_bytes), 'installedSQLReceiptSHA256': core.digest(sql_path),
        'compileInputsSHA256': core.digest(compile_path), 'sourceSHA256': compile_input['source_sha256'],
        'pinnedCoreManifestSHA256': core.digest(manifest_path)}
    core.write(out / 'input.json', data)
    require(core.bounded([str(binary), str(out / 'input.json'), str(out)], out / 'execution.log', 600) == 0,
        'Original natural units/service metadata did not validate against complete independent SQL')
    path = out / 'natural-inspector-targets.json'
    catalog = core.bounded_json(path, 1024 * 1024)
    require(catalog.get('status') == 'ORIGINAL_NATURAL_UNIT_AND_METADATA_CATALOG_NOT_NATIVE_ACCEPTANCE'
        and catalog.get('databaseSHA256') == DATABASE_SHA256
        and [r.get('requestedCount') for r in catalog.get('scales', [])] == SCALES
        and [r.get('originalMetadataCount') for r in catalog['scales']]
            == [c['candidateRawRelationshipCount'] for c in candidates]
        and all(r['originalMetadataCount'] >= r['requestedCount']
            and r.get('exactRequestedCount') is (r['originalMetadataCount'] == r['requestedCount']) for r in catalog['scales']),
        'Original complete natural-service catalog is incomplete')
    for row in catalog['scales']:
        for name, size, digest in [(row['target']['sourceFile'], row['target']['sourceUTF8Bytes'], row['target']['sourceSHA256']),
            (row['metadataFile'], row['metadataBytes'], row['metadataSHA256']),
            (row['identityProjectionFile'], row['identityProjectionBytes'], row['identityProjectionSHA256'])]:
            artifact = out / name
            require(artifact.parent == out and artifact.is_file() and not artifact.is_symlink()
                and artifact.stat().st_size == size and 0 < size <= 16 * 1024 * 1024 and core.digest(artifact) == digest,
                'Original complete source or metadata output changed')
        check_projection(row, core.bounded_json(out / row['identityProjectionFile'], 16 * 1024 * 1024))
    require(sum(row['target']['sourceUTF8Bytes'] + row['metadataBytes'] + row['identityProjectionBytes']
        for row in catalog['scales']) == catalog.get('artifactBytes') <= 64 * 1024 * 1024,
        'Actual complete catalog artifact budget exceeded')
    require(all(core.digest(core.ROOT / name) == value for name, value in compile_input['source_sha256'].items())
        and core.digest(catalog_source) == compile_input['catalog_source']['sha256'],
        'Actual compiled application source changed during oracle execution')
    qualified_core_sources(core, core_source, manifest_path)
    core.write(out / 'native-executable.json', {'binary': core.witness(binary),
        'linkage': core.command(['otool', '-L', str(binary)]).stdout,
        'catalog': core.witness(path), 'nativeUIExecuted': 0, 'nativeCacheObserved': False})
    return out, catalog

def install(core, *, core_source):
    """Execute-only hook. load_core(), the ten Reader targets and v32 stay intact."""
    require(core.CORPUS_NAME == 'full-v40', 'Natural target integration is full-v40 only')
    require(not getattr(core, '_natural_inspector_installed', False), 'Install the additive hook only once')
    previous_prepare, previous_host = core.prepare_catalog, core.ObservationHost
    context = {}

    def prepare_both(config, installation):
        declaration = config.get('natural_inspector_catalog')
        require(isinstance(declaration, dict) and 'candidates_file' in declaration,
            'Separate full-v40 natural candidates are required before any catalog compilation')
        # Missing discovery fails before compiling or decoding the large Reader
        # catalog. This check does not execute SQL, Swift, or native UI.
        admitted = admit_candidates(core.bounded_json(source_file(core, declaration['candidates_file']), 4 * 1024 * 1024))
        verify_original_candidates(core, admitted)
        directory, catalog = previous_prepare(config, installation)
        context['reader_catalog_sha256'] = core.digest(directory / 'catalog.json')
        context['directory'], context['catalog'] = prepare(core, config, installation, core_source=core_source)
        bindings = []
        for row in context['catalog']['scales']:
            target = row['target']; name = target['sourceFile']
            original = context['directory'] / name; native_path = directory / name
            require(original.parent == context['directory'] and native_path.parent == directory
                and name.startswith('natural-inspector-') and not native_path.exists(),
                'Add only fresh separately named original source files beside the immutable Reader catalog')
            os.link(original, native_path, follow_symlinks=False)
            require(original.samefile(native_path) and core.digest(native_path) == target['sourceSHA256'],
                'Native source lookup must use the exact qualified oracle bytes')
            bindings.append({'original': core.witness(original), 'nativeComparatorPath': core.witness(native_path),
                'sameInode': True, 'scope': 'Hardlink of source-oracle text only; no database or original Reader catalog mutation'})
        core.write(context['directory'] / 'native-source-file-bindings.json', bindings)
        require(core.digest(directory / 'catalog.json') == context['reader_catalog_sha256'],
            'The original ten-target Reader catalog must remain byte-identical')
        return directory, catalog

    class NaturalInspectorHost(previous_host):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            require('catalog' in context, 'Actual natural catalog must precede the native observation host')
            self.original_reader_targets = dict(self.targets)
            self.natural_directory, self.natural_catalog = context['directory'], context['catalog']
            self.natural_scales = {row['target']['key']: row for row in self.natural_catalog['scales']}
            self.natural_identity_proofs = {}
            require(len(self.original_reader_targets) == 10 and len(self.natural_scales) == 3
                and not set(self.original_reader_targets).intersection(self.natural_scales),
                'Natural Inspector targets cannot replace an original Reader target')
            self.targets.update({key: row['target'] for key, row in self.natural_scales.items()})

        def environment(self):
            result = super().environment()
            path = self.natural_directory / 'natural-inspector-targets.json'
            result.update(TEST_RUNNER_FULL_V40_NATURAL_INSPECTOR_CATALOG_FILE=str(path),
                TEST_RUNNER_FULL_V40_NATURAL_INSPECTOR_CATALOG_SHA256=core.digest(path))
            return result

        def begin(self, request):
            if request.get('kind', '').startswith('reader-'):
                require(request.get('targetKey') in self.original_reader_targets,
                    'Additional Inspector targets cannot enter the original twenty-open Reader schedule')
            return super().begin(request)

        def complete_reader(self, request):
            original_targets = self.targets
            self.targets = self.original_reader_targets
            try: return super().complete_reader(request)
            finally: self.targets = original_targets

        def validate_inspector(self, request, container):
            result = super().validate_inspector(request, container)
            record = self.inspector_records[result['requestID']]
            target = self.natural_scales.get(record['target_key'])
            if target is not None:
                try:
                    proof = match_native_projection(target, record, result)
                    proof['naturalCatalog'] = core.witness(self.natural_directory / 'natural-inspector-targets.json')
                    core.write(core.OUT / 'natural-inspector-membership-proofs' / (result['requestID'] + '.json'), proof)
                    self.natural_identity_proofs[result['requestID']] = proof
                    result.update(naturalFullMembershipMatched=True,
                        naturalIdentityProjectionSHA256=target['identityProjectionSHA256'],
                        independentCompleteMembershipSHA256=target['rawMembershipSHA256'])
                except Exception as error:
                    core.write(core.OUT / 'natural-inspector-membership-proofs' / (result['requestID'] + '.failed.json'),
                        {'status': 'NATIVE_FULL_MEMBERSHIP_MISMATCH_NOT_ACCEPTED',
                            'requestID': result['requestID'], 'errorType': type(error).__name__})
                    raise
            return result

        def handle(self, request, container):
            if request.get('action') == 'complete_inspector':
                rows = request.get('scales', [])
                require(len(rows) == 3 and [row.get('requestedCount') for row in rows] == SCALES,
                    'Retain all three separately attributed complete natural observations')
                for row in rows:
                    target = self.natural_scales.get(row.get('targetKey'))
                    require(target is not None and row.get('actualCount') == target['originalMetadataCount']
                        and target['requestedCount'] == row.get('requestedCount')
                        and row['actualCount'] >= row['requestedCount'] and row.get('naturalCatalogSHA256')
                        == core.digest(self.natural_directory / 'natural-inspector-targets.json'),
                        'Native actual full cache count must match its own qualified original service target')
                    record = self.inspector_records.get(row.get('observationID'))
                    require(record is not None and record.get('target_key') == row['targetKey']
                        and record.get('full_cached_count') == target['originalMetadataCount'],
                        'Each scale must bind its genuine original cache observation and whole natural unit')
                    proof = self.natural_identity_proofs.get(row.get('observationID'))
                    require(proof is not None and row.get('nativeFullMembershipMatched') is True
                        and row.get('nativeOrderedIdentitySHA256') == proof['nativeOrderedIdentitySHA256']
                        and row.get('independentCompleteMembershipSHA256') == target['rawMembershipSHA256'],
                        'Each native scale must retain its complete original identity comparison, not only its count')
            return super().handle(request, container)

    core.prepare_catalog, core.ObservationHost = prepare_both, NaturalInspectorHost
    core._natural_inspector_installed = True
