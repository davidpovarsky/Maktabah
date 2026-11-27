#!/usr/bin/env python3
"""Synthetic data/source controls only. Never runs Mac, PF, launchd or UIKit."""
import copy
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'study-ui-offline-execution.py'
if not SOURCE.exists(): SOURCE = HERE.parents[4] / 'Scripts/CI/study-ui-offline-execution.py'
spec = importlib.util.spec_from_file_location('offline_join_control_subject', SOURCE)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
NS = 'AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE'
SESSION = '11111111-2222-4333-8444-555555555555'
UDID = '66666666-7777-4888-8999-AAAAAAAAAAAA'
WINDOW = '0123456789abcdef0123456789abcdef'


def pages(engine):
    count, size = m.PAGES[engine]
    events, sql, order, source, native_items = [], {}, [], [], []
    common = {'schemaVersion': 1, 'engine': engine, 'namespace': NS, 'sessionID': SESSION,
              'processID': 123, 'submissionRevision': 1, 'profileID': 'production'}
    for page in range(count):
        rows = []
        for index in range(page * size, (page + 1) * size):
            line_id, book, line = index + 1000, 20, index
            identifier = 'zayit:production:' + str(line_id) if engine == 'zayit' else 'otzaria:otzaria-book:20:' + str(line_id) + ':' + str(line)
            original = {'lineID': line_id, 'bookID': book, 'lineIndex': line, 'bookTitle': 'Original Book', 'reference': 'Original Ref ' + str(line)}
            if engine == 'zayit':
                row = {'book_id': book, 'line_index': line, 'line_id': line_id, 'book_title': original['bookTitle'], 'reference': original['reference'], 'matched_terms': ['בראשית'], 'opaque_metadata': {'keep': index}}
            else:
                row = {'filePath': 'otzaria-book:20', 'segment': line, 'id': line_id, 'title': original['bookTitle'], 'reference': original['reference'], 'opaque_metadata': {'keep': index}}
            item = {'id': identifier, 'bookID': book, 'lineIndex': line, 'bookTitle': original['bookTitle'], 'reference': original['reference'], 'locator': 'otzaria|book:20|line:' + str(line), 'highlightTerms': ['בראשית'], 'snippetSHA256': 'a' * 64}
            sql[identifier] = original; order.append(identifier); source.append(row); rows.append(row); native_items.append(item)
        provider = {**common, 'event': 'provider', 'request': {'querySHA256': m.QUERY_SHA, 'offset': page * size, 'limit': size},
                    'page': {'hits' if engine == 'zayit' else 'results': rows}, 'nextOffset': (page + 1) * size}
        if engine == 'zayit': provider['accumulatedSource'] = copy.deepcopy(source)
        else: provider['retainedRecords'] = [{'metadata': copy.deepcopy(a), 'item': copy.deepcopy(b)} for a, b in zip(source, native_items)]
        events.append(provider); events.append({**common, 'event': 'published', 'items': copy.deepcopy(native_items)})
    return {'events': events, 'independentSQL': sql}

WINDOW_SOURCE = HERE.parent / 'offline-host/study-ui-offline-window.py'
if not WINDOW_SOURCE.exists(): WINDOW_SOURCE = HERE.parents[4] / 'Scripts/CI/study-ui-offline-window.py'
window_spec = importlib.util.spec_from_file_location('offline_window_validation_subject', WINDOW_SOURCE)
w = importlib.util.module_from_spec(window_spec); window_spec.loader.exec_module(w)
EPOCH = 1700000000
IMAGE = '/Users/owner/Library/Developer/CoreSimulator/Devices/' + UDID + '/data/Containers/Bundle/Application/' + SESSION + '/Maktabah.app/Maktabah'


