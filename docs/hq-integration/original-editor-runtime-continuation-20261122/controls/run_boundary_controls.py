"""Run only the new optional schema 2 admission boundaries, once per output path."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest


def identity(path, root):
    raw = path.read_bytes()
    return {"path": path.relative_to(root).as_posix(), "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest()}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=False)
    inputs = sorted([*root.glob("candidate/Scripts/CI/*.py"), *root.glob("controls/*.py"),
                     *root.glob("controls/original-dotfiles/*"), root / "FRAMEWORK_PRODUCER.json"])
    before = [identity(path, root) for path in inputs]
    (args.output / "SOURCE_INPUTS.json").write_text(json.dumps(before, indent=2) + "\n")
    spec = importlib.util.spec_from_file_location("schema2_boundaries", root / "controls/test_schema2_admission.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    suite = unittest.defaultTestLoader.loadTestsFromModule(module)
    expected = sorted(test.id() for group in suite for test in group)
    if len(expected) != 20 or len(set(expected)) != 20:
        raise RuntimeError("Expected exactly the 20 new schema 2 boundaries")
    started, passed = [], []

    class Result(unittest.TextTestResult):
        def startTest(self, test):
            started.append(test.id())
            print(json.dumps({"event": "start", "id": test.id()}), flush=True)
            super().startTest(test)

        def addSuccess(self, test):
            passed.append(test.id())
            print(json.dumps({"event": "pass", "id": test.id()}), flush=True)
            super().addSuccess(test)

    result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite)
    after = [identity(path, root) for path in inputs]
    complete = (result.wasSuccessful() and result.testsRun == 20 and sorted(started) == expected
                and sorted(passed) == expected and not result.skipped and before == after)
    receipt = {
        "status": "PASS_20_NEW_SCHEMA2_ADMISSION_BOUNDARIES" if complete else "FAIL",
        "scope": "Synthetic GitHub metadata, qualification and ZIP boundaries using actual admission functions; exact original dotfile bytes. No SDK/native/app runtime execution.",
        "python": sys.version, "executable": sys.executable,
        "expected_ids": expected, "started_ids": started, "passed_ids": passed,
        "tests_run": result.testsRun, "failures": [test.id() for test, _ in result.failures],
        "errors": [test.id() for test, _ in result.errors], "skipped": result.skipped,
        "source_inputs": before, "source_unchanged": before == after,
        "framework_builds": 0, "simulator_attempts": 0, "prior_controls_replayed": 0,
    }
    (args.output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
