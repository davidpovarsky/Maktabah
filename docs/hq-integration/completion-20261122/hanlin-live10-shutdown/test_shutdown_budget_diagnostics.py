"""New budget/phase controls with explicit subprocess fixtures, not Apple tests."""
import ast
import contextlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
HELPER = HERE / 'candidate/Scripts/CI/shutdown-faithful-simulator.py'
MATRIX = HERE / 'candidate/Scripts/CI/run-faithful-ipad-matrix.py'
UDID = '06C41237-CB8E-455E-BF1A-B7777EBE53F9'


def inventory(value):
    return json.dumps({'devices': {'fixture-runtime': [{'udid': UDID, 'state': value}]}})


class ShutdownBudgetAndPhaseControls(unittest.TestCase):
    def invoke(self, states, outcome):
        output = io.StringIO()
        with patch('sys.argv', [str(HELPER), UDID]), \
             patch('subprocess.check_output', side_effect=states) as observed, \
             patch('subprocess.run', side_effect=outcome if isinstance(outcome, BaseException) else None,
                   return_value=None if isinstance(outcome, BaseException) else outcome) as shutdown, \
             patch('builtins.print', wraps=print) as printed, \
             contextlib.redirect_stdout(output):
            error = None
            try:
                runpy.run_path(str(HELPER), run_name='__main__')
            except BaseException as failure:
                error = failure
        events = [json.loads(line) for line in output.getvalue().splitlines() if line.startswith('{')]
        self.assertTrue(events)
        self.assertTrue(all(event['udid'] == UDID and event['event'] == 'owned_simulator_shutdown' for event in events))
        self.assertTrue(all(call.kwargs.get('flush') is True for call in printed.call_args_list))
        self.assertTrue(all(a['elapsed_seconds'] <= b['elapsed_seconds'] for a, b in zip(events, events[1:])))
        return observed, shutdown, events, error

    def test_recovery_parents_cover_complete_child_budget(self):
        helper = ast.parse(HELPER.read_text())
        child_calls = [node for node in ast.walk(helper) if isinstance(node, ast.Call)
                       and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name)
                       and node.func.value.id == 'subprocess']
        self.assertEqual(len(child_calls), 2)
        budgets = {node.func.attr: next(ast.literal_eval(k.value) for k in node.keywords if k.arg == 'timeout')
                   for node in child_calls}
        self.assertEqual(budgets, {'check_output': 45, 'run': 180})
        state_calls = [node for node in ast.walk(helper) if isinstance(node, ast.Call)
                       and isinstance(node.func, ast.Name) and node.func.id == 'state']
        self.assertEqual(len(state_calls), 2)
        child_maximum = 2 * budgets['check_output'] + budgets['run']
        self.assertEqual(child_maximum, 270)
        normal_parent_budgets = []
        for node in ast.walk(ast.parse(MATRIX.read_text())):
            if not isinstance(node, ast.Call) or not node.args:
                continue
            if not any(isinstance(n, ast.Constant) and n.value == 'Scripts/CI/shutdown-faithful-simulator.py'
                       for n in ast.walk(node.args[0])):
                continue
            timeout = next((k.value for k in node.keywords if k.arg == 'timeout'), None)
            if isinstance(timeout, ast.Constant):
                normal_parent_budgets.append(timeout.value)
        self.assertEqual(normal_parent_budgets, [300, 300, 300])
        self.assertTrue(all(budget >= child_maximum + 30 for budget in normal_parent_budgets))

    def test_nonzero_shutdown_race_uses_one_authoritative_postcondition(self):
        observed, shutdown, events, error = self.invoke(
            [inventory('Booted'), inventory('Shutdown')], subprocess.CompletedProcess([], 1, '', 'race'))
        self.assertIsNone(error)
        self.assertEqual(observed.call_count, 2)
        shutdown.assert_called_once_with(['xcrun', 'simctl', 'shutdown', UDID],
                                         capture_output=True, text=True, timeout=180)
        self.assertEqual([e['phase'] for e in events], ['INITIAL_STATE_REQUESTED', 'INITIAL_STATE_OBSERVED',
            'SHUTDOWN_REQUESTED', 'SHUTDOWN_RETURNED', 'FINAL_STATE_REQUESTED', 'FINAL_STATE_OBSERVED', 'SHUTDOWN_VERIFIED'])
        self.assertEqual(events[-2]['state'], 'Shutdown')

    def test_shutdown_timeout_leaves_flushed_failure_phase_without_acceptance(self):
        observed, shutdown, events, error = self.invoke(
            [inventory('Booted')], subprocess.TimeoutExpired(['xcrun', 'simctl', 'shutdown', UDID], 180))
        self.assertIsInstance(error, subprocess.TimeoutExpired)
        self.assertEqual(observed.call_count, 1)
        self.assertEqual(events[-1]['phase'], 'SHUTDOWN_FAILED')
        self.assertEqual(events[-1]['error_kind'], 'TimeoutExpired')
        self.assertNotIn('SHUTDOWN_VERIFIED', [e['phase'] for e in events])

    def test_postcondition_timeout_keeps_failure_and_exact_phase(self):
        observed, shutdown, events, error = self.invoke(
            [inventory('Booted'), subprocess.TimeoutExpired('fixture-inventory', 45)],
            subprocess.CompletedProcess([], 0, '', ''))
        self.assertIsInstance(error, subprocess.TimeoutExpired)
        self.assertEqual(observed.call_count, 2)
        self.assertEqual(events[-1]['phase'], 'FINAL_STATE_FAILED')
        self.assertNotIn('SHUTDOWN_VERIFIED', [e['phase'] for e in events])


if __name__ == '__main__':
    unittest.main(verbosity=2)