def transport():
    case = m.TARGET + '/' + m.CASES['zayit']
    lease = {'windowID': WINDOW, 'simulatorUDID': UDID, 'controllerSourceSHA256': 'a' * 64,
             'notBeforeUnix': EPOCH - 50, 'hardDeadlineUnix': EPOCH + 800}
    label = lambda packets: 'otzaria-denial-' + WINDOW + ' 1000 ' + str(packets) + ' 100 0 0 7 100 0'
    history = [{'observedMonotonic': 100 + second, 'observedUnix': EPOCH + second,
                'active': True, 'heartbeatNonce': 'a' * 32, 'counters': label(second)} for second in range(51)]
    process = {'processID': 123, 'parentPID': 1, 'startUTC': dt.datetime.fromtimestamp(EPOCH + 20, dt.timezone.utc).strftime('%a %b %d %H:%M:%S %Y'),
               'processImagePath': IMAGE, 'arguments': ['-GlobalSearchNativeTraceNamespace', NS]}
    samples = [{'observedUnix': EPOCH + second, 'observedMonotonic': 100 + second,
                'watchdog': {'active': True, 'originalUnchanged': True, 'ownRulesMatch': True, 'observedMonotonic': 100 + second},
                'applications': [copy.deepcopy(process)] if second >= 20 else []} for second in range(31)]
    probes = []
    for phase, start in [('before', -10), ('during', 1), ('during', 40), ('after', 60)]:
        for kind in ('simulator', 'host'):
            for endpoint in w.ENDPOINTS:
                nonce = format(len(probes) + 1, '032x')
                value = {'schema': 'otzaria.foundation-transport-probe/1', 'windowID': WINDOW, 'phase': phase, 'nonce': nonce,
                         'endpoint': endpoint, 'requestedURL': w.ENDPOINTS[endpoint] + '?otzariaOfflineNonce=' + nonce,
                         'environment': kind, 'simulatorUDID': UDID if kind == 'simulator' else None, 'processID': 800 + len(probes),
                         'deadlineExpired': False, 'taskCompleted': True, 'startedUnix': EPOCH + start, 'finishedUnix': EPOCH + start + .25,
                         'startedUptime': 100 + start, 'finishedUptime': 100 + start + .25, 'ephemeral': True, 'URLCacheDisabled': True,
                         'waitsForConnectivity': False, 'redirects': [], 'HTTPStatus': 200, 'responseBytes': 100,
                         'errorDomain': None, 'errorCode': None,
                         'transactions': [{'resourceFetchType': 'networkLoad', 'proxyConnection': False, 'reusedConnection': False}]}
                if phase == 'during': value.update(HTTPStatus=None, responseBytes=0, errorDomain='NSURLErrorDomain', errorCode=-1004, transactions=[])
                probes.append({'probe': value, 'commandStartedUnix': EPOCH + start - .1, 'commandFinishedUnix': EPOCH + start + .3})
    proof = {'schema': w.VERSION, 'status': 'TRANSPORT_WINDOW_OBSERVED_ORIGINAL_NATIVE_JOIN_STILL_REQUIRED',
             'windowID': WINDOW, 'simulatorUDID': UDID, 'selectedCaseID': case, 'sourceSHA256': 'a' * 64, 'physicalAirplaneMode': False,
             'activation': {'observedUnix': EPOCH, 'observedMonotonic': 100},
             'nativeIntervals': [{'caseID': case, 'callbackReturned': True, 'startedUnix': EPOCH + 20, 'finishedUnix': EPOCH + 30,
                                  'startedMonotonic': 120, 'finishedMonotonic': 130}],
             'cleanup': {'status': 'OWNED_RULES_EMPTY_ROLLBACK_VERIFIED', 'mode': 'network-denial', 'reason': 'normal-finish-requested',
                         'activated': True, 'windowID': WINDOW, 'onlyOwnedAnchor': w.anchor_name(WINDOW),
                         'cleanupUnix': EPOCH + 50, 'cleanupMonotonic': 150, 'history': history},
             'unloaded': {'status': 'OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY', 'originalConfigurationMatches': True,
                          'windowID': WINDOW, 'observedUnix': EPOCH + 51}, 'samples': samples, 'probes': probes}
    return proof, lease, m.validate_pages(pages('zayit'), 'zayit')


