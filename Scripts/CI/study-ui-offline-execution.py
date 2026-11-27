#!/usr/bin/env python3
"""Join one original full-v40 page case to a separately coordinated host window.

No import effects, owner approval generation, database/index installation, or
prerequisite override. Root owns the real run and calls the staged API. The
validator is also usable by the future prerequisite hook, after admission of
this producer contract; it does not itself edit that gate.
"""
from __future__ import annotations

import base64
import datetime as dt
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import stat
import sys
import time
import uuid

SCHEMA = 'otzaria.original-full-v40-offline-case/1'
CASE_PASS = 'ORIGINAL_FULL_V40_PAGES_WITH_OBSERVED_NETWORK_DENIAL_PASS'
SUITE_PASS = 'BOTH_ORIGINAL_FULL_V40_SEARCH_ENGINES_WITH_OBSERVED_NETWORK_DENIAL_PASS'
OFFLINE_PHASE_PASS = 'EXACT_REGISTERED_FULL_V40_OFFLINE_PHASE_UI_PASS'
OFFLINE_NETWORK_SCOPE = 'Observed owned host network denial; original Simulator UI'
TARGET = 'Maktabah-iOSUITests'
CASES = {
    'zayit': 'PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity',
    'otzaria': 'PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata',
}
PAGES = {'zayit': (3, 50), 'otzaria': (2, 100)}
SOURCES = [
    'Scripts/CI/study-ui-offline-execution.py', 'Scripts/CI/study-ui-offline-window.py',
    'Scripts/CI/study-ui-offline-heartbeat.py', 'Scripts/CI/OfflineTransportProbe.swift',
    'Scripts/CI/build-offline-transport-probe.py', 'Scripts/CI/runtime27_interruption.py',
    'Scripts/CI/study-ui-settings-receipts.py', 'Scripts/CI/study-ui-prerequisites.py',
    'Scripts/CI/production-study-v40-ui.py',
]
QUERY_SHA = hashlib.sha256('בראשית'.encode()).hexdigest()
MAX_JSON = 16 * 1024 * 1024
NATIVE_STOP_RESERVE_SECONDS = 240
ROOT_PRIVATE_BASE = Path('/Library/Application Support/OtzariaOffline')


def require(value, message):
    if not value:
        raise ValueError(message)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def uuid_string(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value, 'Require canonical original UUID')
    return value


def strict_json(raw):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, 'Duplicate evidence JSON key')
            result[key] = value
        return result
    def invalid(value):
        raise ValueError('Nonfinite evidence JSON')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'), allow_nan=False)


