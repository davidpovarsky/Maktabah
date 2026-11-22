#!/usr/bin/env python3
"""One finite invocation of only the new Live diagnostic controls."""
import ast
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import sys
import time
import unittest
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
RESULT = ROOT / "python-result.json"
assert not RESULT.exists(), "Preserve an existing diagnostic control execution"
rows = [
    ("inputs/Scripts/CI/runtime27-hanlin-live.py", "e0792b38284dd517551c2312455904a3ef849269f3790953b38d8a9e16ff7a75"),
    ("inputs/Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift", "6cb67796a458fba8bbfee94d584b30744fb57b246d679aa4b909c2216ccd4c15"),
    ("preimage/Scripts/CI/runtime27-hanlin-live.py", "a23383137ac9b52398a75ae50098411422958c6090a97bb0889a1440edbd9aff"),
    ("diagnostic_boundary_controls.py", None), ("run_diagnostic_controls.py", None),
]
inputs = []
for relative, expected in rows:
    raw = (ROOT / relative).read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    assert expected is None or sha == expected, relative
    inputs.append({"path": relative, "bytes": len(raw), "sha256": sha})
(ROOT / "PYTHON_INPUTS.json").write_text(json.dumps({"schemaVersion": 1, "inputs": inputs}, indent=2) + "\n")
candidate = ROOT / rows[0][0]
ast.parse(candidate.read_bytes(), filename=str(candidate))
metadata = {"startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "pid": os.getpid(), "platform": platform.platform(), "python": sys.version,
            "pythonExecutable": sys.executable, "executableResolved": str(Path(sys.executable).resolve()),
            "executableSHA256": hashlib.sha256(Path(sys.executable).resolve().read_bytes()).hexdigest(),
            "completeCandidateAST": "PASS", "inputs": inputs}
spec = importlib.util.spec_from_file_location("new_live_diagnostic_controls", ROOT / "diagnostic_boundary_controls.py")
controls = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controls)
suite = unittest.defaultTestLoader.loadTestsFromTestCase(controls.DiagnosticBoundaryTests)
assert suite.countTestCases() == 34
records = {}
class RecordingResult(unittest.TextTestResult):
    def startTest(self, test):
        records[test.id()] = {"name": test.id(), "startedMonotonic": time.monotonic(), "status": "RUNNING"}
        super().startTest(test)
    def stopTest(self, test):
        row = records[test.id()]
        row["elapsedSeconds"] = time.monotonic() - row.pop("startedMonotonic")
        super().stopTest(test)
    def addSuccess(self, test):
        records[test.id()]["status"] = "PASS"; super().addSuccess(test)
    def addError(self, test, err):
        records[test.id()]["status"] = "ERROR"; super().addError(test, err)
    def addFailure(self, test, err):
        records[test.id()]["status"] = "FAIL"; super().addFailure(test, err)
    def addSubTest(self, test, subtest, err):
        if err is not None:
            records[test.id()]["status"] = "FAIL"
        super().addSubTest(test, subtest, err)
started = time.monotonic()
result = unittest.TextTestRunner(verbosity=2, resultclass=RecordingResult).run(suite)
unchanged = []
for row in inputs:
    raw = (ROOT / row["path"]).read_bytes()
    assert len(raw) == row["bytes"] and hashlib.sha256(raw).hexdigest() == row["sha256"], row["path"]
    unchanged.append(row["path"])
payload = dict(metadata, status="PASS" if result.wasSuccessful() else "FAIL",
               elapsedSeconds=time.monotonic()-started, namedTests=result.testsRun,
               failures=len(result.failures), errors=len(result.errors), skipped=len(result.skipped),
               cases=list(records.values()), observations=controls.OBSERVATIONS,
               unchangedInputs=unchanged,
               scope="Real complete candidate Python validator/capture/admission and POSIX filesystem boundaries. "
                     "Synthetic public canaries only. Three complete-main cases use explicit external source/matrix probes. "
                     "No source checkout edits, original Native tests, Simulator, UI, provider, credential, CI, network or RPC execution.",
               completedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
RESULT.write_text(json.dumps(payload, indent=2) + "\n")
print(json.dumps({key: payload[key] for key in ["status", "namedTests", "failures", "errors", "skipped", "elapsedSeconds", "completeCandidateAST"]}))
sys.exit(0 if result.wasSuccessful() else 1)

