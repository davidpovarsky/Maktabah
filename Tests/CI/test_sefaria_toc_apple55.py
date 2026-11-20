#!/usr/bin/env python3
"""Source/CI controls only; synthetic receipts never claim Apple or Native execution."""
import ast
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
BASE = "f3401ec1597e1d882d2e2c6db9492ed211058712"


def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gate = load("apple_gate", "Scripts/CI/sefaria-toc-apple55.py")
driver = load("transport_driver", "tools/hq-sefaria-toc-transport.py")


def inventory(source):
    tree = ast.parse(source)
    function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "main")
    chosen = [n for n in function.body if isinstance(n, ast.Assign)
              and any(isinstance(t, ast.Name) and t.id in {"common", "modes", "lifetime"} for t in n.targets)
              and not isinstance(n.value, ast.IfExp)]
    values = {}
    exec(compile(ast.Module(body=chosen, type_ignores=[]), "<original case inventory>", "exec"), values)
    return {**values["modes"], **values["lifetime"]}


def blob(relative):
    return subprocess.check_output(["git", "show", BASE + ":" + relative], cwd=ROOT)


class ReceiptControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="apple55-gate-controls-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.names = inventory((ROOT / gate.DRIVER).read_text(encoding="utf-8"))
        self.sources = {}
        records = []
        appendix = (ROOT / gate.APPENDIX).read_bytes()
        for relative in gate.PRODUCTION:
            original = (ROOT / relative).read_bytes()
            self.sources[relative] = {"bytes": len(original), "sha256": gate.sha(original)}
            compiled = original + (b"\n" + appendix if relative == gate.PRODUCTION[-1] else b"")
            target = self.root / "inputs" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(compiled)
            records.append({"path": relative, "bytes": len(original), "sha256": gate.sha(original),
                            "snapshotSHA256": gate.sha(compiled), "originalWholePrefixExact": True})
        self.sources[gate.APPENDIX] = {"bytes": len(appendix), "sha256": gate.sha(appendix)}
        records.append({"path": gate.APPENDIX, **self.sources[gate.APPENDIX]})
        self.write("INPUTS.json", records)
        self.write("CASES_EXPECTED.json", self.names)
        modes = {}
        for mode, names in self.names.items():
            (self.root / mode).mkdir()
            self.write(mode + "/CASES.json", [{"name": name, "passed": True} for name in names])
            modes[mode] = {"returncode": 0, "executed": len(names), "passed": len(names), "failed": []}
        self.result = {"status": "PASS", "modeSelection": "transport-and-lifetime",
                       "httpSnapshot": None, "inputHashesUnchanged": True, "executed": 55, "passed": 55,
                       "compile": {"returncode": 0}, "modes": modes, "native": "NOT_RUN",
                       "appleSDK": "NOT_RUN"}
        self.write("RESULT.json", self.result)

    def write(self, relative, value):
        gate.write_json(self.root / relative, value)

    def assertRejected(self):
        with self.assertRaises((RuntimeError, KeyError, FileNotFoundError)):
            gate.verify_driver_result(self.root, self.sources)

    def test_complete_exact_synthetic_receipt_checks_shape_without_native_credit(self):
        observed = gate.verify_driver_result(self.root, self.sources)
        self.assertEqual(observed["native"], "NOT_RUN")
        self.assertEqual(observed["appleSDK"], "NOT_RUN")

    def test_driver_failure_cannot_be_a_gate_pass(self):
        self.result["status"] = "FAIL"; self.write("RESULT.json", self.result); self.assertRejected()

    def test_lifetime_only_is_not_55(self):
        self.result["modeSelection"] = "lifetime-only"; self.write("RESULT.json", self.result); self.assertRejected()

    def test_snapshot_override_is_not_current_source(self):
        self.result["httpSnapshot"] = "historical.swift"; self.write("RESULT.json", self.result); self.assertRejected()

    def test_mutated_source_receipt_is_rejected(self):
        self.result["inputHashesUnchanged"] = False; self.write("RESULT.json", self.result); self.assertRejected()

    def test_partial_count_is_rejected(self):
        self.result["executed"] = 52; self.write("RESULT.json", self.result); self.assertRejected()

    def test_compiler_failure_is_rejected(self):
        self.result["compile"]["returncode"] = 1; self.write("RESULT.json", self.result); self.assertRejected()

    def test_missing_lifetime_mode_is_rejected(self):
        del self.result["modes"]["lifetime"]; self.write("RESULT.json", self.result); self.assertRejected()

    def test_mode_nonzero_return_is_rejected(self):
        self.result["modes"]["cancel-held"]["returncode"] = 9; self.write("RESULT.json", self.result); self.assertRejected()

    def test_duplicate_actual_leaf_is_rejected(self):
        names = self.names["failure-retry"]
        rows = [{"name": name, "passed": True} for name in names]
        rows[-1] = copy.deepcopy(rows[0])
        self.write("failure-retry/CASES.json", rows); self.assertRejected()

    def test_failed_actual_leaf_is_rejected_despite_summary(self):
        rows = [{"name": name, "passed": True} for name in self.names["cancel-held"]]
        rows[0]["passed"] = False
        self.write("cancel-held/CASES.json", rows); self.assertRejected()

    def test_missing_actual_leaf_is_rejected(self):
        self.write("lifetime/CASES.json", [{"name": name, "passed": True}
                                         for name in self.names["lifetime"][:-1]])
        self.assertRejected()

    def test_duplicate_expected_inventory_is_rejected(self):
        self.names["lifetime"][-1] = self.names["lifetime"][0]
        self.write("CASES_EXPECTED.json", self.names); self.assertRejected()

    def test_missing_eighth_production_source_is_rejected(self):
        records = json.loads((self.root / "INPUTS.json").read_text())
        del records[-2]
        self.write("INPUTS.json", records); self.assertRejected()

    def test_original_whole_prefix_change_is_rejected(self):
        path = self.root / "inputs" / gate.PRODUCTION[0]
        path.write_bytes(b"// changed\n" + path.read_bytes()); self.assertRejected()

    def test_unexpected_nonhttp_appendix_is_rejected_even_with_updated_snapshot(self):
        path = self.root / "inputs" / gate.PRODUCTION[0]
        path.write_bytes(path.read_bytes() + b"\n// extra")
        records = json.loads((self.root / "INPUTS.json").read_text())
        records[0]["snapshotSHA256"] = gate.sha(path.read_bytes())
        self.write("INPUTS.json", records); self.assertRejected()

    def test_changed_test_appendix_is_rejected(self):
        path = self.root / "inputs" / gate.PRODUCTION[-1]
        path.write_bytes(path.read_bytes() + b"\n"); self.assertRejected()

    def test_raw_preservation_keeps_inputs_proofs_and_logs_but_not_executable(self):
        (self.root / "compile.stdout.log").write_bytes(b"actual partial\n")
        (self.root / "toc-transport-foundation.exe").write_bytes(b"synthetic excluded binary")
        output = self.root.parent / (self.root.name + "-copied")
        self.addCleanup(__import__("shutil").rmtree, output, True)
        records = gate.preserve_raw(self.root, output)
        self.assertEqual((output / "compile.stdout.log").read_bytes(), b"actual partial\n")
        self.assertFalse((output / "toc-transport-foundation.exe").exists())
        self.assertTrue(any(row["path"].startswith("inputs/") for row in records))
        for row in records:
            self.assertEqual(gate.sha((output / row["path"]).read_bytes()), row["sha256"])


