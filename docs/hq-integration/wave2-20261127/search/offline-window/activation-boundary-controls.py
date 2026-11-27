#!/usr/bin/env python3
"""Regression controls for the actual watchdog function; all OS effects mocked."""
import argparse
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output-directory', type=Path, required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('offline_boundary_subject', args.source)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
IDENTIFIER = '0123456789abcdef0123456789abcdef'

class BoundaryControls(unittest.TestCase):
    def exercise(self, change, deadline=200, after_labels=False):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            state = {'mono': 100.0, 'unix': 1000.0, 'alive': True, 'boot': 'boot', 'loaded': False,
                     'changed': False}
            sealed = {'windowID': IDENTIFIER, 'bootSession': 'boot', 'preparedMonotonic': 100,
                      'hardDeadlineMonotonic': deadline, 'controller': {'pid': 100},
                      'lease': {'mode': 'network-denial', 'hardDeadlineUnix': deadline + 900,
                                'controls': [], 'translatedVNC': []},
                      'baseline': {'pf': {}, 'network': {}}, 'normalizedRules': 'owned'}
            m.private_write(directory / 'heartbeat.json', {'bootSession': 'boot', 'observedMonotonic': 100, 'nonce': 'initial'})
            m.private_write(directory / 'activate-request.json', {})
            original_write, calls = m.private_write, []
            def maybe_change():
                if not state['changed']:
                    state['changed'] = True
                    change(state, directory, sealed)
            def snapshot(*unused):
                if not after_labels:
                    maybe_change()
                return {}
            def pf(*command):
                calls.append(command)
                if '-f' in command:
                    state['loaded'] = True
                    return ''
                if '-F' in command:
                    state['loaded'] = False
                    return ''
                if command[-2:] == ('-s', 'labels'):
                    if after_labels:
                        maybe_change()
                    return 'counter'
                return 'owned' if state['loaded'] else ''
            def write(path, value, replace=False):
                result = original_write(path, value, replace)
                if Path(path).name == 'status.json':
                    original_write(directory / 'finish-request.json', {}, replace=True)
                return result
            with patch.object(m, 'load_sealed', return_value=(directory, sealed)), \
                 patch.object(m, 'private_write', side_effect=write), \
                 patch.object(m, 'process', return_value={'pid': 200}), \
                 patch.object(m, 'process_is_same', side_effect=lambda unused: state['alive']), \
                 patch.object(m, 'boot_identity', side_effect=lambda: state['boot']), \
                 patch.object(m, 'pf_snapshot', side_effect=snapshot), \
                 patch.object(m, 'network_snapshot', return_value={}), \
                 patch.object(m, 'connections', return_value=[]), \
                 patch.object(m, 'admit_connections', return_value=[]), \
                 patch.object(m, 'pf', side_effect=pf), \
                 patch.object(m.time, 'monotonic', side_effect=lambda: state['mono']), \
                 patch.object(m.time, 'time', side_effect=lambda: state['unix']), \
                 patch.object(m.time, 'sleep', return_value=None):
                try:
                    m.watchdog(IDENTIFIER)
                except Exception:
                    # Any fail-closed implementation may raise after its owned
                    # rollback; the contract under test is absence of late load.
                    pass
            self.assertFalse(state['loaded'], 'Even a failing control must finish with its owned mock rules empty')
            cleanup = json.loads((directory / 'cleanup.json').read_text())
            status = json.loads((directory / 'status.json').read_text()) if (directory / 'status.json').exists() else None
            return calls, cleanup, status

    def rejected_before_load(self, change, deadline=200):
        calls, cleanup, _ = self.exercise(change, deadline)
        self.assertFalse(any('-f' in command for command in calls), 'Ineligible state reached the actual mutating PF call')
        self.assertFalse(cleanup['activated'])

    def test_monotonic_deadline_crossed_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: s.update(mono=111, unix=1011), deadline=110)

    def test_wall_deadline_crossed_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: s.update(mono=101, unix=1101))

    def test_controller_dies_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: s.update(alive=False))

    def test_heartbeat_removed_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: (d / 'heartbeat.json').unlink())

    def test_heartbeat_expires_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: m.private_write(d / 'heartbeat.json',
            {'bootSession': 'boot', 'observedMonotonic': 60, 'nonce': 'old'}, replace=True))

    def test_boot_changes_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: s.update(boot='other'))

    def test_finish_arrives_during_preflight_never_loads(self):
        self.rejected_before_load(lambda s, d, v: m.private_write(d / 'finish-request.json', {}))

    def test_slow_preflight_cannot_reset_observation_gap_as_fresh(self):
        self.rejected_before_load(lambda s, d, v: s.update(mono=109, unix=1009))

    def test_slow_post_load_counters_do_not_publish_a_fresh_status(self):
        calls, cleanup, status = self.exercise(lambda s, d, v: s.update(mono=109, unix=1009), after_labels=True)
        self.assertTrue(any('-f' in command for command in calls), 'This fixture must exercise an actual mock activation')
        self.assertTrue(cleanup['activated'])
        self.assertIsNone(status, 'Stale observations were published with a fresh status timestamp')

suite = unittest.defaultTestLoader.loadTestsFromTestCase(BoundaryControls)
result = unittest.TextTestRunner(verbosity=2).run(suite)
args.output_directory.mkdir(parents=True, exist_ok=True)
record = {'scope': 'SYNTHETIC_ACTUAL_WATCHDOG_SOURCE_CONTROL_NO_PF_LAUNCHD_NETWORK_OR_UI',
          'sourceSHA256': m.digest(args.source.read_bytes()), 'testsRun': result.testsRun,
          'failures': len(result.failures), 'errors': len(result.errors), 'success': result.wasSuccessful(),
          'nativeExecutions': 0, 'denialWindows': 0}
(args.output_directory / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n')
raise SystemExit(0 if result.wasSuccessful() else 1)