def admit_transport(proof, lease, identity):
    return m.validate_transport(proof, engine='zayit', lease=lease, page_identity=identity, window_module=w, expected_image_path=IMAGE)


def root_row(identifier, name, value):
    import base64
    raw = json.dumps(value).encode()
    return {'sourcePath': str(m.ROOT_PRIVATE_BASE / identifier / name), 'bytes': len(raw),
            'sha256': hashlib.sha256(raw).hexdigest(), 'rawBase64': base64.b64encode(raw).decode(), 'uid': 0, 'mode': 0o600}


def relay():
    proof, lease, identity = transport()
    # Oracle and Mac clocks deliberately differ by 100,000 seconds. Causality
    # must use actual remote nonces/root receipts, not an unmeasured wall offset.
    first = {'windowID': WINDOW, 'sequence': 0, 'startedUnix': EPOCH - 100000, 'finishedUnix': EPOCH - 99999,
             'exit': 0, 'relayProcessID': 901, 'relaySourceSHA256': 'b' * 64, 'stderrSHA256': hashlib.sha256(b'').hexdigest(),
             'remote': {'windowID': WINDOW, 'nonce': 'a' * 32, 'observedUnix': EPOCH - 1}}
    cleanup = root_row(WINDOW, 'cleanup.json', proof['cleanup'])
    heartbeat = root_row(WINDOW, 'heartbeat.json', {'nonce': 'a' * 32, 'observedUnix': EPOCH - 1})
    last = {**first, 'sequence': 1, 'startedUnix': EPOCH - 99940, 'finishedUnix': EPOCH - 99939,
            'remote': {'windowID': WINDOW, 'status': 'WINDOW_ALREADY_CLEANED', 'cleanupSHA256': cleanup['sha256']}}
    return [first, last], lease, proof, {WINDOW: {'cleanup.json': cleanup, 'heartbeat.json': heartbeat}}