class DriverFailureControls(unittest.TestCase):
    def test_real_python_timeout_preserves_partial_stdout_stderr(self):
        with tempfile.TemporaryDirectory(prefix="apple55-output-timeout-") as name:
            folder = Path(name)
            command = [sys.executable, "-u", "-c",
                       "import sys,time;print('partial-out',flush=True);print('partial-err',file=sys.stderr,flush=True);time.sleep(10)"]
            with self.assertRaises(subprocess.TimeoutExpired):
                driver.run_captured(command, folder, "probe", 1)
            self.assertIn(b"partial-out", (folder / "probe.stdout.log").read_bytes())
            self.assertIn(b"partial-err", (folder / "probe.stderr.log").read_bytes())

    def test_real_python_failure_retains_nonzero_code_and_raw_output(self):
        with tempfile.TemporaryDirectory(prefix="apple55-output-fail-") as name:
            folder = Path(name)
            result = driver.run_captured([sys.executable, "-c",
                "import sys;print('failure-out');print('failure-err',file=sys.stderr);sys.exit(7)"], folder, "probe", 5)
            self.assertEqual(result.returncode, 7)
            self.assertIn(b"failure-out", result.stdout)
            self.assertIn(b"failure-err", result.stderr)

    def test_timed_out_second_mode_retains_first_verified26_and_marks_unknown_partial(self):
        with tempfile.TemporaryDirectory(prefix="apple55-accounting-") as name:
            folder = Path(name); output = folder / "out"; cache = folder / "cache"; cache.mkdir()

            def controlled_command(command, destination, prefix, timeout):
                # Deliberate Python orchestration double; never invokes Swift or C.
                if prefix == "compile":
                    (output / "toc-transport-foundation.exe").write_bytes(b"not executable test double")
                    return subprocess.CompletedProcess(command, 0, b"", b"")
                if command[1] == "failure-retry":
                    names = json.loads((output / "CASES_EXPECTED.json").read_text())["failure-retry"]
                    return subprocess.CompletedProcess(command, 0,
                        json.dumps([{"name": value, "passed": True} for value in names]).encode(), b"")
                raise subprocess.TimeoutExpired(command, timeout)

            arguments = ["driver", "--root", str(ROOT), "--output", str(output), "--module-cache", str(cache)]
            with patch.object(sys, "argv", arguments), patch.object(driver, "run_captured", controlled_command), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(driver.main(), 1)
            result = json.loads((output / "RESULT.json").read_text())
            self.assertEqual(result["status"], "ERROR")
            self.assertEqual(result["executed"], 26)
            self.assertEqual(result["passed"], 26)
            self.assertTrue(result["timedOut"])
            self.assertEqual(result["unverifiedPartialMode"], "cancel-held")
            self.assertEqual(list(result["modes"]), ["failure-retry"])
            commands = json.loads((output / "COMMANDS.json").read_text())
            self.assertEqual([row["mode"] for row in commands["runtime"]], ["failure-retry", "cancel-held"])

    def test_all55_original_names_and_time_bounds_unchanged(self):
        before = blob(gate.DRIVER).decode()
        after = (ROOT / gate.DRIVER).read_text(encoding="utf-8")
        self.assertEqual(inventory(before), inventory(after))
        self.assertEqual({name: len(rows) for name, rows in inventory(after).items()}, gate.MODE_COUNTS)
        self.assertIn('run_captured(cmd,out,"compile",180)', after)
        self.assertIn('run_captured(command,folder,"runtime",20)', after)


