#!/usr/bin/env python3
"""Synthetic host admission/lifetime controls; never native/PERF evidence."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import uuid
from unittest.mock import patch

parser = argparse.ArgumentParser()
parser.add_argument('--helper', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('candidate_perf01', args.helper)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
records = []


def check(name, action):
    try:
        action()
        records.append({'name': name, 'passed': True})
    except BaseException as error:
        records.append({'name': name, 'passed': False, 'errorType': type(error).__name__, 'error': str(error)})


def reject(action):
    try:
        action()
    except (ValueError, KeyError, TypeError):
        return
    raise AssertionError('Malformed admission was accepted')


def uid(name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, 'synthetic-perf01-control:' + name)).upper()


def catalog():
    rows = []
    for book, name, count in m.BOOKS:
        for mode in m.MODES:
            for index, position in enumerate(m.POSITIONS):
                focus = (0, count // 2, count - 1)[index]
                rows.append({'key': f'{book}-perf01-{mode}-{position}', 'bookID': book, 'bookTitle': name,
                    'bookLineCount': count, 'matrixPosition': position, 'unitMode': mode,
                    'focusLineIndex': focus, 'unitStartLineIndex': focus, 'unitEndLineIndex': focus,
                    'unitRowCount': 1, 'allOriginalAnchorsChecked': 1, 'unitID': f'synthetic:{mode}:{focus}',
                    'sectionLocator': f'otzaria|book:{book}|line:{focus}', 'focusLocator': f'otzaria|book:{book}|line:{focus}',
                    'sourceFile': f'synthetic-{book}-{mode}-{position}.utf8', 'sourceUTF8Bytes': 4,
                    'sourceUTF16Length': 4, 'sourceSHA256': 'b' * 64,
                    'tocSelection': {'schema': 1, 'sourceLineIndex': focus,
                        'canonicalLocator': f'otzaria|book:{book}|line:{focus}', 'allTOCRowsChecked': 3,
                        'tocSQLRowsSHA256': 'c' * 64, 'headings': [{'sourceLineIndex': focus, 'title': 'Synthetic heading'}]}})
    return {'schema': 1, 'status': m.CATALOG_STATUS, 'corpusProfile': 'full-v40', 'databaseSHA256': m.DB_SHA,
        'sourceServiceSHA256': 'd' * 64, 'presentationSourceSHA256': 'e' * 64,
        'catalogCompileInputsSHA256': 'f' * 64, 'uiExecuted': 0, 'performanceObserved': False,
        'searchProviderExecuted': False, 'targets': rows}


def fixture(book=103, mode='line'):
    c = catalog(); targets = {r['key']: r for r in c['targets']}
    away = next(r for r in c['targets'] if r['bookID'] != book and r['unitMode'] == mode and r['matrixPosition'] == 'first')
    request = {'bookID': book, 'unitMode': mode, 'catalogSHA256': 'a' * 64, 'observations': [], 'pairs': []}
    epochs, proofs, modes = {}, [], {}
    document, group = uid('document'), uid('group')

    def mode_proof(name, stage, pid):
        identifier = uid(name)
        modes[identifier] = {'status': 'ORIGINAL_PERSISTED_READER_MODE_OBSERVED', 'proofID': identifier,
                            'unitMode': mode, 'stage': stage, 'processID': pid}
        return identifier

    def source(name, key, pid, routed, epoch=None, route_id=None, duration=None):
        identifier = uid(name)
        proofs.append({'request_id': identifier, 'target_key': key, 'native_process_id': pid,
            'post_resource_epoch': True, 'native_core_receipt_present': routed,
            'actual_workspace_document_id': document, 'actual_workspace_group_id': group,
            'epoch': epoch, 'native_core_request_id': route_id, 'route_visibility_upper_bound_seconds': duration})
        return identifier

    mode_proof('selected', 'selected', 90)
    for i, position in enumerate(m.ORDER):
        pid, before_pid = 100 + i, 90 if i == 0 else 99 + i
        key = f'{book}-perf01-{mode}-{position}'
        pair = {'pairIndex': i + 1, 'targetKey': key, 'awayTargetKey': away['key'],
            'beforeProcessID': before_pid, 'afterProcessID': pid, 'workspaceDocumentID': document, 'workspaceGroupID': group,
            'beforeColdSourceID': source(f'{i}-before', away['key'], before_pid, True),
            'afterColdSourceID': source(f'{i}-after', away['key'], pid, False),
            'warmAwaySourceID': source(f'{i}-warm-away', away['key'], pid, True),
            'beforeModeProofID': mode_proof(f'{i}-before-mode', 'before-cold', before_pid),
            'afterModeProofID': mode_proof(f'{i}-after-mode', 'after-cold', pid),
            'warmModeProofID': mode_proof(f'{i}-warm-mode', 'warm-ready', pid)}
        request['pairs'].append(pair)
        for j, temp in enumerate(('process-cold', 'warm')):
            epoch, overview, route = uid(f'{i}-{j}-epoch'), uid(f'{i}-{j}-overview'), uid(f'{i}-{j}-route')
            for identifier, kind, start, end in ((epoch, 'reader-open', 10.0, 11.0), (overview, 'reader-overview', 11.5, 12.0)):
                epochs[identifier] = {'epoch': identifier, 'kind': kind, 'target_key': key, 'mode': temp,
                    'status': 'OBSERVED_NOT_PERFORMANCE_ACCEPTANCE', 'processID': pid,
                    'resource_start_host_monotonic': start, 'resource_end_host_monotonic': end,
                    'app_cpu_seconds': 0.03, 'sampled_max_rss_bytes': 123456}
            toc = targets[key]['tocSelection']
            request['observations'].append({'pairIndex': i + 1, 'targetKey': key, 'mode': temp,
                'bookID': book, 'unitMode': mode, 'matrixPosition': position, 'processID': pid, 'epoch': epoch,
                'route': {'receiptFields': {'request': route}, 'requestToNativeVisibleUpperBoundSeconds': 0.5},
                'sourceObservationID': source(f'{i}-{j}-source', key, pid, True, epoch, route, 0.5),
                'modeProofID': mode_proof(f'{i}-{j}-mode', 'post-open', pid),
                'firstInteraction': {'epoch': overview, 'actualOverviewIdentifier': 'study-groups-overview',
                    'actualDocumentID': document, 'actualCardIdentifier': 'tab-switcher-grid-cell-' + document,
                    'observationStartedUptime': 20.0, 'nativeActionRequestedUptime': 20.5, 'originalOverviewObservedUptime': 21.0,
                    'requestToOriginalOverviewUpperBoundSeconds': 1.0, 'nativeActionToOverviewUpperBoundSeconds': 0.5},
                'tocEvidence': {'canonicalLocator': toc['canonicalLocator'], 'sourceLineIndex': toc['sourceLineIndex'],
                    'tocSQLRowsSHA256': toc['tocSQLRowsSHA256'], 'originalSelectedRows': [
                        {'identifier': 'toc-row-' + str(toc['sourceLineIndex']), 'label': 'Synthetic heading',
                         'selected': True, 'value': 'selected'}]}})
    return {'request': request, 'book': book, 'mode': mode, 'catalog': c, 'catalog_sha': 'a' * 64,
            'epochs': epochs, 'proofs': proofs, 'mode_proofs': modes}


def validate(f):
    return m.validate_cell(**f)


for book, mode, _ in m.CELLS:
    check(f'synthetic-complete-cell-{book}-{mode}', lambda b=book, u=mode: validate(fixture(b, u)))


def bad(name, mutate):
    def action():
        f = fixture(); mutate(f); reject(lambda: validate(f))
    check(name, action)


bad('missing-one-open-rejected', lambda f: f['request']['observations'].pop())
bad('legacy-twenty-open-substitution-rejected', lambda f: f['request']['observations'].extend(copy.deepcopy(f['request']['observations'][:8])))
bad('missing-pair-rejected', lambda f: f['request']['pairs'].pop())
bad('reordered-pairs-rejected', lambda f: f['request']['pairs'].reverse())
bad('cold-reused-pid-rejected', lambda f: f['request']['pairs'][0].update(afterProcessID=f['request']['pairs'][0]['beforeProcessID']))
bad('warm-restarted-pid-rejected', lambda f: f['request']['observations'][1].update(processID=2000))
bad('warm-without-real-away-rejected', lambda f: f['request']['pairs'][0].update(awayTargetKey=f['request']['pairs'][0]['targetKey']))
bad('missing-source-record-rejected', lambda f: f['proofs'].pop())
bad('extra-source-record-rejected', lambda f: f['proofs'].append(copy.deepcopy(f['proofs'][0])))
bad('stale-source-pid-rejected', lambda f: f['proofs'][3].update(native_process_id=2000))
bad('source-without-core-receipt-rejected', lambda f: f['proofs'][3].update(native_core_receipt_present=False))
bad('substituted-source-core-request-rejected', lambda f: f['proofs'][3].update(native_core_request_id=uid('foreign')))
bad('changed-document-rejected', lambda f: f['proofs'][3].update(actual_workspace_document_id=uid('foreign-doc')))
bad('changed-group-rejected', lambda f: f['request']['pairs'][0].update(workspaceGroupID=uid('foreign-group')))
bad('mode-not-persisted-rejected', lambda f: next(iter(f['mode_proofs'].values())).update(unitMode='chapter'))
bad('extra-mode-observation-rejected', lambda f: f['mode_proofs'].update({uid('extra-mode'): {}}))
bad('reused-mode-proof-rejected', lambda f: f['request']['observations'][1].update(modeProofID=f['request']['observations'][0]['modeProofID']))
bad('failed-resource-epoch-rejected', lambda f: next(iter(f['epochs'].values())).update(status='ABORTED_NOT_ACCEPTED'))
bad('wrong-resource-kind-rejected', lambda f: next(iter(f['epochs'].values())).update(kind='inspector-open'))
bad('missing-resource-epoch-rejected', lambda f: f['epochs'].pop(next(iter(f['epochs']))))
bad('nonfinite-CPU-rejected', lambda f: next(iter(f['epochs'].values())).update(app_cpu_seconds=float('nan')))
bad('overview-overlaps-open-rejected', lambda f: f['epochs'][f['request']['observations'][0]['firstInteraction']['epoch']].update(resource_start_host_monotonic=9))
bad('overview-wrong-actual-card-rejected', lambda f: f['request']['observations'][0]['firstInteraction'].update(actualCardIdentifier='tab-switcher-grid-cell-'+uid('foreign-doc')))
bad('overview-invented-duration-rejected', lambda f: f['request']['observations'][0]['firstInteraction'].update(requestToOriginalOverviewUpperBoundSeconds=0.01))
bad('false-source-visible-time-rejected', lambda f: f['request']['observations'][0]['route'].update(requestToNativeVisibleUpperBoundSeconds=0.01))
bad('wrong-native-TOC-id-rejected', lambda f: f['request']['observations'][0]['tocEvidence']['originalSelectedRows'][0].update(identifier='toc-row--123'))
bad('wrong-native-TOC-label-rejected', lambda f: f['request']['observations'][0]['tocEvidence']['originalSelectedRows'][0].update(label='Foreign heading'))
bad('no-selected-TOC-rejected', lambda f: f['request']['observations'][0]['tocEvidence'].update(originalSelectedRows=[]))
bad('unselected-TOC-rejected', lambda f: f['request']['observations'][0]['tocEvidence']['originalSelectedRows'][0].update(selected=False))
bad('wrong-book-cell-rejected', lambda f: f['request'].update(bookID=28))
bad('wrong-mode-cell-rejected', lambda f: f['request'].update(unitMode='chapter'))
bad('wrong-catalog-digest-rejected', lambda f: f['request'].update(catalogSHA256='0'*64))

for key, value in [('corpusProfile', 'full-v32'), ('databaseSHA256', '0'*64), ('status', 'ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI'),
                   ('performanceObserved', True), ('searchProviderExecuted', True)]:
    check('catalog-rejects-' + key, lambda k=key, v=value: reject(lambda: m.admit_catalog({**catalog(), k:v})))
bad('missing-mode-target-rejected', lambda f: f['catalog']['targets'].pop())
bad('line-target-fallback-rejected', lambda f: f['catalog']['targets'][0].update(unitMode='paragraph'))
bad('unit-source-prefix-rejected', lambda f: f['catalog']['targets'][0].update(allOriginalAnchorsChecked=0))
bad('escaping-source-file-rejected', lambda f: f['catalog']['targets'][0].update(sourceFile='../foreign.utf8'))


def percentiles_control():
    def pct(values):
        ordered = sorted(values)
        return {'n': len(values), 'p50': ordered[2], 'p95': ordered[5], 'individual': values}
    f = fixture(); complete = validate(f)
    result = m.measurements(types.SimpleNamespace(percentiles=pct), complete, f['epochs'])
    assert set(result) == {'process-cold','warm'}
    assert all(r['visibility_upper_bound_seconds']['n'] == 6 and r['positions_in_order'] == m.ORDER for r in result.values())
    assert 'population/single-chapter' in result['warm']['scope']
check('n6-per-temperature-never-mixed-book-aggregate', percentiles_control)


with tempfile.TemporaryDirectory(prefix='synthetic-perf01-storage-') as name:
    root = Path(name); cell = root/'cell'; cell.mkdir(); source = root/'source'; source.mkdir()
    trace = cell/'traces'; trace.mkdir(); (trace/'data').write_bytes(b'owned trace fixture' * 100)
    check('actual-owned-allocated-file-inventory-positive', lambda: m.require(m.allocated_bytes(cell) > 0, 'missing allocated bytes'))
    (trace/'alias').symlink_to(root)
    check('actual-owned-symlink-inventory-rejected', lambda: reject(lambda: m.allocated_bytes(cell)))
    (trace/'alias').unlink()
    guard = m.StorageGuard(root_output=root, cell_output=cell, catalog_output=source,
        trace_bytes=1, artifact_bytes=1_000_000, catalog_bytes=1_000_000, other_bytes=0, os_bytes=1, stop_bytes=1)
    check('actual-trace-budget-overrun-rejected-with-bytes-retained', lambda: reject(guard.check))
    check('actual-cap-failure-does-not-truncate', lambda: m.require((trace/'data').read_bytes() == b'owned trace fixture'*100, 'modified raw bytes'))
    check('nonempty-compiler-folder-refused-before-command', lambda: reject(lambda: m.compile_original_catalog(None, {}, trace)))


class FakeGuard:
    def __init__(self): self.n=0; self.failure=None
    def check(self):
        self.n += 1
        if self.n == 2: raise ValueError('synthetic storage exhaustion after owned Popen')
class FakeTrace:
    def require_running(self): pass
class FakeProcess:
    returncode = None
    def poll(self): return None
class FakeCore:
    OUT = Path('/synthetic-only')
    def write(self, *args): pass


def cleanup_control(method):
    process, stopped = FakeProcess(), []
    proxy = m.BudgetedOriginalRunner(FakeCore(), FakeGuard(), FakeTrace())
    with tempfile.TemporaryDirectory(prefix='synthetic-perf01-owned-process-') as name:
        with patch.object(m.subprocess, 'Popen', return_value=process), \
             patch.object(m.runpy, 'run_path', return_value={'stop_owned_process_group': lambda p: stopped.append(p) or {'group_state':'GONE_CHECKED'}}):
            if method == 'bounded':
                reject(lambda: proxy.bounded(['xcodebuild', 'test-without-building'], Path(name)/'log', 600, {}))
            else:
                reject(lambda: proxy.command(['xcrun','xcresulttool','export','attachments'], timeout=300))
    assert stopped == [process]
    assert proxy.guard.failure == 'ValueError'
check('synthetic-XCTest-post-Popen-ENOSPC-stops-only-owned-handle-once', lambda: cleanup_control('bounded'))
check('synthetic-exporter-post-Popen-ENOSPC-stops-only-owned-handle-once', lambda: cleanup_control('command'))

result = {'schema': 'otzaria.perf01.source-controls/1', 'status': 'PASS' if all(r['passed'] for r in records) else 'FAIL',
    'scope': 'Synthetic parser/admission/owned-process controls and actual tiny local scratch allocation checks only',
    'nativeExecuted': 0, 'appleCompilerExecuted': 0, 'corpusQueries': 0, 'performanceAcceptance': False,
    'helper': {'path': str(args.helper.resolve()), 'bytes': args.helper.stat().st_size,
               'sha256': hashlib.sha256(args.helper.read_bytes()).hexdigest()},
    'controls': records, 'passed': sum(r['passed'] for r in records), 'total': len(records)}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='controls'}, sort_keys=True))
if result['status'] != 'PASS':
    print(json.dumps([r for r in records if not r['passed']], indent=2)); raise SystemExit(1)