def load_support(root, name):
    path = Path(root) / 'Scripts/CI' / name
    spec = importlib.util.spec_from_file_location('offline_join_' + name.replace('-', '_').replace('.', '_'), path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def execution_sources(core, settings):
    records = {}
    for relative in SOURCES:
        path = Path(core.ROOT) / relative
        require(core.git('hash-object', str(path)) == core.git('rev-parse', 'HEAD:' + relative),
                'Offline execution source is not the current committed file: ' + relative)
        records[relative] = settings.witness(path)
    return records


def validate_pages(payload, engine):
    """Repeat the actual original test's identity joins, never invent SQL rows."""
    require(engine in CASES and isinstance(payload, dict), 'Wrong original page engine')
    events, sql = payload.get('events'), payload.get('independentSQL')
    require(isinstance(events, list) and events and isinstance(sql, dict), 'No original source/SQL page attachment')
    providers = [e for e in events if e.get('event') == 'provider']
    publications = [e for e in events if e.get('event') == 'published']
    count, size = PAGES[engine]
    require(len(providers) == count and publications, 'Missing or extra original source page')
    namespaces = {e.get('namespace') for e in events}
    sessions = {e.get('sessionID') for e in events}
    pids = {e.get('processID') for e in events}
    require(len(namespaces) == len(sessions) == len(pids) == 1, 'Page identity is ambiguous')
    namespace = uuid_string(next(iter(namespaces)))
    session = uuid_string(next(iter(sessions)))
    pid = next(iter(pids)); require(integer(pid, 2), 'Original page process is absent')
    require(all(e.get('schemaVersion') == 1 and e.get('event') in ('provider', 'published')
                and e.get('engine') == engine and e.get('profileID') == 'production' for e in events),
            'Page event uses another engine or profile')
    order, source, retained = [], {}, {}
    for index, event in enumerate(providers):
        request, page = event.get('request', {}), event.get('page', {})
        require(event.get('submissionRevision') == 1 and request.get('querySHA256') == QUERY_SHA
                and 'query' not in request and request.get('offset') == index * size
                and request.get('limit') == size and event.get('nextOffset') == (index + 1) * size,
                'Original query, page placement or revision differs')
        rows = page.get('hits' if engine == 'zayit' else 'results')
        require(isinstance(rows, list) and len(rows) == size, 'Incomplete actual provider page')
        for row in rows:
            if engine == 'zayit':
                book, line, line_id = row.get('book_id'), row.get('line_index'), row.get('line_id')
                require(integer(book, 1) and integer(line) and integer(line_id, 1), 'Untyped source hit')
                identifier = 'zayit:production:' + str(line_id)
                title = row.get('book_title')
            else:
                path = row.get('filePath', '')
                require(isinstance(path, str) and re.fullmatch(r'otzaria-book:[1-9][0-9]*', path), 'Noncanonical book path')
                book, line, result_id = int(path.split(':')[1]), row.get('segment'), row.get('id')
                require(integer(line) and integer(result_id), 'Untyped original result identity')
                identifier = 'otzaria:' + path + ':' + str(result_id) + ':' + str(line)
                title = row.get('title')
            original = sql.get(identifier)
            require(isinstance(original, dict) and integer(original.get('lineID'), 1)
                    and original.get('bookID') == book and original.get('lineIndex') == line
                    and original.get('bookTitle') == title and original.get('reference') == (row.get('reference') or ''),
                    'Provider metadata does not equal its independently captured actual SQL row')
            if engine == 'zayit':
                require(original['lineID'] == line_id, 'Zayit ID does not address the original SQL line')
            require(identifier not in source, 'Duplicate source identity across actual pages')
            order.append(identifier); source[identifier] = row
        if engine == 'zayit':
            require(event.get('accumulatedSource') == [source[k] for k in order], 'Earlier Zayit metadata changed')
        else:
            records = event.get('retainedRecords')
            require(isinstance(records, list) and len(records) == len(order), 'Incomplete accumulated Otzaria page')
            for identifier, record in zip(order, records):
                require(record.get('metadata') == source[identifier] and isinstance(record.get('item'), dict), 'Earlier Otzaria metadata changed')
                item = record['item']
                require(identifier not in retained or retained[identifier] == item, 'Published item changed between pages')
                retained[identifier] = item
    require(set(sql) == set(order) and len(order) == count * size, 'SQL does not cover exactly all original results')
    loaded, seen_counts = 0, set()
    for event in events:
        if event['event'] == 'provider':
            loaded += size
            continue
        items = event.get('items')
        require(isinstance(items, list) and len(items) in [size * i for i in range(1, count + 1)]
                and len(items) <= loaded and [v.get('id') for v in items] == order[:len(items)],
                'A published page is missing, premature or not the original accumulated order')
        seen_counts.add(len(items))
        for item in items:
            identifier = item['id']; original, raw = sql[identifier], source[identifier]
            require(item.get('bookID') == original['bookID'] and item.get('lineIndex') == original['lineIndex']
                    and item.get('bookTitle') == original['bookTitle'] and item.get('reference') == (raw.get('reference') or '')
                    and item.get('locator') == 'otzaria|book:' + str(original['bookID']) + '|line:' + str(original['lineIndex']),
                    'Original published locator/metadata is not the independently observed SQL tuple')
            if engine == 'zayit':
                require(item.get('highlightTerms') == raw.get('matched_terms'), 'Matched terms changed')
            else:
                require(item == retained[identifier], 'Published Otzaria item differs from retained original metadata')
    require(seen_counts == {size * i for i in range(1, count + 1)} and len(publications[-1]['items']) == count * size,
            'Every requested visible cumulative page must have its own original publication')
    return {'engine': engine, 'namespace': namespace, 'sessionID': session, 'processID': pid,
            'pageCount': count, 'pageSize': size, 'visibleCumulativeCounts': [size * i for i in range(1, count + 1)],
            'resultCount': len(order), 'canonicalIdentitySHA256': hashlib.sha256(canonical(order).encode()).hexdigest()}


def validate_native_budget(attempt, interval, case_id, lease, budget):
    require(isinstance(attempt, dict) and attempt.get('case') == case_id.removeprefix(TARGET + '/'), 'Wrong original native attempt')
    command = attempt.get('command')
    require(isinstance(command, list) and command[:2] == ['xcodebuild', 'test-without-building']
            and [arg for arg in command if arg.startswith('-only-testing:')] == ['-only-testing:' + case_id],
            'Native callback did not invoke exactly the original selector')
    require(attempt.get('xcodebuild_exit') == 0, 'Original xcodebuild did not pass')
    require(attempt.get('allowance_seconds') == 1800, 'Original registered XCTest allowance changed')
    for flag in ('-default-test-execution-time-allowance', '-maximum-test-execution-time-allowance'):
        require(command.count(flag) == 1 and command[command.index(flag) + 1] == '1800',
                'Original XCTest allowance must remain 1800; only the host timeout may be bounded')
    require(command.count('-test-timeouts-enabled') == 1
            and command[command.index('-test-timeouts-enabled') + 1] == 'YES', 'Original XCTest timeout behavior changed')
    start, end = attempt.get('started_at_unix'), attempt.get('finished_at_unix')
    require(all(finite(v) for v in (start, end, interval.get('startedUnix'), interval.get('finishedUnix')))
            and interval['startedUnix'] <= start <= end <= interval['finishedUnix']
            and end < lease['hardDeadlineUnix'], 'Actual native command is outside its observed denied interval')
    timeout, calculated = budget.get('hostTimeoutSeconds'), budget.get('calculatedAtUnix')
    require(integer(timeout, 1) and finite(calculated) and interval['startedUnix'] <= calculated <= start
            and budget.get('finishReserveSeconds') == NATIVE_STOP_RESERVE_SECONDS
            and budget.get('hardDeadlineUnix') == lease['hardDeadlineUnix']
            and timeout == math.floor(lease['hardDeadlineUnix'] - calculated - NATIVE_STOP_RESERVE_SECONDS)
            and attempt.get('host_timeout_seconds') == timeout,
            'Actual root native timeout is not the fresh calculated remaining window budget')
    require('-destination' in command and command[command.index('-destination') + 1]
            == 'platform=iOS Simulator,id=' + lease['simulatorUDID'], 'Native callback uses another Simulator')


def validate_transport(proof, *, engine, lease, page_identity, window_module, expected_image_path=None):
    case_id = TARGET + '/' + CASES[engine]
    require(proof.get('schema') == window_module.VERSION
            and proof.get('status') == 'TRANSPORT_WINDOW_OBSERVED_ORIGINAL_NATIVE_JOIN_STILL_REQUIRED'
            and proof.get('windowID') == lease['windowID'] and proof.get('simulatorUDID') == lease['simulatorUDID']
            and proof.get('selectedCaseID') == case_id and proof.get('sourceSHA256') == lease['controllerSourceSHA256']
            and proof.get('physicalAirplaneMode') is False, 'Wrong actual transport producer/window')
    activation, cleanup, unloaded = proof.get('activation', {}), proof.get('cleanup', {}), proof.get('unloaded', {})
    intervals = proof.get('nativeIntervals')
    require(isinstance(intervals, list) and len(intervals) == 1, 'Exactly one native interval is required')
    interval = intervals[0]
    require(interval.get('caseID') == case_id and interval.get('callbackReturned') is True, 'Wrong original native interval')
    chain = [activation.get('observedUnix'), interval.get('startedUnix'), interval.get('finishedUnix'), cleanup.get('cleanupUnix')]
    require(all(finite(v) for v in chain) and chain == sorted(chain) and chain[0] < chain[-1]
            and lease['notBeforeUnix'] <= chain[0] and chain[-1] <= lease['hardDeadlineUnix'],
            'Native actions are not wholly bracketed by the actual bounded denial')
    mono = [activation.get('observedMonotonic'), interval.get('startedMonotonic'), interval.get('finishedMonotonic'), cleanup.get('cleanupMonotonic')]
    require(all(finite(v) for v in mono) and mono == sorted(mono) and mono[-1] - mono[0] <= window_module.MAX_DENIAL_SECONDS,
            'Monotonic native/denial ordering differs')
    require(cleanup.get('status') == 'OWNED_RULES_EMPTY_ROLLBACK_VERIFIED'
            and cleanup.get('mode') == 'network-denial' and cleanup.get('reason') == 'normal-finish-requested'
            and cleanup.get('activated') is True and cleanup.get('windowID') == lease['windowID']
            and cleanup.get('onlyOwnedAnchor') == window_module.anchor_name(lease['windowID'])
            and unloaded.get('status') == 'OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY'
            and unloaded.get('originalConfigurationMatches') is True and unloaded.get('windowID') == lease['windowID'],
            'Actual rollback/unload/original-configuration restoration did not complete')
    history = [row for row in cleanup.get('history', []) if row.get('active') is True]
    require(history and history[0]['observedMonotonic'] <= mono[1] and history[-1]['observedMonotonic'] >= mono[2],
            'Actual watchdog observations do not cover the native action interval')
    times = [mono[0], *[row['observedMonotonic'] for row in history], mono[-1]]
    require(all(finite(v) for v in times) and all(0 <= b - a <= window_module.MAX_WATCHDOG_GAP for a, b in zip(times, times[1:])),
            'Actual watchdog coverage has a missing or reversed interval')
    for row in history:
        require(re.fullmatch(r'[a-f0-9]{32}', row.get('heartbeatNonce', '')), 'Observed watchdog heartbeat is missing')
    samples = proof.get('samples')
    require(isinstance(samples, list) and samples, 'No actual application/process observation')
    sample_times = [row.get('observedMonotonic') for row in samples]
    require(all(finite(v) and mono[0] <= v <= mono[-1] for v in sample_times) and sample_times[0] <= mono[1]
            and mono[2] - sample_times[-1] <= window_module.MAX_WATCHDOG_GAP
            and all(0 <= b - a <= window_module.MAX_WATCHDOG_GAP for a, b in zip(sample_times, sample_times[1:])),
            'Application observation does not continuously bracket the original case')
    matching = []
    for row in samples:
        require(finite(row.get('observedUnix')) and chain[0] <= row['observedUnix'] <= chain[-1],
                'Application observation is outside the actual denied window')
        watchdog = row.get('watchdog', {})
        require(watchdog.get('active') is True and watchdog.get('originalUnchanged') is True
                and watchdog.get('ownRulesMatch') is True
                and 0 <= row['observedMonotonic'] - watchdog.get('observedMonotonic', -1) <= window_module.MAX_WATCHDOG_GAP,
                'Actual sampled denial rule/state is unqualified')
        apps = row.get('applications')
        require(isinstance(apps, list) and len(apps) <= 1, 'Ambiguous app process during the original cold lifecycle')
        for app in apps:
            if app.get('processID') != page_identity['processID']:
                continue
            args = app.get('arguments', [])
            require(args.count('-GlobalSearchNativeTraceNamespace') == 1
                    and args[args.index('-GlobalSearchNativeTraceNamespace') + 1] == page_identity['namespace']
                    and '-studyWorkspaceTestingNamespace' not in args and '-smokeBypassBootstrap' not in args,
                    'Page namespace is not the original production process launch')
            image = app.get('processImagePath', '')
            require('/Devices/' + lease['simulatorUDID'] + '/data/' in image and Path(image).name == 'Maktabah',
                    'Page process image belongs to another Simulator/application')
            if expected_image_path is not None:
                require(image == expected_image_path, 'Page process differs from the actual qualified Mach-O path')
            started = dt.datetime.strptime(app['startUTC'], '%a %b %d %H:%M:%S %Y').replace(tzinfo=dt.timezone.utc).timestamp()
            # ps lstart has whole-second resolution. The original test performs
            # a cold launch inside the callback; no older online process counts.
            require(started + 1 >= interval['startedUnix'] and started <= row['observedUnix'] + 1
                    and row['observedUnix'] >= interval['startedUnix'],
                    'A preexisting online application process cannot qualify offline pages')
            if interval['startedUnix'] <= row['observedUnix'] <= interval['finishedUnix'] \
                    and mono[1] <= row['observedMonotonic'] <= mono[2]:
                matching.append(app)
    require(matching and len({canonical(v) for v in matching}) == 1, 'No unique fresh source-qualified original page process')
    rows = proof.get('probes')
    require(isinstance(rows, list) and rows, 'Actual transport requests are absent')
    counts, probe_nonces = {}, set()
    for row in rows:
        value = row.get('probe', {})
        phase, kind, endpoint = value.get('phase'), value.get('environment'), value.get('endpoint')
        require(re.fullmatch(r'[a-f0-9]{32}', value.get('nonce', '')) and value['nonce'] not in probe_nonces,
                'Each actual transport request requires its own unreplayed nonce')
        probe_nonces.add(value['nonce'])
        require(phase in ('before', 'during', 'after') and kind in ('host', 'simulator') and endpoint in window_module.ENDPOINTS,
                'Unknown actual probe scope')
        window_module.probe_valid(value, phase=phase, kind=kind, udid=lease['simulatorUDID'], nonce=value.get('nonce'), endpoint=endpoint)
        require(value.get('windowID') == lease['windowID'] and row['commandStartedUnix'] <= value['startedUnix']
                <= value['finishedUnix'] <= row['commandFinishedUnix'], 'Probe does not belong to its actual command/window')
        if phase == 'before': require(value['finishedUnix'] <= chain[0], 'Online positive control overlaps denial')
        if phase == 'during': require(chain[0] <= value['startedUnix'] <= value['finishedUnix'] <= chain[-1], 'Negative request is outside denial')
        if phase == 'after': require(value['startedUnix'] >= cleanup['cleanupUnix'] and value['startedUnix'] >= unloaded['observedUnix'], 'Restoration control preceded cleanup')
        counts[(phase, kind, endpoint)] = counts.get((phase, kind, endpoint), 0) + 1
    for kind in ('host', 'simulator'):
        for endpoint in window_module.ENDPOINTS:
            require(counts.get(('before', kind, endpoint)) == counts.get(('after', kind, endpoint)) == 1
                    and counts.get(('during', kind, endpoint), 0) >= 2, 'Missing initial/final genuine request round')
    require(window_module.blocking_packets(history[-1]['counters'], lease['windowID'])
            > window_module.blocking_packets(history[0]['counters'], lease['windowID']), 'No increasing actual owned block packets')
    return {'caseID': case_id, 'nativeInterval': interval, 'pageProcess': matching[0],
            'watchdogObservationCount': len(history), 'applicationObservationCount': len(samples),
            'actualTransportRequestCount': len(rows), 'scope': 'Original Simulator pages during a host network-denial window; no physical-airplane-mode claim'}


def validate_probe_build(row, compiled, *, source_sha, driver_sha):
    """Repeat the original probe runner's compile/SDK binding on later readback."""
    kind = row['probe']['environment']
    require(kind in ('host', 'simulator') and compiled.get('schema') == 'otzaria.independent-foundation-probe-build/1'
            and compiled.get('status') == 'COMPILED_ONLY_NO_NETWORK_OR_NATIVE_UI'
            and compiled.get('source') == row['source'] and row['source']['sha256'] == source_sha
            and compiled.get('compilerDriverSource', {}).get('sha256') == driver_sha
            and compiled.get('originalSourceUnchanged') is True, 'Probe build is not the original current source/driver')
    builds = [entry for entry in compiled.get('builds', []) if entry.get('kind') == kind]
    require(len(builds) == 1 and builds[0].get('exit') == 0 and builds[0].get('codeSignVerify', {}).get('exit') == 0
            and builds[0].get('binary') == row['binary'] and builds[0].get('sdkVersion') == '27.0'
            and builds[0].get('actualPlatform') == ('IOSSIMULATOR' if kind == 'simulator' else 'MACOS')
            and builds[0].get('command', [])[:4] == ['xcrun', '--sdk', 'iphonesimulator' if kind == 'simulator' else 'macosx', 'swiftc'],
            'Probe binary/signature/SDK/platform differs from the actual qualified compilation')


def validate_coordination(value, lease, now):
    """Admit an explicit owner's attestation; never synthesize paused approvals."""
    require(value.get('schema') == 'otzaria.coordinated-mac-network-window/1'
            and value.get('status') == 'ALL_LISTED_OWNERS_PAUSED'
            and value.get('windowID') == lease['windowID']
            and value.get('hardDeadlineUnix') == lease['hardDeadlineUnix']
            and value.get('selectedCaseID') == lease['selectedCaseID']
            and value.get('simulatorUDID') == lease['simulatorUDID'], 'No matching explicit coordinated owner window')
    require(finite(value.get('observedAtUnix')) and 0 <= now - value['observedAtUnix'] <= 120,
            'Owner coordination must be fresh at preparation, never renewed implicitly')
    owners = value.get('owners')
    require(isinstance(owners, list) and len(owners) >= 2
            and {row.get('ownerID') for row in owners} == set(lease['coordinatingOwners'])
            and len(owners) == len(lease['coordinatingOwners']), 'All original concurrent owners must explicitly acknowledge')
    for row in owners:
        require(row.get('paused') is True and row.get('windowID') == lease['windowID']
                and finite(row.get('acknowledgedAtUnix'))
                and 0 <= value['observedAtUnix'] - row['acknowledgedAtUnix'] <= 120
                and isinstance(row.get('originalAcknowledgement'), dict), 'Missing original owner pause acknowledgement')
    return value


# This future runtime operation READS only exact root-owned receipt files. It
# accepts neither arbitrary paths nor source code from the coordination lease.
# Raw addresses/commands remain in a private output directory, never public Git.
ROOT_RECEIPT_READER = r'''
from pathlib import Path
import base64,hashlib,json,os,re,stat,sys
ids=json.loads(sys.argv[1]);assert type(ids) is list and 1<=len(ids)<=4 and len(set(ids))==len(ids)
base=Path('/Library/Application Support/OtzariaOffline');result={};total=0
for identifier in ids:
 assert type(identifier) is str and re.fullmatch('[a-f0-9]{32}',identifier)
 directory=base/identifier;rows={}
 for name in ['sealed.json','armed.json','cleanup.json','unloaded.json','heartbeat.json','watchdog.py']:
  path=directory/name
  if name=='heartbeat.json' and not path.exists():continue
  assert path.resolve(strict=True)==path
  for parent in [path,*path.parents]:
   st=parent.lstat();assert st.st_uid==0 and not st.st_mode&0o022 and not stat.S_ISLNK(st.st_mode)
  before=path.lstat();assert stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_size<=4*1024*1024
  data=path.read_bytes();after=path.lstat()
  keys=lambda s:(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
  assert keys(before)==keys(after) and len(data)==before.st_size
  total+=len(data);assert total<=16*1024*1024
  rows[name]={'sourcePath':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'rawBase64':base64.b64encode(data).decode(),
              'device':before.st_dev,'inode':before.st_ino,'mode':stat.S_IMODE(before.st_mode),'uid':before.st_uid,
              'mtimeNs':before.st_mtime_ns,'ctimeNs':before.st_ctime_ns}
 result[identifier]=rows
print(json.dumps(result))
'''


def root_document(exports, identifier, name):
    record = exports[identifier][name]
    require(record.get('sourcePath') == str(ROOT_PRIVATE_BASE / identifier / name)
            and record.get('uid') == 0 and integer(record.get('mode')) and not record['mode'] & 0o022,
            'Private watchdog receipt has another path or owner')
    raw = base64.b64decode(record['rawBase64'], validate=True)
    require(len(raw) == record['bytes'] and hashlib.sha256(raw).hexdigest() == record['sha256'], 'Private root receipt bytes changed')
    return raw if name.endswith('.py') else strict_json(raw)


def validate_root_receipts(exports, lease, deployment, proof):
    identifier, source = lease['windowID'], lease['controllerSourceSHA256']
    sealed = root_document(exports, identifier, 'sealed.json')
    cleanup = root_document(exports, identifier, 'cleanup.json')
    unloaded = root_document(exports, identifier, 'unloaded.json')
    require(deployment.get('windowID') == identifier
            and deployment.get('privateDirectory') == str(ROOT_PRIVATE_BASE / identifier)
            and deployment.get('sealedSHA256') == exports[identifier]['sealed.json']['sha256'], 'Deployment/sealed receipt identity differs')
    require(sealed.get('lease') == lease and sealed.get('sourceSHA256') == source
            and sealed.get('controller', {}).get('pid') == lease['controllerPID']
            and hashlib.sha256(root_document(exports, identifier, 'watchdog.py')).hexdigest() == source,
            'The actual root-owned watchdog/source/controller does not equal this lease')
    require(cleanup == proof['cleanup'] and unloaded == proof['unloaded'], 'Transport proof did not use the original root cleanup/unload')
    armed = root_document(exports, identifier, 'armed.json')
    require(integer(armed.get('watchdog', {}).get('pid'), 2), 'No original armed watchdog process')
    expected = {'controller-death': 'controller-identity-missing', 'deadline': 'hard-deadline',
                'heartbeat-loss': 'authenticated-oracle-heartbeat-expired'}
    receipts = lease.get('watchdogExerciseReceipts')
    require(isinstance(receipts, dict) and set(receipts) == set(expected), 'Three actual no-denial exercise receipts are required')
    exercised = []
    for kind, reason in expected.items():
        witness = receipts[kind]; path = Path(witness['path']); own = path.parent.name
        require(path == ROOT_PRIVATE_BASE / own / 'cleanup.json' and re.fullmatch(r'[a-f0-9]{32}', own)
                and own != identifier and own not in exercised, 'Reused or foreign watchdog exercise')
        exercised.append(own)
        require({key: exports[own]['cleanup.json'][key] for key in ('bytes', 'sha256')}
                == {key: witness[key] for key in ('bytes', 'sha256')}, 'Original exercise receipt changed')
        old, done, stopped = (root_document(exports, own, name) for name in ('sealed.json', 'cleanup.json', 'unloaded.json'))
        require(old.get('sourceSHA256') == source and old.get('bootSession') == sealed.get('bootSession')
                and old.get('lease', {}).get('mode') == done.get('mode') == 'watchdog-exercise-no-denial'
                and hashlib.sha256(root_document(exports, own, 'watchdog.py')).hexdigest() == source
                and done.get('reason') == reason and done.get('activated') is False
                and done.get('status') == 'OWNED_RULES_EMPTY_ROLLBACK_VERIFIED'
                and done.get('attempts') and all(row.get('exit') == 0 and row.get('rulesBeforeSHA256') == hashlib.sha256(b'').hexdigest() for row in done['attempts'])
                and all(row.get('active') is False and row.get('counters') == '' for row in done.get('history', []))
                and stopped.get('status') == 'OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY'
                and stopped.get('originalConfigurationMatches') is True
                and integer(root_document(exports, own, 'armed.json').get('watchdog', {}).get('pid'), 2),
                'A synthetic/no-op/other-source exercise cannot qualify actual watchdog recovery')
    require(set(exports) == {identifier, *exercised}, 'Unexpected private watchdog receipt scope')
    return {'activeWindow': identifier, 'sameSourceSameBootExerciseWindows': exercised,
            'actualController': sealed['controller'], 'actualWatchdog': armed['watchdog']}


def validate_relay(raw, lease, proof, root_exports, expected_source_sha):
    rows = [strict_json(line) for line in raw.decode().splitlines() if line.strip()]
    require(2 <= len(rows) <= 200 and [r.get('sequence') for r in rows] == list(range(len(rows))), 'Incomplete original Oracle heartbeat sequence')
    require(len({r.get('relayProcessID') for r in rows}) == 1 and integer(rows[0].get('relayProcessID'), 2), 'Ambiguous Oracle relay process')
    nonces, previous = {}, -1
    for row in rows:
        require(row.get('windowID') == lease['windowID'] and row.get('relaySourceSHA256') == expected_source_sha
                and row.get('exit') == 0 and row.get('stderrSHA256') == hashlib.sha256(b'').hexdigest()
                and finite(row.get('startedUnix')) and finite(row.get('finishedUnix'))
                and previous <= row['startedUnix'] <= row['finishedUnix'], 'Wrong, failed or reordered original SSH relay request')
        previous = row['finishedUnix']; remote = row.get('remote', {})
        require(remote.get('windowID') == lease['windowID'], 'Heartbeat was authenticated for another window')
        if 'nonce' in remote:
            require(re.fullmatch(r'[a-f0-9]{32}', remote['nonce']) and remote['nonce'] not in nonces
                    and finite(remote.get('observedUnix')), 'Reused or untyped actual Mac heartbeat')
            nonces[remote['nonce']] = remote
        else:
            require(row is rows[-1] and remote.get('status') == 'WINDOW_ALREADY_CLEANED'
                    and remote.get('cleanupSHA256') == root_exports[lease['windowID']]['cleanup.json']['sha256'],
                    'Oracle relay did not observe the actual cleaned window')
    require(rows[-1]['remote'].get('status') == 'WINDOW_ALREADY_CLEANED', 'Original Oracle relay completion is unverified')
    history = [r for r in proof['cleanup']['history'] if r.get('active') is True]
    require(history and all(row.get('heartbeatNonce') in nonces for row in history), 'Watchdog nonce was not emitted by the original Oracle relay')
    actual_heartbeat = root_document(root_exports, lease['windowID'], 'heartbeat.json')
    require(actual_heartbeat.get('nonce') in nonces
            and nonces[actual_heartbeat['nonce']]['observedUnix'] == actual_heartbeat.get('observedUnix'),
            'Actual root-owned Mac heartbeat does not match the remote response nonce/time')
    return {'relayProcessID': rows[0]['relayProcessID'], 'authenticatedRequests': len(nonces),
            'actualCleanedWindowReply': rows[-1]['remote'],
            'clockDomains': {'requestIntervals': 'Oracle local wall clock', 'remoteObservedUnix': 'Mac local wall clock',
                             'crossHostWallClockBracketingClaimed': False},
            'actualMacHeartbeatNonce': actual_heartbeat['nonce']}



class OfflineStudyCase:
    """New helper only. Root retains Simulator lifetime and original exporters.

    root_report is the already admitted current controller report after
    installation_before is set. callback(host_timeout_seconds) invokes only
    run_original_native_actions; XCTest arguments/allowances remain original.
    """
    def __init__(self, *, core, settings, retained_owner, root_report, engine, case_directory,
                 output_directory, private_lease, coordination_receipt, simulator_probe,
                 host_probe, image_path_resolver, on_prepared):
        require(sys.platform == 'darwin' and os.geteuid() != 0, 'Only the original Mac user may coordinate a real case')
        require(engine in CASES, 'Unsupported original offline case')
        self.core, self.settings, self.owner = core, settings, retained_owner
        self.report = json.loads(json.dumps(root_report))
        self.engine, self.case_id = engine, TARGET + '/' + CASES[engine]
        require(self.report.get('study_phase') == 'offline-' + engine
                and self.report.get('selected_case_ids') == [CASES[engine]], 'Root phase must select exactly this original offline case')
        self.source, self.build = self.report['source_before'], self.report['build_before']
        self.udid = uuid_string(self.report['reused_external_owned_simulator'])
        self.output = Path(output_directory)
        require(not self.output.exists() and self.output.is_absolute() and self.output.is_relative_to(Path(core.OUT)), 'Use a new owned private evidence directory')
        self.output.mkdir(mode=0o700)
        require(self.output.resolve() == self.output, 'Private output is redirected')
        self.case_directory = Path(case_directory)
        require(not self.case_directory.exists() and self.case_directory.parent == Path(core.OUT), 'Original case needs its own new root-owned case directory')
        self.sources = execution_sources(core, settings)
        prerequisites = load_support(core.ROOT, 'study-ui-prerequisites.py')
        self.evidence = prerequisites.Evidence(core=core, settings=settings, udid=self.udid,
            source=self.source, build=self.build, installation_result=self.report['original_installation']['result'])
        self.evidence.retained_owner(self.report)
        self.evidence.installation_admission(self.report['installation_before'])
        self.window_module = load_support(core.ROOT, 'study-ui-offline-window.py')
        self.lease_record = settings.witness(private_lease)
        self.lease = self.window_module.admit_lease(settings.decode_json(settings.verify_witness(self.lease_record)),
            self.sources['Scripts/CI/study-ui-offline-window.py']['sha256'])
        require(self.lease['controllerPID'] == os.getpid() and self.lease['selectedCaseID'] == self.case_id
                and self.lease['simulatorUDID'] == self.udid and self.lease['mode'] == 'network-denial', 'Lease is not this actual original controller/selector')
        self.coordination_record = dict(coordination_receipt)
        self.coordination = validate_coordination(settings.decode_json(settings.verify_witness(coordination_receipt)), self.lease, time.time())
        for row in self.coordination['owners']:
            settings.verify_witness(row['originalAcknowledgement'], MAX_JSON)
        self.on_prepared = on_prepared
        require(callable(on_prepared), 'Oracle rendezvous delivery must be explicitly supplied by the integration owner')
        self.resolve_image = image_path_resolver
        self.window = self.window_module.OfflineWindow(private_lease=private_lease, output_dir=self.output / 'transport',
            simulator_probe=simulator_probe, host_probe=host_probe, image_path_resolver=image_path_resolver)
        self.before = self.snapshot()
        self.native_attempt = self.transport = None
        self.prepared = self.closed = False
        self.write('BEFORE.private.json', self.before)

    def write(self, name, value):
        return self.window_module.private_write(self.output / name, value)

    def actual_owner(self):
        container = Path(self.core.command(['xcrun', 'simctl', 'get_app_container', self.udid,
            self.core.BUNDLE, 'data'], timeout=8).stdout.strip())
        require(container.resolve(strict=True) == container, 'Actual app data container is redirected')
        owner = self.settings.discover_owner(self.udid, container.parent)
        require(owner['dataContainer'] == str(container), 'Actual simctl and original MCM ownership differ')
        self.settings.verified_owner(owner)
        return owner

    def snapshot(self):
        owner = self.actual_owner()
        database = Path(owner['storageRoot']) / 'Otzaria/seforim.db'
        admitted = self.report['installation_before']
        require(admitted['database']['path'] == str(database), 'Package owner differs from the independently admitted v40 database')
        manifest = self.settings.raw_manifest(database.parent / 'seforim-installation.json')
        require({'path': manifest['sourcePath'], 'bytes': manifest['bytes'], 'sha256': manifest['sha256']}
                == admitted['installation_manifest'], 'Original managed-v40 installation manifest changed')
        result = {'owner': owner, 'databaseIdentity': self.settings.file_identity(database),
                  'installationManifest': manifest, 'indexes': self.settings.capture_indexes(owner['storageRoot']),
                  'installedImages': self.owner.verify_installed_images(self.udid, self.build)}
        self.evidence.installed_images(result['installedImages'])
        return result

    def prepare_window(self):
        try:
            return self._prepare_window()
        except BaseException as error:
            try:
                self.record_failure(error)
            finally:
                self.abort()
            raise

    def _prepare_window(self):
        require(not self.prepared, 'Window preparation cannot be repeated')
        validate_coordination(self.coordination, self.lease, time.time())
        self.settings.verify_witness(self.coordination_record)
        self.settings.verify_witness(self.lease_record)
        ready = self.window.prepare()
        self.prepared = True
        rendezvous = {**ready, 'schema': 'otzaria.offline-oracle-rendezvous/1', 'actualControllerPID': os.getpid(),
                      'selectedCaseID': self.case_id, 'simulatorUDID': self.udid,
                      'oracleRelaySource': self.sources['Scripts/CI/study-ui-offline-heartbeat.py'],
                      'coordinationReceipt': self.coordination_record, 'lease': self.lease_record}
        self.write('RENDEZVOUS.private.json', rendezvous)
        # Must notify the already waiting Oracle launcher immediately; it starts
        # a fresh pinned-SSH relay there, never a local Mac heartbeat timer.
        self.on_prepared(rendezvous)
        until = min(time.monotonic() + 12, time.monotonic() + self.lease['hardDeadlineUnix'] - time.time())
        while time.monotonic() < until:
            status = self.window._private('status')
            require('cleanup' not in status and 'rollback-failure' not in status, 'Watchdog ended before independent Oracle control arrived')
            current = status.get('status', {})
            if re.fullmatch(r'[a-f0-9]{32}', current.get('heartbeatNonce', '')) and finite(current.get('heartbeatMonotonic')) \
                    and 0 <= time.monotonic() - current['heartbeatMonotonic'] <= 10:
                return rendezvous
            time.sleep(.2)
        raise ValueError('Fresh actual Oracle heartbeat did not arrive within the sealed preparation budget')

    def run_native_actions(self, callback):
        require(self.prepared and self.native_attempt is None and callable(callback), 'One original callback after successful preparation is required')
        try:
            self.window.activate()
            def actual_actions():
                calculated = time.time()
                remaining = math.floor(self.lease['hardDeadlineUnix'] - calculated - NATIVE_STOP_RESERVE_SECONDS)
                require(remaining > 0, 'No bounded native budget remains after transport controls and the explicit cleanup reserve')
                budget = {'hostTimeoutSeconds': remaining, 'calculatedAtUnix': calculated, 'hardDeadlineUnix': self.lease['hardDeadlineUnix'],
                          'finishReserveSeconds': NATIVE_STOP_RESERVE_SECONDS, 'notAPerformanceSLA': True}
                self.write('NATIVE_BUDGET.private.json', budget)
                return callback(remaining)
            value = self.window.observe_native_case(actual_actions)
            self.native_attempt = json.loads(json.dumps(value))
            require(self.native_attempt.get('case_directory') == str(self.case_directory), 'Callback used a different original case directory')
            command = self.native_attempt.get('command', [])
            require(command.count('-xctestrun') == 1 and command[command.index('-xctestrun') + 1] == self.build['xctestrun']['path'],
                    'Native callback used another test-run image closure')
            validate_native_budget(self.native_attempt, self.window.cases[0], self.case_id, self.lease,
                self.settings.read_json(self.output / 'NATIVE_BUDGET.private.json'))
            require(self.settings.read_json(self.case_directory / 'RUN_ATTEMPT.json') == self.native_attempt,
                    'Native callback result differs from the actual original RUN_ATTEMPT')
            return value
        except BaseException as error:
            try:
                self.record_failure(error)
            finally:
                self.abort()
            raise

    def finish_transport(self):
        require(self.native_attempt is not None and self.transport is None, 'Complete one original native attempt first')
        try:
            self.transport = self.window.finish()
            self.closed = True
            return self.transport
        except BaseException as error:
            try:
                self.record_failure(error)
            finally:
                self.abort()
            raise

    def record_failure(self, error):
        # Do not delete/replace an xcresult on native, export or later failure.
        name = 'FAILURE-' + uuid.uuid4().hex + '.private.json'
        return self.write(name, {'schema': SCHEMA, 'status': 'FAILED_OR_INCOMPLETE', 'caseID': self.case_id,
            'caseDirectory': str(self.case_directory), 'xcresultPath': str(self.case_directory / 'original.xcresult'),
            'xcresultRetained': (self.case_directory / 'original.xcresult').is_dir(),
            'runAttemptRetained': (self.case_directory / 'RUN_ATTEMPT.json').is_file(),
            'errorType': type(error).__name__, 'error': str(error), 'noOfflineAcceptance': True})

    def abort(self):
        self.window.abort()
        require(not self.window.deployed and all(thread is None or not thread.is_alive()
            for thread in (self.window.monitor, self.window.probe_thread)), 'Owned transport cleanup/worker exit is unverified')
        self.closed = True
        return {'verified': True, 'ownedWatchdogUnloaded': True, 'ownedWorkersStopped': True,
                'nativeDirectoryRetained': str(self.case_directory), 'offlineAcceptance': False}

    def seal_case(self, *, oracle_relay_receipt, source_after, build_after):
        """Call after root's unchanged verify_original_case/export, never before."""
        try:
            require(self.closed and self.transport is not None and self.window.finished,
                    'Transport must be completely restored before original exports/postchecks')
            require(source_after == self.source and build_after == self.build and execution_sources(self.core, self.settings) == self.sources,
                    'Current source/test/build/SDK/helper closure changed')
            execution = self.settings.verified_execution(self.case_directory, self.case_id, self.udid, repository_root=self.core.ROOT)
            self.evidence.build_identity(build_after)
            self.evidence.source_identity(source_after, 'full-v40')
            after = self.snapshot()
            require(after['owner'] == self.before['owner'] and after['databaseIdentity'] == self.before['databaseIdentity']
                    and after['installationManifest'] == self.before['installationManifest'], 'Actual MCM/corpus/manifest changed during offline case')
            self.settings.require_retained_indexes(self.before['indexes'], after['indexes'])
            image_before = Path(self.before['installedImages']['Maktabah.app']['installed_app_container']) / 'Maktabah'
            image_after = Path(after['installedImages']['Maktabah.app']['installed_app_container']) / 'Maktabah'
            require(image_before == image_after and self.resolve_image() == str(image_before),
                    'Original qualified app image container moved during the offline case')
            page = self.settings.selected_attachment(self.case_directory / 'captures', self.case_id, self.udid,
                'published-v40-' + self.engine + '-original-pages-and-independent-sql')
            identity = validate_pages(page['contents'], self.engine)
            for engine in CASES:
                attachment = self.settings.selected_attachment(self.case_directory / 'captures', self.case_id, self.udid,
                    'published-v40-' + engine + '-actual-installed-manifest')
                installed = next(row for row in self.before['indexes'] if row['engine'] == engine)['manifest']
                require(self.settings.verify_witness(attachment['file']) == base64.b64decode(installed['rawBase64'], validate=True),
                        'Native manifest attachment differs from the actual retained package')
            proof = self.transport['proof']
            require(self.settings.decode_json(self.settings.verify_witness(self.transport['witness'], MAX_JSON)) == proof,
                    'Actual transport receipt changed')
            joined = validate_transport(proof, engine=self.engine, lease=self.lease, page_identity=identity,
                window_module=self.window_module, expected_image_path=str(image_before))
            validate_native_budget(self.native_attempt, joined['nativeInterval'], self.case_id, self.lease,
                self.settings.read_json(self.output / 'NATIVE_BUDGET.private.json'))
            ids = [self.lease['windowID'], *[Path(v['path']).parent.name for v in self.lease['watchdogExerciseReceipts'].values()]]
            result = self.core.command(['/usr/bin/sudo', '-n', '/usr/bin/python3', '-I', '-B', '-c', ROOT_RECEIPT_READER, json.dumps(ids)], timeout=20)
            require(len(result.stdout.encode()) <= MAX_JSON * 2 and not result.stderr, 'Actual private root receipt export is incomplete')
            root_exports = self.settings.decode_json(result.stdout.encode())
            root_record = self.write('ROOT_WATCHDOG_RECEIPTS.private.json', root_exports)
            deployment = self.settings.read_json(self.window.output / 'DEPLOYMENT.json')
            root_proof = validate_root_receipts(root_exports, self.lease, deployment, proof)
            relay_proof = validate_relay(self.settings.verify_witness(oracle_relay_receipt, MAX_JSON), self.lease, proof,
                root_exports, self.sources['Scripts/CI/study-ui-offline-heartbeat.py']['sha256'])
            self.evidence.reverify_files()
            value = {'schema': SCHEMA, 'status': CASE_PASS, 'engine': self.engine, 'caseID': self.case_id,
                'source': self.source, 'build': self.build, 'runtime': self.report['runtime'],
                'device_type': self.report['device_type'], 'ownership': {key: self.report[key] for key in
                    ('reused_external_owned_simulator', 'external_simulator_will_be_retained', 'original_installation')},
                'installation': self.report['installation_before'], 'executionSources': self.sources,
                'simulatorUDID': self.udid, 'caseDirectory': str(self.case_directory), 'execution': execution,
                'nativeAttempt': self.settings.witness(self.case_directory / 'RUN_ATTEMPT.json'),
                'nativeBudget': self.settings.witness(self.output / 'NATIVE_BUDGET.private.json'),
                'sourceBeforeEqualsAfter': True, 'before': self.before, 'after': after,
                'lease': self.lease_record, 'coordination': self.coordination_record,
                'transport': self.transport['witness'], 'rootReceipts': root_record, 'deployment': self.settings.witness(self.window.output / 'DEPLOYMENT.json'),
                'oracleRelay': oracle_relay_receipt, 'originalPages': page, 'pageIdentity': identity,
                'transportJoin': joined, 'rootWatchdogJoin': root_proof, 'oracleRelayJoin': relay_proof,
                'scope': 'Original cold Simulator page results under host network denial; unchanged installed package/corpus inventories',
                'physicalAirplaneMode': False, 'zeroAttemptedNetworkRequestsClaimed': False,
                'rootFinalPhasePostchecksAndRetainedCleanupStillRequired': True}
            witness = self.write('CASE_RESULT.private.json', value)
            return {'proof': value, 'witness': witness}
        except BaseException as error:
            self.record_failure(error)
            raise


def validate_case(record, *, evidence, expected_engine):
    """Read-only admission: reconstruct the joins from original retained files."""
    settings, core = evidence.settings, evidence.core
    value = evidence.read_witness(record)
    require(value.get('schema') == SCHEMA and value.get('status') == CASE_PASS
            and value.get('engine') == expected_engine and value.get('caseID') == TARGET + '/' + CASES[expected_engine]
            and value.get('simulatorUDID') == evidence.udid and value.get('physicalAirplaneMode') is False,
            'Not the exact original offline case producer')
    evidence.source_identity(value.get('source'), 'full-v40')
    evidence.build_identity(value.get('build'))
    evidence.retained_owner({**value['ownership'], 'runtime': value['runtime'], 'device_type': value['device_type']})
    evidence.installation_admission(value['installation'])
    require(value.get('executionSources') == execution_sources(core, settings), 'Offline helpers changed since execution')
    for witness in value['executionSources'].values(): evidence.read_witness(witness, json_value=False)
    directory = settings.canonical_path(value['caseDirectory'], directory=True)
    execution = settings.verified_execution(directory, value['caseID'], evidence.udid, repository_root=core.ROOT)
    require(execution == value.get('execution'), 'Original native result/zero-skip/export identity changed')
    for witness in execution.values():
        if isinstance(witness, dict) and set(witness) == {'path', 'bytes', 'sha256'}:
            evidence.read_witness(witness, maximum=64 * 1024 * 1024, json_value=False)
    page = settings.selected_attachment(directory / 'captures', value['caseID'], evidence.udid,
        'published-v40-' + expected_engine + '-original-pages-and-independent-sql')
    require(page == value.get('originalPages'), 'Original actual source/SQL attachment changed')
    evidence.read_witness(page['file']); evidence.read_witness(page['exportManifest'])
    identity = validate_pages(page['contents'], expected_engine)
    require(identity == value.get('pageIdentity'), 'Stored page summary cannot substitute for the actual original pages')
    before, after = value.get('before', {}), value.get('after', {})
    for snapshot in (before, after):
        settings.validate_owner_record(snapshot['owner'])
        require(snapshot['owner']['simulatorUDID'] == evidence.udid, 'Package owner belongs to another Simulator')
        evidence.installed_images(snapshot['installedImages'])
        manifest = snapshot['installationManifest']
        raw, parsed = settings.decode_raw(manifest)
        require(manifest['sourcePath'] == str(Path(snapshot['owner']['storageRoot']) / 'Otzaria/seforim-installation.json')
                and parsed.get('releaseID') == settings.V40_ID and parsed.get('releaseTag') == settings.V40_TAG
                and parsed.get('databaseFileSize') == settings.V40_BYTES, 'Wrong actual managed-v40 identity')
        require({'path': manifest['sourcePath'], 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
                == value['installation']['installation_manifest'], 'Package/corpus admission is not the same original manifest')
    require(before['owner'] == after['owner'] and before['databaseIdentity'] == after['databaseIdentity']
            and before['installationManifest'] == after['installationManifest'], 'Original owner/corpus changed under denial')
    settings.require_retained_indexes(before['indexes'], after['indexes'])
    for engine in CASES:
        attached = settings.selected_attachment(directory / 'captures', value['caseID'], evidence.udid,
            'published-v40-' + engine + '-actual-installed-manifest')
        manifest = next(v for v in before['indexes'] if v['engine'] == engine)['manifest']
        require(evidence.read_witness(attached['file'], json_value=False) == base64.b64decode(manifest['rawBase64'], validate=True),
                'Original UI package attachment differs from retained actual files')
        evidence.read_witness(attached['exportManifest'])
    lease = evidence.read_witness(value['lease'])
    require(lease['controllerSourceSHA256'] == value['executionSources']['Scripts/CI/study-ui-offline-window.py']['sha256']
            and lease['selectedCaseID'] == value['caseID'] and lease['simulatorUDID'] == evidence.udid,
            'Private lease belongs to another source/device/case')
    coordination = evidence.read_witness(value['coordination'])
    # Evaluate original freshness at the real pre-deploy epoch, not at this
    # later read-only prerequisite check. No expiry is renewed here.
    root_exports = evidence.read_witness(value['rootReceipts'])
    sealed = root_document(root_exports, lease['windowID'], 'sealed.json')
    validate_coordination(coordination, lease, sealed['preparedUnix'])
    for row in coordination['owners']: evidence.read_witness(row['originalAcknowledgement'], json_value=False)
    transport = evidence.read_witness(value['transport'])
    window_module = load_support(core.ROOT, 'study-ui-offline-window.py')
    image_before = Path(before['installedImages']['Maktabah.app']['installed_app_container']) / 'Maktabah'
    image_after = Path(after['installedImages']['Maktabah.app']['installed_app_container']) / 'Maktabah'
    require(image_before == image_after, 'Original qualified app image container changed')
    joined = validate_transport(transport, engine=expected_engine, lease=lease, page_identity=identity,
                                window_module=window_module, expected_image_path=str(image_before))
    require(joined == value['transportJoin'], 'Transport/native join summary changed')
    attempt = evidence.read_witness(value['nativeAttempt'])
    require(value['nativeAttempt']['path'] == str(directory / 'RUN_ATTEMPT.json'), 'Native command witness is unbound')
    validate_native_budget(attempt, joined['nativeInterval'], value['caseID'], lease, evidence.read_witness(value['nativeBudget']))
    command = attempt['command']
    require(command.count('-xctestrun') == 1 and command[command.index('-xctestrun') + 1] == value['build']['xctestrun']['path'],
            'Original native attempt used another xctestrun closure')
    actual_case = evidence.read_witness(execution['caseResult'])
    require(all(actual_case.get(key) == item for key, item in attempt.items()), 'Original completed result changed its native command interval')
    deployment = evidence.read_witness(value['deployment'])
    require(validate_root_receipts(root_exports, lease, deployment, transport) == value['rootWatchdogJoin'], 'Original no-denial/watchdog proof changed')
    relay = evidence.read_witness(value['oracleRelay'], json_value=False)
    require(validate_relay(relay, lease, transport, root_exports,
        value['executionSources']['Scripts/CI/study-ui-offline-heartbeat.py']['sha256']) == value['oracleRelayJoin'], 'Actual Oracle relay proof changed')
    for row in transport['probes']:
        for key in ('binary', 'source'):
            evidence.read_witness(row[key], json_value=False)
        validate_probe_build(row, evidence.read_witness(row['compileReceipt']),
            source_sha=value['executionSources']['Scripts/CI/OfflineTransportProbe.swift']['sha256'],
            driver_sha=value['executionSources']['Scripts/CI/build-offline-transport-probe.py']['sha256'])
    return {'caseReceipt': record, 'execution': execution, 'pageIdentity': identity, 'transportJoin': joined,
            'windowID': lease['windowID'], 'phase': 'offline-' + expected_engine}


def validate_suite(record, *, evidence):
    """Future explicit prerequisite hook; current pending gate is unchanged."""
    return _validate_suite_value(evidence.read_witness(record), evidence=evidence)


def _validate_suite_value(value, *, evidence):
    require(value.get('schema') == 'otzaria.original-full-v40-offline-suite/1'
            and value.get('status') == SUITE_PASS and value.get('simulatorUDID') == evidence.udid
            and set(value.get('cases', {})) == set(value.get('phases', {})) == set(CASES), 'Both genuine original offline phases are required')
    results, windows = {}, set()
    for engine in CASES:
        joined = validate_case(value['cases'][engine], evidence=evidence, expected_engine=engine)
        require(joined['windowID'] not in windows, 'Each original selector needs its own separately coordinated window')
        windows.add(joined['windowID'])
        phase_record = value['phases'][engine]
        phase = evidence.read_witness(phase_record)
        case = CASES[engine]
        require(Path(phase_record['path']).name == 'RESULT.json'
                and phase.get('status') == OFFLINE_PHASE_PASS
                and phase.get('network_scope') == OFFLINE_NETWORK_SCOPE
                and phase.get('study_phase') == 'offline-' + engine
                and phase.get('selected_case_ids') == [case] and phase.get('post_verification_failures') == []
                and phase.get('native_cases_completed') is True
                and phase.get('offline_case') == value['cases'][engine], 'Root final phase/postchecks did not completely pass')
        require(phase.get('source_before') == phase.get('source_after')
                and phase['source_before'].get('study_ui_phase') == 'offline-' + engine
                and phase['source_before'].get('executed_case_ids') == [case], 'Offline source phase scope changed')
        evidence.source_identity(phase['source_before'], 'full-v40')
        evidence.build_identity(phase.get('build_before')); evidence.build_identity(phase.get('build_after'))
        evidence.retained_owner(phase); evidence.installation_admission(phase['installation_before'])
        evidence.database_identity(phase['database_after'])
        evidence.original_receipts(phase['original_installation_receipts_after'])
        evidence.installed_images(phase['installed_images_after']); evidence.retained_cleanup(phase['owned_cleanup'])
        rows = phase.get('case_results')
        require(isinstance(rows, list) and len(rows) == 1 and rows[0].get('case') == case
                and rows[0].get('case_result') == joined['execution']['caseResult']
                and Path(rows[0]['case_directory']).parent == Path(phase_record['path']).parent,
                'Root phase did not retain exactly the same original executed case')
        actual_result = evidence.read_witness(rows[0]['case_result'])
        require(actual_result == {key: item for key, item in rows[0].items() if key != 'case_result'}, 'Root case result differs from its immutable original file')
        results[engine] = joined
    evidence.reverify_files()
    require(value.get('joined') == results and value.get('physicalAirplaneMode') is False,
            'Aggregate summary is not the reverified original two-window result')
    return {'cases': results, 'scope': 'Both original full-v40 local search engines, actual pages/SQL and cold app launches under bounded host network denial'}


def seal_suite(*, case_receipts, phase_results, evidence, output):
    """Called after immutable root RESULT files; never creates a hash cycle."""
    require(set(case_receipts) == set(phase_results) == set(CASES), 'Two complete original case and final root-phase receipts are required')
    joined = {engine: validate_case(case_receipts[engine], evidence=evidence, expected_engine=engine) for engine in CASES}
    value = {'schema': 'otzaria.original-full-v40-offline-suite/1', 'status': SUITE_PASS,
             'simulatorUDID': evidence.udid, 'cases': case_receipts, 'phases': phase_results,
             'joined': joined, 'physicalAirplaneMode': False,
             'scope': 'Actual Simulator network-denial UI; separate from physical device airplane mode, unrelated Reader and PERF acceptance'}
    # Validate every immutable final root-phase join before writing any PASS.
    _validate_suite_value(value, evidence=evidence)
    result = evidence.settings.write_new(output, value)
    return {'proof': value, 'witness': result}