class SourceIdentityControls(unittest.TestCase):
    def test_invalid_or_wrong_checkout_fails_before_source_reads(self):
        with self.assertRaises(RuntimeError):
            gate.source_inputs(ROOT, "branch-name")
        with patch.object(gate.subprocess, "check_output", return_value=b"b" * 40 + b"\n"):
            with self.assertRaises(RuntimeError):
                gate.source_inputs(ROOT, "a" * 40)

    def test_changed_raw_file_rejected_against_immutable_git_blob(self):
        with tempfile.TemporaryDirectory(prefix="apple55-identity-") as name:
            root = Path(name)
            original = {}
            for relative in [*gate.PRODUCTION, gate.APPENDIX, gate.DRIVER, gate.LANGUAGE_DRIVER, gate.WRAPPER, gate.INTERRUPTION_HELPER]:
                raw = ("// owned identity fixture " + relative).encode()
                original[relative] = raw
                path = root / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)

            def git(command, cwd):
                return b"a" * 40 + b"\n" if command[1] == "rev-parse" else original[command[-1].split(":", 1)[1]]

            with patch.object(gate.subprocess, "check_output", git):
                self.assertEqual(len(gate.source_inputs(root, "a" * 40)), 13)
                (root / gate.PRODUCTION[-1]).write_bytes(b"changed")
                with self.assertRaises(RuntimeError):
                    gate.source_inputs(root, "a" * 40)

    def test_non_apple_host_cannot_issue_apple_acceptance(self):
        with tempfile.TemporaryDirectory(prefix="apple55-nonapple-") as name:
            root = Path(name)
            with patch.object(gate.sys, "platform", "win32"), contextlib.redirect_stdout(io.StringIO()):
                result = gate.main(["--expected-sha", "a" * 40,
                                    "--artifacts-dir", str(root / "evidence"), "--work-dir", str(root / "work")])
            self.assertEqual(result, 1)
            receipt = json.loads((root / "evidence/RESULT.json").read_text())
            self.assertEqual(receipt["executed"], 0)
            self.assertEqual(receipt["status"], "ERROR")
            self.assertEqual(receipt["native"], "NOT_RUN")


if __name__ == "__main__":
    unittest.main(verbosity=2)
