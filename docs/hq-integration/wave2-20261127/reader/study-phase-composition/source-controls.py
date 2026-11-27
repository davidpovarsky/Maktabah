#!/usr/bin/env python3
"""Source-only ordinary/denied-phase ordering controls with explicit doubles.

No network, SSH, PF, Apple command, corpus, Simulator or XCTest is run. These
controls exercise the real root controller and its bounded private file parser.
The retained original controller checks are reused without changing their bytes.
"""
import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(add_help=False)
parser.add_argument('--candidate', type=Path, default=HERE / 'production-study-v40-ui.py')
parser.add_argument('--original-controls', type=Path,
                    default=HERE.parent / 'study-ui-driver-draft/test_study_ui_driver.py')
args, rest = parser.parse_known_args()
spec = importlib.util.spec_from_file_location('original_study_controls', args.original_controls.resolve(strict=True))
BASE = importlib.util.module_from_spec(spec)
with patch.object(sys, 'argv', [str(args.original_controls), '--candidate', str(args.candidate)]):
    spec.loader.exec_module(BASE)
D = BASE.DRIVER


class OfflineScenario(BASE.Scenario):
    def __init__(self, root, engine='zayit'):
        super().__init__(root, 'offline-' + engine)
        self.fail_at = None
        self.aborts = 0
        self.native_budget = None
        s = self

        class OfflineHost:
            def __init__(self, **kwargs):
                self.output, self.case = kwargs['output_directory'], kwargs['case_directory']
                self.transport = None
                self.output.mkdir()
                s.events.append('offline-constructed')
            def prepare_window(self):
                s.step('prepare')
            def run_native_actions(self, callback):
                s.step('active-denial')
                return callback(421)
            def finish_transport(self):
                s.step('restore-transport')
                self.transport = {'scope': 'synthetic restored-window control'}
            def seal_case(self, **kwargs):
                s.step('seal-offline')
                if self.transport is None or 'verify-original' not in s.events:
                    raise ValueError('Offline case sealed before original verification/restoration')
                path = self.output / 'CASE_RESULT.private.json'
                BASE.write(path, {'scope': 'synthetic case control only'})
                return {'witness': BASE.witness(path)}
            def record_failure(self, error):
                s.events.append('failure-receipt')
                return {'scope': 'synthetic failure control'}
            def abort(self):
                s.aborts += 1
                s.step('abort-offline')
                return {'verified': not s.cleanup_failure}

        class Rendezvous:
            def __init__(self, **kwargs):
                pass
            def coordinated_inputs(self):
                s.step('real-coordination-input')
                return {'lease': BASE.witness(s.pages_file), 'coordination': BASE.witness(s.pages_file),
                        'hostProbe': {}, 'simulatorProbe': {}}
            def prepared(self, value):
                pass
            def restored(self, host):
                if host.transport is None:
                    raise ValueError('Relay requested before restoration')
                s.step('relay-readback')
                return BASE.witness(s.pages_file)
            def emit(self, event, **payload):
                s.events.append('event:' + event)
                if payload.get('rootFinalResultPending') is not True:
                    raise ValueError('Intermediate event misrepresents final root checks')
                return payload

        self.rendezvous = Rendezvous
        self.modules['study-ui-offline-execution.py'] = NS(OfflineStudyCase=OfflineHost,
            OFFLINE_PHASE_PASS='SYNTHETIC_ORIGINAL_OFFLINE_PHASE_CONTROL',
            OFFLINE_NETWORK_SCOPE='synthetic network control only')

    def step(self, stage):
        self.events.append(stage)
        if self.fail_at == stage:
            raise ValueError('Synthetic failure at ' + stage)

    def native(self, core, test_run, udid, case, allowance, output, environment,
               private_values=(), *, host_timeout_seconds=None):
        self.native_calls += 1
        self.native_budget = host_timeout_seconds
        self.asserted_allowance = allowance
        output.mkdir()
        attempt = {'case': case, 'case_directory': str(output), 'xcodebuild_exit': 0,
                   'host_timeout_seconds': host_timeout_seconds}
        BASE.write(output / 'RUN_ATTEMPT.json', attempt)
        self.step('native-actions')
        return attempt

    def verify(self, core, udid, attempt):
        self.step('verify-original')
        value = {**attempt, 'passed': not self.native_failure}
        BASE.write(Path(attempt['case_directory']) / 'RESULT.json', value)
        return value

    def run(self):
        execute = D.execute
        def with_offline_arg(arguments):
            arguments.offline_coordinator_wait_seconds = 300
            return execute(arguments)
        with patch.multiple(D, OfflineRendezvous=self.rendezvous,
                            run_original_native_actions=self.native, verify_original_case=self.verify,
                            execute=with_offline_arg):
            return super().run()