class Controls(unittest.TestCase):
    def rejects(self, engine, change):
        value = pages(engine); change(value)
        with self.assertRaises((ValueError, KeyError, TypeError, IndexError)):
            m.validate_pages(value, engine)

    def test_original_zayit_three_pages_all150_source_sql_identities(self):
        value = m.validate_pages(pages('zayit'), 'zayit')
        self.assertEqual(value['visibleCumulativeCounts'], [50, 100, 150])
        self.assertEqual(value['resultCount'], 150)

    def test_original_otzaria_two_cumulative_pages_all200_sql_identities(self):
        value = m.validate_pages(pages('otzaria'), 'otzaria')
        self.assertEqual(value['visibleCumulativeCounts'], [100, 200])
        self.assertEqual(value['resultCount'], 200)

    def test_partial_last_page_fails(self):
        self.rejects('zayit', lambda v: v['events'][-2]['page']['hits'].pop())

    def test_missing_intermediate_publication_fails(self):
        self.rejects('zayit', lambda v: v['events'].pop(1))

    def test_fake_full150_publication_before_second_provider_fails(self):
        self.rejects('zayit', lambda v: v['events'][1].update(items=copy.deepcopy(v['events'][-1]['items'])))

    def test_offset50_cannot_be_counted_as_offset100(self):
        self.rejects('zayit', lambda v: v['events'][-2]['request'].update(offset=50))

    def test_other_query_digest_fails(self):
        self.rejects('otzaria', lambda v: v['events'][0]['request'].update(querySHA256='b' * 64))

    def test_extra_unattributed_sql_row_fails(self):
        self.rejects('otzaria', lambda v: v['independentSQL'].update(foreign={'lineID': 99}))

    def test_wrong_actual_sql_identity_fails(self):
        self.rejects('zayit', lambda v: next(iter(v['independentSQL'].values())).update(lineID=9))

    def test_wrong_native_locator_fails(self):
        self.rejects('zayit', lambda v: v['events'][1]['items'][0].update(locator='otzaria|book:999|line:0'))

    def test_wrong_native_title_on_first_page_fails_even_if_final_correct(self):
        self.rejects('zayit', lambda v: v['events'][1]['items'][0].update(bookTitle='Foreign'))

    def test_wrong_matched_terms_fails(self):
        self.rejects('zayit', lambda v: v['events'][-1]['items'][0].update(highlightTerms=[]))

    def test_earlier_full_zayit_metadata_must_remain_byte_structurally_equal(self):
        self.rejects('zayit', lambda v: v['events'][-2]['accumulatedSource'][0]['opaque_metadata'].update(keep=-1))

    def test_earlier_otzaria_full_metadata_must_remain_equal(self):
        self.rejects('otzaria', lambda v: v['events'][-2]['retainedRecords'][0]['metadata']['opaque_metadata'].update(keep=-1))

    def test_earlier_otzaria_native_item_cannot_change_later(self):
        self.rejects('otzaria', lambda v: v['events'][-2]['retainedRecords'][0]['item'].update(snippetSHA256='c' * 64))

    def test_duplicate_real_line_id_cannot_inflate_result_count(self):
        self.rejects('zayit', lambda v: v['events'][-2]['page']['hits'][-1].update(line_id=1000))

    def test_changed_process_namespace_session_or_profile_fails(self):
        for key, value in [('processID', 456), ('namespace', SESSION), ('sessionID', NS), ('profileID', 'miniTest10')]:
            with self.subTest(key=key): self.rejects('zayit', lambda v, k=key, x=value: v['events'][-1].update({k: x}))

    def test_boolean_id_and_unknown_event_schema_fail(self):
        self.rejects('zayit', lambda v: v['events'][0]['page']['hits'][0].update(line_id=True))
        self.rejects('zayit', lambda v: v['events'][0].update(schemaVersion=2))

    def coordinator(self):
        case = m.TARGET + '/' + m.CASES['zayit']
        lease = {'windowID': WINDOW, 'hardDeadlineUnix': 1800, 'selectedCaseID': case, 'simulatorUDID': UDID, 'coordinatingOwners': ['root', 'wave3']}
        value = {'schema': 'otzaria.coordinated-mac-network-window/1', 'status': 'ALL_LISTED_OWNERS_PAUSED',
                 'windowID': WINDOW, 'hardDeadlineUnix': 1800, 'selectedCaseID': case, 'simulatorUDID': UDID,
                 'observedAtUnix': 1000, 'owners': [{'ownerID': owner, 'paused': True, 'windowID': WINDOW,
                    'acknowledgedAtUnix': 999, 'originalAcknowledgement': {'path': '/synthetic-only/' + owner, 'bytes': 1, 'sha256': 'a' * 64}}
                    for owner in ('root', 'wave3')]}
        return value, lease

    def test_exact_explicit_fresh_owner_coordination_shape(self):
        value, lease = self.coordinator()
        self.assertEqual(m.validate_coordination(value, lease, 1001), value)

    def test_missing_actual_owner_acknowledgement_fails(self):
        value, lease = self.coordinator(); value['owners'].pop()
        with self.assertRaises(ValueError): m.validate_coordination(value, lease, 1001)

    def test_later_deadline_cannot_be_invented_from_old_owner_pause(self):
        value, lease = self.coordinator(); lease['hardDeadlineUnix'] += 100
        with self.assertRaises(ValueError): m.validate_coordination(value, lease, 1001)

    def test_unpaused_or_stale_owner_never_becomes_automatic_approval(self):
        value, lease = self.coordinator(); value['owners'][0]['paused'] = False
        with self.assertRaises(ValueError): m.validate_coordination(value, lease, 1001)
        value, lease = self.coordinator()
        with self.assertRaises(ValueError): m.validate_coordination(value, lease, 1121)

    def attempt(self):
        case = m.TARGET + '/' + m.CASES['zayit']
        lease = {'simulatorUDID': UDID, 'hardDeadlineUnix': 1800}
        interval = {'startedUnix': 1000, 'finishedUnix': 1100}
        value = {'case': m.CASES['zayit'], 'command': ['xcodebuild', 'test-without-building', '-destination',
            'platform=iOS Simulator,id=' + UDID, '-only-testing:' + case, '-test-timeouts-enabled', 'YES',
            '-default-test-execution-time-allowance', '1800', '-maximum-test-execution-time-allowance', '1800'],
            'xcodebuild_exit': 0, 'allowance_seconds': 1800,
            'started_at_unix': 1001, 'finished_at_unix': 1099, 'host_timeout_seconds': 560}
        budget = {'hostTimeoutSeconds': 560, 'calculatedAtUnix': 1000, 'hardDeadlineUnix': 1800,
                  'finishReserveSeconds': m.NATIVE_STOP_RESERVE_SECONDS}
        return value, interval, case, lease, budget

    def test_original_native_interval_inside_denial(self):
        m.validate_native_budget(*self.attempt())

    def test_native_finished_after_window_is_never_accepted(self):
        value, interval, case, lease, budget = self.attempt(); value['finished_at_unix'] = 1801
        with self.assertRaises(ValueError): m.validate_native_budget(value, interval, case, lease, budget)

    def test_native_partial_nonzero_exit_is_not_a_pass(self):
        value, interval, case, lease, budget = self.attempt(); value['xcodebuild_exit'] = 65
        with self.assertRaises(ValueError): m.validate_native_budget(value, interval, case, lease, budget)

    def test_extra_selector_cannot_hide_in_native_command(self):
        value, interval, case, lease, budget = self.attempt(); value['command'].append('-only-testing:Other/testOther')
        with self.assertRaises(ValueError): m.validate_native_budget(value, interval, case, lease, budget)

    def test_genuine_transport_shape_joins_original_page_process_and_window(self):
        proof, lease, identity = transport()
        result = admit_transport(proof, lease, identity)
        self.assertEqual(result['pageProcess']['processID'], 123)
        self.assertEqual(result['actualTransportRequestCount'], 16)

    def bad_transport(self, mutation):
        proof, lease, identity = transport(); mutation(proof, lease, identity)
        with self.assertRaises((ValueError, KeyError, IndexError, TypeError)):
            admit_transport(proof, lease, identity)

    def test_same_udid_different_image_container_does_not_qualify(self):
        self.bad_transport(lambda p, l, i: p['samples'][-1]['applications'][0].update(processImagePath=IMAGE.replace(SESSION, NS)))

    def test_preexisting_online_process_is_not_a_fresh_offline_case(self):
        self.bad_transport(lambda p, l, i: p['samples'][-1]['applications'][0].update(startUTC='Tue Nov 14 21:00:00 2023'))

    def test_wrong_process_namespace_and_fixture_namespace_are_rejected(self):
        self.bad_transport(lambda p, l, i: p['samples'][-1]['applications'][0].update(arguments=['-GlobalSearchNativeTraceNamespace', SESSION]))
        self.bad_transport(lambda p, l, i: p['samples'][-1]['applications'][0]['arguments'].append('-studyWorkspaceTestingNamespace'))

    def test_native_interval_after_rollback_is_rejected(self):
        self.bad_transport(lambda p, l, i: p['nativeIntervals'][0].update(finishedUnix=EPOCH + 51))

    def test_missing_watchdog_interval_never_counts_as_continuity(self):
        self.bad_transport(lambda p, l, i: p['cleanup'].update(history=p['cleanup']['history'][:5] + p['cleanup']['history'][20:]))

    def test_missing_actual_process_observation_fails(self):
        self.bad_transport(lambda p, l, i: p.update(samples=[]))

    def test_cleanup_deadline_or_drift_is_not_normal_success(self):
        self.bad_transport(lambda p, l, i: p['cleanup'].update(reason='hard-deadline'))
        self.bad_transport(lambda p, l, i: p['unloaded'].update(originalConfigurationMatches=False))

    def test_negative_http_error_is_not_network_denial(self):
        self.bad_transport(lambda p, l, i: p['probes'][4]['probe'].update(HTTPStatus=503))

    def test_negative_request_outside_actual_window_is_rejected(self):
        def change(p, l, i):
            p['probes'][4]['probe'].update(startedUnix=EPOCH + 52, finishedUnix=EPOCH + 52.25)
            p['probes'][4].update(commandStartedUnix=EPOCH + 51.9, commandFinishedUnix=EPOCH + 52.3)
        self.bad_transport(change)

    def test_missing_final_or_initial_probe_round_fails(self):
        self.bad_transport(lambda p, l, i: p['probes'].pop())
        self.bad_transport(lambda p, l, i: p.update(probes=p['probes'][:8] + p['probes'][12:]))

    def test_no_block_counter_increase_fails(self):
        self.bad_transport(lambda p, l, i: p['cleanup']['history'][-1].update(counters=p['cleanup']['history'][0]['counters']))

    def test_oracle_and_mac_clock_skew_is_not_fabricated_ordering(self):
        rows, lease, proof, exports = relay()
        result = m.validate_relay(('\n'.join(json.dumps(r) for r in rows)).encode(), lease, proof, exports, 'b' * 64)
        self.assertFalse(result['clockDomains']['crossHostWallClockBracketingClaimed'])

    def test_foreign_oracle_heartbeat_cannot_explain_actual_root_nonce(self):
        rows, lease, proof, exports = relay(); rows[0]['remote']['nonce'] = 'c' * 32
        with self.assertRaises(ValueError): m.validate_relay(('\n'.join(json.dumps(r) for r in rows)).encode(), lease, proof, exports, 'b' * 64)

    def test_oracle_terminal_reply_must_match_exact_root_cleanup(self):
        rows, lease, proof, exports = relay(); rows[-1]['remote']['cleanupSHA256'] = 'd' * 64
        with self.assertRaises(ValueError): m.validate_relay(('\n'.join(json.dumps(r) for r in rows)).encode(), lease, proof, exports, 'b' * 64)

    def test_root_mac_heartbeat_time_must_match_its_actual_remote_nonce(self):
        rows, lease, proof, exports = relay(); rows[0]['remote']['observedUnix'] += 1
        with self.assertRaises(ValueError): m.validate_relay(('\n'.join(json.dumps(r) for r in rows)).encode(), lease, proof, exports, 'b' * 64)

    def test_modified_original_xctest_allowance_fails(self):
        value, interval, case, lease, budget = self.attempt(); value['allowance_seconds'] = 900
        with self.assertRaises(ValueError): m.validate_native_budget(value, interval, case, lease, budget)

    def test_missing_or_unbounded_actual_host_timeout_fails(self):
        value, interval, case, lease, budget = self.attempt(); value['host_timeout_seconds'] = 900
        with self.assertRaises(ValueError): m.validate_native_budget(value, interval, case, lease, budget)

    def test_receipt_write_failure_cannot_skip_preparation_rollback(self):
        subject = object.__new__(m.OfflineStudyCase)
        with patch.object(subject, '_prepare_window', side_effect=ValueError('source control')), \
             patch.object(subject, 'record_failure', side_effect=OSError('synthetic ENOSPC')), \
             patch.object(subject, 'abort', return_value={'verified': True}) as abort:
            with self.assertRaises(OSError): subject.prepare_window()
            abort.assert_called_once()

    def test_duplicate_root_json_cannot_replace_private_receipt_fields(self):
        with self.assertRaises(ValueError): m.strict_json('{"mode":"network-denial","mode":"synthetic"}')
        with self.assertRaises(ValueError): m.strict_json('{"hardDeadlineUnix":NaN}')

    def test_a_pid_seen_only_after_the_case_does_not_qualify_its_actions(self):
        def change(proof, lease, identity):
            for row in proof['samples']: row['applications'] = []
            future = copy.deepcopy(proof['samples'][-1])
            future.update(observedUnix=EPOCH + 31, observedMonotonic=131)
            future['watchdog']['observedMonotonic'] = 131
            future['applications'] = [{'processID': 123, 'parentPID': 1, 'startUTC': dt.datetime.fromtimestamp(EPOCH + 20, dt.timezone.utc).strftime('%a %b %d %H:%M:%S %Y'), 'processImagePath': IMAGE, 'arguments': ['-GlobalSearchNativeTraceNamespace', NS]}]
            proof['samples'].append(future)
        self.bad_transport(change)

    def test_replayed_negative_probe_cannot_replace_a_fresh_final_probe(self):
        self.bad_transport(lambda p, l, i: p['probes'].__setitem__(8, copy.deepcopy(p['probes'][4])))


    def probe_build(self, kind='simulator'):
        source = {'path': '/original/OfflineTransportProbe.swift', 'bytes': 8000, 'sha256': 'a' * 64}
        binary = {'path': '/original/probe-' + kind, 'bytes': 100000, 'sha256': 'b' * 64}
        row = {'probe': {'environment': kind}, 'source': source, 'binary': binary}
        compiled = {'schema': 'otzaria.independent-foundation-probe-build/1', 'status': 'COMPILED_ONLY_NO_NETWORK_OR_NATIVE_UI',
                    'source': source, 'compilerDriverSource': {'sha256': 'c' * 64}, 'originalSourceUnchanged': True,
                    'builds': [{'kind': kind, 'exit': 0, 'codeSignVerify': {'exit': 0}, 'binary': binary, 'sdkVersion': '27.0',
                                'actualPlatform': 'IOSSIMULATOR' if kind == 'simulator' else 'MACOS',
                                'command': ['xcrun', '--sdk', 'iphonesimulator' if kind == 'simulator' else 'macosx', 'swiftc']}]}
        return row, compiled

    def test_original_probe_build_retains_its_actual_kind_and_current_source(self):
        for kind in ('host', 'simulator'):
            row, compiled = self.probe_build(kind)
            m.validate_probe_build(row, compiled, source_sha='a' * 64, driver_sha='c' * 64)

    def test_other_sdk_cannot_qualify_probe_readback(self):
        row, compiled = self.probe_build(); compiled['builds'][0]['sdkVersion'] = '26.0'
        with self.assertRaises(ValueError): m.validate_probe_build(row, compiled, source_sha='a' * 64, driver_sha='c' * 64)

    def test_host_probe_binary_cannot_substitute_for_simulator(self):
        row, compiled = self.probe_build(); compiled['builds'][0]['actualPlatform'] = 'MACOS'
        with self.assertRaises(ValueError): m.validate_probe_build(row, compiled, source_sha='a' * 64, driver_sha='c' * 64)

    def test_old_probe_driver_cannot_qualify_current_closure(self):
        row, compiled = self.probe_build(); compiled['compilerDriverSource']['sha256'] = 'd' * 64
        with self.assertRaises(ValueError): m.validate_probe_build(row, compiled, source_sha='a' * 64, driver_sha='c' * 64)


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    record = {'scope': 'SYNTHETIC_SOURCE_VALIDATOR_CONTROLS_ONLY_NO_MAC_PF_NETWORK_OR_UI',
              'testsRun': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
              'sourceSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'nativeExecutions': 0, 'networkDenialWindows': 0}
    (HERE / 'SOURCE_CONTROLS.json').write_text(json.dumps(record, indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
