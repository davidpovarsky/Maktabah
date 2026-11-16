"""Verify exact-device cleanup and timeout recovery without touching a device."""
import json
from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import patch
import uuid


class SimulatorCleanupTests(unittest.TestCase):
    def setUp(self):
        self.udid = str(uuid.uuid4()).upper()
        self.path = str(Path(__file__).with_name("shutdown-faithful-simulator.py"))

    def inventory(self, state):
        return json.dumps({"devices": {"runtime": [{"udid": self.udid, "state": state}]}})

    def execute(self, states, code=0):
        with patch("sys.argv", [self.path, self.udid]), \
             patch("subprocess.check_output", side_effect=states), \
             patch("subprocess.run", return_value=subprocess.CompletedProcess([], code, "", "error")) as command:
            runpy.run_path(self.path, run_name="__main__")
            return command

    def test_already_shutdown_never_mutates(self):
        self.execute([self.inventory("Shutdown")]).assert_not_called()

    def test_booted_only_exact_owned_target_then_verify(self):
        command = self.execute([self.inventory("Booted"), self.inventory("Shutdown")])
        command.assert_called_once_with(["xcrun", "simctl", "shutdown", self.udid],
                                        capture_output=True, text=True, timeout=180)

    def test_inventory_timeout_still_attempts_exact_shutdown_and_verifies(self):
        command = self.execute([subprocess.TimeoutExpired("inventory", 45), self.inventory("Shutdown")])
        self.assertEqual(command.call_args.args[0], ["xcrun", "simctl", "shutdown", self.udid])

    def test_failure_or_unverified_final_state_is_never_success(self):
        for states, code in [([self.inventory("Booted"), self.inventory("Booted")], 1),
                             ([self.inventory("Booted"), self.inventory("Booted")], 0)]:
            with self.subTest(code=code), self.assertRaises(SystemExit):
                self.execute(states, code)

    def test_final_inventory_timeout_remains_failure(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.execute([self.inventory("Booted"), subprocess.TimeoutExpired("inventory", 45)])


if __name__ == "__main__":
    unittest.main()