class OfflineFlow(unittest.TestCase):
    def scenario(self, engine='zayit'):
        temp = tempfile.TemporaryDirectory(prefix='offline-root-source-control-')
        self.addCleanup(temp.cleanup)
        return OfflineScenario(Path(temp.name), engine)

    def test_two_engines_restore_before_original_export_and_final_checks(self):
        for engine in ('zayit', 'otzaria'):
            with self.subTest(engine=engine):
                s = self.scenario(engine); error, result = s.run()
                self.assertIsNone(error)
                self.assertEqual(result['status'], 'SYNTHETIC_ORIGINAL_OFFLINE_PHASE_CONTROL')
                ordered = ['real-coordination-input', 'prepare', 'active-denial', 'native-actions',
                           'restore-transport', 'relay-readback', 'verify-original', 'seal-offline',
                           'abort-offline', 'event:CONTROLLER_POSTCHECKS_PENDING', 'images-verified', 'simulator-retained']
                self.assertEqual([e for e in s.events if e in ordered], ordered)
                self.assertEqual(s.asserted_allowance, 1800)
                self.assertEqual(s.native_budget, 421)
                self.assertEqual(s.aborts, 1)
                self.assertNotIn('offline-' + engine, D.PRE_UPDATE_PHASES)

    def test_each_failed_stage_aborts_and_never_passes_or_seals_early(self):
        for stage in ('prepare', 'active-denial', 'native-actions', 'restore-transport',
                      'relay-readback', 'verify-original', 'seal-offline'):
            with self.subTest(stage=stage):
                s = self.scenario(); s.fail_at = stage; error, result = s.run()
                self.assertIsNotNone(error)
                self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')
                self.assertGreaterEqual(s.aborts, 1)
                self.assertLess(s.events.index('abort-offline'), s.events.index('simulator-retained'))
                self.assertIn('event:WINDOW_ABORTED', s.events)
                if stage != 'seal-offline':
                    self.assertNotIn('seal-offline', s.events)

    def test_bad_native_result_never_seals(self):
        s = self.scenario(); s.native_failure = True; error, result = s.run()
        self.assertIsNotNone(error); self.assertNotIn('seal-offline', s.events)
        self.assertIn('restore-transport', s.events)
        self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')

    def test_unverified_abort_prevents_simulator_shutdown(self):
        s = self.scenario(); s.fail_at = 'native-actions'; s.cleanup_failure = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertNotIn('simulator-retained', s.events)
        self.assertEqual(result['owned_cleanup']['status'], 'NOT_SHUT_DOWN_HOST_CLEANUP_UNVERIFIED')
        self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')

    def test_exception_while_aborting_prevents_simulator_shutdown(self):
        s = self.scenario(); s.fail_at = 'abort-offline'
        error, result = s.run()
        self.assertIsNotNone(error); self.assertNotIn('simulator-retained', s.events)
        self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')

    def test_source_change_after_native_cannot_become_final_phase_pass(self):
        s = self.scenario(); s.source_changed = True; error, result = s.run()
        self.assertIsNotNone(error)
        self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')
        self.assertTrue(any(x.startswith('source_build:') for x in result['post_verification_failures']))


class PrivateRendezvous(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='offline-private-parser-control-')
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.settings = NS(decode_json=json.loads)
        with patch.object(D, 'load_support', return_value=NS(private_write=BASE.write)):
            self.bridge = D.OfflineRendezvous(core=NS(OUT=self.path), settings=self.settings,
                offline=None, report={}, output=self.path, wait_seconds=1)

    def input(self, value, mode=0o600):
        p = self.bridge.directory / 'INPUT.private.json'
        BASE.write(p, value); p.chmod(mode)
        return p

    def valid(self):
        return {'schema': 'otzaria.offline-coordinator-input/1', 'requestID': self.bridge.request_id,
                'oracleRelay': {'scope': 'synthetic file parser only'}}

    def test_bounded_private_matching_response(self):
        value = self.valid(); self.input(value)
        self.assertEqual(self.bridge.receive('INPUT.private.json', {'oracleRelay'}), value)

    def test_other_request_rejected(self):
        value = self.valid(); value['requestID'] = 'b' * 32; self.input(value)
        with self.assertRaises(ValueError): self.bridge.receive('INPUT.private.json', {'oracleRelay'})

    def test_extra_field_rejected(self):
        value = self.valid(); value['accepted'] = True; self.input(value)
        with self.assertRaises(ValueError): self.bridge.receive('INPUT.private.json', {'oracleRelay'})

    def test_readable_by_other_users_rejected(self):
        self.input(self.valid(), 0o644)
        with self.assertRaises(ValueError): self.bridge.receive('INPUT.private.json', {'oracleRelay'})

    def test_hard_link_rejected(self):
        p = self.input(self.valid()); os.link(p, self.path / 'second-link')
        with self.assertRaises(ValueError): self.bridge.receive('INPUT.private.json', {'oracleRelay'})

    def test_symbolic_link_rejected(self):
        p = self.input(self.valid()); q = self.path / 'original'; p.rename(q); p.symlink_to(q)
        with self.assertRaises(ValueError): self.bridge.receive('INPUT.private.json', {'oracleRelay'})

    def test_oversized_input_rejected(self):
        value = self.valid(); value['oracleRelay'] = 'x' * 131073; self.input(value)
        with self.assertRaises(ValueError): self.bridge.receive('INPUT.private.json', {'oracleRelay'})


if __name__ == '__main__':
    suite = unittest.TestSuite([
        unittest.defaultTestLoader.loadTestsFromTestCase(BASE.ControllerChecks),
        unittest.defaultTestLoader.loadTestsFromTestCase(OfflineFlow),
        unittest.defaultTestLoader.loadTestsFromTestCase(PrivateRendezvous),
    ])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    receipt = {'scope': 'Source-only root lifecycle and real local private-file parsing with explicit synthetic device/UI/SDK/PF/relay doubles',
               'testsRun': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
               'candidate': BASE.witness(args.candidate), 'originalControlRecipe': BASE.witness(args.original_controls),
               'nativeExecutions': 0, 'SSHExecutions': 0, 'PFChanges': 0, 'corpusQueries': 0, 'acceptanceClaimed': False}
    print(json.dumps(receipt, indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
